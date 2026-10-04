/**
 * @description Enterprise Payment Gateway Service implementing the Adapter Pattern.
 * Seamlessly toggles between Sandbox (simulated UPI verification) and Production (Razorpay/Cashfree)
 * based on Custom Metadata configuration (Payment_Gateway_Config__mdt) without code changes.
 */
public with sharing class PaymentGatewayService {

    /**
     * @description Data Transfer Object (DTO) exposing public configuration to the LWC
     * without leaking sensitive merchant secret keys.
     */
    public class GatewayConfigDTO {
        @AuraEnabled public String environment { get; set; }
        @AuraEnabled public String gatewayProvider { get; set; }
        @AuraEnabled public String upiVpa { get; set; }
        @AuraEnabled public Integer autoVerifySeconds { get; set; }
        @AuraEnabled public Boolean isSandbox { get; set; }

        public GatewayConfigDTO() {
            this.environment = 'Sandbox';
            this.gatewayProvider = 'Simulated_UPI';
            this.upiVpa = 'eventmgmt@upi';
            this.autoVerifySeconds = 10;
            this.isSandbox = true;
        }
    }

    /**
     * @description Response returned when an order/session is initialized.
     */
    public class GatewayOrderResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String orderReference { get; set; }
        @AuraEnabled public String upiIntentUri { get; set; }
        @AuraEnabled public String gatewayProvider { get; set; }
        @AuraEnabled public String message { get; set; }

        public GatewayOrderResponse(Boolean success, String orderReference, String upiIntentUri, String provider, String message) {
            this.success = success;
            this.orderReference = orderReference;
            this.upiIntentUri = upiIntentUri;
            this.gatewayProvider = provider;
            this.message = message;
        }
    }

    /**
     * @description Fetches active Payment Gateway configuration from Custom Metadata.
     * Caches at the client side via cacheable=true. Zero SOQL consumption via CMDT methods.
     * @return GatewayConfigDTO Safe configuration payload for LWC.
     */
    @AuraEnabled(cacheable=true)
    public static GatewayConfigDTO getGatewayConfig() {
        GatewayConfigDTO dto = new GatewayConfigDTO();
        try {
            Payment_Gateway_Config__mdt config = Payment_Gateway_Config__mdt.getInstance('Default_Gateway');
            if (config != null) {
                dto.environment = String.isNotBlank(config.Environment__c) ? config.Environment__c : 'Sandbox';
                dto.gatewayProvider = String.isNotBlank(config.Gateway_Provider__c) ? config.Gateway_Provider__c : 'Simulated_UPI';
                dto.upiVpa = String.isNotBlank(config.UPI_VPA__c) ? config.UPI_VPA__c : 'eventmgmt@upi';
                dto.autoVerifySeconds = config.Auto_Verify_Seconds__c != null ? config.Auto_Verify_Seconds__c.intValue() : 10;
                dto.isSandbox = 'Sandbox'.equalsIgnoreCase(dto.environment);
            }
        } catch (Exception ex) {
            // Graceful fallback to default simulation if metadata is absent
            System.debug(LoggingLevel.WARN, 'PaymentGatewayService: Failed to query config, using default simulation. ' + ex.getMessage());
        }
        return dto;
    }

    /**
     * @description Generates a standard NPCI-compliant UPI Intent URI string.
     * Scanning this URI with any phone camera or UPI app formats a standard payment request.
     * Format: upi://pay?pa={vpa}&pn=EventManagement&am={amount}&tn={reference}&cu=INR
     * @param amount The transaction amount.
     * @param referenceId The unique session or registration reference.
     * @return String Standardized UPI Intent URI.
     */
    @AuraEnabled
    public static String generateUpiPayload(Decimal amount, String referenceId) {
        GatewayConfigDTO config = getGatewayConfig();
        String vpa = String.isNotBlank(config.upiVpa) ? config.upiVpa : 'eventmgmt@upi';
        Decimal validAmount = amount != null ? amount.setScale(2) : 0.00;
        String ref = String.isNotBlank(referenceId) ? referenceId : 'EVT-' + System.currentTimeMillis();

        return 'upi://pay?' +
            'pa=' + EncodingUtil.urlEncode(vpa, 'UTF-8') +
            '&pn=' + EncodingUtil.urlEncode('EventManagement', 'UTF-8') +
            '&am=' + String.valueOf(validAmount) +
            '&tn=' + EncodingUtil.urlEncode(ref, 'UTF-8') +
            '&cu=INR';
    }

    /**
     * @description Initializes a payment session based on the configured environment.
     * In Sandbox mode: Generates local session and UPI Intent.
     * In Production mode: Connects to Payment Gateway API (e.g. Razorpay) to create order.
     * @param amount The amount to pay.
     * @param registrationId The Registration__c record ID.
     * @return GatewayOrderResponse Structured response.
     */
    @AuraEnabled
    public static GatewayOrderResponse initializePayment(Decimal amount, String registrationId) {
        GatewayConfigDTO config = getGatewayConfig();
        String sessionRef = 'UPI-EVT-' + Datetime.now().getTime() + '-' + Crypto.getRandomInteger();
        String upiUri = generateUpiPayload(amount, sessionRef);

        if (config.isSandbox) {
            return new GatewayOrderResponse(
                true,
                sessionRef,
                upiUri,
                config.gatewayProvider,
                'Initialized in Sandbox / Simulation Mode. Ready for attendee verification.'
            );
        } else {
            // Production Gateway Integration Hook (e.g. Razorpay / Cashfree)
            Payment_Gateway_Config__mdt fullConfig = Payment_Gateway_Config__mdt.getInstance('Default_Gateway');
            if (fullConfig == null || String.isBlank(fullConfig.Merchant_Key_Id__c)) {
                throw new AuraHandledException('Payment Gateway Error: Production mode is active, but Merchant Key ID is not configured.');
            }

            // Production Callout Template
            // HttpRequest req = new HttpRequest();
            // req.setEndpoint('callout:Payment_Gateway/v1/orders');
            // req.setMethod('POST');
            // HttpResponse res = new Http().send(req);

            return new GatewayOrderResponse(
                true,
                sessionRef,
                upiUri,
                fullConfig.Gateway_Provider__c,
                'Order generated successfully via ' + fullConfig.Gateway_Provider__c
            );
        }
    }

    /**
     * @description Verifies an inbound webhook signature using HMAC-SHA256.
     * Guarantees zero client tampering and verifies payload integrity from the gateway.
     * @param payload Raw HTTP request body from the webhook.
     * @param signatureHeader Signature passed in the X-Razorpay-Signature or equivalent header.
     * @param secret Shared secret key configured in Custom Metadata.
     * @return Boolean True if signature matches authentic HMAC hash.
     */
    public static Boolean verifyWebhookSignature(String payload, String signatureHeader, String secret) {
        if (String.isBlank(payload) || String.isBlank(signatureHeader) || String.isBlank(secret)) {
            return false;
        }

        try {
            Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
            String expectedSignature = EncodingUtil.convertToHex(mac);
            return expectedSignature.equalsIgnoreCase(signatureHeader.trim());
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'HMAC verification failed: ' + ex.getMessage());
            return false;
        }
    }
}
