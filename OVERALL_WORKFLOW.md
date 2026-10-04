# Event Management CRM — Master Overall Workflow & Architecture Guide

> **Document Type:** Master End-to-End System Workflow  
> **Platform:** Salesforce Lightning Enterprise Platform (API v60.0)  
> **Source of Truth:** Workspace Metadata (`objects/`, `classes/`, `lwc/`, `flows/`, `approvalProcesses/`, `customMetadata/`, `permissionsets/`)  
> **Personas Covered:** System Administrator, Event Organizer, Event Manager / Approver, Attendee, Event Registration Team, Event Finance

---

## 1. Master System Workflow & Macro Architecture

The Event Management CRM coordinates 6 functional personas and automated background engines across the entire event lifecycle: from administrative provisioning and event inception, through dynamic budget approval, public discovery, multi-seat booking, simulated UPI payment, entry pass issuance, and post-event survey analytics.

```
═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
                                      MASTER END-TO-END WORKFLOW MAP
═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

   [1. SYSTEM ADMIN]               [2. EVENT ORGANIZER]            [3. EVENT MANAGER]              [4. ATTENDEE]
           │                                │                              │                             │
   Configures Org Baseline,                 │                              │                             │
   Venues, Custom Metadata                  │                              │                             │
   (Approval Matrix, UPI Gateway)           │                              │                             │
           │                                │                              │                             │
           └───────────────────────────────►│                              │                             │
                                    Launches Screen Flow                   │                             │
                                    [+ Create Event]                       │                             │
                                            │                              │                             │
                                    1. Basic Info & Category (9 Types)     │                             │
                                    2. Future Dates Scheduling             │                             │
                                    3. Venue Selection & Capacity Ceiling  │                             │
                                    4. Dynamic Ticket Tiers (LWC)          │                             │
                                    5. Proposed Budget (₹)                 │                             │
                                            │                              │                             │
                                            ▼                              │                             │
                                 [Dynamic Approval Engine]                 │                             │
                                  (Approval_Matrix__mdt)                   │                             │
                                            │                              │                             │
                            ┌───────────────┴───────────────┐              │                             │
                   Budget <= Auto-Limit            Budget > Auto-Limit     │                             │
                            │                               │              │                             │
                            ▼                               ▼              │                             │
                     [AUTO-APPROVED]                [PENDING APPROVAL]────►│                             │
                            │                                              │                             │
                            │                                       Reviews Details,                     │
                            │                                       Budget & Category                    │
                            │                                              │                             │
                            │                                       ┌──────┴──────┐                      │
                            │                                    APPROVE        REJECT                   │
                            │                                       │             │                      │
                            │                                       │      Mandatory Reason              │
                            │                                       │      (Resubmit / Cancel)           │
                            │                                       ▼             │                      │
                            └──────────────────────────────► [APPROVED EVENT]◄────┘                      │
                                                                    │                                    │
                                                            Organizer Publishes                          │
                                                           (Status = 'Published')                        │
                                                           (Reg Status = 'Open')                         │
                                                                    │                                    │
                                                                    ▼                                    │
                                                            [PRICING & QUOTA                             │
                                                             LOCKED BY DB VR]                            │
                                                                    │                                    │
                                                                    └───────────────────────────────────►│
                                                                                             Browses Events via Portal
                                                                                             (Event Booking Tab)
                                                                                                         │
                                                                                             Selects Tier & Seat Count
                                                                                             ([-] 2 [+])
                                                                                                         │
                                                                                             Enters Attendee Roster
                                                                                             (Name, Email, Phone)
                                                                                                         │
                                                                                                         ▼
                                                                                             [Atomic Multi-Seat Booking]
                                                                                             Creates Attendee & Regs
                                                                                             Assigns Booking_Group_Id__c
                                                                                             (Reg Status = 'Pending')
                                                                                                         │
                                                                                                         ▼
                                                                                             [Simulated UPI QR Payment]
                                                                                             Interactive LWC with
                                                                                             170px SVG Countdown Ring
                                                                                                         │
                                                                                                         ▼
   [5. FINANCE TEAM]            [AUTOMATED BACKEND ENGINES]                                  [Payment Confirmed]
           │                                │                                                            │
   Monitors Payments Ledger,                ├── 1. Idempotency Guard Checks Duplicate                    │
   Reconciles UPI References,               ├── 2. Payment__c Record Created (UPI/Successful)            │
   Verifies Webhook Signatures              ├── 3. Registration Status Flips to 'Confirmed'             │
           ▲                                └── 4. Ticket__c Entry Passes Issued (TKT-XXXXX)             │
           │                                        │                                                    ▼
           └────────────────────────────────────────┴───────────────────────────────────────► [Downloads PDF Pass]
                                                    │                                         Visualforce Barcoded Pass
                                                    │                                         with Full Attendee Roster
                                                    ▼                                                    │
                                     [24 Hours Prior to Event Start]                                     │
                                     Scheduled Flow Sends Reminder Email                                 │
                                     with Ticket Barcode & Venue Link                                    │
                                                    │                                                    │
   [6. REGISTRATION TEAM]                           │                                                    │
           │                                        ▼                                                    │
   On-Desk Barcode Scanning ◄─────────────── [EVENT HAPPENS] ◄───────────────────────────────────────────┘
   Updates Ticket to 'Checked In'                   │
                                                    ▼
                                     [10 Hours Post Event End]
                                     Scheduled Flow Sends Survey Request
                                                    │
                                                    ▼
                                     Attendee Submits Rating (1–5 Stars)
                                     Feedback_Submitted__c Flag Locked
═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 2. System Administrator Workflow

The **System Administrator** sets up the organizational foundation, security baselines, and configuration tables.

### 2.1 User Provisioning & Role Hierarchy Assignment
1. **Creates Standard Users** and assigns them to the **Role Hierarchy**:
   - `Event Manager` sits at the top.
   - `Event Organizer`, `Event Finance`, and `Event Speaker Coordinator` report to `Event Manager`.
   - `Event Registration Team` reports to `Event Organizer`.
2. **Assigns Modular Permission Sets:**
   - Assigns `Event_Manager_Permissions`, `Event_Organizer_Permissions`, `Event_Finance_Permissions`, `Event_Registration_Team_Permissions`, or `Event_Speaker_Coordinator_Permissions` based on employee role.
   - Assigns `Event_Management_Core_Access` (Permission Set Group) to grant baseline platform access.

### 2.2 Organization-Wide Defaults (OWD) Governance
Ensures strict least-privilege data isolation:
- `Event__c`: **Private** (Organizers only see their own records; Managers see all via hierarchy).
- `Venue__c`: **Public Read Only** (Physical venues visible to all organizers; editable only by Admins/Ops).
- `Attendee__c`: **Private** (Customer PII protection).
- `Registration__c`, `Ticket_Type__c`, `Ticket__c`, `Payment__c`, `Feedback__c`: **Controlled by Parent** (Detail objects in Master-Detail relationships inherit parent security).

### 2.3 Master Data & Venue Setup
- Populates `Venue__c` physical asset records:
  - Facility Name (e.g. *Bangalore International Exhibition Centre*).
  - City (e.g. *Bangalore*).
  - Physical Safety Limit (`Venue_Capacity__c = 1500`).
  - Contact Operations details.

### 2.4 Custom Metadata Configuration
Admin manages 3 Custom Metadata Types without requiring code deployments:
1. **`Approval_Matrix__mdt`:** Defines multi-tier budget approval ceilings across the 9 event categories:
   - Concert (Auto: ₹3L, Manager: ₹15L, Finance Signoff > ₹15L).
   - Conference (Auto: ₹2.5L, Manager: ₹10L, Finance Signoff > ₹10L).
   - Hackathon (Auto: ₹1.5L, Manager: ₹5L, Finance Signoff > ₹5L).
   - Workshop / Training (Auto: ₹1L, Manager: ₹3L, Finance Signoff > ₹3L).
   - Meetup (Auto: ₹50K, Manager: ₹1.5L, Finance Signoff > ₹1.5L).
   - Webinar (Auto: ₹30K, Manager: ₹1L, Finance Signoff > ₹1L).
   - Executive Summit (Auto: ₹0 [Always Review], Manager: ₹5L, Finance Signoff > ₹5L).
   - Other (Auto: ₹50K, Manager: ₹2L, Finance Signoff > ₹2L).
2. **`Approval_Settings__mdt`:** Global fallback threshold (`Budget_Threshold__c = 200000`).
3. **`Payment_Gateway_Config__mdt`:** Active gateway credentials:
   - Provider (`Razorpay`, `Stripe`, `UPI_Sandbox`).
   - Environment (`Sandbox` or `Production`).
   - Active Merchant VPA (`UPI_VPA__c = events@upi`).
   - Auto-verify countdown duration (`Auto_Verify_Seconds__c = 10`).
   - Webhook cryptographic HMAC SHA256 secret.

---

## 3. Event Organizer Workflow

The **Event Organizer** is the event creator and campaign owner.

### 3.1 Accessing the Command Center
1. Organizer logs in and opens the **Organizer Dashboard** (`lwc/organizerDashboard`).
2. Dashboard queries events owned by the user using `OrganizerDashboardController.cls` (`public with sharing class`).
3. Displays live KPI summary cards:
   - **Total Events Managed**
   - **Active Registered Attendees**
   - **Gross Event Revenue (₹)**
   - **Seat Occupancy Rate (%)**

### 3.2 Creating an Event via Guided Screen Flow
Organizer clicks **`[+ Create Event]`**, launching `Event_Creation_Screen_Flow`:
- **Step 1 (Details):** Inputs Event Name, Description, and selects one of the 9 Categories.
- **Step 2 (Dates):** Selects Start & End Date/Times. Database validation rules ensure the start date is in the future and the end date is strictly after the start date.
- **Step 3 (Venue):** Selects an active venue. Flow retrieves and displays the venue's physical safety limit (`Venue_Capacity__c`).
- **Step 4 (Dynamic Ticket Tiers):** Flow embeds `ticketTypeCollector` LWC:
  - Organizer clicks **"Add Ticket Tier"** to create $N$ tiers (e.g. *Early Bird ₹1,000 / Quota 100*, *VIP Pass ₹5,000 / Quota 50*).
  - The component runs real-time client-side aggregation: if `SUM(Quotas) > Venue_Capacity__c`, an immediate warning prevents overbooking before save.
- **Step 5 (Proposed Budget):** Inputs target event budget (`Proposed_Budget__c` in ₹).
- **Step 6 (Review & Final Submission):** Submits event. Flow atomically inserts the `Event__c` and related `Ticket_Type__c` records.

### 3.3 Dynamic Approval Routing & Resolution
The event triggers `EventApprovalService.cls`:
- **Scenario A (Within Auto-Approve Ceiling):**
  - If Budget $\le$ Category Auto-Approve Limit, the system automatically sets `Approval_Status__c = 'Approved'`.
  - The organizer receives an instant confirmation banner and can publish immediately.
- **Scenario B (Exceeds Auto-Limit):**
  - System sets `Approval_Status__c = 'Pending Approval'`.
  - Event record is locked against modifications.
  - Automatically submitted to the Salesforce Approval Process for Manager / Finance review.
- **Scenario C (Rejected by Manager):**
  - Manager enters mandatory rejection feedback (`Rejection_Reason__c`).
  - Organizer receives notification.
  - Organizer can either edit the budget/venue and resubmit, or cancel the event (`Approval_Status__c = 'Cancelled'`).

### 3.4 Event Publication & Pricing Lockdown
1. Once approved, the organizer clicks **"Publish Event"**:
   - `Publication_Status__c` transitions to `Published`.
   - `Registration_Status__c` transitions to `Open`.
2. **Database Integrity Lock:**
   - Validation rules `No_Price_Change_After_Registration_Open` and `No_Quota_Change_After_Registration_Open` automatically lock ticket prices and quotas against accidental alteration.
   - Validation rule `Quota_Not_Below_Booked_Seats` guarantees quotas can never be reduced below tickets already booked.

---

## 4. Event Manager / Approver Workflow

The **Event Manager** represents executive oversight, budget governance, and organizational reporting.

### 4.1 Reviewing Approval Work Items
1. Manager receives email notification and in-app bell notification when an event budget requires review.
2. Navigates to **Approval Requests** in Salesforce:
   - Evaluates proposed budget against category ceilings.
   - Verifies expected ROI, venue selection, and ticket pricing tiers.
3. **Approver Actions:**
   - **Approve:** Updates `Approval_Status__c = 'Approved'` and sets `Approved_By__c = UserInfo.getUserId()`. Event is unlocked and ready for publication.
   - **Reject:** Prompts for mandatory comments. Sets `Approval_Status__c = 'Rejected'` and stores comments in `Rejection_Reason__c`.
4. **Self-Approval Guard:**
   - Approval routing rules and database validation rule `No_Self_Approval` guarantee that an organizer can never approve their own event.

### 4.2 Executive Analytics & P&L Oversight
- Manager opens the **Executive BI Dashboard**:
  - Views cross-category revenue trends.
  - Compares venue utilization and capacity bottlenecks.
  - Reviews post-event satisfaction scores across all events.

---

## 5. Attendee Journey & Booking Workflow

The **Attendee** is the customer discovering events and purchasing tickets.

### 5.1 Public Event Discovery
1. Attendee opens the **Event Booking Portal** (`Event_Booking` tab / LWC).
2. Browse published, active events. Controller filters out draft, unapproved, cancelled, or closed events.
3. Attendee filters by category, location, or date.
4. Clicks **"Book Tickets"** on the desired event card.

### 5.2 Multi-Ticket Selection & Attendee Roster
1. Attendee selects a ticket tier (e.g. *General Admission ₹2,000*).
2. Uses the quantity stepper (`[-] 2 [+]`) to select the number of passes ($N$ seats).
3. The UI expands to render an individual entry roster for each seat:
   - Primary Booker: Name, Email, Phone.
   - Additional Guest(s): Name, Email, Phone.
4. Clicks **"Proceed to Payment"**.

### 5.3 Atomic Multi-Seat Reservation
Frontend calls `EventBookingController.bookMultipleTickets()`:
- **Server-Side Concurrency Lock:** Queries `Ticket_Type__c` using `[SELECT ... FOR UPDATE]` to prevent race conditions.
- Verifies `Available_Seats__c >= N`.
- Generates/matches `Attendee__c` records.
- Inserts $N$ `Registration__c` records with `Registration_Status__c = 'Pending'`.
- Generates a unique group identifier: `Booking_Group_Id__c` (e.g. `GRP-1725538000-842`).
- Locks in `Booked_Price__c` for each pass.

### 5.4 Simulated UPI QR Payment & Verification
1. LWC component `paymentQrVerification` opens:
   - Fetches merchant configuration from `Payment_Gateway_Config__mdt` (`events@upi`).
   - Generates dynamic UPI payload: `upi://pay?pa=events@upi&pn=EventHub&am=4000.00&tr=GRP-1725538000-842`.
   - Renders a live QR code inside a **170px SVG Circular Countdown Ring** (10-second timer).
