import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

let keySeq = 0;

/**
 * Screen Flow custom component. Drop this into the Add_Ticket_Type screen
 * of Event_Creation_Screen_Flow in place of the native Go-To-Connector loop
 * (elements 6-9 in event-creation-flow.md). One screen, live add/remove
 * rows, instead of a screen that re-enters itself per ticket type.
 *
 * Flow-facing contract (see the matching <property> entries in
 * ticketTypeCollector.js-meta.xml):
 *   - Input:  venueCapacity        (Number)  — bind to Get_Selected_Venue_Capacity's output
 *   - Output: ticketTypes          (TicketTypeWrapper[]) — bind to a collection
 *             variable of Apex-Defined type TicketTypeWrapper
 *   - Output: runningQuotaTotal    (Number)  — live sum, if the Review screen wants it
 *
 * Flow calls @api validate() automatically when the user clicks the
 * screen's own Next button — this component does NOT render its own
 * Next/Back buttons, Flow supplies those.
 */
export default class TicketTypeCollector extends LightningElement {
    @api venueCapacity = 0;

    _ticketTypes = [];

    // ---- Flow-bound output collection -------------------------------------

    @api
    get ticketTypes() {
        // Strip the internal 'key' before handing back to Flow — Flow's
        // TicketTypeWrapper shape only has name/price/quota/description.
        return this._ticketTypes.map(({ key, ...rest }) => rest);
    }

    set ticketTypes(value) {
        // Lets Flow pre-populate the component (e.g. navigating Back to this
        // screen after Review) without losing row identity for the template.
        this._ticketTypes = (value || []).map((tt) => ({ ...tt, key: this.nextKey() }));
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

    handleAddTicketType() {
        this._ticketTypes = [
            ...this._ticketTypes,
            { key: this.nextKey(), name: '', price: null, quota: null, description: '' }
        ];
        this.notifyFlow();
    }

    handleRemoveTicketType(event) {
        const key = event.currentTarget.dataset.key;
        this._ticketTypes = this._ticketTypes.filter((tt) => tt.key !== key);
        this.notifyFlow();
    }

    handleFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this._ticketTypes = this._ticketTypes.map((tt) =>
            tt.key === key ? { ...tt, [field]: value } : tt
        );
        this.notifyFlow();
    }

    // Keeps Flow's bound variables live-updated on every edit, not just on
    // Next — useful if a later screen (e.g. Review) references them before
    // the user leaves this screen.
    notifyFlow() {
        this.dispatchEvent(new FlowAttributeChangeEvent('ticketTypes', this.ticketTypes));
        this.dispatchEvent(new FlowAttributeChangeEvent('runningQuotaTotal', this.runningQuotaTotal));
    }

    // ---- Flow validation lifecycle hook ---------------------------------

    @api
    validate() {
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
