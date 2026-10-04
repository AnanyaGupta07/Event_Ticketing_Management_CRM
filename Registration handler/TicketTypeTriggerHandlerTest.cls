@IsTest
private class TicketTypeTriggerHandlerTest {

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

    private static Event__c createEvent(Id venueId) {
        Event__c ev = new Event__c(
            Name = 'Test Event',
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(10),
            End_Date_Time__c = Datetime.now().addDays(10).addHours(3),
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 1000,
            Approval_Status__c = 'Draft',
            Publication_Status__c = 'Unpublished',
            Registration_Status__c = 'Not Open'
        );
        insert ev;
        return ev;
    }

    @IsTest
    static void testSingleTicketTypeWithinCapacity_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id);

        Test.startTest();
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'General',
            Event__c = ev.Id,
            Price__c = 500,
            Quota__c = 80,
            Status__c = 'Available'
        );
        insert tt;
        Test.stopTest();

        System.assertNotEquals(null, tt.Id, 'Ticket Type within capacity should insert successfully.');
    }

    @IsTest
    static void testSingleTicketTypeExceedsCapacity_Fails() {
        Venue__c venue = createVenue(50);
        Event__c ev = createEvent(venue.Id);

        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'VIP',
            Event__c = ev.Id,
            Price__c = 2000,
            Quota__c = 75, // exceeds venue capacity of 50
            Status__c = 'Available'
        );

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert tt;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('exceed venue capacity'),
                'Error message should explain the capacity overshoot.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Insert exceeding venue capacity should fail.');
    }

    @IsTest
    static void testBulkInsertAggregateExceedsCapacity_Fails() {
        // Each individual row is fine on its own, but the SUM across the
        // batch exceeds capacity — this is exactly the case a per-record
        // Validation Rule cannot catch.
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id);

        List<Ticket_Type__c> batch = new List<Ticket_Type__c>{
            new Ticket_Type__c(Name = 'VIP', Event__c = ev.Id, Price__c = 3000, Quota__c = 40, Status__c = 'Available'),
            new Ticket_Type__c(Name = 'General', Event__c = ev.Id, Price__c = 1000, Quota__c = 40, Status__c = 'Available'),
            new Ticket_Type__c(Name = 'Student', Event__c = ev.Id, Price__c = 500, Quota__c = 40, Status__c = 'Available')
        }; // sums to 120 > 100 capacity

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert batch;
        } catch (DmlException e) {
            dmlFailed = true;
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Bulk insert whose aggregate quota exceeds capacity should fail.');
    }

    @IsTest
    static void testUpdateAccountsForExistingSiblings_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id);

        Ticket_Type__c existing = new Ticket_Type__c(
            Name = 'General', Event__c = ev.Id, Price__c = 1000, Quota__c = 60, Status__c = 'Available'
        );
        insert existing;

        Ticket_Type__c toUpdate = new Ticket_Type__c(
            Name = 'VIP', Event__c = ev.Id, Price__c = 3000, Quota__c = 30, Status__c = 'Available'
        );
        insert toUpdate; // 60 + 30 = 90, within 100 capacity so far

        Test.startTest();
        toUpdate.Quota__c = 50; // 60 + 50 = 110 > 100 capacity
        Boolean dmlFailed = false;
        try {
            update toUpdate;
        } catch (DmlException e) {
            dmlFailed = true;
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Update that pushes aggregate quota over capacity (counting existing siblings) should fail.');
    }

    @IsTest
    static void testBoundaryExactlyAtCapacity_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id);

        Test.startTest();
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'General', Event__c = ev.Id, Price__c = 500, Quota__c = 100, Status__c = 'Available'
        );
        insert tt; // exactly at capacity — should be allowed (rule is ">", not ">=")
        Test.stopTest();

        System.assertNotEquals(null, tt.Id, 'Quota exactly equal to capacity should be allowed.');
    }
}
