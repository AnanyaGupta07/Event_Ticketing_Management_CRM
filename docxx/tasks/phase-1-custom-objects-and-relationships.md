# Task Documentation: Phase 1 — Custom Objects, Fields & Relationships

**Status:** ✅ Completed  
**Relevant Folder:** [`objects/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Establish the complete Salesforce data model metadata (objects, custom fields, and relationship architecture) as specified in `datamodel (2).md` and `relationship (1).md`:
- **9 Core Custom Objects**: `Venue__c`, `Event__c`, `Ticket_Type__c`, `Attendee__c`, `Registration__c`, `Ticket__c`, `Payment__c`, `Speaker__c`, `Feedback__c`.
- **1 Custom Metadata Type**: `Approval_Settings__mdt` with default record `Approval_Settings.Default_Threshold.md-meta.xml`.
- **Relationship Integrity**: Master-Detail (`Ticket_Type__c -> Event__c`, `Registration__c -> Event__c`, `Ticket__c -> Registration__c`), Lookups (`Venue__c -> Event__c`, `Attendee__c -> Registration__c`, etc.), and no duplicate relationship fields.

---

## 2. Objects and Fields Breakdown

### 1. `Venue__c`
- **Location:** [`objects/Venue__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Venue__c/)
- **Fields:**
  - `Address__c`: TextArea
  - `City__c`: Text(100), Required
  - `Venue_Capacity__c`: Number(18, 0), Required
  - `Contact_Person__c`: Text(120)
  - `Contact_Phone__c`: Phone
  - `Status__c`: Picklist (Active, Inactive), Required

### 2. `Attendee__c`
- **Location:** [`objects/Attendee__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Attendee__c/)
- **Fields:**
  - `Name`: Standard Name
  - `Email__c`: Email, Required
  - `Phone__c`: Phone
  - `Organization__c`: Text(120)
  - `Attendee_Status__c`: Picklist (Active, Inactive), Required
  - `User__c`: Lookup(User)

### 3. `Event__c`
- **Location:** [`objects/Event__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/)
- **Fields:**
  - `Name`: Standard Text(255), Required
  - `Description__c`: LongTextArea(32768)
  - `Category__c`: Picklist (Conference, Workshop, Webinar, Meetup, Other), Required
  - `Start_Date_Time__c`: DateTime, Required
  - `End_Date_Time__c`: DateTime, Required
  - `Venue__c`: Lookup(Venue__c), Required
  - `Organizer__c`: Lookup(User), Required
  - `Proposed_Budget__c`: Currency(18, 2), Required
  - `Approval_Status__c`: Picklist (Draft, Pending Approval, Approved, Rejected, Cancelled), Required
  - `Publication_Status__c`: Picklist (Unpublished, Published), Required
  - `Registration_Status__c`: Picklist (Not Open, Open, Closed), Required
  - `Total_Capacity__c`: Roll-Up Summary (SUM of `Ticket_Type__c.Quota__c`)
  - `Booked_Seats__c`: Roll-Up Summary (SUM of `Ticket_Type__c.Booked_Seats__c`)
  - `Available_Seats__c`: Formula (`Total_Capacity__c - Booked_Seats__c`)
  - `Rejection_Reason__c`: LongTextArea(32768)
  - `Approved_By__c`: Lookup(User)

### 4. `Ticket_Type__c`
- **Location:** [`objects/Ticket_Type__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Ticket_Type__c/)
- **Fields:**
  - `Name`: Standard Text(80), Required
  - `Event__c`: Master-Detail(`Event__c`), Required
  - `Price__c`: Currency(18, 2), Required
  - `Quota__c`: Number(18, 0), Required
  - `Booked_Seats__c`: Number(18, 0)
  - `Available_Seats__c`: Formula (`Quota__c - BLANKVALUE(Booked_Seats__c, 0)`)
  - `Description__c`: LongTextArea(32768)
  - `Status__c`: Picklist (Available, Sold Out, Closed), Required

### 5. `Registration__c`
- **Location:** [`objects/Registration__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Registration__c/)
- **Fields:**
  - `Name`: AutoNumber (`REG-{00000}`)
  - `Event__c`: Master-Detail(`Event__c`), Required
  - `Attendee__c`: Lookup(`Attendee__c`), Required
  - `Ticket_Type__c`: Lookup(`Ticket_Type__c`), Required
  - `Registration_Date_Time__c`: DateTime
  - `Registration_Status__c`: Picklist (Pending, Confirmed, Cancelled, Rejected), Required
  - `Booked_Price__c`: Currency(18, 2), Required
  - `Confirmation_Status__c`: Picklist (Not Sent, Sent, Failed)
  - `Feedback_Submitted__c`: Checkbox

### 6. `Ticket__c`
- **Location:** [`objects/Ticket__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Ticket__c/)
- **Fields:**
  - `Name`: AutoNumber (`TKT-{00000}`)
  - `Registration__c`: Master-Detail(`Registration__c`), Required
  - `Issue_Date_Time__c`: DateTime
  - `Ticket_Status__c`: Picklist (Active, Used, Cancelled), Required

### 7. `Payment__c`
- **Location:** [`objects/Payment__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Payment__c/)
- **Fields:**
  - `Name`: AutoNumber (`PAY-{00000}`)
  - `Registration__c`: Lookup(`Registration__c`), Required
  - `Amount__c`: Currency(18, 2), Required
  - `Payment_Date_Time__c`: DateTime, Required
  - `Payment_Status__c`: Picklist (Pending, Successful, Failed, Refunded), Required
  - `Payment_Method__c`: Picklist (UPI, Card, Cash, Other), Required
  - `Transaction_Reference__c`: Text(100)

### 8. `Speaker__c`
- **Location:** [`objects/Speaker__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Speaker__c/)
- **Fields:**
  - `Name`: Standard Text(120), Required
  - `Email__c`: Email
  - `Phone__c`: Phone
  - `Organization__c`: Text(120)
  - `Expertise__c`: Text(255)
  - `Bio__c`: LongTextArea(32768)
  - `Status__c`: Picklist (Active, Inactive), Required
  - `Event__c`: Lookup(`Event__c`)

### 9. `Feedback__c`
- **Location:** [`objects/Feedback__c/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Feedback__c/)
- **Fields:**
  - `Name`: AutoNumber (`FB-{00000}`)
  - `Event__c`: Lookup(`Event__c`), Required
  - `Attendee__c`: Lookup(`Attendee__c`), Required
  - `Registration__c`: Lookup(`Registration__c`), Required
  - `Overall_Rating__c`: Number(1, 0), Required
  - `Event_Experience__c`: Number(1, 0)
  - `Speaker_Rating__c`: Number(1, 0)
  - `Venue_Rating__c`: Number(1, 0)
  - `Comments__c`: LongTextArea(32768)
  - `Submitted_Date_Time__c`: DateTime

### 10. `Approval_Settings__mdt`
- **Location:** [`objects/Approval_Settings__mdt/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Approval_Settings__mdt/)
- **Field:** `Budget_Threshold__c` (Currency)
- **Record:** `Approval_Settings.Default_Threshold.md-meta.xml` in [`customMetadata/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/customMetadata/)