2. Attendee completes the payment simulation:
   - Upon timer expiry or clicking **"I Have Paid"**, frontend invokes `confirmPayment()`.
3. **Apex Execution (`confirmPayment`):**
   - **Idempotency Guard:** Verifies no payment record already exists for this registration group.
   - Inserts `Payment__c` record (`Payment_Status__c = 'Successful'`, `Payment_Method__c = 'UPI'`, `Amount__c = 4000.00`).
   - Atomically updates all registrations in the booking group from `Pending` to `Confirmed`.
   - Generates official `Ticket__c` records (`TKT-00101`, `TKT-00102`).

### 5.5 Printable Barcoded Ticket Pass
1. Attendee navigates to **"My Tickets"** tab.
2. Clicks **"View / Print Pass"**, opening `PrintableTicket.page` (Visualforce PDF):
   - Displays event banner, start date, end date, and venue map location.
   - Machine-scannable barcode generated from `Ticket__c.Name`.
   - Primary booker details and transaction reference (`UPI-1725538000-9842`).
   - **Complete Co-Attendee Roster:** Tables all attendees registered under that `Booking_Group_Id__c`.

---

## 6. On-Desk Registration Team Workflow

The **Event Registration Team** operates at the physical venue on the day of the event.

### 6.1 Attendee Check-In & Entry Verification
1. Attendee arrives at the venue gate and presents their printed or mobile PDF pass.
2. Registration Team staff uses a barcode scanner or mobile device:
   - Scans barcode (`TKT-XXXXX`).
   - Queries `Ticket__c` and related `Registration__c` record.
