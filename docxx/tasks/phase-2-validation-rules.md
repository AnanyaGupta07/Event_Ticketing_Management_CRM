# Task Documentation: Phase 2 — Validation Rules

**Status:** ✅ Completed  
**Relevant Folder:** [`objects/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Implement all declarative validation rules defined in `validationrules (2).md` across the custom objects to ensure data consistency, lifecycle governance, and booking integrity.

*(Note: `Quota_Not_Exceed_Venue_Capacity` and concurrent seat-booking protection are intentionally enforced in Apex via `TicketTypeTriggerHandler` and `RegistrationTriggerHandler` per `validationrules (2).md Resolved §1 & §2`).*

---

## 2. Validation Rules Catalog

### 1. `Venue__c`
- **`Capacity_Positive`**
  - **File:** [`objects/Venue__c/validationRules/Capacity_Positive.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Venue__c/validationRules/Capacity_Positive.validationRule-meta.xml)
  - **Formula:** `Venue_Capacity__c <= 0`
  - **Error Message:** "Venue Capacity must be a positive number greater than zero."

---

### 2. `Event__c`
- **`End_After_Start`**
  - **File:** [`objects/Event__c/validationRules/End_After_Start.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/End_After_Start.validationRule-meta.xml)
  - **Formula:** `Start_Date_Time__c >= End_Date_Time__c`
  - **Error Message:** "End Date/Time must be strictly after Start Date/Time."

- **`Budget_Required_On_Submit`**
  - **File:** [`objects/Event__c/validationRules/Budget_Required_On_Submit.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/Budget_Required_On_Submit.validationRule-meta.xml)
  - **Formula:** `ISBLANK(Proposed_Budget__c) && ISPICKVAL(Approval_Status__c, "Pending Approval")`
  - **Error Message:** "Proposed Budget is required before submitting an event for approval."

- **`No_Publish_Before_Approved`**
  - **File:** [`objects/Event__c/validationRules/No_Publish_Before_Approved.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/No_Publish_Before_Approved.validationRule-meta.xml)
  - **Formula:** `ISPICKVAL(Publication_Status__c, "Published") && NOT(ISPICKVAL(Approval_Status__c, "Approved"))`
  - **Error Message:** "An event cannot be published until its approval status is Approved."

- **`No_Booking_On_Rejected_Or_Cancelled`**
  - **File:** [`objects/Event__c/validationRules/No_Booking_On_Rejected_Or_Cancelled.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/No_Booking_On_Rejected_Or_Cancelled.validationRule-meta.xml)
  - **Formula:** `(ISPICKVAL(Approval_Status__c, "Rejected") || ISPICKVAL(Approval_Status__c, "Cancelled")) && ISPICKVAL(Publication_Status__c, "Published")`
  - **Error Message:** "Rejected or Cancelled events cannot be published."

- **`Rejection_Reason_Required`**
  - **File:** [`objects/Event__c/validationRules/Rejection_Reason_Required.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/Rejection_Reason_Required.validationRule-meta.xml)
  - **Formula:** `ISPICKVAL(Approval_Status__c, "Rejected") && ISBLANK(Rejection_Reason__c)`
  - **Error Message:** "Rejection Reason is mandatory when an event is rejected."

- **`No_Self_Approval`**
  - **File:** [`objects/Event__c/validationRules/No_Self_Approval.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Event__c/validationRules/No_Self_Approval.validationRule-meta.xml)
  - **Formula:** `ISPICKVAL(Approval_Status__c, "Approved") && NOT(ISBLANK(Approved_By__c)) && Approved_By__c = Organizer__c`
  - **Error Message:** "An organizer cannot approve their own event."

---

