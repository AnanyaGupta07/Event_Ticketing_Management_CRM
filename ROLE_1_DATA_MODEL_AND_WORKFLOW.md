# ROLE 1: Data Model, Relationships, Validation Rules & Complete Project Workflow
## Dedicated Technical Defense & Viva Manual

---

## 📌 Role Objective
You are the **Data Architect & Lead Workflow Engineer**. Your responsibility during the evaluation/viva is to explain:
1. The relational database schema (ERD), entity definitions, and relationship types.
2. Roll-up summary fields and field calculations.
3. Every validation rule (formula, trigger condition, and business impact).
4. The full end-to-end lifecycle workflow of events, attendees, and tickets.

---

# 1. Entity Relationship Diagram (ERD) & Schema Architecture

```
     ┌──────────────┐
     │   Venue__c   │
     └──────┬───────┘
            │ 1
            │
            │ N (Lookup)
     ┌──────┴───────┐                         ┌──────────────┐
     │   Event__c   │◀───────(Lookup)─────────│  Speaker__c  │
     └──────┬───────┘                         └──────────────┘
            │
            ├──────────────────────────┐
            │ 1 (Master-Detail)        │ 1 (Master-Detail)
            ▼ N                        ▼ N
     ┌──────────────┐           ┌────────────────┐
     │Ticket_Type__c│           │ Registration__c│◀──────(Lookup)──────┐
     └──────────────┘           └──────┬─────────┘                     │
                                       │                        ┌──────┴───────┐
                                       ├─────────────┐          │  Attendee__c │
                                       │ 1 (M-D)     │ 1 (Lookup)└──────────────┘
                                       ▼ N           ▼ N
                                ┌──────────────┐ ┌──────────────┐
                                │   Ticket__c  │ │  Payment__c  │
                                └──────────────┘ └──────────────┘
                                       ▲
                                       │ (Lookup)
                                ┌──────┴───────┐
                                │  Feedback__c │
                                └──────────────┘
```

---

# 2. Detailed Object Dictionary & Relationships

### 1. `Event__c` (Master Event Record)
- **Purpose:** Core table storing event lifecycle metadata, budget, venue link, and capacity.
- **Key Relationships:**
  - `Venue__c` (Lookup to `Venue__c`): Selected venue hosting the event.
  - `Organizer__c` (Lookup to `User`): The event manager/organizer in charge.
- **Roll-up Summary & Capacity Fields:**
  - `Total_Capacity__c` (Roll-up Summary: `SUM(Ticket_Type__c.Quota__c)`): Total seats across all ticket tiers.
  - `Booked_Seats__c` (Roll-up Summary: `SUM(Ticket_Type__c.Booked_Seats__c)`): Total registered attendees.
  - `Available_Seats__c` (Formula: `Total_Capacity__c - Booked_Seats__c`): Real-time seats left.
- **Lifecycle Picklists:**
  - `Category__c`: `Conference`, `Workshop`, `Training`, `Hackathon`, `Concert`, `Executive Summit`, `Webinar`, `Meetup`, `Other`.
  - `Approval_Status__c`: `Draft`, `Pending Approval`, `Approved`, `Rejected`.
  - `Publication_Status__c`: `Unpublished`, `Published`.
  - `Registration_Status__c`: `Not Open`, `Open`, `Closed`, `Sold Out`.

### 2. `Venue__c` (Physical Facility)
- **Purpose:** Physical locations where events occur.
- **Key Fields:** `Name`, `Address__c`, `City__c`, `Venue_Capacity__c` (Maximum physical safety limit), `Contact_Person__c`, `Contact_Phone__c`.

### 3. `Ticket_Type__c` (Ticket Tier Configuration)
- **Relationship:** **Master-Detail** to `Event__c`.
- **Purpose:** Defines seat quotas and prices (e.g. VIP ₹5,000, General ₹2,000, Student ₹800).
- **Key Fields:**
  - `Price__c` (Currency in ₹).
  - `Quota__c` (Number): Allocated seats for this specific tier.
  - `Booked_Seats__c` (Roll-up Summary: `COUNT(Registration__c)` where status is confirmed).
  - `Available_Seats__c` (Formula: `Quota__c - Booked_Seats__c`).
  - `Status__c`: `Available`, `Sold Out`, `Closed`.

### 4. `Attendee__c` (Customer / Participant Identity)
- **Purpose:** Represents individual participants.
- **Key Fields:** `Name`, `Email__c` (Unique identifier), `Phone__c` (10-digit mobile), `Organization__c`, `User__c` (Lookup to `User` for portal login).

### 5. `Registration__c` (Booking Junction)
- **Relationship:** **Master-Detail** to `Event__c`, **Lookup** to `Ticket_Type__c`, **Lookup** to `Attendee__c`.
- **Purpose:** Connects an attendee to an event and selected ticket type.
- **Key Fields:**
  - `Booking_Group_Id__c` (External ID): Groups multi-seat checkouts together (e.g., `GRP-1725530000-842`).
  - `Booked_Price__c`: Locked-in price at time of purchase in ₹.
  - `Confirmation_Status__c`: `Pending`, `Confirmed`, `Cancelled`.

### 6. `Ticket__c` (Issued Entry Pass)
- **Relationship:** **Master-Detail** to `Registration__c`.
- **Key Fields:** `Name` (Autonumber: `TKT-{00000}`), `Issue_Date_Time__c`, `Ticket_Status__c` (`Active`, `Checked In`, `Cancelled`).

### 7. `Payment__c` (Financial Transaction)
- **Relationship:** **Lookup** to `Registration__c`.
- **Key Fields:** `Amount__c` (Currency in ₹), `Payment_Method__c` (`UPI`, `Card`, `Net Banking`), `Payment_Status__c` (`Pending`, `Completed`, `Failed`), `Transaction_Reference__c`.