3. If ticket is `Active`:
   - Staff clicks **"Check In"**, updating `Ticket_Status__c = 'Checked In'`.
   - Badge is printed or admission band issued.
4. If ticket is already `Checked In` or `Cancelled`:
   - System displays an immediate visual warning preventing duplicate entry fraud.

### 6.2 Assisting Walk-In Registrations
- If seats remain available (`Available_Seats__c > 0`), staff can create on-desk bookings for walk-in attendees directly through the registration desk interface.

---

## 7. Event Finance Team Workflow

The **Event Finance** persona handles revenue tracking, ledger auditing, and payment gateway health.

### 7.1 Financial Audit & Reconciliation
1. Finance user navigates to the **Payments Ledger**:
   - Accesses `Payment__c` records with full read/edit access.
   - Verifies gateway transaction references (`Transaction_Reference__c`).
   - Validates that `Payment__c.Amount__c` matches `Registration__r.Booked_Price__c` (`Amount_Matches_Registration_Booked_Price` validation rule).
2. **Refund Management:**
   - In case of event cancellation or attendee withdrawal, finance updates `Payment_Status__c = 'Refunded'`.

### 7.2 Webhook Signature Verification
- In production integrations with Razorpay or Stripe, incoming webhooks hit Salesforce REST endpoints.
- `PaymentGatewayService.verifyWebhookSignature()` calculates HMAC SHA256 hashes against `Webhook_Secret__c` to authenticate incoming gateway callbacks before flipping transaction statuses.

