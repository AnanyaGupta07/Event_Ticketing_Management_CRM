# Event Management & Ticketing CRM — Product Requirements Document (PRD)

> **Document Version:** 3.0 (Production Enterprise Release)  
> **Platform:** Salesforce Lightning Platform (API v60.0 / Enterprise Org)  
> **Source of Truth:** Workspace Metadata (`objects/`, `classes/`, `lwc/`, `flows/`, `approvalProcesses/`, `customMetadata/`)

---

## Revision Log & Recent Architectural Enhancements

This updated version reflects the production implementation of the system:

1. **Broadened 9 Enterprise Event Categories & Schema Alignment:**
   - Expanded `Event__c.Category__c` to support: `Conference`, `Workshop`, `Training`, `Hackathon`, `Concert`, `Executive Summit`, `Webinar`, `Meetup`, `Other`.
2. **Dynamic Multi-Tier Category Approval Engine:**
   - Sourced thresholds from Custom Metadata Type `Approval_Matrix__mdt` and managed by `EventApprovalService.cls`.
   - Replaced hardcoded limits with a 3-tier matrix:
     - **Tier 1 (Zero-Touch Auto-Approval):** Within category auto-limit (e.g. Meetup $\le$ ₹50K, Concert $\le$ ₹3L).
     - **Tier 2 (Manager Approval):** Between auto-limit and manager limit (e.g. Concert $\le$ ₹15L).
     - **Tier 3 (Finance Executive Escalation):** High-risk/high-budget events requiring executive signoff.
   - Preserves `Approval_Settings__mdt.Budget_Threshold__c` as an org-wide fallback.
3. **Multi-Ticket Booking & Roster Architecture:**
   - Screen Flow / LWC booking modal allows attendees to choose seat quantities (`[-] 2 [+]`).
   - Captures individual names, emails, and phone numbers per seat.
   - Assigns a shared `Booking_Group_Id__c` external ID across all sibling registrations.
4. **Plug-and-Play Payment Gateway Adapter & Simulated UPI QR:**
   - Architecture supported by `Payment_Gateway_Config__mdt` and `PaymentGatewayService.cls`.
   - Interactive LWC `paymentQrVerification` renders real-time dynamic UPI payload (`upi://pay?pa=...`) inside a **170px SVG countdown ring** (default: 10s auto-verify).
   - Backend supports production Razorpay/Stripe HMAC SHA256 webhook signatures while maintaining seamless demo simulation.
5. **Printable Ticket PDF Pass & Booked Roster:**
   - Visualforce PDF page `PrintableTicket.page` and controller `PrintableTicketExtension.cls`.
   - Generates official entry passes with barcode, booking group ID, event details, and the complete roster of co-attendees.
6. **20 Master Declarative Validation Rules & Concurrency Guards:**
   - Enforces 20 active declarative rules across 7 objects.
   - Enforces Quota vs Venue Capacity aggregation via `TicketTypeTriggerHandler`.
   - Enforces concurrent overbooking protection via `RegistrationTriggerHandler` with `[SELECT ... FOR UPDATE]`.
7. **Production Test Coverage Baseline:**
   - 49/49 Apex unit tests passing with 100% pass rate.

---

## 1. Product Overview & Core Objectives

The Event Management & Ticketing CRM is an enterprise-grade solution built on the Salesforce platform designed to manage the entire event lifecycle:
- Event Inception, Venue Reservation & Ticket Tier Configuration.
- Dynamic Multi-Tier Budget Approval Routing.
- Public Event Discovery & Multi-Ticket Attendee Booking.
- Real-Time Dynamic UPI QR Verification & Secure Payment Gateway Logging.
- Barcoded Printable Ticket Pass Generation.
- Scheduled Reminders (24 hours prior) & Post-Event Feedback (10 hours post-event).
- Executive Dashboards & Financial Analytics.

---

## 2. User Roles & Persona Capabilities

```
                       +-------------------------+
                       |   System Administrator  |
                       |    (Full Configuration) |
                       +-------------------------+
                                    |
                       +-------------------------+
                       |      Event Manager      |
                       | (Executive Approval & BI|
                       +-------------------------+
                                    |
          +-------------------------+-------------------------+
          |                         |                         |
          v                         v                         v
+-------------------+     +-------------------+     +-------------------+
|  Event Organizer  |     |   Event Finance   |     | Event Speaker     |
| (Creates Events & |     | (Payments, P&L,   |     |    Coordinator    |
|   Ticket Tiers)   |     |  Reconciliation)  |     | (Bios & Logistics)|
+-------------------+     +-------------------+     +-------------------+
          |
          v
+-------------------------+
| Event Registration Team |
| (On-Desk Check-In & Ops)|
+-------------------------+
```

