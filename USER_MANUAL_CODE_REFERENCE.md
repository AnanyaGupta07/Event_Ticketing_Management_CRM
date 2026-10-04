# Enterprise Event Management & Ticketing CRM (Salesforce)
## Comprehensive Technical Manual, Codebase Walkthrough & Viva Guide

---

## 📌 Document Overview & Purpose
This guide is designed as an end-to-end technical manual for the **Salesforce Event Management CRM & Ticketing Platform**. It explains every code folder, class, trigger, LWC component, Visualforce page, flow, security permission, and architecture decision. 

Use this manual to prepare for code walkthroughs, project reviews, and professor/client defense sessions ("viva").

---

# 1. High-Level Architecture & Tech Stack

```
                                  [ USER INTERFACES ]
                                           │
         ┌─────────────────────────────────┴─────────────────────────────────┐
         ▼                                                                   ▼
[ Attendee Portal App ]                                           [ Event Management App ]
  • LWC: attendeeEventBooking                                       • LWC: organizerDashboard
  • LWC: paymentQrVerification                                      • Flow: Event_Creation_Screen_Flow
  • VF:  PrintableTicket.page                                         └─ LWC: ticketTypeCollector
         │                                                                   │
         ▼                                                                   ▼
[ Apex: EventBookingController ]                                  [ Apex: OrganizerDashboardController ]
  (without sharing - public access)                                 (with sharing - role/user scoped)
  • getPublishedEvents()                                            • getMyEvents()
  • bookMultipleTickets()                                                    │
  • confirmPayment()                                                         ▼
  • getMyTickets()                                                [ Approval Process ]
         │                                                          • Budget > ₹2,00,000 -> Manager
         └─────────────────────────────────┬─────────────────────────────────┘
                                           │
                                           ▼
                                 [ DATABASE LAYER ]
            Event__c ──(Master-Detail)──> Registration__c ──(Master-Detail)──> Ticket__c
               │                                │
        (Lookup/MD)                         (Lookup)
               ▼                                ▼
          Ticket_Type__c                    Payment__c
               ▲                                ▲
               │                                │
    [ TicketTypeTrigger ]             [ RegistrationTrigger ]
    • Validates quota <= venue cap     • Atomic quota validation
    • Sibling sum validation           • Auto-marks 'Sold Out'
```

### Core Technologies
- **Backend:** Apex (v60.0 / v67.0) with bulkified handler patterns.
- **Frontend:** Lightning Web Components (LWC) with custom responsive CSS (zero Tailwind dependencies).
- **Document Generation:** Visualforce PDF Rendering Engine (`renderAs="pdf"`) with custom extension.
- **Process Automation:** Salesforce Screen Flow + Approval Process with Custom Metadata Types.
- **Security:** Private Org-Wide Defaults (OWD), Role Hierarchy, Object-Level Security (OLS), Field-Level Security (FLS), and Permission Sets.

---

# 2. Folder-by-Folder Code Walkthrough

---

## 📂 `classes/` — Apex Controllers, Handlers, Wrappers & Tests

### 1. `EventBookingController.cls`
- **Role:** Main backend controller backing the **Attendee Portal** (`attendeeEventBooking` LWC).
- **Sharing Mode:** `public without sharing class`
  > **Why `without sharing`?** In this CRM, `Event__c` has a `Private` Org-Wide Default (OWD) and is owned by Event Organizers. Attendees are external/portal users. Declaring this class `without sharing` allows authenticated attendees to discover approved, published events and retrieve ticket tiers. Security is enforced programmatically in Apex: `getMyTickets()` and `confirmPayment()` strictly filter by `UserInfo.getUserId()`.
- **Key Methods:**
  - `getPublishedEvents()`: Fetches all approved, published events where `Registration_Status__c = 'Open'`.
  - `getEventDetail(Id eventId)`: Retrieves full event specifications including venue address and assigned speakers (`Speakers__r`).
  - `getEventTicketTypes(Id eventId)`: Returns active ticket tiers with real-time remaining quota (`Available_Seats__c`) and price in ₹.
  - `bookMultipleTickets(Id eventId, Id ticketTypeId, List<AttendeeInput> attendees)`:
    - Atomically processes multi-ticket group bookings.
    - Generates a unique `Booking_Group_Id__c` (e.g. `GRP-1725530000-842`).
    - Creates $N$ `Attendee__c` records and $N$ `Registration__c` records in `Pending` status.
    - Returns primary registration ID and group ID to LWC.
  - `confirmPayment(Id registrationId, String transactionRef)`:
    - Bulk payment verification: updates all registrations under the same `Booking_Group_Id__c` from `Pending` to `Confirmed`.
    - Creates corresponding `Payment__c` records with payment method `UPI` and status `Completed`.
    - Issues active `Ticket__c` records with unique autonumbers (`TKT-XXXXX`).
    - Contains idempotency guards to prevent double-charging or duplicate ticket generation.
  - `getMyTickets()`: Queries all confirmed tickets belonging to the logged-in user via `Registration__r.Attendee__r.User__c = :currentUserId`.

