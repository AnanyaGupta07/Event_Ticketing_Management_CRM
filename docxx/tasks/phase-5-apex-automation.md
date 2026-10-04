# Task Documentation: Phase 5 — Apex Automation

**Status:** ✅ Completed  
**Relevant Folder:** [`Registration handler/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Implement and test the core inventory and capacity gatekeepers for the Event Management & Ticketing platform:
1. **`TicketTypeTriggerHandler` + `TicketTypeTrigger` (Phase 5a)**: Protect against aggregate ticket type quotas exceeding the host venue's capacity using row-level locking (`FOR UPDATE`).
2. **`RegistrationTriggerHandlerTest` (Phase 5b)**: Unit test suite for `RegistrationTriggerHandler.beforeInsert` to ensure booking concurrency, quota constraints, status transitions, and data integrity.

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`TicketTypeTriggerHandler.cls`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/TicketTypeTriggerHandler.cls) | Apex Class | `Registration handler/` | Enforces capacity rules, locks sibling ticket types with `FOR UPDATE`, and tallies in-memory. |
| [`TicketTypeTriggerHandler.cls-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/TicketTypeTriggerHandler.cls-meta.xml) | Metadata XML | `Registration handler/` | API version (61.0) and status definition. |
| [`TicketTypeTrigger.trigger`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/TicketTypeTrigger.trigger) | Apex Trigger | `Registration handler/` | Dispatches `before insert` and `before update` events on `Ticket_Type__c` to handler. |
| [`TicketTypeTrigger.trigger-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/TicketTypeTrigger.trigger-meta.xml) | Metadata XML | `Registration handler/` | API version (61.0) and status definition. |
| [`RegistrationTriggerHandlerTest.cls`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/RegistrationTriggerHandlerTest.cls) | Apex Test Class | `Registration handler/` | 10 unit test scenarios covering all execution paths for `RegistrationTriggerHandler`. |
| [`RegistrationTriggerHandlerTest.cls-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Registration%20handler/RegistrationTriggerHandlerTest.cls-meta.xml) | Metadata XML | `Registration handler/` | API version (61.0) and status definition. |

---

## 3. Implementation Details

### Phase 5a: Capacity Gatekeeper Logic (`TicketTypeTriggerHandler`)
- **Parent Query & Locking**:
  - Collects all distinct `Event__c` parent IDs from the incoming batch.
  - Queries `Event__c` records along with `Venue__r.Venue_Capacity__c`.
  - Executes `[SELECT Id, Event__c, Quota__c FROM Ticket_Type__c WHERE Event__c IN :eventIds FOR UPDATE]` to obtain exclusive row locks on all existing sibling ticket types.
- **In-Memory Accumulator**:
  - Pre-populates a running quota tally per event using existing siblings (excluding records currently being updated).
  - Evaluates each incoming record sequentially against the running tally.
  - If prospective sum `> Venue_Capacity__c`, calls `tt.addError()` with message: `'Total ticket quota (...) cannot exceed venue capacity (...).'`.
  - Ensures exactly-at-capacity quotas (`prospectiveTotal == Venue_Capacity__c`) are allowed.

### Phase 5b: Registration Test Coverage (`RegistrationTriggerHandlerTest`)
The test class provides 10 standalone test cases:
1. `testHappyPathWithinQuota_Succeeds`: Verifies successful insert and increment of `Booked_Seats__c`.
2. `testExactAtQuotaBoundary_SucceedsAndMarksSoldOut`: Verifies booking the last available seat automatically sets `Status__c = 'Sold Out'`.
3. `testQuotaExceeded_Fails`: Verifies attempts to register for a ticket type whose quota is exhausted are rejected with a `"sold out"` error message.
4. `testWrongEventTicketType_Fails`: Ensures registrations referencing a ticket type belonging to a different event are rejected.
5. `testClosedRegistrationEvent_Fails`: Rejects registration attempts on events where `Registration_Status__c != 'Open'`.
6. `testSoldOutTicketTypeStatus_Fails`: Rejects attempts on ticket types with explicit `Status__c = 'Sold Out'`.
7. `testClosedTicketTypeStatus_Fails`: Rejects attempts on ticket types with explicit `Status__c = 'Closed'`.
8. `testBulkRegistrationsAgainstSameTicketType_Succeeds`: Tests batch registration within quota, verifying correct multi-count increments.
9. `testBulkRegistrationsExceedingQuota_Fails`: Tests batch registration exceeding quota, verifying bulk transaction safety.
10. `testRegistrationWithoutTicketType_HandledSafely`: Ensures graceful handling when `Ticket_Type__c` is null.