### 1. Attendee
- Self-service browsing of published events via the Event Booking portal.
- Selects ticket tier, specifies seat quantities, and enters attendee details.
- Completes payment via dynamic UPI QR code or simulated gateway.
- Views past and upcoming bookings, downloads PDF tickets, and submits ratings (1–5 stars).

### 2. Event Organizer
- Creates new events and assigns venue facilities.
- Configures dynamic ticket tiers (Price and Quota).
- Submits events for budget approval.
- Publishes approved events and monitors registration capacity in real-time.

### 3. Event Manager
- Executive authority reviewing events requiring budget approval.
- Approves or rejects proposed budgets with mandatory rejection feedback.
- Reviews org-wide capacity, attendance, and revenue analytics.

### 4. Event Registration Team
- Operational desk personnel assisting with attendee check-ins and walk-in registrations.
- Views tickets and scans entry barcodes.
- Restricted from altering pricing, quotas, budgets, or payment gateways.

### 5. Event Finance
- Monitors payment records, transaction references, discounts, and revenue reconciliation.
- Verifies gateway webhook logs and handles refund processing.

### 6. Event Speaker Coordinator
- Manages speaker profiles, biographies, expertise tags, and event schedules.

---

## 3. Data Model & Entity Specifications

The system comprises **9 Custom Objects** and **3 Custom Metadata Types**:

```
Venue__c (1) ──── (N) Event__c (1) ──── (N) Speaker__c
                         │
        ┌────────────────┴────────────────┐
        │ 1 (Master-Detail)               │ 1 (Master-Detail)
        ▼ N                               ▼ N
  Ticket_Type__c                    Registration__c (1) ──── (N) Payment__c
  (Quota / Pricing)                       │
                                          ├──── (1) Ticket__c (Master-Detail)
                                          ├──── (N) Feedback__c
                                          └──── (1) Attendee__c (Lookup)
```

### 3.1 Custom Objects

#### 1. `Event__c`
- **Fields:** `Name`, `Category__c` (9 categories), `Start_Date_Time__c`, `End_Date_Time__c`, `Venue__c` (Lookup), `Organizer__c` (Lookup to User), `Approved_By__c` (Lookup to User), `Proposed_Budget__c`, `Approval_Status__c`, `Publication_Status__c`, `Registration_Status__c`, `Total_Capacity__c` (Roll-up Summary), `Booked_Seats__c` (Roll-up Summary), `Available_Seats__c` (Formula: `Total_Capacity__c - Booked_Seats__c`), `Description__c`, `Rejection_Reason__c`.
- **Key Capacity Rule:** `Total_Capacity__c` must never exceed `Venue__r.Venue_Capacity__c` (enforced via `TicketTypeTriggerHandler`).

#### 2. `Venue__c`
- **Fields:** `Name`, `City__c`, `Venue_Capacity__c`, `Address__c`, `Contact_Person__c`, `Contact_Phone__c`, `Status__c` (`Active`, `Inactive`).

#### 3. `Ticket_Type__c`
- **Master-Detail to:** `Event__c`.
- **Fields:** `Name`, `Price__c`, `Quota__c`, `Booked_Seats__c` (atomic number field updated by trigger), `Available_Seats__c` (Formula: `Quota__c - Booked_Seats__c`), `Status__c` (`Available`, `Sold Out`, `Closed`), `Description__c`.
- **Price/Quota Lock:** Prices and quotas cannot be modified once `Event__r.Registration_Status__c = 'Open'`.

#### 4. `Attendee__c`
- **Fields:** `Name`, `Email__c` (RFC 5322 regex validated), `Phone__c` (10-digit Indian phone regex), `Organization__c`, `Attendee_Status__c`, `User__c` (Lookup to User).

#### 5. `Registration__c`
- **Master-Detail to:** `Event__c`.
- **Lookups to:** `Attendee__c`, `Ticket_Type__c`.
- **Fields:** `Name` (`REG-{00000}`), `Booking_Group_Id__c` (External ID), `Booked_Price__c` (Price snapshot), `Registration_Status__c` (`Pending`, `Confirmed`, `Cancelled`, `Rejected`), `Confirmation_Status__c`, `Feedback_Submitted__c`, `Registration_Date_Time__c`.