---

### 2. `OrganizerDashboardController.cls`
- **Role:** Controller backing the executive **Organizer Dashboard** (`organizerDashboard` LWC).
- **Sharing Mode:** `public with sharing class`
- **Key Methods:**
  - `getMyEvents()`: 
    - Dynamically evaluates if the logged-in user is an **Event Manager** (`Event_Manager_Permissions` or role `Event_Manager`) or **Event Organizer**.
    - If Manager: queries **all events** organization-wide to monitor organizational performance.
    - If Organizer: filters by `WHERE Organizer__c = :currentUserId` so organizers only see their own assigned events.
    - Aggregates metrics into `EventSummaryWrapper`: Total Capacity, Booked Seats, Available Seats, Confirmed Registrations, and Realized Revenue in ₹.

---

### 3. `PrintableTicketExtension.cls`
- **Role:** Controller backing the printable PDF admission pass (`pages/PrintableTicket.page`).
- **Sharing Mode:** `public without sharing class`
- **Key Architecture:**
  - Provides a **no-arg constructor** for custom Visualforce page controller usage: parses `?id=` parameter directly from `ApexPages.currentPage().getParameters()`.
  - Provides a **StandardController constructor** (`ApexPages.StandardController`) for test harness execution.
  - Detects single-attendee passes vs **Multi-Attendee Group Passes**: queries all sibling tickets sharing the same `Booking_Group_Id__c` to build the complete `groupTickets` roster.
  - Calculates total price paid across all passes in ₹.

---

### 4. `RegistrationTriggerHandler.cls`
- **Role:** Business logic handler executed before insert of `Registration__c`.
- **Key Architecture & Validations:**
  - **Bulkified Validation:** Queries parent `Event__c` and `Ticket_Type__c` in a single SOQL query.
  - **Event Registration Status Guard:** Blocks registrations if event registration status is closed or not open.
  - **Ticket Type Status Guard:** Prevents booking against 'Sold Out' or 'Closed' ticket tiers.
  - **Atomic Quota Protection:** Maintains an in-memory `runningBookedByTicketType` map. If 50 simultaneous registrations arrive in a bulk transaction, it sums them and verifies `bookedSoFar + incomingCount <= quota`.
  - **Auto-Sold-Out Transition:** If the batch fills the final remaining seat, it immediately marks the `Ticket_Type__c` as `Sold Out`.

---

### 5. `TicketTypeTriggerHandler.cls`
- **Role:** Business logic handler for `Ticket_Type__c` before insert and before update.
- **Key Architecture & Validations:**
  - **Venue Capacity Guard:** Ensures that the sum of quotas across all ticket types for an event never exceeds the venue's physical capacity (`Venue__r.Venue_Capacity__c`).
  - **Sibling Aggregate SOQL:** Uses `[SELECT Event__c, SUM(Quota__c) FROM Ticket_Type__c GROUP BY Event__c]` to account for existing tiers when inserting or updating new tiers.

---

### 6. `PaymentGatewayService.cls`
- **Role:** Enterprise Payment Gateway Service implementing the Adapter Pattern.
- **Key Architecture & Security:**
  - **Zero-Code Switching:** Uses Custom Metadata (`Payment_Gateway_Config__mdt`) to toggle between Sandbox simulation and live gateway settlements (Razorpay/Cashfree).
  - **UPI Intent Generation:** Produces NPCI-compliant `upi://pay?pa={vpa}&pn=EventManagement&am={amount}&tn={ref}&cu=INR` URIs readable by any phone scanner.
  - **HMAC-SHA256 Webhook Verification:** Verifies payload integrity and digital signatures via `Crypto.generateMac('HmacSHA256', ...)` to eliminate client-side tampering.

---

