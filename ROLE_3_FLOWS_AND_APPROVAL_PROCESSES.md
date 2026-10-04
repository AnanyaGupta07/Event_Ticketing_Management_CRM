# ROLE 3 VIVA PREPARATION & TECHNICAL MANUAL
## Flows, Declarative Automation, Custom Metadata & Approval Processes

> **Candidate Name / Role:** Teammate 3 (Automation & Workflow Specialist)  
> **Project Title:** Event Management CRM on Salesforce Platform  
> **Target Audience:** Professor / External Viva Examiner ("Sir")

---

## 1. Executive Summary & Automation Strategy

Our project embraces a **Declarative-First ("Clicks Before Code")** philosophy. We reserved custom Apex for high-concurrency/bulkified operations and leveraged **Lightning Flow Builder** and **Salesforce Approval Processes** for business workflow automation.

### Core Automation Assets:
1. **Screen Flows:**
   - `Event_Creation_Screen_Flow`: Guided multi-step event setup with embedded LWC.
   - `Event_Registration_Screen_Flow`: Rapid registration wizard for internal staff and walk-in attendees.
2. **Record-Triggered Flow:**
   - `Post_Registration_Automation`: Fires after registration creation to update statuses, trigger alerts, and coordinate ticket creation.
3. **Scheduled-Triggered Flows:**
   - `Event_Reminder_Scheduled_Flow`: Automated 24-hour pre-event reminder notification.
   - `Post_Event_Feedback_Scheduled_Flow`: Automated post-event feedback request sent 2 hours after event completion.
4. **Approval Process:**
   - `Event__c.Event_Budget_Approval`: Automated routing of high-budget events (> ₹2,00,000) to the Event Manager.
5. **Custom Metadata Type:**
   - `Approval_Settings__mdt.Default_Threshold`: Configurable budget ceiling (₹2,00,000) without hardcoded values.

---

## 2. Event Creation Screen Flow Deep Dive

**Metadata File:** [`flows/Event_Creation_Screen_Flow.flow-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/flows/Event_Creation_Screen_Flow.flow-meta.xml)

### Architecture & Step-by-Step Execution:
```
[Start]
   |
   v
[Screen 1: Basic_Details] 
- Event Name, Event Type, Start/End DateTime, Venue Selection, Proposed Budget
   |
   v
[Screen 2: Ticket_Configuration]
- Embedded LWC: ticketTypeCollector
- Collects dynamic list of Ticket Types (Name, Price, Capacity) as TicketTypeWrapper objects
   |
   v
[Create Records: Create_Event]
- Inserts Event__c record -> captures varEventId
   |
   v
[Loop: Loop_Ticket_Types]
- Iterates over the Apex-defined collection returned from ticketTypeCollector
- Assigns Event__c = varEventId to each Ticket_Type__c
- Adds to varTicketTypeCollection
   |
   v
[Create Records: Create_Ticket_Types]
- Performs single bulk DML insert on varTicketTypeCollection
   |
   v
[Decision: Is_Approval_Required?]
- Checks: Proposed_Budget__c > $CustomMetadata.Approval_Settings__mdt.Default_Threshold.Budget_Threshold__c (200,000)
       |
       +---> [TRUE: Budget > 2 Lakhs]
       |         |
       |         v
       |     [Action: Submit_For_Approval_Action]
       |     - Submits Event to Event_Budget_Approval
       |     - Status updated to "Pending Approval"
       |     - Shows Screen: Approval_Submitted_Screen
       |
       +---> [FALSE: Budget <= 2 Lakhs]
                 |
                 v
             [Update Record: Set Status = 'Approved' / 'Active']
             - Auto-approves standard low-budget events
             - Shows Screen: Success_Screen
```

### Key Technical Innovations in this Flow:
1. **LWC inside Screen Flow (`ticketTypeCollector`):**
   - Standard Flow screens cannot add repeating dynamic rows of fields natively without complex workarounds.
   - We embedded a custom Lightning Web Component (`c:ticketTypeCollector`) directly into the Flow screen.
   - It outputs an `@api` property containing a list of `TicketTypeWrapper` Apex objects.
2. **Bulk DML Outside the Loop:**
   - We strictly adhere to governor limit best practices: records are assigned inside the loop and collected in a list variable (`varTicketTypeCollection`), then inserted with a **single DML operation outside the loop**.

---

## 3. Dynamic Custom Metadata Approval Matrix (`Approval_Matrix__mdt`)

**Metadata Object:** [`objects/Approval_Matrix__mdt/Approval_Matrix__mdt.object-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/objects/Approval_Matrix__mdt/Approval_Matrix__mdt.object-meta.xml)  
**Apex Service:** [`classes/EventApprovalService.cls`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/classes/EventApprovalService.cls)