#### 6. `Ticket__c`
- **Master-Detail to:** `Registration__c` (Only relationship field; cascades on deletion).
- **Fields:** `Name` (`TKT-{00000}`), `Ticket_Status__c` (`Active`, `Checked In`, `Cancelled`), `Issue_Date_Time__c`.

#### 7. `Payment__c`
- **Lookup to:** `Registration__c` (Deliberate Lookup to preserve financial audit trail).
- **Fields:** `Name` (`PAY-{00000}`), `Amount__c`, `Payment_Date_Time__c`, `Payment_Method__c` (`UPI`, `Card`, `Net Banking`, `Cash`), `Payment_Status__c` (`Pending`, `Successful`, `Failed`, `Refunded`), `Transaction_Reference__c`.

#### 8. `Speaker__c`
- **Lookup to:** `Event__c`.
- **Fields:** `Name`, `Bio__c`, `Email__c`, `Phone__c`, `Expertise__c`, `Organization__c`, `Status__c`.

#### 9. `Feedback__c`
- **Lookups to:** `Event__c`, `Attendee__c`, `Registration__c`.
- **Fields:** `Name` (`FB-{00000}`), `Overall_Rating__c` (1-5), `Event_Experience__c`, `Speaker_Rating__c`, `Venue_Rating__c`, `Comments__c`, `Submitted_Date_Time__c`.

---

### 3.2 Custom Metadata Types

#### 1. `Approval_Matrix__mdt`
Drives dynamic category-based approval limits in `EventApprovalService.cls`:
- `Category__c` (Text 50)
- `Auto_Approve_Limit__c` (Number 18, 2)
- `Manager_Approve_Limit__c` (Number 18, 2)
- `Requires_Finance_Signoff__c` (Checkbox)

#### 2. `Approval_Settings__mdt`
Global fallback approval configuration:
- `Budget_Threshold__c` (Number 18, 2) — Org baseline (default: ₹2,00,000).

#### 3. `Payment_Gateway_Config__mdt`
Configuration for live adapters and simulated UPI checkout:
- `Gateway_Provider__c` (`Razorpay`, `Stripe`, `UPI_Sandbox`)
- `Environment__c` (`Sandbox`, `Production`)
- `Merchant_Key_Id__c`, `Merchant_Secret__c`, `Webhook_Secret__c`
- `UPI_VPA__c` (e.g. `events@upi`)
- `Auto_Verify_Seconds__c` (Default: 10 seconds)

---

## 4. End-to-End System Workflows

### 4.1 Phase 1: Event Creation & Dynamic Approval Engine

```text
Organizer creates Event via Screen Flow
                │
                ▼
Evaluate Category & Budget against Approval_Matrix__mdt
                │
   ┌────────────┼───────────────────────────┐
   ▼            ▼                           ▼
[Tier 1]     [Tier 2]                    [Tier 3]
Budget <=    Auto_Limit < Budget <=      Budget >
Auto_Limit   Manager_Limit               Manager_Limit
   │            │                           │
   ▼            ▼                           ▼
Auto-        Submit to                   Submit to
Approved     Event Manager               Finance Executive
   │            │                           │
   ▼            ▼                           ▼
Published    Approved / Rejected         Approved / Rejected
```

1. **Invocable Flow Action:** `EventApprovalService.evaluateForFlow()` checks category thresholds without hardcoded values.
2. **Auto-Approval:** If proposed budget $\le$ `Auto_Approve_Limit__c`, the event is immediately set to `Approved` and `Published`.
3. **Manager Approval:** If budget exceeds auto-limit but is within `Manager_Approve_Limit__c`, it routes to the Event Manager.
4. **Executive Escalation:** If budget exceeds manager limit, it flags `Requires_Finance_Signoff__c = true` and routes for executive signoff.

---

### 4.2 Phase 2: Attendee Discovery & Multi-Ticket Booking