### 7. `EventApprovalService.cls`
- **Role:** Dynamic multi-tier approval evaluation engine.
- **Key Architecture:**
  - Connects Lightning Flow Builder to `Approval_Matrix__mdt` via `@InvocableMethod evaluateForFlow(...)`.
  - Implements category-specific thresholds (Concert, Hackathon, Training, Summit, Webinar, Meetup).
  - Programmatically submits event records to `Event_Budget_Approval` process via `Approval.ProcessSubmitRequest`.

---

### 8. `TicketTypeWrapper.cls`
- **Role:** Apex-Defined Data Type (DTO) used by the Screen Flow (`Event_Creation_Screen_Flow`) and LWC (`ticketTypeCollector`).
- **Fields:** `name` (String), `price` (Decimal), `quota` (Decimal), `description` (String).

---

### 9. Apex Test Classes (100% Pass Rate - 49 Tests)
- `EventBookingControllerTest.cls`: Tests event queries, multi-ticket booking, atomic quota overflow failures, payment idempotency, and ticket roster generation.
- `OrganizerDashboardControllerTest.cls`: Tests dashboard metric aggregation, revenue calculations, and empty-state handling.
- `PaymentGatewayServiceTest.cls`: Tests metadata config fetching, UPI payload generation, sandbox order initialization, and HMAC-SHA256 signature verification.
- `EventApprovalServiceTest.cls`: Tests category matrix routing, multi-tier threshold evaluation, and Invocable Flow execution.
- `RegistrationTriggerHandlerTest.cls`: Tests quota boundaries, sold-out triggers, closed events, and bulk safety.
- `TicketTypeTriggerHandlerTest.cls`: Tests venue capacity overflow enforcement and sibling quota updates.
- `OrganizerJourneyE2ETest.cls`: End-to-end integration test simulating the entire Organizer lifecycle: event creation, capacity checks, budget approval submission, and manager approval/rejection.
- `AttendeeJourneyE2ETest.cls`: End-to-end integration test simulating the Attendee lifecycle: browsing events, reserving tickets, making payments, and viewing tickets.

---

## 📂 `triggers/` — Apex Database Triggers

### 1. `RegistrationTrigger.trigger`
```apex
trigger RegistrationTrigger on Registration__c (before insert) {
    RegistrationTriggerHandler.beforeInsert(Trigger.new);
}
```
- Implements the **One-Trigger-Per-Object** enterprise pattern.
- Completely delegates business logic to `RegistrationTriggerHandler`.

### 2. `TicketTypeTrigger.trigger`
```apex
trigger TicketTypeTrigger on Ticket_Type__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            TicketTypeTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TicketTypeTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
```
- Context-aware routing: routes new tiers to `beforeInsert` and modifications to `beforeUpdate`.

---

## 📂 `lwc/` — Lightning Web Components

### 1. `attendeeEventBooking`
- **Purpose:** Full Attendee Portal front-end.
- **Key Features:**
  - **Explore Events Tab:** Real-time search bar, category filter pills (Conference, Workshop, Seminar, etc.), and event cards with date badges, venue info, and pricing.
  - **Multi-Ticket Counter (`[-] [Count] [+]`):** Allows attendees to select 1 to $N$ tickets (bounded by real-time available seats).
  - **Dynamic Attendee Input Cards:** Reactive forms that dynamically render fields for each attendee (`Ticket #1 Primary Booker`, `Ticket #2`, etc.) with strict name, email, and 10-digit phone validation.
  - **Integrated Checkout:** Seamlessly passes total price and booking details to the QR payment modal.
  - **My Tickets Tab:** Clean ticket dashboard showing all booked passes with status badges, event details, and a direct "View / Print Pass" button.

### 2. `paymentQrVerification`
- **Purpose:** Realistic UPI/QR Payment verification simulation.
- **Key Features:**
  - Generates dynamic UPI payload string: `upi://pay?pa=eventhub@salesforce&pn=Salesforce+Event+Management&am={amount}&cu=INR`.
  - Renders a clean QR code display with the formatted total amount in **₹ (INR)**.
  - **170px SVG Circular Countdown Ring:** An animated SVG circle that smoothly depletes over 60 seconds around a clean, centered numeric countdown timer.
  - **Idempotent Polling & Confirmation:** Verifies payment with the Apex backend upon countdown completion or manual "I Have Paid" click.