### Category-Wise Delegation of Authority (DOA) Matrix:
To eliminate approval bottlenecks and prevent executive approval fatigue, approval thresholds are dynamic per event category:

| Category | Tier 1: Auto-Approve Limit | Tier 2: Manager Limit | Tier 3: Finance/Executive Signoff |
| :--- | :---: | :---: | :---: |
| **Webinar** | $\le$ ₹30,000 | ₹30,001 – ₹1,00,000 | > ₹1,00,000 |
| **Meetup** | $\le$ ₹50,000 | ₹50,001 – ₹1,50,000 | > ₹1,50,000 |
| **Workshop** | $\le$ ₹1,00,000 | ₹1,00,001 – ₹3,00,000 | > ₹3,00,000 |
| **Training** | $\le$ ₹1,00,000 | ₹1,00,001 – ₹3,00,000 | > ₹3,00,000 |
| **Hackathon** | $\le$ ₹1,50,000 | ₹1,50,001 – ₹5,00,000 | > ₹5,00,000 |
| **Conference** | $\le$ ₹2,50,000 | ₹2,50,001 – ₹10,00,000 | > ₹10,00,000 |
| **Concert** | $\le$ ₹3,00,000 | ₹3,00,001 – ₹15,00,000 | > ₹15,00,000 |
| **Executive Summit** | ₹0 *(Always Review)* | Up to ₹5,00,000 | > ₹5,00,000 |
| **Other** | $\le$ ₹50,000 | ₹50,001 – ₹2,00,000 | > ₹2,00,000 |

### Lightning Flow Integration (`EventApprovalService.evaluateForFlow`):
- The Screen Flow invokes `EventApprovalService.cls` via an `@InvocableMethod`.
- The service queries `Approval_Matrix__mdt.getAll()` (0 SOQL queries) and returns:
  - `isAutoApproved` (Boolean)
  - `requiresManagerApproval` (Boolean)
  - `requiresFinanceSignoff` (Boolean)
  - `guidanceMessage` (String)
- If `isAutoApproved == true`, the Flow automatically updates `Approval_Status__c = 'Approved'` without human delay.
- If `requiresManagerApproval == true`, the Flow locks the record and submits to `Event_Budget_Approval`.

---

## 4. Approval Process: `Event_Budget_Approval`

