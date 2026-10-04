# Salesforce Org Deployment & Interaction Guide
**Project:** Event Management & Ticketing Platform  
**Target Environment:** Salesforce Developer Edition / Sandbox Org  
**Metadata API Version:** 60.0  

---

## 1. Executive Summary & Prerequisites

This document provides a comprehensive, step-by-step guide for deploying and interacting with the entire Event Management & Ticketing platform in your connected Salesforce org.

### Prerequisites Checklist:
- **VS Code** with the **Salesforce Extension Pack (Expanded)** installed.
- **Salesforce CLI (`sf`)** installed (verified version: `@salesforce/cli/2.142.7+`).
- An authenticated Salesforce Org (e.g. `my-org`, username `10priyanshukumar2020.56c9e873613b@agentforce.com`).

---

## 2. Pre-Deployment Verification

Before triggering the deployment, verify that VS Code is connected to your target Salesforce org:

### Step 2.1: Check Connected Orgs via Terminal
Open the VS Code Terminal (`Ctrl + \`` or `Terminal -> New Terminal`) and run:
```bash
sf org list
```
You should see your org listed with status `Connected`:
```
┌──┬────────┬──────────────────────────────────────────────────┬────────────────────┬───────────┐
│  │ Alias  │ Username                                         │ Org Id             │ Status    │
├──┼────────┼──────────────────────────────────────────────────┼────────────────────┼───────────┤
│  │ my-org │ 10priyanshukumar2020.56c9e873613b@agentforce.com │ 00DdL00000yTFU9UAO │ Connected │
└──┴────────┴──────────────────────────────────────────────────┴────────────────────┴───────────┘
```

### Step 2.2: Set Target Org as Default
Set `my-org` as the active default target org for this workspace:
```bash
sf config set target-org my-org
```
*(Alternatively, look at the bottom status bar in VS Code: click on the org name or plug icon to select `my-org` as default).*

---

## 3. How to Deploy (Step-by-Step)

You have two deployment options: **Method 1 (One-Click / Recommended)** or **Method 2 (Staged Deployment by Layer)**.

---

### Method 1: The One-Click Manifest Deployment (Recommended)