### 3. `ticketTypeCollector`
- **Purpose:** Custom Screen Flow component embedded inside `Event_Creation_Screen_Flow`.
- **Contract with Flow:**
  - **Input (`@api venueCapacity`):** Binds to the selected venue's capacity.
  - **Output (`@api ticketTypes`):** Outputs a collection of `TicketTypeWrapper` records.
  - **Output (`@api runningQuotaTotal`):** Real-time sum of ticket quotas.
- **Key Feature:** Replaces native Flow screen loops with a dynamic multi-row table where organizers can add/remove ticket tiers and preview remaining venue capacity in real-time.

### 4. `organizerDashboard`
- **Purpose:** Executive dashboard for Organizers and Managers.
- **Key Features:**
  - Metric summary cards: Total Events, Confirmed Registrations, Total Realized Revenue in ₹.
  - Event management table with status filter chips (`Draft`, `Pending Approval`, `Approved`, `Rejected`).
  - "Create Event" button launching the `Event_Creation_Screen_Flow`.

---

## 📂 `pages/` — Visualforce PDF Admission Pass

### `PrintableTicket.page`
- **Controller:** `controller="PrintableTicketExtension"`
- **Render Mode:** `renderAs="pdf"` (generates standard letter/A4 printable PDF).
- **Key Layout Sections:**
  - **Official Admission Header:** Event Title, Ticket Tier badge, Pass Status, and unique Ticket Number (`TKT-XXXXX`).
  - **Group Pass Badge:** Automatically renders `"Group Pass (N Attendees)"` when booking contains multiple tickets.
  - **Primary Booker & Venue Details:** Booker Name, Booker Email, Event Date/Time, Venue Name, Full Address, Booking Reference, and Total Paid in ₹.
  - **Booked Attendees Roster Table:** A clean numbered table listing every attendee in the group with their individual Name, Email, Phone, and Ticket Code.
  - **Barcode & Security Box:** Scannable barcode representation with terms and admission conditions.

---

## 📂 `objects/` — Custom Objects & Schema Architecture

| Object Name | API Name | Sharing Model | Key Responsibilities |
|---|---|---|---|
| **Event** | `Event__c` | Private | Core event metadata: budget, approval status, publication status, dates, capacity. |
| **Venue** | `Venue__c` | Private | Physical venue: address, city, contact person, maximum venue capacity. |
| **Ticket Type** | `Ticket_Type__c` | ControlledByParent (`Event__c`) | Tier configuration: VIP, General, Student; quota, price, available seats. |
| **Speaker** | `Speaker__c` | Private | Keynote speakers: bio, email, phone, expertise, linked event. |
| **Attendee** | `Attendee__c` | Private | Individual attendee identity: name, email, phone, organization, user lookup. |
| **Registration** | `Registration__c` | ControlledByParent (`Event__c`) | Junction record linking Attendee to Event & Ticket Type with booked price and booking group ID. |
| **Ticket** | `Ticket__c` | ControlledByParent (`Registration__c`) | Issued entry pass generated upon confirmed payment with autonumber `TKT-{00000}`. |
| **Payment** | `Payment__c` | Private | Financial transactions linked 1:1 with registrations with transaction reference and status. |
| **Feedback** | `Feedback__c` | Private | Post-event attendee reviews: overall rating (1-5), venue rating, speaker rating, comments. |

---

## 📂 `flows/` & `approvalProcesses/` — Automated Business Workflows

### 1. `Event_Creation_Screen_Flow` (Flow)
1. **Screen 1 (Event & Venue Selection):** Captures Title, Category, Start/End Dates, Venue (retrieves `Venue_Capacity__c`), and Proposed Budget.
2. **Screen 2 (Ticket Type Collection):** Embeds `ticketTypeCollector` LWC to dynamically configure ticket tiers.
3. **Threshold Check:** Inspects `Approval_Settings__mdt.Budget_Threshold__c` (₹2,00,000):
   - **Budget $\le ₹2,00,000$:** Routes to `Set_Approved`, automatically approving and publishing the event.
   - **Budget $> ₹2,00,000$:** Sets status to `Pending Approval` and submits to `Event_Budget_Approval` process.

### 2. `Event_Budget_Approval` (Approval Process)
- **Object:** `Event__c`
- **Entry Criteria:** `Approval_Status__c = 'Draft' AND Proposed_Budget__c > 200000`
- **Approver:** Assigned to user with role `Event_Manager`.
- **On Approval:** Sets `Approval_Status__c = 'Approved'`, `Publication_Status__c = 'Published'`, `Registration_Status__c = 'Open'`.
- **On Rejection:** Sets `Approval_Status__c = 'Rejected'` and prompts for rejection comments.

