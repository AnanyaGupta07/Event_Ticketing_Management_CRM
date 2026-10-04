/**
 * @description Controller for PrintableTicket.page.
 * Supports both single-ticket printing and multi-attendee group booking passes.
 * Uses 'without sharing' so that authenticated attendees can generate their PDF admission passes
 * without being blocked by private OWD on parent Event records.
 */
public without sharing class PrintableTicketExtension {

    public Ticket__c primaryTicket { get; set; }
    public List<Ticket__c> groupTickets { get; set; }
    public Boolean isGroupBooking { get; set; }
    public Integer totalAttendeeCount { get; set; }
    public Decimal totalGroupPrice { get; set; }

    /**
     * @description Default constructor for custom controller usage.
     * Extracts the 'id' parameter from the current Visualforce page URL.
     */
    public PrintableTicketExtension() {
        Id ticketId = ApexPages.currentPage() != null 
            ? ApexPages.currentPage().getParameters().get('id') 
            : null;
        init(ticketId);
    }

    /**
     * @description StandardController constructor for backwards compatibility and unit test harnesses.
     * @param stdController The StandardController instance.
     */
    public PrintableTicketExtension(ApexPages.StandardController stdController) {
        Id ticketId = stdController != null ? stdController.getId() : null;
        if (ticketId == null && ApexPages.currentPage() != null) {
            ticketId = ApexPages.currentPage().getParameters().get('id');
        }
        init(ticketId);
    }

    /**
     * @description Queries ticket details and any associated sibling tickets in a group booking.
     * @param ticketId The ID of the Ticket__c record.
     */
    private void init(Id ticketId) {
        this.groupTickets = new List<Ticket__c>();
        this.isGroupBooking = false;
        this.totalAttendeeCount = 1;
        this.totalGroupPrice = 0;

        if (ticketId == null) {
            this.primaryTicket = new Ticket__c();
            return;
        }

        List<Ticket__c> currentTickets = [
            SELECT Id, Name, Ticket_Status__c, Issue_Date_Time__c,
                   Registration__c, Registration__r.Name, Registration__r.Booked_Price__c,
                   Registration__r.Booking_Group_Id__c,
                   Registration__r.Attendee__r.Name, Registration__r.Attendee__r.Email__c, Registration__r.Attendee__r.Phone__c,
                   Registration__r.Event__c, Registration__r.Event__r.Name,
                   Registration__r.Event__r.Start_Date_Time__c, Registration__r.Event__r.End_Date_Time__c,
                   Registration__r.Event__r.Venue__r.Name, Registration__r.Event__r.Venue__r.Address__c,
                   Registration__r.Event__r.Venue__r.City__c,
                   Registration__r.Ticket_Type__r.Name
            FROM Ticket__c
            WHERE Id = :ticketId
            LIMIT 1
        ];

        if (currentTickets.isEmpty()) {
            this.primaryTicket = new Ticket__c();
            return;
        }

        this.primaryTicket = currentTickets[0];
        String bookingGroupId = this.primaryTicket.Registration__r != null 
            ? this.primaryTicket.Registration__r.Booking_Group_Id__c 
            : null;

        if (String.isNotBlank(bookingGroupId)) {
            this.groupTickets = [
                SELECT Id, Name, Ticket_Status__c, Issue_Date_Time__c,
                       Registration__c, Registration__r.Name, Registration__r.Booked_Price__c,
                       Registration__r.Booking_Group_Id__c,
                       Registration__r.Attendee__r.Name, Registration__r.Attendee__r.Email__c, Registration__r.Attendee__r.Phone__c,
                       Registration__r.Ticket_Type__r.Name
                FROM Ticket__c
                WHERE Registration__r.Booking_Group_Id__c = :bookingGroupId
                ORDER BY Name ASC
            ];
        }

        if (this.groupTickets.isEmpty()) {
            this.groupTickets.add(this.primaryTicket);
        }

        this.isGroupBooking = (this.groupTickets.size() > 1);
        this.totalAttendeeCount = this.groupTickets.size();

        for (Ticket__c t : this.groupTickets) {
            if (t.Registration__r != null && t.Registration__r.Booked_Price__c != null) {
                this.totalGroupPrice += t.Registration__r.Booked_Price__c;
            }
        }
    }
}
