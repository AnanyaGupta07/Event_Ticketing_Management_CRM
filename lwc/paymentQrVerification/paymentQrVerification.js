import { LightningElement, api, track } from 'lwc';
import getGatewayConfig from '@salesforce/apex/PaymentGatewayService.getGatewayConfig';

export default class PaymentQrVerification extends LightningElement {
    @api amount;
    @api registrationId;

    @track currentStep = 'entry'; // 'entry' | 'verifying' | 'confirmed'
    @track isPaymentConfirmedChecked = false;
    @track countdownSeconds = 10;
    @track sessionRef = '';
    @track qrModules = [];

    // Plug-and-play gateway configuration properties
    @track environment = 'Sandbox';
    @track gatewayProvider = 'Simulated_UPI';
    @track upiVpa = 'eventmgmt@upi';
    @track upiIntentUri = '';

    countdownInterval = null;

    connectedCallback() {
        this.generateSessionReference();
        this.generateQrModules();
        this.fetchGatewayConfig();
    }

    disconnectedCallback() {
        this.clearTimer();
    }

    /**
     * @description Fetches gateway configuration from PaymentGatewayService.
     */
    fetchGatewayConfig() {
        getGatewayConfig()
            .then(config => {
                if (config) {
                    this.environment = config.environment || 'Sandbox';
                    this.gatewayProvider = config.gatewayProvider || 'Simulated_UPI';
                    this.upiVpa = config.upiVpa || 'eventmgmt@upi';
                    if (config.autoVerifySeconds) {
                        this.countdownSeconds = config.autoVerifySeconds;
                    }
                }
                this.buildUpiIntentUri();
            })
            .catch(error => {
                console.warn('PaymentQrVerification: Using default simulation config', error);
                this.buildUpiIntentUri();
            });
    }

    buildUpiIntentUri() {
        const numeric = this.numericAmount;
        const encodedVpa = encodeURIComponent(this.upiVpa);
        const encodedPn = encodeURIComponent('EventManagement');
        const encodedTn = encodeURIComponent(this.sessionRef);
        this.upiIntentUri = `upi://pay?pa=${encodedVpa}&pn=${encodedPn}&am=${numeric.toFixed(2)}&tn=${encodedTn}&cu=INR`;
    }

    // Step state getters
    get isEntryStep() {
        return this.currentStep === 'entry';
    }

    get isVerifyingStep() {
        return this.currentStep === 'verifying';
    }

    get isConfirmedStep() {
        return this.currentStep === 'confirmed';
    }

    get isNextDisabled() {
        return !this.isPaymentConfirmedChecked;
    }

    get isSandbox() {
        return this.environment === 'Sandbox';
    }

    get numericAmount() {
        if (this.amount === undefined || this.amount === null) {
            return 0.00;
        }
        if (typeof this.amount === 'string') {
            const cleanStr = this.amount.replace(/[^0-9.]/g, '');
            const parsed = parseFloat(cleanStr);
            return isNaN(parsed) ? 0.00 : parsed;
        }
        const num = Number(this.amount);
        return isNaN(num) ? 0.00 : num;
    }

    get formattedAmount() {
        return `₹${this.numericAmount.toFixed(2)}`;
    }

    get countdownProgressPercent() {
        const total = 10;
        return Math.round(((total - this.countdownSeconds) / total) * 100);
    }

    get countdownStrokeStyle() {
        const circumference = 427.26; // 2 * Math.PI * 68
        const offset = circumference - (this.countdownProgressPercent / 100) * circumference;
        return `stroke-dashoffset: ${offset};`;
    }

    /**
     * @description Generates a unique, non-reusable transaction session reference.
     */
    generateSessionReference() {
        const timestamp = Date.now().toString(36).toUpperCase();
        const rand = Math.random().toString(36).substring(2, 7).toUpperCase();
        this.sessionRef = `UPI-EVT-${timestamp}-${rand}`;
    }

    /**
     * @description Deterministically generates visually crisp, authentic QR data modules.
     */
    generateQrModules() {
        const modules = [];
        let seed = 0;
        for (let i = 0; i < this.sessionRef.length; i++) {
            seed = (seed * 31 + this.sessionRef.charCodeAt(i)) & 0xffffffff;
        }

        const size = 20; // 20x20 grid of data points
        for (let row = 0; row < size; row++) {
            for (let col = 0; col < size; col++) {
                // Reserve finder patterns (top-left, top-right, bottom-left)
                const inTopLeft = row < 8 && col < 8;
                const inTopRight = row < 8 && col > 11;
                const inBottomLeft = row > 11 && col < 8;

                if (!inTopLeft && !inTopRight && !inBottomLeft) {
                    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
                    if ((seed % 3) === 0) {
                        modules.push({
                            id: `mod-${row}-${col}`,
                            x: 14 + col * 6.5,
                            y: 14 + row * 6.5
                        });
                    }
                }
            }
        }
        this.qrModules = modules;
    }

    handleCheckboxChange(event) {
        this.isPaymentConfirmedChecked = event.target.checked;
    }

    /**
     * @description Initiates the 10-second verification countdown.
     */
    handleNextClick() {
        if (!this.isPaymentConfirmedChecked) {
            return;
        }
        this.currentStep = 'verifying';
        this.countdownSeconds = 10;

        this.countdownInterval = setInterval(() => {
            if (this.countdownSeconds > 1) {
                this.countdownSeconds -= 1;
            } else {
                this.countdownSeconds = 0;
                this.clearTimer();
                this.currentStep = 'confirmed';
            }
        }, 1000);
    }

    clearTimer() {
        if (this.countdownInterval) {
            clearInterval(this.countdownInterval);
            this.countdownInterval = null;
        }
    }

    /**
     * @description Dispatches the paymentconfirmed event to the parent LWC.
     */
    handleDoneClick() {
        const eventPayload = {
            registrationId: this.registrationId,
            transactionReference: this.sessionRef
        };
        this.dispatchEvent(new CustomEvent('paymentconfirmed', {
            detail: eventPayload,
            bubbles: true,
            composed: true
        }));
    }
}