---

## 📂 `permissionsets/` — Multi-Persona Security Matrix

1. **`Event_Attendee_Permissions`:** Self-service booking, `CR` access on own registration/payment/feedback, Apex access to `EventBookingController` and `PrintableTicketExtension`.
2. **`Event_Organizer_Permissions`:** CRUD on `Event__c`, `Ticket_Type__c`, `Speaker__c`, read on `Venue__c` and `Feedback__c`, Apex access to `OrganizerDashboardController`.
3. **`Event_Manager_Permissions`:** Full organizational oversight across all events, budgets, attendees, and tickets.
4. **`Event_Registration_Team_Permissions`:** Operational CRUD on `Registration__c`, `Attendee__c`, `Ticket__c`, and check-in status.
5. **`Event_Finance_Permissions`:** Full CRUD and `View All / Modify All` on `Payment__c`, read on registrations and event budgets.
6. **`Event_Speaker_Coordinator_Permissions`:** Full CRUD on `Speaker__c`, read on events and venues.

---

# 3. Viva & Project Defense Cheat Sheet (Q&A for Sir)

### Q1: "Why did you declare `EventBookingController` as `without sharing`?"
> **Answer:** *"In our CRM, `Event__c` has a Private Org-Wide Default (OWD) so that organizers only manage their own events. However, Attendees are public/portal users who need to discover open, approved events. If the controller was `with sharing`, the private OWD would return 0 events to attendees. By using `without sharing`, attendees can query published events, while record-level security on payments and tickets is strictly enforced programmatically using `UserInfo.getUserId()`."*

### Q2: "How do you prevent overbooking if 100 users try to book the last 5 tickets simultaneously?"
> **Answer:** *"We enforce capacity at two distinct layers:
> 1. In `EventBookingController.cls`, we query remaining seats and validate before creating pending registrations.
> 2. In `RegistrationTriggerHandler.cls`, we use an in-memory tracking map (`runningBookedByTicketType`) that calculates running sums across all records in the execution batch. If the total exceeds the ticket type's quota, it calls `addError()` to rollback the transaction. If it fills the quota exactly, it atomically flips the status to 'Sold Out'."*

### Q3: "Why did you use a Custom Controller instead of a StandardController on `PrintableTicket.page`?"
> **Answer:** *"Initially, we had `standardController='Ticket__c'`. But in Salesforce, `Ticket__c` inherits sharing from `Registration__c`, which inherits from `Event__c` (Private OWD). When a standard controller executes with an ID parameter, Salesforce runs an internal pre-flight query in the user's sharing context. For an attendee who doesn't own the event, Salesforce threw a `NoDataFoundException`. Switching to a custom controller (`PrintableTicketExtension`) allows our Apex code to run with elevated privileges to generate the PDF pass while still validating that the ticket belongs to the user."*

### Q4: "How does the Screen Flow interact with the custom LWC component `ticketTypeCollector`?"
> **Answer:** *"We used Apex-Defined Data Types. We created an Apex class `TicketTypeWrapper` with `@AuraEnabled` fields (`name`, `price`, `quota`, `description`). The LWC defines `@api ticketTypes` and emits `FlowAttributeChangeEvent` whenever a user adds or removes a row. Flow receives this collection, loops through it, and performs a bulk insert."*

### Q5: "What is your budget approval threshold and how is it configurable?"
> **Answer:** *"Our threshold is ₹2,00,000 (2 Lakhs INR). Rather than hardcoding this number in Apex or Flow, we stored it in a Custom Metadata Type (`Approval_Settings__mdt.Default_Threshold`). Both our Screen Flow and Approval Process dynamically query this threshold. If leadership ever wants to change the threshold to ₹5,00,000, an admin can change it in Setup without modifying any code."*

### Q6: "Why is there only one trigger on `Registration__c`?"
> **Answer:** *"We follow Salesforce Enterprise Architecture Best Practices: One Trigger Per Object. Multiple triggers on the same object have non-deterministic execution orders. Having a single trigger that delegates to `RegistrationTriggerHandler` guarantees consistent execution order, clean bulkification, and high testability."*

---

# 4. Quick Verification Commands

```powershell
# Run all 36 Apex Tests
sf apex run test -o my-org -w 5 --result-format human

# Deploy entire project metadata
sf project deploy start -o my-org
```
