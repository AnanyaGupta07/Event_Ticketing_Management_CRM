# ROLE 5 VIVA PREPARATION & TECHNICAL MANUAL
## Reports, Dashboards, Custom Report Types & Business KPI Analytics

> **Candidate Name / Role:** Teammate 5 (Business Intelligence & Analytics Specialist)  
> **Project Title:** Event Management CRM on Salesforce Platform  
> **Target Audience:** Professor / External Viva Examiner ("Sir")

---

## 1. Executive Summary & Analytics Strategy

The reporting and analytics layer translates operational transactional data (`Event__c`, `Registration__c`, `Ticket_Type__c`, `Feedback__c`, `Payment__c`) into actionable executive insights for Event Managers, Organizers, and Finance leaders.

### Key BI Capabilities Built:
- **3 Custom Report Types (CRTs):** Unlocks cross-object relationships not available in out-of-the-box standard report types.
- **5 Configured Analytics Reports:** Encompassing Summary formats, column/donut visualizations, record grouping, and aggregate formulas.
- **1 Unified Event Executive Dashboard:** An interactive 12-column grid providing 360-degree visibility over revenue, budget approval bottlenecks, ticket tier inventory, and customer satisfaction (CSAT).

---

## 2. Custom Report Types (CRTs)

Standard Salesforce reports only support default standard object pairings. When dealing with custom Master-Detail hierarchies, **Custom Report Types** are required to define how objects join and which fields are exposed to report builders.

| CRT Label | Primary Object | Related Object | Relationship Condition | Purpose / Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **`Events with Registrations`** | `Event__c` (A) | `Registration__c` (B) | **"Each "A" record must have at least one related "B" record."** | Analyzes confirmed attendee registrations, booked pricing, and ticket sales velocity. |
| **`Events with Ticket Types`** | `Event__c` (A) | `Ticket_Type__c` (B) | **"Each "A" record must have at least one related "B" record."** | Monitors ticket inventory allocation, capacity limits, and pricing tiers. |
| **`Events with Feedback`** | `Event__c` (A) | `Feedback__c` (B) | **"Each "A" record must have at least one related "B" record."** | Calculates average CSAT scores, speaker effectiveness, and venue satisfaction ratings. |

> **Key Viva Tip for Sir:**  
> When "Sir" asks: *"What is the difference between selecting 'Each A must have at least one B' versus 'A records may or may not have related B records'?"*  
> **Answer:** *"Sir, that is the difference between an **INNER JOIN** and an **OUTER JOIN** in SQL!  
> - If we select 'Each A must have B' (Inner Join), events with 0 registrations are omitted from the report.  
> - If we select 'A may or may not have B' (Left Outer Join), all events are listed even if zero tickets have been booked yet."*

---

## 3. Production Reports Breakdown

All reports are stored in the shared folder `reports/Event_Reports/`.

### 1. `My Events Revenue Summary`
- **Metadata File:** `My_Events_Revenue_Summary.report-meta.xml`
- **Format:** Summary Report
- **Groupings:**
  1. `Event__c.Name` (Group 1)
  2. `Event__c.Category__c` (Group 2)
- **Aggregations:** `SUM(Registration__c.Booked_Price__c)`
- **Filters:** `Registration_Status__c = 'Confirmed'`
- **Visualization:** Vertical Column Chart (X-Axis: Event Name, Y-Axis: Total Revenue in INR).
- **Executive Value:** Identifies which event formats (e.g. AI Workshops vs Tech Conferences) yield the highest commercial return.

### 2. `My Events by Approval Status`
- **Metadata File:** `My_Events_by_Approval_Status.report-meta.xml`
- **Format:** Summary Report
- **Groupings:** `Event__c.Approval_Status__c` (`Draft`, `Pending Approval`, `Approved`, `Rejected`)
- **Aggregations:** `RowCount` (Total number of events per status)
- **Visualization:** Donut Chart with total count in the center.
- **Executive Value:** Highlights operational bottlenecks—alerts the Event Manager if too many events are languishing in `Pending Approval`.

### 3. `Event Ticket Types Allocation`
- **Metadata File:** `Event_Ticket_Types_Allocation.report-meta.xml`
- **Format:** Summary Report
- **Groupings:** `Event__c.Name` -> `Ticket_Type__c.Name`
- **Columns:** `Capacity__c`, `Price__c`, `Seats_Sold__c`, `Remaining_Seats__c`
- **Visualization:** Horizontal Bar Chart comparing capacity allocations.
- **Executive Value:** Helps organizers decide when to release more Early Bird or VIP tickets based on real-time sales demand.

### 4. `Event Feedback Analysis`
- **Metadata File:** `Event_Feedback_Analysis.report-meta.xml`
- **Format:** Summary Report
- **Groupings:** `Event__c.Name`
- **Aggregations:**
  - `AVG(Feedback__c.Overall_Rating__c)` (1-5 Star Scale)
  - `AVG(Feedback__c.Speaker_Rating__c)`
  - `AVG(Feedback__c.Venue_Rating__c)`
- **Visualization:** Bar Chart showing multi-criteria satisfaction.
- **Executive Value:** Feeds into future speaker selection and venue renewal negotiations.

### 5. `All Organized Events Overview`
- **Metadata File:** `All_Organized_Events_Overview.report-meta.xml`
- **Format:** Summary / Tabular Report
- **Groupings:** `Event__c.Status__c`
- **Columns:** Event Name, Venue, Start Date, End Date, Proposed Budget, Actual Revenue.
- **Executive Value:** Comprehensive roster used by internal audit and executive leadership for quarterly review.

