@IsTest
private class RegistrationTriggerHandlerTest {

    private static Venue__c createVenue(Decimal capacity) {
        Venue__c v = new Venue__c(
            Name = 'Test Venue',
            City__c = 'Test City',
            Venue_Capacity__c = capacity,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId, String regStatus) {
        Event__c ev = new Event__c(
            Name = 'Test Event',
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(10),
            End_Date_Time__c = Datetime.now().addDays(10).addHours(3),
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 1000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = regStatus
        );
        insert ev;
        return ev;
    }

    private static Ticket_Type__c createTicketType(Id eventId, Decimal quota, Decimal bookedSeats, String status) {
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = eventId,
            Price__c = 100,
            Quota__c = quota,
            Booked_Seats__c = bookedSeats,
            Status__c = status
        );
        insert tt;
        return tt;
    }

    @IsTest
    static void testHappyPathWithinQuota_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 2, 'Available');

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        insert reg;
        Test.stopTest();

        System.assertNotEquals(null, reg.Id, 'Registration within quota should insert successfully.');

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(3, updatedTT.Booked_Seats__c, 'Booked_Seats__c should increment by 1.');
        System.assertEquals('Available', updatedTT.Status__c, 'Status should remain Available when quota is not reached.');
    }

    @IsTest
    static void testExactAtQuotaBoundary_SucceedsAndMarksSoldOut() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 5, 4, 'Available'); // 1 seat remaining

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        insert reg;
        Test.stopTest();

        System.assertNotEquals(null, reg.Id, 'Booking the last seat should succeed.');

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(5, updatedTT.Booked_Seats__c, 'Booked seats should equal quota.');
        System.assertEquals('Sold Out', updatedTT.Status__c, 'Status should flip to Sold Out when booked seats reaches quota.');
    }

    @IsTest
    static void testQuotaExceeded_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 5, 5, 'Available'); // Already at quota

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('sold out'),
                'Error message should indicate ticket type is sold out.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration exceeding quota should fail.');
    }

    @IsTest
    static void testWrongEventTicketType_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev1 = createEvent(venue.Id, 'Open');
        Event__c ev2 = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt1 = createTicketType(ev1.Id, 50, 0, 'Available');

        // Registration points to ev2 but uses Ticket Type from ev1
        Registration__c reg = new Registration__c(
            Event__c = ev2.Id,
            Ticket_Type__c = tt1.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('does not belong to the selected event'),
                'Error message should flag event mismatch.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration with mismatched event and ticket type should fail.');
    }

    @IsTest
    static void testClosedRegistrationEvent_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Closed');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 0, 'Available');

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('not currently open for registration'),
                'Error message should indicate registration is not open.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a closed event should fail.');
    }

    @IsTest
    static void testSoldOutTicketTypeStatus_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 10, 'Sold Out');

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('no longer available'),
                'Error message should indicate ticket type is no longer available.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a Sold Out ticket type should fail.');
    }

    @IsTest
    static void testClosedTicketTypeStatus_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 10, 'Closed');

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Ticket_Type__c = tt.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('no longer available'),
                'Error message should indicate ticket type is no longer available.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a Closed ticket type should fail.');
    }

    @IsTest
    static void testBulkRegistrationsAgainstSameTicketType_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        List<Registration__c> batch = new List<Registration__c>();
        for (Integer i = 0; i < 5; i++) {
            batch.add(new Registration__c(
                Event__c = ev.Id,
                Ticket_Type__c = tt.Id,
                Registration_Status__c = 'Pending'
            ));
        }

        Test.startTest();
        insert batch;
        Test.stopTest();

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(5, updatedTT.Booked_Seats__c, 'Booked seats should reflect all 5 batch registrations.');
        System.assertEquals('Available', updatedTT.Status__c, 'Status should remain Available when quota (10) is not reached.');
    }

    @IsTest
    static void testBulkRegistrationsExceedingQuota_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 2, 0, 'Available');

        List<Registration__c> batch = new List<Registration__c>{
            new Registration__c(Event__c = ev.Id, Ticket_Type__c = tt.Id, Registration_Status__c = 'Pending'),
            new Registration__c(Event__c = ev.Id, Ticket_Type__c = tt.Id, Registration_Status__c = 'Pending'),
            new Registration__c(Event__c = ev.Id, Ticket_Type__c = tt.Id, Registration_Status__c = 'Pending')
        }; // 3 registrations against quota of 2

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert batch;
        } catch (DmlException e) {
            dmlFailed = true;
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Bulk insert exceeding available quota should fail.');
    }

    @IsTest
    static void testRegistrationWithoutTicketType_HandledSafely() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Registration_Status__c = 'Pending'
        );

        Test.startTest();
        insert reg;
        Test.stopTest();

        System.assertNotEquals(null, reg.Id, 'Registration without ticket type should safely bypass inventory check.');
    }
}
