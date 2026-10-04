# Task Documentation: Phase 6 — Event Registration Screen Flow

**Status:** ✅ Completed  
**Relevant Folder:** [`flows/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Implement the attendee self-registration Screen Flow [`Event_Registration_Screen_Flow.flow-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/Event_Registration_Screen_Flow.flow-meta.xml) per [`docxx/flows (1).md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/docxx/flows%20%281%29.md) Flow 1 and [`docxx/attendee-implementation-plan.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/docxx/attendee-implementation-plan.md) Phase 6:
- **Input / Output Variables**:
  - Inputs: `recordId` (Event Id), `selectedTicketTypeId` (Ticket Type Id), `currentAttendeeId`.
  - Outputs: `outcome` (`"Success"`, `"SoldOut"`, `"Failed"`), `newRegistrationId`.
- **Pre-Check Availability**: Queries `Ticket_Type__c` by `selectedTicketTypeId`; routes to `Sold_Out_Message` if `Available_Seats__c <= 0` or `Status__c = 'Sold Out'`.
- **Attendee Resolution & Creation**:
  - Matches `User__c = $User.Id` first to enforce authenticated user binding for ownership checks.
  - Fallback lookup on `Email__c` for unlinked contacts.
  - Dynamically creates `Attendee__c` with `User__c = $User.Id` if no record exists.
- **Review & Pending Registration**:
  - Review screen summarizing ticket type, price, attendee details.
  - Creates `Registration__c` in **`Pending`** status with `Booked_Price__c = Ticket_Type__r.Price__c` and `Confirmation_Status__c = 'Not Sent'`.
  - Wires fault connector to `Registration_Failed` screen to capture validation rule errors or concurrency rejection gracefully.
  - Sets `outcome = 'Success'` and stores `newRegistrationId` upon successful insertion, allowing the parent LWC to transition directly into QR payment verification.

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`Event_Registration_Screen_Flow.flow-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/Event_Registration_Screen_Flow.flow-meta.xml) | Flow Metadata | `flows/` | Complete Screen Flow handling attendee booking and pending registration creation. |