### 3. `Ticket_Type__c`
- **`No_Price_Change_After_Registration_Open`**
  - **File:** [`objects/Ticket_Type__c/validationRules/No_Price_Change_After_Registration_Open.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Ticket_Type__c/validationRules/No_Price_Change_After_Registration_Open.validationRule-meta.xml)
  - **Formula:** `ISCHANGED(Price__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")`
  - **Error Message:** "Ticket price cannot be modified after registration has opened."

- **`No_Quota_Change_After_Registration_Open`**
  - **File:** [`objects/Ticket_Type__c/validationRules/No_Quota_Change_After_Registration_Open.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Ticket_Type__c/validationRules/No_Quota_Change_After_Registration_Open.validationRule-meta.xml)
  - **Formula:** `ISCHANGED(Quota__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")`
  - **Error Message:** "Ticket quota cannot be modified after registration has opened."

- **`Quota_Not_Below_Booked_Seats`**
  - **File:** [`objects/Ticket_Type__c/validationRules/Quota_Not_Below_Booked_Seats.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Ticket_Type__c/validationRules/Quota_Not_Below_Booked_Seats.validationRule-meta.xml)
  - **Formula:** `Quota__c < Booked_Seats__c`
  - **Error Message:** "Ticket quota cannot be reduced below the number of already booked seats."

---

### 4. `Registration__c`
- **`Ticket_Type_Must_Belong_To_Event`**
  - **File:** [`objects/Registration__c/validationRules/Ticket_Type_Must_Belong_To_Event.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Registration__c/validationRules/Ticket_Type_Must_Belong_To_Event.validationRule-meta.xml)
  - **Formula:** `Ticket_Type__r.Event__c <> Event__c`
  - **Error Message:** "The selected ticket type does not belong to the selected event."

- **`No_Registration_On_Unpublished_Or_Closed_Event`**
  - **File:** [`objects/Registration__c/validationRules/No_Registration_On_Unpublished_Or_Closed_Event.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Registration__c/validationRules/No_Registration_On_Unpublished_Or_Closed_Event.validationRule-meta.xml)
  - **Formula:** `ISNEW() && NOT(ISPICKVAL(Event__r.Registration_Status__c, "Open"))`
  - **Error Message:** "Registrations cannot be created for events that are not currently open for registration."

- **`Booked_Price_Required`**
  - **File:** [`objects/Registration__c/validationRules/Booked_Price_Required.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Registration__c/validationRules/Booked_Price_Required.validationRule-meta.xml)
  - **Formula:** `ISNEW() && ISBLANK(Booked_Price__c)`
  - **Error Message:** "Booked Price is required when creating a registration."

---

### 5. `Payment__c`
- **`Transaction_Reference_Required_When_Successful`**
  - **File:** [`objects/Payment__c/validationRules/Transaction_Reference_Required_When_Successful.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Payment__c/validationRules/Transaction_Reference_Required_When_Successful.validationRule-meta.xml)
  - **Formula:** `ISPICKVAL(Payment_Status__c, "Successful") && ISBLANK(Transaction_Reference__c)`
  - **Error Message:** "Transaction Reference is required when Payment Status is Successful."

- **`Amount_Matches_Registration_Booked_Price`**
  - **File:** [`objects/Payment__c/validationRules/Amount_Matches_Registration_Booked_Price.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Payment__c/validationRules/Amount_Matches_Registration_Booked_Price.validationRule-meta.xml)
  - **Formula:** `Amount__c <> Registration__r.Booked_Price__c`
  - **Error Message:** "Payment amount must match the booked price of the registration."

---

### 6. `Feedback__c`
- **`One_Feedback_Per_Registration`**
  - **File:** [`objects/Feedback__c/validationRules/One_Feedback_Per_Registration.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Feedback__c/validationRules/One_Feedback_Per_Registration.validationRule-meta.xml)
  - **Formula:** `Registration__r.Feedback_Submitted__c = TRUE`
  - **Error Message:** "Feedback has already been submitted for this registration."

- **`Rating_Range`**
  - **File:** [`objects/Feedback__c/validationRules/Rating_Range.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Feedback__c/validationRules/Rating_Range.validationRule-meta.xml)
  - **Formula:** `Overall_Rating__c < 1 || Overall_Rating__c > 5`
  - **Error Message:** "Overall Rating must be an integer between 1 and 5."

- **`No_Feedback_Before_Event_Ends`**
  - **File:** [`objects/Feedback__c/validationRules/No_Feedback_Before_Event_Ends.validationRule-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Feedback__c/validationRules/No_Feedback_Before_Event_Ends.validationRule-meta.xml)
  - **Formula:** `Registration__r.Event__r.End_Date_Time__c > NOW()`
  - **Error Message:** "Feedback cannot be submitted before the event has ended."