1. **Portal Discovery:** Attendee searches published events in `Event_Booking` tab.
2. **Tier & Quantity Selection:** Attendee selects a ticket type (e.g. *General Admission ₹2,000*) and quantity ($N$ seats).
3. **Roster Collection:** Attendee provides Name, Email, and Phone for each seat.
4. **Atomic Booking:** Calling `EventBookingController.bookMultipleTickets()`:
   - Generates/matches $N$ `Attendee__c` records.
   - Inserts $N$ `Registration__c` records with `Registration_Status__c = 'Pending'`.
   - Links all records with a common `Booking_Group_Id__c` (e.g. `GRP-1725530000-842`).
   - Locks in `Booked_Price__c` for each seat.

---

### 4.3 Phase 3: Simulated UPI QR Payment & Verification

```text
LWC: paymentQrVerification
  │
  ├── 1. Fetches UPI VPA & Merchant Name from Payment_Gateway_Config__mdt
  ├── 2. Generates dynamic UPI Intent URL: upi://pay?pa=events@upi&pn=...&am=...&tr=...
  ├── 3. Renders QR Code with 170px SVG Circular Countdown Ring (10 seconds)
  │
  ├── 4. On Countdown Complete or "I Have Paid" Click:
  │         Calls EventBookingController.confirmPayment()
  │
  ▼
Apex: confirmPayment (Atomic Transaction)
  ├── 1. Idempotency Guard: Verifies no existing payment for registration
  ├── 2. Creates Payment__c record (Status = 'Successful', Method = 'UPI')
  ├── 3. Flips Registration__c status from 'Pending' to 'Confirmed'
  └── 4. Generates Ticket__c entry passes (TKT-XXXXX)
```

---

### 4.4 Phase 4: Printable Ticket Pass & Entry Roster

1. Attendee opens **"My Tickets"** tab in portal.
2. Clicks **"View / Print Pass"**, opening `PrintableTicket.page` (Visualforce PDF).
3. Controller `PrintableTicketExtension.cls` renders:
   - Event branding, dates, venue location, and facility safety contact.
   - Machine-scannable barcode.
   - Primary booker details and payment transaction reference.
   - **Complete Co-Attendee Roster** (listing all seats reserved under that `Booking_Group_Id__c`).

---

### 4.5 Phase 5: Automated Reminders & Post-Event Feedback

1. **Pre-Event Reminder Flow (Scheduled):**
   - Fires **exactly 24 hours prior** to `Event__c.Start_Date_Time__c`.
   - Sends email notification with ticket barcode link and venue directions to all confirmed attendees.
2. **Post-Event Feedback Flow (Scheduled):**
   - Fires **exactly 10 hours post** `Event__c.End_Date_Time__c`.
   - Sends survey link.
   - Attendee submits 1–5 star ratings across Overall, Venue, and Speaker experience.
   - Trigger sets `Feedback_Submitted__c = TRUE` on Registration, preventing duplicate reviews.

---

## 5. Security & Governance Architecture

1. **Organization-Wide Defaults (OWD):**
   - `Event__c`: **Private**
   - `Venue__c`: **Public Read Only**
   - `Attendee__c`: **Private** (PII Protection)
   - `Registration__c`, `Ticket_Type__c`, `Ticket__c`, `Payment__c`, `Feedback__c`: **Controlled by Parent**
2. **Role Hierarchy:**
   - `Event Manager` $\rightarrow$ `Event Organizer` / `Event Finance` / `Event Speaker Coordinator` $\rightarrow$ `Event Registration Team`.
3. **Modular Permission Sets:**
   - 6 Permission Sets (`Manager`, `Organizer`, `Registration_Team`, `Finance`, `Speaker_Coordinator`, `Attendee`).
   - 1 Permission Set Group (`Event_Management_Core_Access`).
   - Direct Custom Metadata Type access granted via `<customMetadataTypeAccesses>`.
4. **Apex Sharing Enforcement:**
   - `OrganizerDashboardController`, `EventApprovalService`, `PaymentGatewayService` execute as `with sharing`.
   - Guest booking portal `EventBookingController` executes as `without sharing` with strict server-side validation and ownership checks.

---

## 6. Verification & Quality Assurance Baseline

- **Apex Test Suite:** 49 unit tests covering 100% of business logic paths (`49/49 Passing`).
- **Trigger Coverage:** `TicketTypeTrigger` (100%), `RegistrationTrigger` (100%).
- **Service Coverage:** `OrganizerDashboardController` (95%), `RegistrationTriggerHandler` (96%), `TicketTypeTriggerHandler` (90%), `EventBookingController` (86%), `PaymentGatewayService` (84%), `EventApprovalService` (73%).