---

## 8. Automated Background Engines (Flows & Triggers)

The CRM relies on automated platform engines that run in the background without user intervention:

### 8.1 Apex Triggers
1. **`TicketTypeTriggerHandler` (Before Insert / Before Update):**
   - Aggregates the sum of all ticket quotas under the parent event.
   - Cross-checks against `Venue__c.Venue_Capacity__c`.
   - Throws field error if total quotas exceed physical venue safety limits.
2. **`RegistrationTriggerHandler` (Before Insert / After Insert):**
   - Acquires pessimistic lock on `Ticket_Type__c` using `FOR UPDATE`.
   - Enforces real-time seat availability checks under high concurrency.
   - Increments `Ticket_Type__c.Booked_Seats__c` atomically upon registration creation.
   - Automatically marks tier as `Sold Out` when `Available_Seats__c == 0`.

### 8.2 Scheduled Lifecycle Flows
1. **Pre-Event Reminder Flow (Scheduled Flow):**
   - Scheduled path executes **exactly 24 hours prior** to `Event__c.Start_Date_Time__c`.
   - Selects all confirmed registrations for the event.
   - Dispatches automated reminder email with venue directions, start time, and printable ticket link.
2. **Post-Event Feedback Survey Flow (Scheduled Flow):**
   - Scheduled path executes **exactly 10 hours post** `Event__c.End_Date_Time__c`.
   - Sends survey invitation to all attendees who checked in.
   - Attendee completes 1–5 star rating across Overall, Venue, and Speaker experience.
   - Database trigger marks `Registration__c.Feedback_Submitted__c = TRUE` to guarantee one review per attendee.

