# Task Documentation: Phase 10 — Scheduled Reminder & Feedback Flows

**Status:** ✅ Completed  
**Relevant Folder:** [`flows/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Implement the schedule-triggered automations supporting the post-booking and post-event lifecycle:
- **`Event_Reminder_Scheduled_Flow.flow-meta.xml`**:
  - Scans for upcoming approved, published events.
  - Queries all related `Confirmed` registrations.
  - Dispatches automated 24-hour reminder emails with event start times and venue directions.
- **`Post_Event_Feedback_Scheduled_Flow.flow-meta.xml`**:
  - Scans for concluded events.
  - Loops over confirmed attendees.
  - **Deduplication Check**: Queries `Feedback__c` to ensure attendees who have already submitted feedback are not re-contacted.
  - Dispatches personalized survey emails to gather ratings and qualitative reviews.

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`Event_Reminder_Scheduled_Flow.flow-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/Event_Reminder_Scheduled_Flow.flow-meta.xml) | Scheduled Flow | `flows/` | Scheduled reminder notifications for upcoming events. |
| [`Post_Event_Feedback_Scheduled_Flow.flow-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/Post_Event_Feedback_Scheduled_Flow.flow-meta.xml) | Scheduled Flow | `flows/` | Scheduled post-event feedback invitations with deduplication. |