### 8. `Speaker__c` (Keynote Presenters)
- **Relationship:** **Lookup** to `Event__c`.
- **Key Fields:** `Name`, `Bio__c`, `Email__c`, `Phone__c`, `Expertise__c`, `Organization__c`, `Status__c`.

### 9. `Feedback__c` (Post-Event Reviews)
- **Relationship:** **Lookup** to `Event__c`, **Lookup** to `Attendee__c`, **Lookup** to `Registration__c`.
- **Key Fields:** `Overall_Rating__c` (1-5), `Venue_Rating__c` (1-5), `Speaker_Rating__c` (1-5), `Comments__c`.

---

# 3. Master Validation Rules

| Object | Rule API Name | Error Condition Formula | Business Purpose |
|---|---|---|---|
| **Event** | `End_Date_After_Start_Date` | `End_Date_Time__c <= Start_Date_Time__c` | Prevents backwards time scheduling. |
| **Event** | `Start_Date_Must_Be_In_Future` | `ISNEW() && Start_Date_Time__c < NOW()` | Prevents scheduling new events in the past. |
| **Attendee** | `Valid_Phone_Number` | `!REGEX(Phone__c, "^[0-9]{10}$")` | Enforces exact 10-digit Indian telephone format. |
| **Speaker** | `Valid_Speaker_Phone` | `!ISBLANK(Phone__c) && !REGEX(Phone__c, "^[0-9]{10}$")` | Enforces standard 10-digit mobile for speakers. |
| **Venue** | `Valid_Contact_Phone` | `!ISBLANK(Contact_Phone__c) && !REGEX(Contact_Phone__c, "^[0-9]{10}$")` | Enforces 10-digit venue contact phone. |
| **Registration** | `Prevent_Registration_When_Sold_Out` | `ISPICKVAL(Ticket_Type__r.Status__c, "Sold Out") && ISNEW()` | Hard database guard blocking bookings on sold-out tiers. |
| **Payment** | `Amount_Matches_Registration_Booked_Price` | `Amount__c != Registration__r.Booked_Price__c` | Financial integrity guard preventing underpayment or mismatch. |
| **Payment** | `Completed_Payment_Requires_Reference` | `ISPICKVAL(Payment_Status__c, "Completed") && ISBLANK(Transaction_Reference__c)` | Ensures auditability of settled funds. |
| **Feedback** | `Rating_Range_1_to_5` | `Overall_Rating__c < 1 \|\| Overall_Rating__c > 5` | Standardizes metric scales for reports and dashboards. |

---

# 4. Full End-to-End Project Workflow

### Phase 1: Event Inception & Budget Routing
1. **Event Organizer** opens the **Organizer Dashboard** and clicks **"Create Event"**.
2. **Screen Flow (`Event_Creation_Screen_Flow`)** collects Event Details, selects Venue, and embeds **`ticketTypeCollector` LWC** to dynamically add ticket tiers.
3. **Threshold Check:** 
   - If Budget $\le ₹2,00,000$ (Custom Metadata: `Approval_Settings__mdt.Default_Threshold`): Auto-approved and published immediately.
   - If Budget $> ₹2,00,000$: Status becomes `Pending Approval` and routes to **Event Manager**.

### Phase 2: Attendee Discovery & Multi-Ticket Booking
1. **Attendee** logs into the **Event Portal App** (`Event_Booking` tab).
2. Live search filters approved & published events.
3. Attendee clicks **"Book Tickets"**, chooses a ticket tier, and uses the counter (`[-] 2 [+]`) to select quantity.
4. Attendee fills out individual names, emails, and phone numbers for each pass.
5. Apex method `bookMultipleTickets` creates $N$ attendees, $N$ pending registrations, and assigns a shared `Booking_Group_Id__c`.

### Phase 3: Simulated UPI QR Payment & Pass Issuance
1. LWC component `paymentQrVerification` displays a realistic UPI QR code with a **170px SVG countdown ring**.
2. Upon countdown expiry or "I Have Paid" click, Apex method `confirmPayment` executes:
   - Atomically updates all registrations in the group to `Confirmed`.
   - Creates matching `Payment__c` records.
   - Generates official `Ticket__c` records (`TKT-XXXXX`).
3. Attendee navigates to **"My Tickets"** and clicks **"View / Print Pass"**, launching the Visualforce PDF pass (`PrintableTicket.page`) displaying the primary booker, event details, barcode, and **complete Booked Attendees Roster**.

---

# 5. Viva / Oral Exam Q&A for Role 1

### Q1: "Why did you use Master-Detail for `Ticket_Type__c` and `Registration__c`, but Lookup for `Payment__c` and `Attendee__c`?"
> **Answer:** *"Master-Detail on `Ticket_Type__c` and `Registration__c` to `Event__c` enables Roll-Up Summary fields (`Booked_Seats__c`, `Total_Capacity__c`) on the Event record without writing triggers. It also guarantees cascading deletes if an event is cancelled. For `Payment__c` and `Attendee__c`, we used Lookup because Attendees exist independently of individual events (one attendee can attend many events), and Payments must be retained independently for accounting audits even if an event record is modified."*

### Q2: "How do your validation rules work with multi-seat bookings?"
> **Answer:** *"Our `Valid_Phone_Number` rule checks `!REGEX(Phone__c, '^[0-9]{10}$')`. In our LWC front-end, we validate all attendee rows before submitting. When `bookMultipleTickets()` inserts the Attendee and Registration records, each record is validated by the Salesforce database engine, preventing bad data from entering the system."*
