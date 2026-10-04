/**
 * Final gatekeeper for registration availability (prd.md §14).
 *
 * Runs before insert on Registration__c. Re-validates everything the UI
 * already checked (Event open, Ticket Type belongs to Event, Ticket Type
 * available, quota not exceeded) because none of that is safe to trust from
 * the client, and additionally protects against CONCURRENT booking attempts
 * for the last seat(s) via row-level locking (FOR UPDATE) — something no
 * Validation Rule can do, since a VR evaluates against transaction-start
 * state with no locking mechanism (validationrules.md Resolved §2).
 *
 * This class also owns the write to Ticket_Type__c.Booked_Seats__c. That
 * field is a plain Number, NOT a native Roll-Up Summary — Registration→
 * Ticket Type is a Lookup, not Master-Detail (relationship.md), so a native
 * rollup isn't available here, and prd.md's "one source of truth for
 * inventory" principle means only this class ever writes it (never the
 * Record-Triggered Flow — see flows.md Flow 2's scope note).
 *
 * Bulk-safe: one locking query, all validation done in-memory against
 * running counters (so multiple Registrations in the same batch against the
 * same Ticket Type are still counted correctly), one bulk update.
 */
public class RegistrationTriggerHandler {

    public static void beforeInsert(List<Registration__c> newRecords) {
        Set<Id> ticketTypeIds = new Set<Id>();
        for (Registration__c reg : newRecords) {
            if (reg.Ticket_Type__c != null) {
                ticketTypeIds.add(reg.Ticket_Type__c);
            }
        }
        if (ticketTypeIds.isEmpty()) {
            return;
        }

        // Row-level lock. Any other transaction trying to insert a
        // Registration against one of these same Ticket Types blocks here
        // until this transaction commits or rolls back — this is what
        // makes the last-seat race condition safe.
        Map<Id, Ticket_Type__c> lockedTicketTypes = new Map<Id, Ticket_Type__c>([
            SELECT Id, Event__c, Quota__c, Booked_Seats__c, Status__c,
                   Event__r.Registration_Status__c
            FROM Ticket_Type__c
            WHERE Id IN :ticketTypeIds
            FOR UPDATE
        ]);

        // Seed running counters from the locked snapshot, then increment
        // in-memory as each Registration in THIS batch is validated — this
        // is what keeps bulk registrations against the same Ticket Type
        // safe within a single transaction.
        Map<Id, Decimal> runningBookedSeats = new Map<Id, Decimal>();
        for (Ticket_Type__c tt : lockedTicketTypes.values()) {
            runningBookedSeats.put(tt.Id, tt.Booked_Seats__c != null ? tt.Booked_Seats__c : 0);
        }

        Set<Id> ticketTypeIdsToUpdate = new Set<Id>();

        for (Registration__c reg : newRecords) {
            Ticket_Type__c tt = lockedTicketTypes.get(reg.Ticket_Type__c);

            if (tt == null) {
                reg.addError('Selected ticket type could not be found.');
                continue;
            }
            if (reg.Event__c != tt.Event__c) {
                reg.addError('Selected ticket type does not belong to the selected event.');
                continue;
            }
            if (tt.Event__r.Registration_Status__c != 'Open') {
                reg.addError('This event is not currently open for registration.');
                continue;
            }
            if (tt.Status__c == 'Sold Out' || tt.Status__c == 'Closed') {
                reg.addError('This ticket type is no longer available. Please choose another ticket type.');
                continue;
            }

            Decimal currentBooked = runningBookedSeats.get(tt.Id);
            Decimal quota = tt.Quota__c != null ? tt.Quota__c : 0;

            if (currentBooked + 1 > quota) {
                reg.addError('This ticket type just sold out. Please choose another ticket type.');
                continue;
            }

            // Reserve the seat for this Registration.
            runningBookedSeats.put(tt.Id, currentBooked + 1);
            ticketTypeIdsToUpdate.add(tt.Id);
        }

        if (ticketTypeIdsToUpdate.isEmpty()) {
            return;
        }

        List<Ticket_Type__c> updates = new List<Ticket_Type__c>();
        for (Id ttId : ticketTypeIdsToUpdate) {
            Ticket_Type__c original = lockedTicketTypes.get(ttId);
            Decimal newBookedSeats = runningBookedSeats.get(ttId);

            Ticket_Type__c updateRecord = new Ticket_Type__c(
                Id = ttId,
                Booked_Seats__c = newBookedSeats
            );
            if (original.Quota__c != null && newBookedSeats >= original.Quota__c) {
                updateRecord.Status__c = 'Sold Out';
            }
            updates.add(updateRecord);
        }

        // Single bulk DML — same transaction as the Registration insert, so
        // if the Registration insert itself later fails for any other
        // reason, this update rolls back with it.
        update updates;
    }
}
