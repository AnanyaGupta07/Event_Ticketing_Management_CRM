/**
 * @description End-to-End Integration Test for the complete Attendee Journey.
 * Exercises:
 * 1. Event discovery & Ticket Type availability.
 * 2. Registration creation in 'Pending' status.
 * 3. Payment verification execution via EventBookingController.confirmPayment.
 * 4. Payment record generation, amount pinning to Booked_Price__c.
 * 5. Downstream ticket generation and confirmation status verification.
 */
@IsTest
private class AttendeeJourneyE2ETest {

    @TestSetup
    static void setupTestData() {
        // Create Venue
        Venue__c venue = new Venue__c(
            Name = 'Grand Tech Pavilion',
            Venue_Capacity__c = 1000,
            City__c = 'Austin'
        );
        insert venue;

        // Create Approved & Published Event
        Event__c evt = new Event__c(
            Name = 'Global Developer Forum 2026',
            Venue__c = venue.Id,
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(7),
            End_Date_Time__c = Datetime.now().addDays(8),
            Proposed_Budget__c = 5000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = 'Open'
        );
        insert evt;

        // Create Ticket Type
        Ticket_Type__c earlyBird = new Ticket_Type__c(
            Name = 'Early Bird Pass',
            Event__c = evt.Id,
            Price__c = 99.00,
            Quota__c = 300,
            Status__c = 'Available'
        );
        insert earlyBird;
    }

    @IsTest
    static void testFullAttendeeLifecycle_Success() {
        Event__c evt = [SELECT Id, Name FROM Event__c WHERE Name = 'Global Developer Forum 2026' LIMIT 1];
        Ticket_Type__c tt = [SELECT Id, Price__c FROM Ticket_Type__c WHERE Event__c = :evt.Id LIMIT 1];

        // 1. Create Attendee bound to current user
        Attendee__c attendee = new Attendee__c(
            Name = 'John Doe',
            Email__c = 'john.doe@example.com',
            User__c = UserInfo.getUserId(),
            Attendee_Status__c = 'Active'
        );
        insert attendee;

        // 2. Simulate Flow 1 creating a Pending Registration
        Registration__c reg = new Registration__c(
            Event__c = evt.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = attendee.Id,
            Registration_Status__c = 'Pending',
            Booked_Price__c = tt.Price__c,
            Confirmation_Status__c = 'Not Sent'
        );
        insert reg;

        // Verify initial pending state
        Registration__c preSaveReg = [SELECT Id, Registration_Status__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Pending', preSaveReg.Registration_Status__c, 'New registration must start as Pending');

        // 3. Attendee verifies payment via QR flow
        String testTxnRef = 'UPI-PAY-SESSION-ABC123XYZ';

        Test.startTest();
        String confirmResult = EventBookingController.confirmPayment(reg.Id, testTxnRef);
        Test.stopTest();

        System.assert(confirmResult.contains('Confirmed'), 'confirmPayment should return success');

        // 4. Assert Registration flipped to Confirmed
        Registration__c postSaveReg = [
            SELECT Id, Registration_Status__c, Booked_Price__c 
            FROM Registration__c 
            WHERE Id = :reg.Id
        ];
        System.assertEquals('Confirmed', postSaveReg.Registration_Status__c, 'Registration must be Confirmed');

        // 5. Assert Payment record created with exact Booked_Price__c
        List<Payment__c> payments = [
            SELECT Id, Amount__c, Payment_Status__c, Payment_Method__c, Transaction_Reference__c 
            FROM Payment__c 
            WHERE Registration__c = :reg.Id
        ];
        System.assertEquals(1, payments.size(), 'Exactly one Payment record must exist');
        System.assertEquals(99.00, payments[0].Amount__c, 'Payment Amount must match Booked_Price__c');
        System.assertEquals('Successful', payments[0].Payment_Status__c);
        System.assertEquals('UPI', payments[0].Payment_Method__c);
        System.assertEquals(testTxnRef, payments[0].Transaction_Reference__c);

        // 6. Verify Ticket created by Post_Registration_Automation flow
        List<Ticket__c> tickets = [SELECT Id, Ticket_Status__c FROM Ticket__c WHERE Registration__c = :reg.Id];
        System.assert(tickets.size() >= 1, 'Ticket must be issued for confirmed registration');
        System.assertEquals('Active', tickets[0].Ticket_Status__c);
    }

    @IsTest
    static void testEventDiscoveryAndTicketAvailability() {
        Test.startTest();
        List<Event__c> publishedEvents = EventBookingController.getPublishedEvents();
        System.assertNotEquals(0, publishedEvents.size(), 'Published events should be returned');

        Id eventId = publishedEvents[0].Id;
        List<Ticket_Type__c> tickets = EventBookingController.getEventTicketTypes(eventId);
        Test.stopTest();

        System.assertNotEquals(0, tickets.size(), 'Ticket types should be available for booking');
        System.assertEquals(99.00, tickets[0].Price__c);
    }

    @IsTest
    static void testDoublePaymentIdempotency() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c tt = [SELECT Id, Price__c FROM Ticket_Type__c LIMIT 1];

        Attendee__c attendee = new Attendee__c(
            Name = 'Idempotency Tester',
            Email__c = 'idem@example.com',
            User__c = UserInfo.getUserId()
        );
        insert attendee;

        Registration__c reg = new Registration__c(
            Event__c = evt.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = attendee.Id,
            Registration_Status__c = 'Pending',
            Booked_Price__c = tt.Price__c
        );
        insert reg;

        Test.startTest();
        // First payment confirmation
        String res1 = EventBookingController.confirmPayment(reg.Id, 'TXN-FIRST');
        // Immediate second call (double click)
        String res2 = EventBookingController.confirmPayment(reg.Id, 'TXN-RETRY');
        Test.stopTest();

        System.assert(res1.contains('Confirmed'));
        System.assert(res2.contains('Already Confirmed') || res2.contains('Payment Exists'));

        List<Payment__c> payments = [SELECT Id FROM Payment__c WHERE Registration__c = :reg.Id];
        System.assertEquals(1, payments.size(), 'Duplicate payment call must not insert multiple payments');
    }
}
