/**
 * @description Comprehensive unit tests for EventBookingController.
 * Validates event discovery, ticket retrieval, ownership enforcement, duplicate-payment guards, and idempotency.
 */
@IsTest
private class EventBookingControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Venue
        Venue__c venue = new Venue__c(
            Name = 'Tech Expo Arena',
            Venue_Capacity__c = 500,
            City__c = 'San Francisco'
        );
        insert venue;

        // Create Published & Open Event
        Event__c publishedEvent = new Event__c(
            Name = 'Cloud Summit 2026',
            Venue__c = venue.Id,
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(6),
            Proposed_Budget__c = 5000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = 'Open'
        );
        insert publishedEvent;

        // Create Draft Event (should not be returned in getPublishedEvents)
        Event__c draftEvent = new Event__c(
            Name = 'Draft Internal Meeting',
            Venue__c = venue.Id,
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(10),
            End_Date_Time__c = Datetime.now().addDays(11),
            Proposed_Budget__c = 5000,
            Approval_Status__c = 'Draft',
            Publication_Status__c = 'Unpublished',
            Registration_Status__c = 'Closed'
        );
        insert draftEvent;

        // Create Ticket Types under Published Event
        Ticket_Type__c vipTicket = new Ticket_Type__c(
            Name = 'VIP Pass',
            Event__c = publishedEvent.Id,
            Price__c = 150.00,
            Quota__c = 100,
            Status__c = 'Available'
        );
        Ticket_Type__c genTicket = new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = publishedEvent.Id,
            Price__c = 50.00,
            Quota__c = 200,
            Status__c = 'Available'
        );
        insert new List<Ticket_Type__c>{ vipTicket, genTicket };

        // Create Attendee linked to current user
        Attendee__c attendee = new Attendee__c(
            Name = 'Alice TestUser',
            Email__c = 'alice@example.com',
            User__c = UserInfo.getUserId(),
            Attendee_Status__c = 'Active'
        );
        insert attendee;

        // Create Pending Registration
        Registration__c reg = new Registration__c(
            Event__c = publishedEvent.Id,
            Ticket_Type__c = vipTicket.Id,
            Attendee__c = attendee.Id,
            Registration_Status__c = 'Pending',
            Booked_Price__c = 150.00,
            Confirmation_Status__c = 'Not Sent'
        );
        insert reg;
    }

    @IsTest
    static void testGetPublishedEvents() {
        Test.startTest();
        List<Event__c> events = EventBookingController.getPublishedEvents();
        Test.stopTest();

        System.assertNotEquals(null, events, 'Events list should not be null');
        System.assertEquals(1, events.size(), 'Only approved, published, open events should be returned');
        System.assertEquals('Cloud Summit 2026', events[0].Name, 'Should match published event name');
    }

    @IsTest
    static void testGetEventDetail() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Cloud Summit 2026' LIMIT 1];

        Test.startTest();
        Event__c detail = EventBookingController.getEventDetail(evt.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Event detail should not be null');
        System.assertEquals('Cloud Summit 2026', detail.Name);
        System.assertEquals('San Francisco', detail.Venue__r.City__c);
    }

    @IsTest
    static void testGetEventTicketTypes() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Cloud Summit 2026' LIMIT 1];

        Test.startTest();
        List<Ticket_Type__c> ticketTypes = EventBookingController.getEventTicketTypes(evt.Id);
        Test.stopTest();

        System.assertEquals(2, ticketTypes.size(), 'Should return all 2 active ticket types');
    }

    @IsTest
    static void testConfirmPayment_Success() {
        Registration__c reg = [SELECT Id, Registration_Status__c, Booked_Price__c FROM Registration__c LIMIT 1];
        String txnRef = 'UPI-TXN-987654321';

        Test.startTest();
        String result = EventBookingController.confirmPayment(reg.Id, txnRef);
        Test.stopTest();

        System.assert(result.contains('Confirmed'), 'Result should indicate confirmation: ' + result);

        // Verify Registration updated to Confirmed
        Registration__c updatedReg = [SELECT Id, Registration_Status__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Confirmed', updatedReg.Registration_Status__c, 'Registration must be flipped to Confirmed');

        // Verify Payment inserted with exact Booked_Price__c
        List<Payment__c> payments = [SELECT Id, Amount__c, Payment_Status__c, Payment_Method__c, Transaction_Reference__c 
                                     FROM Payment__c WHERE Registration__c = :reg.Id];
        System.assertEquals(1, payments.size(), 'Exactly one Payment record should be inserted');
        System.assertEquals(150.00, payments[0].Amount__c, 'Payment amount must match Booked_Price__c');
        System.assertEquals('Successful', payments[0].Payment_Status__c);
        System.assertEquals('UPI', payments[0].Payment_Method__c);
        System.assertEquals(txnRef, payments[0].Transaction_Reference__c);
    }

    @IsTest
    static void testConfirmPayment_AlreadyConfirmedIdempotent() {
        Registration__c reg = [SELECT Id FROM Registration__c LIMIT 1];
        reg.Registration_Status__c = 'Confirmed';
        update reg;

        Test.startTest();
        String result = EventBookingController.confirmPayment(reg.Id, 'TXN-RETRY');
        Test.stopTest();

        System.assertEquals('Already Confirmed', result, 'Should return early when already confirmed');
        List<Payment__c> payments = [SELECT Id FROM Payment__c WHERE Registration__c = :reg.Id];
        System.assertEquals(0, payments.size(), 'No payment should be inserted for already confirmed registration');
    }

    @IsTest
    static void testConfirmPayment_DuplicatePaymentGuard() {
        Registration__c reg = [SELECT Id, Booked_Price__c FROM Registration__c LIMIT 1];

        // Insert pre-existing payment
        Payment__c existingPay = new Payment__c(
            Registration__c = reg.Id,
            Amount__c = 150.00,
            Payment_Status__c = 'Successful',
            Payment_Method__c = 'UPI',
            Transaction_Reference__c = 'TXN-INITIAL',
            Payment_Date_Time__c = Datetime.now()
        );
        insert existingPay;

        Test.startTest();
        String result = EventBookingController.confirmPayment(reg.Id, 'TXN-DOUBLECLICK');
        Test.stopTest();

        System.assert(result.contains('Payment Exists'), 'Should trigger duplicate payment guard');
        List<Payment__c> payments = [SELECT Id FROM Payment__c WHERE Registration__c = :reg.Id];
        System.assertEquals(1, payments.size(), 'No second payment should be created');
    }

    @IsTest
    static void testConfirmPayment_OwnershipMismatch() {
        // Create another user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' OR Name = 'Standard Platform User' LIMIT 1];
        User otherUser = new User(
            FirstName = 'Bob',
            LastName = 'OtherUser',
            Email = 'bob.otheruser@example.com',
            Username = 'bob.otheruser.' + System.currentTimeMillis() + '@example.com',
            Alias = 'bother',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert otherUser;

        // Create attendee belonging to otherUser
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Cloud Summit 2026' LIMIT 1];
        Ticket_Type__c tt = [SELECT Id FROM Ticket_Type__c WHERE Event__c = :evt.Id LIMIT 1];
        Attendee__c otherAttendee = new Attendee__c(
            Name = 'Bob Other',
            Email__c = 'bob.other@example.com',
            User__c = otherUser.Id
        );
        insert otherAttendee;

        Registration__c otherReg = new Registration__c(
            Event__c = evt.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = otherAttendee.Id,
            Registration_Status__c = 'Pending',
            Booked_Price__c = 150.00
        );
        insert otherReg;

        Test.startTest();
        Boolean caughtException = false;
        try {
            // Running as test execution user (not otherUser), should fail ownership check
            EventBookingController.confirmPayment(otherReg.Id, 'TXN-HIJACK');
        } catch (AuraHandledException e) {
            caughtException = true;
        }
        Test.stopTest();

        System.assert(caughtException, 'Should throw AuraHandledException when user does not own registration');
    }

    @IsTest
    static void testGetMyTickets() {
        Registration__c reg = [SELECT Id FROM Registration__c LIMIT 1];
        Ticket__c tkt = new Ticket__c(
            Registration__c = reg.Id,
            Ticket_Status__c = 'Active',
            Issue_Date_Time__c = Datetime.now()
        );
        insert tkt;

        Test.startTest();
        List<EventBookingController.TicketDTO> tickets = EventBookingController.getMyTickets();
        Test.stopTest();

        System.assertNotEquals(null, tickets, 'Tickets list should not be null');
        System.assert(tickets.size() > 0, 'Should return at least one ticket');
        System.assertEquals(tkt.Id, tickets[0].ticketId, 'Ticket ID should match');
        System.assertEquals('Cloud Summit 2026', tickets[0].eventName, 'Event name should match');
        System.assert(tickets[0].printableTicketUrl.contains(tkt.Id), 'Printable URL should contain ticket ID');
    }

    @IsTest
    static void testBookMultipleTickets_Success() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Cloud Summit 2026' LIMIT 1];
        Ticket_Type__c tt = [SELECT Id, Price__c FROM Ticket_Type__c WHERE Event__c = :evt.Id LIMIT 1];

        List<EventBookingController.AttendeeInput> attendees = new List<EventBookingController.AttendeeInput>();
        EventBookingController.AttendeeInput a1 = new EventBookingController.AttendeeInput();
        a1.name = 'John Doe';
        a1.email = 'john.doe@example.com';
        a1.phone = '1234567890';
        attendees.add(a1);

        EventBookingController.AttendeeInput a2 = new EventBookingController.AttendeeInput();
        a2.name = 'Jane Doe';
        a2.email = 'jane.doe@example.com';
        a2.phone = '9876543210';
        attendees.add(a2);

        Test.startTest();
        EventBookingController.BookingResult res = EventBookingController.bookMultipleTickets(evt.Id, tt.Id, attendees);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result should not be null');
        System.assertEquals(2, res.ticketCount, 'Should have booked 2 tickets');
        System.assertNotEquals(null, res.bookingGroupId, 'Booking group ID should be populated');
        System.assertEquals(2, res.registrationIds.size(), 'Should return 2 registration IDs');

        // Verify confirmPayment confirms both registrations in the group
        String confirmMsg = EventBookingController.confirmPayment(res.primaryRegistrationId, 'TXN-MULTITEST');
        System.assert(confirmMsg.contains('Payment Verified'), 'Payment confirmation should succeed');

        // Test PrintableTicketExtension
        List<Ticket__c> tkts = [SELECT Id FROM Ticket__c WHERE Registration__c = :res.primaryRegistrationId LIMIT 1];
        if (!tkts.isEmpty()) {
            ApexPages.StandardController sc = new ApexPages.StandardController(tkts[0]);
            PrintableTicketExtension pte = new PrintableTicketExtension(sc);
            System.assertEquals(true, pte.isGroupBooking, 'Should be detected as group booking');
            System.assertEquals(2, pte.totalAttendeeCount, 'Should have 2 attendees in roster');
        }
    }

    @IsTest
    static void testBookMultipleTickets_QuotaExceeded_Fails() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Cloud Summit 2026' LIMIT 1];
        Ticket_Type__c tt = [SELECT Id, Available_Seats__c FROM Ticket_Type__c WHERE Event__c = :evt.Id LIMIT 1];

        // Request more tickets than available capacity (250 tickets when quota is 100/200)
        List<EventBookingController.AttendeeInput> attendees = new List<EventBookingController.AttendeeInput>();
        for (Integer i = 0; i < 250; i++) {
            EventBookingController.AttendeeInput a = new EventBookingController.AttendeeInput();
            a.name = 'Overflow User ' + i;
            a.email = 'overflow' + i + '@example.com';
            a.phone = '9876543210';
            attendees.add(a);
        }

        Test.startTest();
        Boolean caught = false;
        try {
            EventBookingController.bookMultipleTickets(evt.Id, tt.Id, attendees);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Should throw exception when tickets requested exceed quota');
    }
}
