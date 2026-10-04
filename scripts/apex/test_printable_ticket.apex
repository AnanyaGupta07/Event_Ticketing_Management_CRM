Ticket__c tkt = [
    SELECT Id, Name, Ticket_Status__c,
           Registration__r.Name, Registration__r.Event__r.Name, Registration__r.Attendee__r.Name,
           Registration__r.Booking_Group_Id__c
    FROM Ticket__c
    WHERE Id = 'a0GdL00000VuLj4UAF'
    LIMIT 1
];
System.debug('FOUND_TICKET: ' + tkt.Name + ' | ' + tkt.Registration__r.Attendee__r.Name + ' | Event: ' + tkt.Registration__r.Event__r.Name);

ApexPages.StandardController sc = new ApexPages.StandardController(tkt);
PrintableTicketExtension pte = new PrintableTicketExtension(sc);
System.debug('PTE_IS_GROUP: ' + pte.isGroupBooking);
System.debug('PTE_COUNT: ' + pte.totalAttendeeCount);
System.debug('PTE_TOTAL_PRICE: ' + pte.totalGroupPrice);
System.debug('PTE_ROSTER_SIZE: ' + pte.groupTickets.size());
