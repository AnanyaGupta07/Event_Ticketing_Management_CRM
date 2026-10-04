import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPublishedEvents from '@salesforce/apex/EventBookingController.getPublishedEvents';
import getEventTicketTypes from '@salesforce/apex/EventBookingController.getEventTicketTypes';
import confirmPayment from '@salesforce/apex/EventBookingController.confirmPayment';
import getMyTickets from '@salesforce/apex/EventBookingController.getMyTickets';

export default class AttendeeEventBooking extends LightningElement {
    @track activePortalTab = 'events'; // 'events' | 'my-tickets'
    @track currentState = 'BROWSE'; // BROWSE | DETAIL | FLOW | PAYMENT | SOLD_OUT | SUCCESS
    @track events = [];
    @track filteredEvents = [];
    @track ticketTypes = [];
    @track selectedEvent = null;
    @track selectedTicketTypeId = null;
    @track selectedTicketType = null;
    @track newRegistrationId = null;
    @track searchKey = '';
    @track selectedCategory = '';
    @track categoryOptions = [{ label: 'All Categories', value: '' }];
    @track isLoading = true;

    @track myTickets = [];
    @track isLoadingTickets = false;

    flowInputVariables = [];

    connectedCallback() {
        this.loadEvents();
        this.loadMyTickets();
    }

    // Tab getters
    get isEventsTab() {
        return this.activePortalTab === 'events';
    }

    get isMyTicketsTab() {
        return this.activePortalTab === 'my-tickets';
    }

    get myTicketsCount() {
        return this.myTickets ? this.myTickets.length : 0;
    }

    get hasMyTickets() {
        return this.myTickets && this.myTickets.length > 0;
    }

    get eventsTabClass() {
        return `portal-tab ${this.activePortalTab === 'events' ? 'active' : ''}`;
    }

    get ticketsTabClass() {
        return `portal-tab ${this.activePortalTab === 'my-tickets' ? 'active' : ''}`;
    }

    // View state getters
    get isBrowseState() {
        return this.currentState === 'BROWSE';
    }

    get isDetailState() {
        return this.currentState === 'DETAIL';
    }

    get isFlowState() {
        return this.currentState === 'FLOW';
    }

    get isPaymentState() {
        return this.currentState === 'PAYMENT';
    }

    get isSoldOutState() {
        return this.currentState === 'SOLD_OUT';
    }

    get isSuccessState() {
        return this.currentState === 'SUCCESS';
    }

    get hasEvents() {
        return this.filteredEvents && this.filteredEvents.length > 0;
    }

    get isProceedDisabled() {
        return !this.selectedTicketType || this.selectedTicketType.Available_Seats__c <= 0;
    }

    get selectedTicketTypePrice() {
        return this.selectedTicketType ? `₹${this.selectedTicketType.Price__c}` : '₹0.00';
    }

    /**
     * @description Fetches published events from the server.
     */
    loadEvents() {
        this.isLoading = true;
        getPublishedEvents()
            .then(result => {
                const categories = new Set();
                this.events = result.map(evt => {
                    if (evt.Category__c) {
                        categories.add(evt.Category__c);
                    }
                    return {
                        ...evt,
                        formattedStartDate: this.formatDate(evt.Start_Date_Time__c),
                        formattedEndDate: this.formatDate(evt.End_Date_Time__c)
                    };
                });

                this.categoryOptions = [
                    { label: 'All Categories', value: '' },
                    ...Array.from(categories).map(cat => ({ label: cat, value: cat }))
                ];

                this.applyFilters();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error Loading Events', error.body?.message || error.message, 'error');
            });
    }

    /**
     * @description Fetches the current user's booked tickets.
     */
    loadMyTickets() {
        this.isLoadingTickets = true;
        getMyTickets()
            .then(result => {
                this.myTickets = (result || []).map(tkt => ({
                    ...tkt,
                    formattedStartDate: this.formatDate(tkt.eventStartDate)
                }));
                this.isLoadingTickets = false;
            })
            .catch(error => {
                this.isLoadingTickets = false;
                console.error('Error loading my tickets:', error);
            });
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    handleTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        this.activePortalTab = tab;
        if (tab === 'my-tickets') {
            this.loadMyTickets();
        }
    }

    handleGoToMyTickets() {
        this.activePortalTab = 'my-tickets';
        this.currentState = 'BROWSE';
        this.loadMyTickets();
    }

