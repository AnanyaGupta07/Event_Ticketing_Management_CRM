@IsTest
private class OrganizerDashboardControllerTest {

    private static Venue__c createVenue(Decimal capacity) {
        Venue__c v = new Venue__c(
            Name = 'Grand Auditorium',
            City__c = 'San Francisco',
            Venue_Capacity__c = capacity,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId, String name, String approvalStatus, String pubStatus, String regStatus) {
        Event__c ev = new Event__c(
            Name = name,
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(5).addHours(4),
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 5000,
            Approval_Status__c = approvalStatus,
            Publication_Status__c = pubStatus,
            Registration_Status__c = regStatus
        );
        insert ev;
        return ev;
    }

    private static Ticket_Type__c createTicketType(Id eventId, String name, Decimal quota, Decimal bookedSeats, Decimal price) {
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = name,
            Event__c = eventId,
            Price__c = price,
            Quota__c = quota,
            Booked_Seats__c = bookedSeats,
            Status__c = 'Available'
        );
        insert tt;
        return tt;
    }

    private static Attendee__c createAttendee() {
        Attendee__c att = new Attendee__c(
            Name = 'Test Attendee',
            Email__c = 'attendee' + Crypto.getRandomInteger() + '@example.com',
            Attendee_Status__c = 'Active'
        );
        insert att;
        return att;
    }

    private static Registration__c createRegistration(Id eventId, Id ticketTypeId, String status, Decimal bookedPrice) {
        Attendee__c att = createAttendee();
        Registration__c reg = new Registration__c(
            Event__c = eventId,
            Ticket_Type__c = ticketTypeId,
            Attendee__c = att.Id,
            Registration_Status__c = status,
            Booked_Price__c = bookedPrice
        );
        insert reg;
        return reg;
    }

    @IsTest
    static void testGetMyEvents_ReturnsDecoratedSummaries() {
        Venue__c venue = createVenue(200);
        Event__c event1 = createEvent(venue.Id, 'Tech Summit 2026', 'Approved', 'Published', 'Open');
        Ticket_Type__c tt1 = createTicketType(event1.Id, 'VIP', 50, 20, 200);
        Ticket_Type__c tt2 = createTicketType(event1.Id, 'General', 100, 30, 100);

        createRegistration(event1.Id, tt1.Id, 'Confirmed', 200);
        createRegistration(event1.Id, tt2.Id, 'Confirmed', 100);
        createRegistration(event1.Id, tt2.Id, 'Pending', 100);

        Test.startTest();
        List<OrganizerDashboardController.EventSummaryWrapper> summaries = OrganizerDashboardController.getMyEvents();
        Test.stopTest();

        System.assertNotEquals(null, summaries, 'Summaries should not be null.');
        System.assertEquals(1, summaries.size(), 'Should return 1 event organized by the current user.');

        OrganizerDashboardController.EventSummaryWrapper dto = summaries[0];
        System.assertEquals(event1.Id, dto.eventId);
        System.assertEquals('Tech Summit 2026', dto.eventName);
        System.assertEquals('Grand Auditorium', dto.venueName);
        System.assertEquals('Approved', dto.approvalStatus);
        System.assertEquals('Published', dto.publicationStatus);
        System.assertEquals('Open', dto.registrationStatus);
        System.assertEquals(150, dto.totalCapacity, 'Total capacity should be sum of ticket quotas (50+100).');
        System.assertEquals(53, dto.bookedSeats, 'Booked seats should sum (20+30) + 3 inserted registrations.');
        System.assertEquals(97, dto.availableSeats, 'Available seats should be 150 - 53 = 97.');
        System.assertEquals(2, dto.confirmedRegistrations, 'Should count 2 confirmed registrations.');
        System.assertEquals(300, dto.revenue, 'Revenue should sum confirmed registration booked prices (200 + 100).');
    }

    @IsTest
    static void testGetMyEvents_EmptyWhenNoEvents() {
        Test.startTest();
        List<OrganizerDashboardController.EventSummaryWrapper> summaries = OrganizerDashboardController.getMyEvents();
        Test.stopTest();

        System.assertNotEquals(null, summaries);
        System.assertEquals(0, summaries.size());
    }
}
