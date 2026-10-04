@IsTest
private class PaymentGatewayServiceTest {

    @IsTest
    static void testGetGatewayConfig() {
        Test.startTest();
        PaymentGatewayService.GatewayConfigDTO config = PaymentGatewayService.getGatewayConfig();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Config should not be null');
        System.assertNotEquals(null, config.environment, 'Environment should be populated');
        System.assertNotEquals(null, config.gatewayProvider, 'Provider should be populated');
        System.assertNotEquals(null, config.upiVpa, 'UPI VPA should be populated');
        System.assert(config.autoVerifySeconds > 0, 'Auto verify seconds should be positive');
    }

    @IsTest
    static void testGenerateUpiPayload() {
        Test.startTest();
        String payload = PaymentGatewayService.generateUpiPayload(750.50, 'TEST-REF-1234');
        Test.stopTest();

        System.assert(payload.startsWith('upi://pay?'), 'Payload should start with upi://pay?');
        System.assert(payload.contains('750.50'), 'Payload should contain formatted amount');
        System.assert(payload.contains('TEST-REF-1234'), 'Payload should contain reference ID');
        System.assert(payload.contains('cu=INR'), 'Currency should be INR');
    }

    @IsTest
    static void testGenerateUpiPayloadWithNulls() {
        Test.startTest();
        String payload = PaymentGatewayService.generateUpiPayload(null, null);
        Test.stopTest();

        System.assert(payload.startsWith('upi://pay?'), 'Payload should start with upi://pay? even with nulls');
        System.assert(payload.contains('0.00'), 'Amount should default to 0.00');
    }

    @IsTest
    static void testInitializePaymentSandbox() {
        Test.startTest();
        PaymentGatewayService.GatewayOrderResponse res = PaymentGatewayService.initializePayment(500.00, 'REG-001');
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals(true, res.success, 'Sandbox payment should initialize successfully');
        System.assert(res.orderReference.startsWith('UPI-EVT-'), 'Order reference should start with UPI-EVT-');
        System.assert(res.upiIntentUri.startsWith('upi://pay?'), 'UPI URI should be populated');
    }

    @IsTest
    static void testVerifyWebhookSignatureValid() {
        String testPayload = '{"event":"payment.captured","amount":50000}';
        String secret = 'my_test_secret_key_123';

        // Calculate expected HMAC
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(testPayload), Blob.valueOf(secret));
        String validSignature = EncodingUtil.convertToHex(mac);

        Test.startTest();
        Boolean isValid = PaymentGatewayService.verifyWebhookSignature(testPayload, validSignature, secret);
        Boolean isInvalid = PaymentGatewayService.verifyWebhookSignature(testPayload, 'tampered_signature', secret);
        Boolean isNullSafe = PaymentGatewayService.verifyWebhookSignature(null, null, null);
        Test.stopTest();

        System.assertEquals(true, isValid, 'Valid HMAC signature should pass verification');
        System.assertEquals(false, isInvalid, 'Tampered signature should fail verification');
        System.assertEquals(false, isNullSafe, 'Null arguments should safely return false');
    }
}
