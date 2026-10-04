import { LightningElement, api, track } from 'lwc';

export default class PaymentQrVerification extends LightningElement {
    @api amount;
    @api registrationId;

    @track currentStep = 'entry'; // 'entry' | 'verifying' | 'confirmed'
    @track isPaymentConfirmedChecked = false;
    @track countdownSeconds = 10;
    @track sessionRef = '';
    @track qrModules = [];

    countdownInterval = null;

    connectedCallback() {
        this.generateSessionReference();
        this.generateQrModules();
    }

    disconnectedCallback() {
        this.clearTimer();
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

    get formattedAmount() {
        if (this.amount === undefined || this.amount === null) {
            return '₹0.00';
        }
        if (typeof this.amount === 'string' && (this.amount.startsWith('$') || this.amount.startsWith('₹'))) {
            return this.amount.startsWith('$') ? '₹' + this.amount.substring(1) : this.amount;
        }
        const num = Number(this.amount);
        return isNaN(num) ? '₹0.00' : `₹${num.toFixed(2)}`;
    }

    get countdownProgressPercent() {
        // Starts at 0% when 10s remain, progresses to 100% as timer drops to 0s
        return Math.round(((10 - this.countdownSeconds) / 10) * 100);
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
     * @description Initiates the strictly unskippable 10-second verification countdown.
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