All project metadata types are cataloged in [`manifest/package.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/manifest/package.xml).

#### Option A: Via VS Code GUI (No typing required)
1. In the VS Code File Explorer (left sidebar), navigate to the `manifest/` folder.
2. Right-click on **`package.xml`**.
3. Select **`SFDX: Deploy Source in Manifest to Org`**.
4. Monitor the deployment progress in the VS Code **Output** tab (select *Salesforce CLI* in the dropdown).

#### Option B: Via Terminal Command
Run the following single command in your terminal:
```powershell
sf project deploy start -x manifest/package.xml -o my-org
```
*Tip:* You can run a dry-run test first without affecting the org by adding `--dry-run`:
```powershell
sf project deploy start -x manifest/package.xml --dry-run -o my-org
```

---

### Method 2: Staged Phased Deployment (Step-by-Step)

If you prefer to deploy and verify each architectural layer step-by-step, use the following dependency-ordered commands:

#### Phase 1: Custom Objects, Fields, & Validation Rules (Data Foundation)
```powershell
sf project deploy start --source-dir objects -o my-org
sf project deploy start --source-dir customMetadata -o my-org
```
*Deploys 9 Custom Objects (`Venue__c`, `Event__c`, `Ticket_Type__c`, `Attendee__c`, `Registration__c`, `Payment__c`, `Ticket__c`, `Speaker__c`, `Feedback__c`), 17 Validation Rules, Compact Layouts, and `Approval_Settings__mdt`.*

#### Phase 2: Security & Visibility (Roles & Sharing)
```powershell
sf project deploy start --source-dir roles -o my-org
sf project deploy start --source-dir sharingRules -o my-org
```
*Deploys 2-tier Role Hierarchy (`Event_Manager` > `Event_Organizer`) and Private Sharing Rule for pending-approval events.*

#### Phase 3: Apex Classes & Triggers (Business Logic)
```powershell
sf project deploy start --source-dir classes -o my-org
sf project deploy start --source-dir triggers -o my-org
```
*Deploys concurrency-safe handlers (`TicketTypeTriggerHandler`, `RegistrationTriggerHandler`), Controllers (`OrganizerDashboardController`, `EventBookingController`), and all Test suites.*

#### Phase 4: Lightning Web Components (LWC)
```powershell
sf project deploy start --source-dir lwc -o my-org
```
*Deploys `organizerDashboard`, `ticketTypeCollector`, `attendeeEventBooking`, and `paymentQrVerification`.*

#### Phase 5: Automation Flows
```powershell
sf project deploy start --source-dir flows -o my-org
```
*Deploys `Event_Creation_Screen_Flow`, `Event_Registration_Screen_Flow`, `Post_Registration_Automation`, `Event_Reminder_Scheduled_Flow`, and `Post_Event_Feedback_Scheduled_Flow`.*

#### Phase 6: Visualforce Ticket Generation
```powershell
sf project deploy start --source-dir pages -o my-org
```
*Deploys printable barcode PDF ticket page `PrintableTicket.page`.*

#### Phase 7: UI & Navigation (Layouts, FlexiPages, Tabs & Apps)
```powershell
sf project deploy start --source-dir layouts -o my-org
sf project deploy start --source-dir flexipages -o my-org
sf project deploy start --source-dir tabs -o my-org
sf project deploy start --source-dir applications -o my-org
```
*Deploys Custom Lightning Apps (`Event_Management`, `Event_Portal`), FlexiPage Record/App pages, and Navigation Tabs.*

#### Phase 8: Workflows, Approval Processes & Reports
```powershell
sf project deploy start --source-dir workflows -o my-org
sf project deploy start --source-dir approvalProcesses -o my-org
sf project deploy start --source-dir reportTypes -o my-org
sf project deploy start --source-dir reports -o my-org
```
*Deploys workflow field updates, `Event_Budget_Approval` process, and executive event reports.*

#### Phase 9: Permission Sets
```powershell
sf project deploy start --source-dir permissionsets -o my-org
```
*Deploys `Event_Organizer_Permissions`, `Event_Manager_Permissions`, and `Event_Attendee_Permissions`.*

---

## 4. Post-Deployment Configuration in Salesforce

Once the deployment completes successfully, perform these three quick setup tasks:

### 4.1 Assign Permission Sets to Your User
In your terminal, assign the Organizer and Manager permissions to your user:
```powershell
# Assign Event Organizer Permissions
sf org assign permset --name Event_Organizer_Permissions -o my-org

# Assign Event Manager Permissions
sf org assign permset --name Event_Manager_Permissions -o my-org

# (Optional) Assign Attendee Permissions for portal testing
sf org assign permset --name Event_Attendee_Permissions -o my-org
```

### 4.2 Activate Approval Process
1. Log into your org (or run `sf org open -o my-org`).
2. Go to **Setup** (gear icon top-right) -> search for **Approval Processes** in Quick Find.
3. In the "Manage Approval Processes For" dropdown, select **Event**.
4. Click on **Event Budget Approval** and click the **Activate** button if it is in Draft status.

### 4.3 Run Apex Tests & Confirm 100% Coverage
Execute the comprehensive test suite to verify everything functions in your org:
```powershell
sf apex run test --code-coverage --result-format human -o my-org
```

---

## 5. How to View and Interact with the Project in Your Browser

### Step 5.1: Open Your Salesforce Org
From VS Code terminal, launch your browser directly to your org:
```powershell
sf org open -o my-org
```

### Step 5.2: Open the Applications
1. In Salesforce, click on the **App Launcher** (the 9 dots icon in the upper left corner).
2. Search for:
   - **Event Management**: Opens the Organizer & Manager application.
     - **Organizer Dashboard Tab**: Interactive LWC with event KPI metrics, pending approvals banner, and quick-action button to launch the **Event Creation Screen Flow**.
     - **Events Tab**: Full list view, record pages with highlights, related ticket types, speakers, and budget tracking.
     - **Venues Tab**: Capacity management, venue records with Google Maps address rendering.
     - **Reports Tab**: Real-time revenue and ticket sales analytics.
   - **Event Portal**: Opens the Attendee Self-Service experience.
     - **Event Booking Tab**: Interactive LWC catalog with search, category filtering, ticket type selection, built-in registration flow, and simulated 10-second UPI QR payment verification.

### Step 5.3: Test Key Workflows Live
1. **Organizer Journey:**
   - On the Organizer Dashboard, click **"Create New Event"**.
   - Fill in Event Title, Venue, Dates, and Budget. Add Tiered Ticket Types (e.g. VIP, General) using the dynamic ticket collector.
   - If Budget > $50,000, watch the flow automatically submit the event to Manager Approval!
2. **Attendee Journey:**
   - Switch to **Event Portal** app -> Click **Event Booking**.
   - Select a published event -> choose a ticket type -> complete registration.
   - Scan the QR code -> check "I have completed the payment" -> watch the 10-second verification countdown finish and issue your confirmed registration!
   - Click "Print Ticket" to view your PDF ticket with barcode pass!
