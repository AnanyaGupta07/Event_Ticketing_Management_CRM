/**
 * @description Controller for Attendee Event Booking and Payment Confirmation.
 * Handles event discovery, ticket type availability, and secure payment confirmation.
 */
public with sharing class EventBookingController {

    /**
     * @description Fetches all approved, published events where registration is currently open.
     * @return List of Event__c records with venue and capacity information.
     */
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getPublishedEvents() {
        return [
            SELECT Id, Name, Description__c, Category__c, Start_Date_Time__c, End_Date_Time__c,
                   Registration_Status__c, Approval_Status__c, Publication_Status__c,
                   Total_Capacity__c, Available_Seats__c,
                   Venue__c, Venue__r.Name, Venue__r.City__c, Venue__r.Venue_Capacity__c
            FROM Event__c
            WHERE Approval_Status__c = 'Approved'
              AND Publication_Status__c = 'Published'
              AND Registration_Status__c = 'Open'
            ORDER BY Start_Date_Time__c ASC
            LIMIT 100
        ];
    }

    /**
     * @description Fetches detailed information for a single event.
     * @param eventId The Id of the Event__c record.
     * @return Event__c record with venue and speaker details.
     */
    @AuraEnabled(cacheable=true)
    public static Event__c getEventDetail(Id eventId) {
        if (eventId == null) {
            return null;
        }
        List<Event__c> events = [
            SELECT Id, Name, Description__c, Category__c, Start_Date_Time__c, End_Date_Time__c,
                   Registration_Status__c, Approval_Status__c, Publication_Status__c,
                   Total_Capacity__c, Available_Seats__c,
                   Venue__c, Venue__r.Name, Venue__r.Address__c, Venue__r.City__c, Venue__r.Venue_Capacity__c,
                   (SELECT Id, Name, Bio__c, Email__c FROM Speakers__r)
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];
        return events.isEmpty() ? null : events[0];
    }

    /**
     * @description Fetches all available Ticket Types for an event.
     * @param eventId The Id of the Event__c.
     * @return List of Ticket_Type__c records with pricing and remaining quotas.
     */
    @AuraEnabled(cacheable=true)
    public static List<Ticket_Type__c> getEventTicketTypes(Id eventId) {
        if (eventId == null) {
            return new List<Ticket_Type__c>();
        }
        return [
            SELECT Id, Name, Price__c, Quota__c, Booked_Seats__c, Available_Seats__c, Status__c, Description__c
            FROM Ticket_Type__c
            WHERE Event__c = :eventId
              AND Status__c != 'Closed'
            ORDER BY Price__c ASC
        ];
    }

    /**
     * @description Confirms payment for a pending registration following QR payment verification.
     * Enforces ownership checks, idempotency, duplicate payment guards, and pins amount to Booked_Price__c.
     * @param registrationId The Id of the Registration__c to confirm.
     * @param transactionReference The external/QR payment session reference.
     * @return String confirmation message or status.
     */
    @AuraEnabled
    public static String confirmPayment(Id registrationId, String transactionReference) {
        if (registrationId == null) {
            throw new AuraHandledException('Invalid Registration: registrationId is required.');
        }

        // 1. Query Registration with Attendee User binding and Booked Price
        List<Registration__c> regs = [
            SELECT Id, Name, Registration_Status__c, Booked_Price__c, Event__c,
                   Attendee__c, Attendee__r.User__c, Attendee__r.Email__c
            FROM Registration__c
            WHERE Id = :registrationId
            LIMIT 1
        ];

        if (regs.isEmpty()) {
            throw new AuraHandledException('Registration not found.');
        }

        Registration__c reg = regs[0];

        // 2. Ownership Check (validationrules.md §8)
        // Ensure portal/community user matches the Attendee's linked User record (if populated)
        Id currentUserId = UserInfo.getUserId();
        if (reg.Attendee__r != null && reg.Attendee__r.User__c != null) {
            if (reg.Attendee__r.User__c != currentUserId) {
                throw new AuraHandledException('Unauthorized: You can only confirm payment for your own registration.');
            }
        }

        // 3. Idempotency Check
        // If registration is already confirmed, return early without re-processing
        if ('Confirmed'.equalsIgnoreCase(reg.Registration_Status__c)) {
            return 'Already Confirmed';
        }

        // 4. Duplicate-Payment Guard
        // Guard against double-click/retry creating multiple Payment__c records
        List<Payment__c> existingPayments = [
            SELECT Id, Payment_Status__c, Transaction_Reference__c
            FROM Payment__c
            WHERE Registration__c = :registrationId
            LIMIT 1
        ];

        if (!existingPayments.isEmpty()) {
            // Payment record already exists; ensure registration is marked Confirmed and return
            if (!'Confirmed'.equalsIgnoreCase(reg.Registration_Status__c)) {
                reg.Registration_Status__c = 'Confirmed';
                update reg;
            }
            return 'Payment Exists - Registration Confirmed';
        }

        // 5. Insert Payment__c record
        // Amount__c is set exclusively from Registration__c.Booked_Price__c (never from client input)
        Payment__c newPayment = new Payment__c();
        newPayment.Registration__c = reg.Id;
        newPayment.Amount__c = (reg.Booked_Price__c != null) ? reg.Booked_Price__c : 0;
        newPayment.Payment_Status__c = 'Successful';
        newPayment.Payment_Method__c = 'UPI';
        newPayment.Transaction_Reference__c = String.isNotBlank(transactionReference) 
            ? transactionReference 
            : 'QR-' + System.currentTimeMillis();
        newPayment.Payment_Date_Time__c = Datetime.now();
        insert newPayment;

        // 6. Update Registration Status to Confirmed
        // This is the specific write that fires Flow 2 (Post_Registration_Automation)
        reg.Registration_Status__c = 'Confirmed';
        update reg;

        return 'Payment Verified and Registration Confirmed';
    }

    public class TicketDTO {
        @AuraEnabled public String ticketId;
        @AuraEnabled public String ticketNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime issueDateTime;
        @AuraEnabled public String registrationId;
        @AuraEnabled public String registrationNumber;
        @AuraEnabled public String attendeeName;
        @AuraEnabled public String attendeeEmail;
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public Datetime eventStartDate;
        @AuraEnabled public Datetime eventEndDate;
        @AuraEnabled public String venueName;
        @AuraEnabled public String venueCity;
        @AuraEnabled public String ticketTypeName;
        @AuraEnabled public Decimal bookedPrice;
        @AuraEnabled public String printableTicketUrl;
    }

    /**
     * @description Fetches all issued tickets for the current attendee/user.
     * Matches by linked User, Attendee Email, or Attendee Name, with demo fallback.
     * @return List of TicketDTO objects containing event, venue, and pass details.
     */
    @AuraEnabled(cacheable=true)
    public static List<TicketDTO> getMyTickets() {
        Id currentUserId = UserInfo.getUserId();
        String currentUserEmail = UserInfo.getUserEmail();
        String currentUserName = UserInfo.getName();

        List<Ticket__c> tickets = [
            SELECT Id, Name, Ticket_Status__c, Issue_Date_Time__c,
                   Registration__c, Registration__r.Name, Registration__r.Booked_Price__c,
                   Registration__r.Attendee__r.Name, Registration__r.Attendee__r.Email__c,
                   Registration__r.Event__c, Registration__r.Event__r.Name,
                   Registration__r.Event__r.Start_Date_Time__c, Registration__r.Event__r.End_Date_Time__c,
                   Registration__r.Event__r.Venue__r.Name, Registration__r.Event__r.Venue__r.City__c,
                   Registration__r.Ticket_Type__r.Name
            FROM Ticket__c
            WHERE Registration__r.Attendee__r.User__c = :currentUserId
               OR Registration__r.Attendee__r.Email__c = :currentUserEmail
               OR Registration__r.Attendee__r.Name = :currentUserName
            ORDER BY Issue_Date_Time__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 100
        ];

        // Fallback for Admin / Dev sandbox testing when user has not yet booked in their own name
        if (tickets.isEmpty()) {
            tickets = [
                SELECT Id, Name, Ticket_Status__c, Issue_Date_Time__c,
                       Registration__c, Registration__r.Name, Registration__r.Booked_Price__c,
                       Registration__r.Attendee__r.Name, Registration__r.Attendee__r.Email__c,
                       Registration__r.Event__c, Registration__r.Event__r.Name,
                       Registration__r.Event__r.Start_Date_Time__c, Registration__r.Event__r.End_Date_Time__c,
                       Registration__r.Event__r.Venue__r.Name, Registration__r.Event__r.Venue__r.City__c,
                       Registration__r.Ticket_Type__r.Name
                FROM Ticket__c
                ORDER BY Issue_Date_Time__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        }

        List<TicketDTO> dtoList = new List<TicketDTO>();
        for (Ticket__c t : tickets) {
            TicketDTO dto = new TicketDTO();
            dto.ticketId = t.Id;
            dto.ticketNumber = t.Name;
            dto.status = String.isNotBlank(t.Ticket_Status__c) ? t.Ticket_Status__c : 'Active';
            dto.issueDateTime = t.Issue_Date_Time__c;
            if (t.Registration__r != null) {
                dto.registrationId = t.Registration__c;
                dto.registrationNumber = t.Registration__r.Name;
                dto.bookedPrice = t.Registration__r.Booked_Price__c;
                if (t.Registration__r.Attendee__r != null) {
                    dto.attendeeName = t.Registration__r.Attendee__r.Name;
                    dto.attendeeEmail = t.Registration__r.Attendee__r.Email__c;
                }
                if (t.Registration__r.Event__r != null) {
                    dto.eventId = t.Registration__r.Event__c;
                    dto.eventName = t.Registration__r.Event__r.Name;
                    dto.eventStartDate = t.Registration__r.Event__r.Start_Date_Time__c;
                    dto.eventEndDate = t.Registration__r.Event__r.End_Date_Time__c;
                    if (t.Registration__r.Event__r.Venue__r != null) {
                        dto.venueName = t.Registration__r.Event__r.Venue__r.Name;
                        dto.venueCity = t.Registration__r.Event__r.Venue__r.City__c;
                    }
                }
                if (t.Registration__r.Ticket_Type__r != null) {
                    dto.ticketTypeName = t.Registration__r.Ticket_Type__r.Name;
                }
            }
            dto.printableTicketUrl = '/apex/PrintableTicket?id=' + t.Id;
            dtoList.add(dto);
        }
        return dtoList;
    }
}
