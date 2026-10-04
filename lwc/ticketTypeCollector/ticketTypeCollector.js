import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

let keySeq = 0;

/**
 * Screen Flow custom component for collecting ticket types.
 *
 * Flow-facing contract:
 *   - Input:  venueCapacity        (Number)  — capacity of selected venue
 *   - Output: ticketTypes          (TicketTypeWrapper[]) — collection of ticket types
 *   - Output: runningQuotaTotal    (Number)  — total allocated quota
 */
export default class TicketTypeCollector extends LightningElement {
    @api venueCapacity = 0;

    _ticketTypes = [];

    // ---- Flow-bound output collection -------------------------------------

    @api
    get ticketTypes() {
        return this._ticketTypes.map(({ key, ...rest }) => rest);
    }

    set ticketTypes(value) {
        if (!value || !Array.isArray(value)) {
            return;
        }
        // If we already have user-entered rows in component state, do NOT let
        // Flow's two-way binding overwrite them and destroy user focus/typing.
        if (this._ticketTypes && this._ticketTypes.length > 0) {
            return;
        }
        this._ticketTypes = value.map((tt) => ({
            key: this.nextKey(),
            name: tt.name || '',
            price: tt.price !== undefined && tt.price !== null ? tt.price : null,
            quota: tt.quota !== undefined && tt.quota !== null ? tt.quota : null,
            description: tt.description || ''
        }));
    }

    // ---- Derived display state ---------------------------------------------

    @api
    get runningQuotaTotal() {
        return this._ticketTypes.reduce((sum, tt) => sum + (Number(tt.quota) || 0), 0);
    }

    get quotaExceedsCapacity() {
        return this.venueCapacity > 0 && this.runningQuotaTotal > this.venueCapacity;
    }

    get capacityPreviewText() {
        return `Running total: ${this.runningQuotaTotal} / Venue capacity: ${this.venueCapacity}`;
    }

    get hasNoTicketTypes() {
        return this._ticketTypes.length === 0;
    }

    // ---- Row handlers --------------------------------------------------------

    nextKey() {
        keySeq += 1;
        return `tt-${keySeq}`;
    }

    syncFromDOM() {
        const inputs = this.template.querySelectorAll('lightning-input');
        if (!inputs || inputs.length === 0) return;
        inputs.forEach((input) => {
            const key = input.dataset.key;
            const field = input.dataset.field;
            let val = input.value;
            if (field === 'price' || field === 'quota') {
                val = val === '' || val === null || isNaN(val) ? null : Number(val);
            }
            const target = this._ticketTypes.find((tt) => tt.key === key);
            if (target) {
                target[field] = val;
            }
        });
    }

    handleAddTicketType() {
        this.syncFromDOM();
        this._ticketTypes = [
            ...this._ticketTypes,
            { key: this.nextKey(), name: '', price: null, quota: null, description: '' }
        ];
        this.notifyFlow();
    }

    handleRemoveTicketType(event) {
        this.syncFromDOM();
        const key = event.currentTarget.dataset.key;
        this._ticketTypes = this._ticketTypes.filter((tt) => tt.key !== key);
        this.notifyFlow();
    }

    handleFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        let value = event.target.value;

        if (field === 'price' || field === 'quota') {
            value = value === '' || value === null || isNaN(value) ? null : Number(value);
        }

        const target = this._ticketTypes.find((tt) => tt.key === key);
        if (target) {
            target[field] = value;
        }
        // CRITICAL: Do NOT dispatch FlowAttributeChangeEvent on every keystroke!
        // Dispatching FlowAttributeChangeEvent on keystroke causes Salesforce Flow
        // to re-evaluate screen reactivity and re-render the host component,
        // which steals focus away from the input after a single character.
    }

    handleBlur() {
        // Dispatch to Flow only when the user finishes typing and leaves the field
        this.syncFromDOM();
        this.notifyFlow();
    }

    notifyFlow() {
        this.dispatchEvent(new FlowAttributeChangeEvent('ticketTypes', this.ticketTypes));
        this.dispatchEvent(new FlowAttributeChangeEvent('runningQuotaTotal', this.runningQuotaTotal));
    }

    // ---- Flow validation lifecycle hook ---------------------------------

    @api
    validate() {
        this.syncFromDOM();
        this.notifyFlow();

        if (this._ticketTypes.length === 0) {
            return {
                isValid: false,
                errorMessage: 'An event needs at least one ticket type.'
            };
        }
        const incomplete = this._ticketTypes.some(
            (tt) =>
                !tt.name ||
                tt.price === null ||
                tt.price === '' ||
                tt.quota === null ||
                tt.quota === ''
        );
        if (incomplete) {
            return {
                isValid: false,
                errorMessage: 'Every ticket type needs a Name, Price, and Quota.'
            };
        }
        return { isValid: true };
    }
}