    handleGoToBrowse() {
        this.activePortalTab = 'events';
        this.currentState = 'BROWSE';
    }

    handlePrintTicket(event) {
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.target.value;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredEvents = this.events.filter(evt => {
            const matchesSearch = !this.searchKey ||
                evt.Name?.toLowerCase().includes(this.searchKey) ||
                evt.Venue__r?.Name?.toLowerCase().includes(this.searchKey) ||
                evt.Venue__r?.City__c?.toLowerCase().includes(this.searchKey);

            const matchesCat = !this.selectedCategory || evt.Category__c === this.selectedCategory;
            return matchesSearch && matchesCat;
        });
    }

    /**
     * @description Loads event detail and ticket types.
     */
    handleSelectEvent(event) {
        const eventId = event.target.dataset.id;
        this.selectedEvent = this.events.find(e => e.Id === eventId);
        this.selectedTicketTypeId = null;
        this.selectedTicketType = null;
        this.isLoading = true;

        getEventTicketTypes({ eventId })
            .then(result => {
                this.ticketTypes = result.map(tt => {
                    const isSoldOut = tt.Available_Seats__c <= 0 || tt.Status__c === 'Sold Out';
                    return {
                        ...tt,
                        isSoldOut,
                        cardClass: `ticket-type-card ${isSoldOut ? 'ticket-disabled' : ''}`,
                        statusBadgeClass: `slds-badge ${isSoldOut ? 'slds-theme_error' : 'slds-theme_success'}`
                    };
                });
                this.isLoading = false;
                this.currentState = 'DETAIL';
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error Loading Ticket Types', error.body?.message || error.message, 'error');
            });
    }

    handleSelectTicketType(event) {
        const ticketId = event.currentTarget.dataset.id;
        const tt = this.ticketTypes.find(t => t.Id === ticketId);
        if (tt && !tt.isSoldOut) {
            this.selectedTicketTypeId = ticketId;
            this.selectedTicketType = tt;

            // Highlight selected card
            this.ticketTypes = this.ticketTypes.map(t => ({
                ...t,
                cardClass: `ticket-type-card ${t.Id === ticketId ? 'ticket-selected' : ''}`
            }));
        }
    }

    handleProceedToFlow() {
        if (!this.selectedEvent || !this.selectedTicketTypeId) {
            return;
        }

        this.flowInputVariables = [
            { name: 'recordId', type: 'String', value: this.selectedEvent.Id },
            { name: 'selectedTicketTypeId', type: 'String', value: this.selectedTicketTypeId }
        ];
        this.currentState = 'FLOW';
    }

    /**
     * @description Listens to status transitions inside Event_Registration_Screen_Flow.
     */
    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            const outputVariables = event.detail.outputVariables || [];
            let outcome = null;
            let regId = null;

            outputVariables.forEach(v => {
                if (v.name === 'outcome') {
                    outcome = v.value;
                } else if (v.name === 'newRegistrationId') {
                    regId = v.value;
                }
            });

            if (outcome === 'Success' && regId) {
                this.newRegistrationId = regId;
                this.currentState = 'PAYMENT';
            } else if (outcome === 'SoldOut') {
                this.currentState = 'SOLD_OUT';
            } else if (outcome === 'Failed') {
                this.showToast('Registration Error', 'Unable to complete reservation.', 'error');
                this.currentState = 'DETAIL';
            } else {
                // Default fallback if finished with registration id
                if (regId) {
                    this.newRegistrationId = regId;
                    this.currentState = 'PAYMENT';
                } else {
                    this.currentState = 'DETAIL';
                }
            }
        }
    }

    /**
     * @description Invoked when paymentQrVerification child fires paymentconfirmed.
     */
    handlePaymentConfirmed(event) {
        const { registrationId, transactionReference } = event.detail;
        this.isLoading = true;

        confirmPayment({ registrationId, transactionReference })
            .then(result => {
                this.isLoading = false;
                this.showToast('Payment Verified', 'Your registration is officially confirmed!', 'success');
                this.currentState = 'SUCCESS';
                this.loadMyTickets();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Payment Confirmation Error', error.body?.message || error.message, 'error');
            });
    }

    handleBackToBrowse() {
        this.currentState = 'BROWSE';
        this.selectedEvent = null;
        this.selectedTicketTypeId = null;
        this.selectedTicketType = null;
        this.newRegistrationId = null;
    }

    handleBackToDetail() {
        this.currentState = 'DETAIL';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
