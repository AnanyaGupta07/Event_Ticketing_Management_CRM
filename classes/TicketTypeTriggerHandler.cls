/**
 * Gatekeeper for Ticket Type quota allocation against Venue Capacity (prd.md §14).
 *
 * Runs before insert and before update on Ticket_Type__c.
 *
 * Validates that the cumulative quota of all Ticket Types under an Event
 * does not exceed the hosting Venue's capacity (Venue__r.Venue_Capacity__c).
 * Uses row-level locking (FOR UPDATE) on sibling Ticket Types to protect
 * against concurrent quota modifications and race conditions.
 *
 * Bulk-safe: one locking query across all parent events in the batch,
 * running tally evaluated in-memory, zero DML required in before-triggers.
 */
public class TicketTypeTriggerHandler {

    public static void beforeInsert(List<Ticket_Type__c> newRecords) {
        validateQuotaAgainstVenueCapacity(newRecords);
    }

    public static void beforeUpdate(List<Ticket_Type__c> newRecords, Map<Id, Ticket_Type__c> oldMap) {
        validateQuotaAgainstVenueCapacity(newRecords);
    }

    /**
     * Validates that the sum of quotas for all ticket types of an event
     * (including existing sibling records and incoming new/updated records)
     * does not exceed the Venue's capacity.
     */
    private static void validateQuotaAgainstVenueCapacity(List<Ticket_Type__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Set<Id> eventIds = new Set<Id>();
        Set<Id> incomingIds = new Set<Id>();

        for (Ticket_Type__c tt : newRecords) {
            if (tt.Event__c != null) {
                eventIds.add(tt.Event__c);
            }
            if (tt.Id != null) {
                incomingIds.add(tt.Id);
            }
        }

        if (eventIds.isEmpty()) {
            return;
        }

        // Query parent Events and their Venue capacities
        Map<Id, Event__c> eventsMap = new Map<Id, Event__c>([
            SELECT Id, Venue__c, Venue__r.Venue_Capacity__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);

        // Lock sibling Ticket Types for concurrency safety
        List<Ticket_Type__c> existingSiblings = [
            SELECT Id, Event__c, Quota__c
            FROM Ticket_Type__c
            WHERE Event__c IN :eventIds
            FOR UPDATE
        ];

        // Seed running counters for each event with existing sibling quotas (excluding records in this transaction)
        Map<Id, Decimal> runningQuotaByEvent = new Map<Id, Decimal>();
        for (Id evtId : eventIds) {
            runningQuotaByEvent.put(evtId, 0);
        }

        for (Ticket_Type__c sibling : existingSiblings) {
            if (!incomingIds.contains(sibling.Id)) {
                Decimal currentTotal = runningQuotaByEvent.get(sibling.Event__c);
                Decimal siblingQuota = sibling.Quota__c != null ? sibling.Quota__c : 0;
                runningQuotaByEvent.put(sibling.Event__c, (currentTotal != null ? currentTotal : 0) + siblingQuota);
            }
        }

        // Validate each incoming record against running aggregate and venue capacity
        for (Ticket_Type__c tt : newRecords) {
            if (tt.Event__c == null) {
                continue;
            }

            Event__c event = eventsMap.get(tt.Event__c);
            if (event == null || event.Venue__c == null || event.Venue__r.Venue_Capacity__c == null) {
                continue;
            }

            Decimal venueCapacity = event.Venue__r.Venue_Capacity__c;
            Decimal currentRunning = runningQuotaByEvent.get(tt.Event__c);
            Decimal recordQuota = tt.Quota__c != null ? tt.Quota__c : 0;
            Decimal prospectiveTotal = (currentRunning != null ? currentRunning : 0) + recordQuota;

            if (prospectiveTotal > venueCapacity) {
                tt.addError('Total ticket quota (' + prospectiveTotal + ') cannot exceed venue capacity (' + venueCapacity + ').');
            } else {
                runningQuotaByEvent.put(tt.Event__c, prospectiveTotal);
            }
        }
    }
}
