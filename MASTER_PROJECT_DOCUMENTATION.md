# EVENT MANAGEMENT CRM ON SALESFORCE
## Master Project Documentation & Team Viva Defense Guide

> **Project Name:** Event Management CRM (Salesforce Platform)  
> **Repository:** `PriyanshuKr-2027/Event-Management-CRM-SALESFORCE`  
> **Team Architecture:** 5-Member Engineering & Delivery Team

---

## 1. Project Overview

The **Event Management CRM** is a cloud-native enterprise application built on the Salesforce platform designed to handle end-to-end event operations:
- Event conceptualization and budget approval routing
- Dynamic multi-tier ticketing and venue capacity management
- Public attendee booking portal with simulated UPI QR payment
- Automated check-in, Visualforce PDF entry passes with verification QR codes
- Post-event attendee feedback and executive analytics dashboard

---

## 2. Team Member Role Distribution & Viva Manuals

To ensure every team member can master and defend their individual contribution in front of the project evaluator ("Sir"), the project has been segmented into 5 distinct specialized domains. Each domain has a dedicated technical manual complete with architectural justification and tough Viva Q&A.

| Role # | Focus Area | Assigned Owner | Dedicated Viva Manual | Key Deliverables |
| :---: | :--- | :--- | :--- | :--- |
| **Role 1** | **Data Model, Relationships, Validation Rules & End-to-End Workflow** | Project Lead (You) | [`ROLE_1_DATA_MODEL_AND_WORKFLOW.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/ROLE_1_DATA_MODEL_AND_WORKFLOW.md) | 8 Custom Objects, Master-Detail & Lookup ERD, Rollup Summaries, 13 Validation Rules, Complete Lifecycle. |
| **Role 2** | **Security Architecture, Role Hierarchy, OWD, OLS, FLS & Permission Sets** | Teammate 2 | [`ROLE_2_SECURITY_OWD_PERMISSIONS.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/ROLE_2_SECURITY_OWD_PERMISSIONS.md) | OWD matrix, 5-Level Role Hierarchy, 5 Permission Sets, 1 Permission Set Group, Sharing enforcement. |
| **Role 3** | **Flows, Declarative Automation, Custom Metadata & Approval Processes** | Teammate 3 | [`ROLE_3_FLOWS_AND_APPROVAL_PROCESSES.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/ROLE_3_FLOWS_AND_APPROVAL_PROCESSES.md) | Event Creation Screen Flow with LWC embedding, ₹2L Threshold CMDT, Event Budget Approval Process, Scheduled Flows. |
| **Role 4** | **Custom Code, Apex Classes, Triggers, Handlers, LWCs & Visualforce PDF** | Teammate 4 | [`ROLE_4_CUSTOM_CODE_APEX_LWC_TRIGGERS.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/ROLE_4_CUSTOM_CODE_APEX_LWC_TRIGGERS.md) | 12 Apex Classes, 2 Triggers, 4 LWCs, `PrintableTicket.page`, 36/36 passing unit tests (100% pass rate). |
| **Role 5** | **Business Intelligence, Custom Report Types, Reports & Dashboards** | Teammate 5 | [`ROLE_5_REPORTS_AND_DASHBOARDS.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/ROLE_5_REPORTS_AND_DASHBOARDS.md) | 3 Custom Report Types, 5 Analytics Reports, 12-Column Executive Dashboard, Business KPI Formulas. |

---

## 3. Project Technical Assets Reference

- **Complete Code Reference Manual:** [`USER_MANUAL_CODE_REFERENCE.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/USER_MANUAL_CODE_REFERENCE.md)
  *(Detailed code walkthrough explaining every method, variable, parameter, and hook in all Apex, LWC, and VF files)*
- **Complete Project Zip Package:** `Event_Management_CRM_Complete_Project_Package.zip`
  *(Contains all source code, metadata, layouts, flows, permission sets, reports, and all 5 role manuals)*

---

## 4. End-to-End System Architecture

```
[Attendee / Customer]                 [Event Organizer / Staff]                 [Event Manager / Exec]
         |                                        |                                        |
         v                                        v                                        v
+------------------+                    +--------------------+                   +--------------------+
| attendeeEvent-   |                    | Event_Creation_    |                   | Event_Budget_      |
| Booking (LWC)    |                    | Screen_Flow        |                   | Approval Process   |
| + UPI QR Timer   |                    | + ticketType-      |                   | (Threshold > ₹2L)  |
+------------------+                    |   Collector (LWC)  |                   +--------------------+
         |                              +--------------------+                             |
         v                                        |                                        v
+-----------------------------------------------------------------------------------------------------+
|                                          SALESFORCE CORE                                            |
|                                                                                                     |
|  [Security Layer]                                                                                   |
|  - OWD: Private (Event__c, Attendee__c) | Controlled by Parent (Registration__c, Ticket_Type__c)    |
|  - Role Hierarchy: Event_Manager -> Event_Organizer / Finance / Speaker / Registration               |
|  - Permission Sets: Modular least-privilege entitlements                                            |
|                                                                                                     |
|  [Business Logic & Automation]                                                                      |
|  - Apex Triggers & Handlers: RegistrationTrigger, TicketTypeTrigger                                 |
|  - Apex Controllers: EventBookingController, OrganizerDashboardController                          |
|  - Flows: Post_Registration_Automation, Reminder & Feedback Scheduled Flows                         |
|                                                                                                     |
|  [Data Model (8 Custom Objects)]                                                                    |
|  Event__c <===(M-D)=== Ticket_Type__c                                                               |
|  Event__c <===(M-D)=== Registration__c <===(M-D)=== Ticket__c & Payment__c                          |
|  Event__c <===(M-D)=== Feedback__c                                                                  |
|  Event__c ===(Lookup)==> Venue__c & Speaker__c                                                      |
|  Registration__c ===(Lookup)==> Attendee__c                                                         |
|                                                                                                     |
|  [Output & Analytics]                                                                               |
|  - Visualforce PDF: PrintableTicket.page (Ticket pass with verification QR)                        |
|  - BI Layer: 3 Custom Report Types, 5 Production Reports, Event Executive Dashboard                 |
+-----------------------------------------------------------------------------------------------------+
```

---

## 5. Instructions for Team Members Before Viva

1. Open your assigned role manual:
   - Lead: `ROLE_1_DATA_MODEL_AND_WORKFLOW.md`
   - Security: `ROLE_2_SECURITY_OWD_PERMISSIONS.md`
   - Flows: `ROLE_3_FLOWS_AND_APPROVAL_PROCESSES.md`
   - Code: `ROLE_4_CUSTOM_CODE_APEX_LWC_TRIGGERS.md`
   - Reports: `ROLE_5_REPORTS_AND_DASHBOARDS.md`
2. Thoroughly review the **"Viva Q&A Cheat Sheet"** at the bottom of your manual.
3. Understand how your module connects with the adjacent roles (e.g. how the Data Model dictates Security OWD, how Flows trigger Approval Processes, and how Custom Code populates data for Reports).
4. Download and extract `Event_Management_CRM_Complete_Project_Package.zip` to have local access to all components during the presentation.
