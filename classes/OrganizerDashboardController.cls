/**
 * Controller backing the organizerDashboard LWC.
 *
 * Scoped to the running user's organized events (Organizer__c = UserInfo.getUserId()),
 * providing aggregated metrics: booked seats, total capacity, available seats,
 * confirmed registrations, and calculated event revenue.
 */
public with sharing class OrganizerDashboardController {

    public class EventSummaryWrapper {
        @AuraEnabled public Id eventId { get; set; }
        @AuraEnabled public String eventName { get; set; }
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public String venueName { get; set; }
        @AuraEnabled public String approvalStatus { get; set; }
        @AuraEnabled public String publicationStatus { get; set; }
        @AuraEnabled public String registrationStatus { get; set; }
        @AuraEnabled public Decimal bookedSeats { get; set; }
        @AuraEnabled public Decimal totalCapacity { get; set; }
        @AuraEnabled public Decimal availableSeats { get; set; }
        @AuraEnabled public Integer confirmedRegistrations { get; set; }
        @AuraEnabled public Decimal revenue { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<EventSummaryWrapper> getMyEvents() {
        Id currentUserId = UserInfo.getUserId();

        // Check if user is an Event Manager to display an organization-wide overview
        Boolean isManager = false;
        List<PermissionSetAssignment> mgrAssignments = [
            SELECT Id FROM PermissionSetAssignment 
            WHERE AssigneeId = :currentUserId 
              AND PermissionSet.Name = 'Event_Manager_Permissions'
            LIMIT 1
        ];
        if (!mgrAssignments.isEmpty()) {
            isManager = true;
        } else {
            List<User> users = [SELECT UserRole.DeveloperName FROM User WHERE Id = :currentUserId LIMIT 1];
            if (!users.isEmpty() && users[0].UserRole != null && users[0].UserRole.DeveloperName == 'Event_Manager') {
                isManager = true;
            }
        }

        List<Event__c> events;
        if (isManager) {
            events = [
                SELECT Id, Name, Start_Date_Time__c, Venue__c, Venue__r.Name, Venue__r.Venue_Capacity__c,
                       Approval_Status__c, Publication_Status__c, Registration_Status__c,
                       (SELECT Id, Quota__c, Booked_Seats__c, Price__c FROM Ticket_Types__r),
                       (SELECT Id, Registration_Status__c, Booked_Price__c FROM Registrations__r)
                FROM Event__c
                ORDER BY Start_Date_Time__c ASC
            ];
        } else {
            events = [
                SELECT Id, Name, Start_Date_Time__c, Venue__c, Venue__r.Name, Venue__r.Venue_Capacity__c,
                       Approval_Status__c, Publication_Status__c, Registration_Status__c,
                       (SELECT Id, Quota__c, Booked_Seats__c, Price__c FROM Ticket_Types__r),
                       (SELECT Id, Registration_Status__c, Booked_Price__c FROM Registrations__r)
                FROM Event__c
                WHERE Organizer__c = :currentUserId
                ORDER BY Start_Date_Time__c ASC
            ];
        }

        List<EventSummaryWrapper> results = new List<EventSummaryWrapper>();

        for (Event__c ev : events) {
            EventSummaryWrapper dto = new EventSummaryWrapper();
            dto.eventId = ev.Id;
            dto.eventName = ev.Name;
            dto.startDateTime = ev.Start_Date_Time__c;
            dto.venueName = ev.Venue__r != null ? ev.Venue__r.Name : '';
            dto.approvalStatus = ev.Approval_Status__c != null ? ev.Approval_Status__c : 'Draft';
            dto.publicationStatus = ev.Publication_Status__c != null ? ev.Publication_Status__c : 'Unpublished';
            dto.registrationStatus = ev.Registration_Status__c != null ? ev.Registration_Status__c : 'Not Open';

            Decimal totalCapacity = 0;
            Decimal bookedSeats = 0;

            if (ev.Ticket_Types__r != null && !ev.Ticket_Types__r.isEmpty()) {
                for (Ticket_Type__c tt : ev.Ticket_Types__r) {
                    if (tt.Quota__c != null) {
                        totalCapacity += tt.Quota__c;
                    }
                    if (tt.Booked_Seats__c != null) {
                        bookedSeats += tt.Booked_Seats__c;
                    }
                }
            } else if (ev.Venue__r != null && ev.Venue__r.Venue_Capacity__c != null) {
                totalCapacity = ev.Venue__r.Venue_Capacity__c;
            }

            dto.totalCapacity = totalCapacity;
            dto.bookedSeats = bookedSeats;
            dto.availableSeats = Math.max(0, totalCapacity - bookedSeats);

            Integer confirmedCount = 0;
            Decimal totalRevenue = 0;

            if (ev.Registrations__r != null && !ev.Registrations__r.isEmpty()) {
                for (Registration__c reg : ev.Registrations__r) {
                    if (reg.Registration_Status__c == 'Confirmed') {
                        confirmedCount++;
                        if (reg.Booked_Price__c != null) {
                            totalRevenue += reg.Booked_Price__c;
                        }
                    }
                }
            }

            dto.confirmedRegistrations = confirmedCount;
            dto.revenue = totalRevenue;

            results.add(dto);
        }

        return results;
    }
}
