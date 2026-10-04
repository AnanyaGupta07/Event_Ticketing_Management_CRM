# Task Documentation: Phase 3 & 4 — Attendee Access, Permissions & Portal UI Shell

**Status:** ✅ Completed  
**Relevant Folders:** [`permissionsets/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/permissionsets/), [`tabs/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/tabs/), [`applications/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/applications/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Establish the access control and navigation scaffolding for portal/community and internal attendees:
- **Permission Set**: Created [`Event_Attendee_Permissions`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/permissionsets/Event_Attendee_Permissions.permissionset-meta.xml):
  - Read access on `Event__c`, `Venue__c`, `Ticket_Type__c`, and `Ticket__c`.
  - Create/Read access on `Registration__c` and `Payment__c`.
  - Field-level permissions on booking fields, prices, and attendee lookups.
  - Aligns with the private OWD and row-level ownership checks enforced in Apex.
- **Custom Tab**: Created [`Event_Booking.tab-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/tabs/Event_Booking.tab-meta.xml) hosting the `c:attendeeEventBooking` LWC.
- **Lightning Application**: Created [`Event_Portal.app-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/applications/Event_Portal.app-meta.xml) bundling the Event Booking portal tab with published event views.

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`Event_Attendee_Permissions.permissionset-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/permissionsets/Event_Attendee_Permissions.permissionset-meta.xml) | Permission Set | `permissionsets/` | Security and object/field access for community and portal attendees. |
| [`Event_Booking.tab-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/tabs/Event_Booking.tab-meta.xml) | Custom Tab | `tabs/` | Custom Lightning Component tab hosting the attendee booking portal. |
| [`Event_Portal.app-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/applications/Event_Portal.app-meta.xml) | Lightning Application | `applications/` | Dedicated Event Portal application. |