---

## 9. Entity State Machine & Lifecycle Transitions

### 9.1 `Event__c` Lifecycle

```
[Draft]
   │
   ▼
[Pending Approval] ──(Rejection)──► [Rejected] ──(Edit & Resubmit)──► [Pending Approval]
   │                                   │
   │ (Approval)                        └──(Cancel)──► [Cancelled]
   ▼
[Approved]
   │
   ▼ (Organizer Clicks Publish)
[Published]
   │
   ▼ (Registration Opens)
[Registration: Open] ──(All Seats Filled)──► [Registration: Sold Out]
   │                                                 │
   ▼ (Event Date Passed)                             ▼
[Registration: Closed] ───────────────────────► [Completed]
```

### 9.2 `Registration__c` Lifecycle

```
[Pending] ──(Payment Complete)──► [Confirmed] ──(Ticket Issued)──► [Active Pass]
   │                                   │
   └──(Timeout / Abandon)──► [Cancelled]└──(Cancellation)────────► [Cancelled / Refunded]
```

### 9.3 `Ticket__c` Lifecycle

```
[Active] ──(Scanned at Gate)──► [Checked In]
   │
   └──(Registration Cancelled)──► [Cancelled]
```

---

## 10. Viva / Technical Defense Master Q&A

### Q1: "Walk me through what happens behind the scenes when an Attendee books 3 tickets."
> **Answer:**  
> *"Sir, when the attendee selects 3 seats and fills out the roster, our LWC calls `EventBookingController.bookMultipleTickets()`.  
> 1. In Apex, we lock the `Ticket_Type__c` record using `[SELECT ... FOR UPDATE]` to prevent concurrent race conditions.  
> 2. We verify that `Available_Seats__c >= 3`.  
> 3. We create or match 3 `Attendee__c` records and insert 3 `Registration__c` records with `Registration_Status__c = 'Pending'`.  
> 4. All 3 registrations share a single `Booking_Group_Id__c` external ID.  
> 5. The attendee is presented with our UPI QR modal. Once verified, `confirmPayment()` executes an atomic transaction: it inserts a single `Payment__c` record, flips all 3 registrations to `Confirmed`, and generates 3 individual `Ticket__c` entry passes (`TKT-XXXXX`)."*