**Metadata File:** [`approvalProcesses/Event__c.Event_Budget_Approval.approvalProcess-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/approvalProcesses/Event__c.Event_Budget_Approval.approvalProcess-meta.xml)

### Detailed Configuration:
1. **Object:** `Event__c`
2. **Entry Criteria:**
   ```formula
   (ISBLANK(TEXT(Approval_Status__c)) || ISPICKVAL(Approval_Status__c, "Draft")) && (Proposed_Budget__c > 200000)
   ```
3. **Initial Submission Actions:**
   - **Record Lock:** Locks the `Event__c` record so that organizers cannot tamper with the dates, venue, or budget while under review.
   - **Field Update:** Updates `Approval_Status__c` to `'Pending Approval'`.
4. **Approval Step 1 (`Manager_Review`):**
   - **Assigned Approver:** User with the `Event_Manager` role (or designated manager).
   - Prevents self-approval: An organizer cannot approve their own event budget.
5. **Final Approval Actions:**
   - **Field Update:** Updates `Approval_Status__c` to `'Approved'`.
   - **Record Lock State:** Unlocks record for event execution.
6. **Final Rejection Actions:**
   - **Field Update:** Updates `Approval_Status__c` to `'Rejected'`.
   - Record unlocked so the organizer can read the comments and amend the proposal.
   - **Validation Rule Tie-in:** Validation rule `Require_Rejection_Reason` enforces that if status is `'Rejected'`, the `Rejection_Reason__c` field must not be blank.
7. **Recall Actions:**
   - Allows the submitter to recall the submission if they made a typo; resets status back to `'Draft'`.

---

## 5. Scheduled-Triggered Flows

### 1. `Event_Reminder_Scheduled_Flow`
- **Cadence:** Runs daily.
- **Target Audience:** Attendees registered for events starting tomorrow (`Event__r.Start_Date_Time__c = TOMORROW`).
- **Action:** Sends automated email template with venue address, QR ticket link, and check-in timing.

### 2. `Post_Event_Feedback_Scheduled_Flow`
- **Cadence:** Runs daily.
- **Filter Criteria:** `Event__r.End_Date_Time__c = YESTERDAY` AND `Status__c = 'Attended'`.
- **Action:** Sends email survey link inviting attendees to rate the venue, speakers, and overall event.

---

## 6. Viva Q&A Cheat Sheet (Flows & Automation)

### Q1: "What are the different types of Flows in Salesforce, and which did you use?"
> **Answer:**  
> *"Sir, Salesforce offers 5 main Flow types:
> 1. **Screen Flows** (interactive user wizards - we used for Event Creation and Staff Registration),
> 2. **Record-Triggered Flows** (runs on record create/update/delete - we used for Post-Registration updates),
> 3. **Schedule-Triggered Flows** (runs on batch schedules - we used for Event Reminders and Feedback requests),
> 4. **Autolaunched Flows** (triggered by Apex, REST API, or subflows),
> 5. **Platform Event-Triggered Flows**.  
> We deliberately chose Screen Flows for guided data collection and Scheduled Flows for proactive attendee communications."*

### Q2: "How did you pass data from a custom Lightning Web Component back into your Screen Flow?"
> **Answer:**  
> *"Sir, we used the `@api` decorator in our LWC JS controller. In the LWC configuration file (`ticketTypeCollector.js-meta.xml`), we declared `lightning__FlowScreen` as a target and defined an input/output property typed as an Apex-defined object (`TicketTypeWrapper`). When the user clicks next in the Flow, the Flow engine reads this output variable and maps it into a Flow collection variable without requiring any custom Apex controller."*

### Q3: "How does your flow avoid hitting SOQL and DML governor limits?"
> **Answer:**  
> *"Sir, we strictly enforce **Bulkification in Flows**. We never place 'Create Records', 'Update Records', or 'Get Records' elements inside a Loop. Instead, inside the loop we only use 'Assignment' elements to add items to a collection. The 'Create Records' element is placed after the loop finishes, executing a single DML operation for the entire batch."*

### Q4: "Why did you use an Approval Process instead of just updating the status via a Record-Triggered Flow?"
> **Answer:**  
> *"Sir, an Approval Process provides enterprise governance that a simple Flow cannot match out-of-the-box:
> 1. Automatic record locking while under review,
> 2. Native approval history tracking with timestamps and approver comments,
> 3. Out-of-the-box email and push notification approvals,
> 4. Support for delegated approvers and formal recalls."*

### Q5: "What is the difference between Fast Field Updates (Before-Save) and Actions and Related Records (After-Save) in Record-Triggered Flows?"
> **Answer:**  
> *"Sir, **Fast Field Updates (Before-Save)** execute before the record is committed to the database. They are up to 10x faster and should be used whenever updating fields on the same record that triggered the flow, because they don't cause an extra DML event.  
> **Actions and Related Records (After-Save)** execute after the record is saved. They are required whenever we need to update related records (like child Tickets or Payments), send emails, or call external actions."*