---

## 4. Event Executive Dashboard

**Metadata File:** [`dashboards/Event_Dashboards/Event_Executive_Dashboard.dashboard-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/dashboards/Event_Dashboards/Event_Executive_Dashboard.dashboard-meta.xml)

### Dashboard Layout & Architecture (12-Column Responsive Grid):
```
+---------------------------------------------------------------------------------------+
|                              EVENT EXECUTIVE DASHBOARD                                |
+---------------------------------------------------+-----------------------------------+
|  [Component 1: Col 0-5, Row 0-7]                  |  [Component 2: Col 6-11, Row 0-7] |
|  Type: Vertical Bar Chart                         |  Type: Donut Chart                |
|  Title: Total Revenue by Event                    |  Title: Events by Approval Status |
|  Source: My_Events_Revenue_Summary                |  Source: My_Events_by_Approval... |
+---------------------------------------------------+-----------------------------------+
|  [Component 3: Col 0-5, Row 8-15]                 |  [Component 4: Col 6-11, Row 8-15]|
|  Type: Horizontal Bar Chart                       |  Type: Bar Chart                  |
|  Title: Ticket Allocation by Tier                 |  Title: Attendee Satisfaction     |
|  Source: Event_Ticket_Types_Allocation            |  Source: Event_Feedback_Analysis  |
+---------------------------------------------------+-----------------------------------+
```

### Running User Configuration:
- **Configured Running User:** System Administrator / Event Manager.
- **Static vs Dynamic Dashboard:**
  - In our implementation, it runs as a **Specified User** (Admin/Manager), providing an organization-wide roll-up of all company events.
  - In an Enterprise Edition production deployment, it can be configured as a **Dynamic Dashboard ("Run as Logged-In User")**, so when an Organizer opens the dashboard, they only see metrics for their personal events.

---

## 5. Key Business KPIs Tracked

1. **Gross Ticket Revenue:**  
   $$\text{Total Revenue} = \sum (\text{Confirmed Registrations} \times \text{Booked Price})$$
2. **Budget Variance:**  
   $$\text{Variance} = \text{Actual Revenue} - \text{Proposed Budget}$$
   *(Demonstrates whether the event turned a profit)*
3. **Venue Capacity Utilization:**  
   $$\text{Utilization \%} = \left(\frac{\text{Total Sold Tickets}}{\text{Venue Capacity}}\right) \times 100$$
4. **Net CSAT (Customer Satisfaction Score):**  
   $$\text{Average CSAT} = \frac{\sum \text{Overall Ratings}}{\text{Total Feedback Count}} \quad (\text{Target: } \ge 4.2 / 5.0)$$

---

## 6. Viva Q&A Cheat Sheet (Reports & Dashboards)

### Q1: "What are the four formats of Reports in Salesforce?"
> **Answer:**  
> *"Sir, the four report formats in Salesforce are:
> 1. **Tabular Report:** A simple spreadsheet-like list of records with no groupings (used for mailing lists).
> 2. **Summary Report:** Allows records to be grouped by rows (e.g. grouped by Event Name) to calculate subtotals and display charts.
> 3. **Matrix Report:** Allows records to be grouped by both rows AND columns (e.g. Event Name on rows, Ticket Tier on columns).
> 4. **Joined Report:** Combines data from multiple unrelated report types into side-by-side blocks."*

### Q2: "What is a Summary Formula versus a Row-Level Formula?"
> **Answer:**  
> *"Sir:
> - A **Row-Level Formula** evaluates logic on every single record individually (e.g. calculating `End_Date__c - Start_Date__c` to get duration in days for each event). You can have only one row-level formula per report.
> - A **Summary Formula** calculates math across grouped records or grand totals (e.g. calculating the percentage of revenue that each event contributed to the grand total: `Booked_Price__c:SUM / GRAND_SUMMARY(Booked_Price__c:SUM)`)."*

### Q3: "What is a Dynamic Dashboard, and what are its limits?"
> **Answer:**  
> *"Sir, a standard dashboard runs as a single 'Specified User', meaning everyone sees the same numbers regardless of their role.  
> A **Dynamic Dashboard** runs as the 'Logged-In User'. When an Organizer opens it, they see their data; when a Manager opens it, they see their team's data.  
> Salesforce limits Enterprise Edition orgs to **5 Dynamic Dashboards** and Unlimited Edition to **10 Dynamic Dashboards** due to database caching overhead."*

### Q4: "Why did you create Custom Report Types instead of using Standard ones?"
> **Answer:**  
> *"Sir, standard report types do not always expose all fields across custom Master-Detail relationships, nor do they allow us to customize the layout. With Custom Report Types:
> 1. We control whether the relationship is an Inner Join or Outer Join.
> 2. We can pull in fields from lookups up to 4 levels away via 'Add fields related via lookup'.
> 3. We can organize fields into custom sections and rename labels for business users."*

### Q5: "How does the Role Hierarchy affect what a user sees on a report?"
> **Answer:**  
> *"Sir, every report has a standard filter called **Scope** (e.g., 'My Events', 'My Team's Events', or 'All Events').  
> If an Organizer runs a report with scope 'My Team's Events', they only see their own records because they have no subordinates. When an Event Manager runs the exact same report, the Role Hierarchy automatically expands the scope to include all records owned by any organizer reporting to them."*