### Q2: "How does the Dynamic Approval Engine decide whether an event needs approval?"
> **Answer:**  
> *"Instead of hardcoding a single threshold, we implemented a dynamic matrix using Custom Metadata Type `Approval_Matrix__mdt` and service class `EventApprovalService.cls`.  
> When an event is submitted, the engine looks up the record matching `Event__c.Category__c`.  
> - If `Proposed_Budget__c` is within `Auto_Approve_Limit__c`, it is auto-approved instantly.  
> - If it exceeds the auto-limit but is within `Manager_Approve_Limit__c`, it routes to the Event Manager.  
> - If it exceeds the manager limit, it flags `Requires_Finance_Signoff__c = true` and escalates to senior executive approval. This allows the business to tune approval rules without modifying code."*

### Q3: "What happens if an event's registration window closes while an attendee is scanning the QR code?"
> **Answer:**  
> *"Sir, we anticipated this exact timing condition. Our validation rule `No_Reg_On_Unpublished_Or_Closed_Event` is guarded with `ISNEW()`. This means the rule only gates the initial booking creation. When `confirmPayment()` runs 10 seconds later to update the registration from `Pending` to `Confirmed`, the `ISNEW()` condition evaluates to false, allowing the payment confirmation and ticket issuance to complete cleanly without trapping the attendee's transaction."*

### Q4: "How is record security preserved when Organizers, Managers, and Attendees use the system?"
> **Answer:**  
> *"We follow Salesforce's Defense-in-Depth model:  
> 1. `Event__c` OWD is **Private**, meaning Organizers can only see and edit events they own.  
> 2. The **Role Hierarchy** opens up visibility vertically so Event Managers automatically see all events owned by subordinate organizers.  
> 3. Detail records (`Registration__c`, `Ticket__c`, `Ticket_Type__c`) are set to **Controlled by Parent**.  
> 4. Internal controllers (`OrganizerDashboardController`) run in `with sharing` to enforce database row security, while the guest booking controller (`EventBookingController`) runs in `without sharing` with strict server-side validation to allow public bookings safely."*
