# ROLE 2 VIVA PREPARATION & TECHNICAL MANUAL
## Security, Role Hierarchy, Users, OWD, Object/Field Level Security & Permission Sets

> **Candidate Name / Role:** Teammate 2 (Security & User Access Architect)  
> **Project Title:** Event Management CRM on Salesforce Platform  
> **Target Audience:** Professor / External Viva Examiner ("Sir")

---

## 1. Executive Summary & Security Strategy

In this project, security was designed following the **Principle of Least Privilege (PoLP)** and Salesforce's **Defense-in-Depth** multi-layered security architecture.

Rather than granting broad administrative rights or bloating user profiles, we decoupled **Authentication & Base Access** (Profiles) from **Job Function Entitlements** (Permission Sets & Groups), backed by strict **Data-Level Security** (OWD and Role Hierarchy).

```
+-------------------------------------------------------------------+
|                        1. AUTHENTICATION                          |
| Login IP Ranges, Login Hours, Multi-Factor Authentication (MFA)    |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|               2. OBJECT-LEVEL SECURITY (OLS - CRUD)                |
| Base Profile (Minimal Access) + Permission Sets (Manager/Org/Fin) |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|              3. FIELD-LEVEL SECURITY (FLS - Read/Edit)            |
| Protects Sensitive Fields (Revenue, Discount_Code, Budget, etc.)   |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|               4. RECORD-LEVEL SECURITY (Sharing & OWD)            |
| Organization-Wide Defaults (OWD) -> Role Hierarchy -> Sharing Rules|
+-------------------------------------------------------------------+
```

---

## 2. Organization-Wide Defaults (OWD)

OWD defines the **baseline security** for records that a user does **not** own. If a user does not own a record, OWD determines if they can view, edit, or even see it.

| Object API Name | OWD Setting | Architectural Justification |
| :--- | :--- | :--- |
| **`Event__c`** | **Private** | Organizers should only edit their own assigned events. Event Managers see all via Role Hierarchy. Public users interact via controlled guest/attendee interfaces. |
| **`Venue__c`** | **Public Read Only** | Venues are shared corporate physical assets. Any organizer can view venue capacities, locations, and amenities, but only Venue/Operations coordinators can create/modify them. |
| **`Attendee__c`** | **Private** | Contains Personal Identifiable Information (PII) such as phone, email, and company name. Restricted to protect attendee privacy. |
| **`Registration__c`** | **Controlled by Parent** (`Event__c`) | Master-Detail relationship with `Event__c`. The security is automatically inherited from the parent Event record. |
| **`Ticket_Type__c`** | **Controlled by Parent** (`Event__c`) | Master-Detail relationship with `Event__c`. Tightly coupled with the event lifecycle. |
| **`Ticket__c`** | **Controlled by Parent** (`Registration__c`) | Master-Detail relationship with `Registration__c`. |
| **`Payment__c`** | **Controlled by Parent** (`Registration__c`) | Master-Detail relationship. Payment data inherits access from registration. |
| **`Feedback__c`** | **Controlled by Parent** (`Event__c`) | Master-Detail relationship. Organizers review feedback for events they manage. |

> **Key Viva Tip for Sir:**  
> When "Sir" asks: *"Why do Ticket_Type__c, Registration__c, Ticket__c, and Feedback__c not have an explicit OWD radio button in Sharing Settings?"*  
> **Answer:** *"Sir, because they are on the detail side of a Master-Detail relationship. In Salesforce, detail objects automatically inherit the OWD of their master object, which is listed as 'Controlled by Parent'."*

---

## 3. Role Hierarchy Architecture

Salesforce uses Role Hierarchy to **open up record access vertically** above the record owner. We enabled **Grant Access Using Hierarchies** on all custom objects.

### Role Hierarchy Tree:
```
               +-----------------------------------+
               |        Event Manager (Role)       |
               | (Full org-wide oversight, reports)|
               +-----------------------------------+
                                 |
         +-----------------------+-----------------------+
         |                       |                       |
         v                       v                       v
+-----------------+     +-----------------+     +-----------------+
| Event Organizer |     | Event Finance   |     | Event Speaker   |
|     (Role)      |     |     (Role)      |     |   Coordinator   |
+-----------------+     +-----------------+     +-----------------+
         |
         v
+-------------------------+
| Event Registration Team |
|         (Role)          |
+-------------------------+
```

### Role Access & Responsibility Breakdown:
1. **Event Manager (`roles/Event_Manager.role-meta.xml`)**:
   - Executive head. Sits at the top of the hierarchy.
   - Automatically inherits Read and Edit access to all `Event__c` and related child records created by Organizers and Registration staff.
   - Final approval authority for Event Budgets exceeding ₹2,00,000.
2. **Event Organizer (`roles/Event_Organizer.role-meta.xml`)**:
   - Owns and manages specific events, sets up ticket tiers, coordinates venue booking, and monitors attendance.
   - Subordinate to Event Manager.
3. **Event Registration Team (`roles/Event_Registration_Team.role-meta.xml`)**:
   - Handles on-desk check-in, manual ticket issuance, and attendee registration assistance.
4. **Event Finance (`roles/Event_Finance.role-meta.xml`)**:
   - Reviews payment records, payment gateway transaction IDs, budget allocations, and revenue reconciliation.
5. **Event Speaker Coordinator (`roles/Event_Speaker_Coordinator.role-meta.xml`)**:
   - Manages speaker profiles, session scheduling, and speaker travel/venue logistics.

---

## 4. Profiles vs. Permission Sets Design

### The Modern Salesforce Best Practice:
Instead of creating heavy custom profiles with hard-to-maintain permissions, we used:
- **Base Profile:** Standard User / Minimum Access Profile.
- **6 Modular Permission Sets:** Assigned according to business responsibility.
- **1 Permission Set Group (`Event_Management_Core_Access`):** Bundles common operational permissions.

### Permission Sets Implemented:

#### 1. `Event_Manager_Permissions` (`permissionsets/Event_Manager_Permissions.permissionset-meta.xml`)
- **OLS:** View All & Modify All on `Event__c`, `Venue__c`, `Speaker__c`, `Attendee__c`, `Registration__c`, `Payment__c`, `Feedback__c`.
- **FLS:** Read/Edit on `Proposed_Budget__c`, `Total_Budget__c`, `Approval_Status__c`, `Approved_By__c`, `Payment__c.Transaction_Id__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Approval_Settings__mdt`, `Payment_Gateway_Config__mdt`.
- **Apex Access:** `OrganizerDashboardController`, `EventBookingController`, `PrintableTicketExtension`, `EventApprovalService`, `PaymentGatewayService`.
- **Visualforce Access:** `PrintableTicket`.
- **Tabs:** `Event_Dashboard`, `Event_Executive_Dashboard`, `Venue__c`, `Speaker__c`, `Attendee__c`, `Registration__c`.

#### 2. `Event_Organizer_Permissions` (`permissionsets/Event_Organizer_Permissions.permissionset-meta.xml`)
- **OLS:** Full CRUD on `Event__c`, `Ticket_Type__c`, `Registration__c`, `Attendee__c`, `Feedback__c`; Read-only on `Venue__c`.
- **FLS:** Read/Edit on `Proposed_Budget__c`, `Total_Budget__c`; Read-only on `Approved_By__c`, `Approval_Status__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Approval_Settings__mdt`, `Payment_Gateway_Config__mdt`.
- **Apex Access:** `OrganizerDashboardController`, `PrintableTicketExtension`, `EventApprovalService`.
- **Visualforce Access:** `PrintableTicket`.
- **Tabs:** `Event_Dashboard`, `Venue__c`, `Speaker__c`, `Attendee__c`, `Registration__c`.

#### 3. `Event_Registration_Team_Permissions` (`permissionsets/Event_Registration_Team_Permissions.permissionset-meta.xml`)
- **OLS:** Create, Read, Edit on `Attendee__c`, `Registration__c`, `Ticket__c`; Read on `Event__c` and `Ticket_Type__c`.
- **FLS:** Access to `Attendee__c.Email__c`, `Phone__c`, `Company__c`, `Registration_Date__c`, `Status__c`, `Ticket_Type__c`.
- **Custom Metadata Access:** `Payment_Gateway_Config__mdt`.
- **Apex Access:** `EventBookingController`, `PrintableTicketExtension`.
- **Visualforce Access:** `PrintableTicket`.

#### 4. `Event_Finance_Permissions` (`permissionsets/Event_Finance_Permissions.permissionset-meta.xml`)
- **OLS:** Read & Edit on `Payment__c`, Read on `Event__c`, `Registration__c`, `Ticket_Type__c`.
- **FLS:** Read/Edit on `Payment__c.Transaction_Id__c`, `Payment_Status__c`, `Payment_Method__c`, `Payment_Date__c`, `Total_Amount__c`, `Discount_Code__c`; Read-only on `Event__c.Proposed_Budget__c`, `Approved_By__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Payment_Gateway_Config__mdt`.
- **Tabs:** `Registration__c`.

#### 5. `Event_Speaker_Coordinator_Permissions` (`permissionsets/Event_Speaker_Coordinator_Permissions.permissionset-meta.xml`)
- **OLS:** Full CRUD on `Speaker__c`; Read on `Event__c`, `Venue__c`.
- **FLS:** `Speaker__c.Bio__c`, `Email__c`, `Phone__c`, `Expertise__c`, `Social_Profile__c`.
- **Tabs:** `Speaker__c`, `Venue__c`.

#### 6. `Event_Attendee_Permissions` (`permissionsets/Event_Attendee_Permissions.permissionset-meta.xml`)
- **OLS:** Create & Edit on `Attendee__c`, `Registration__c`, `Payment__c`, `Feedback__c`; Read-only on published `Event__c`, `Venue__c`, `Ticket_Type__c`.
- **FLS:** Access to self-service booking fields, feedback rating, and payment submission details.
- **Custom Metadata Access:** `Payment_Gateway_Config__mdt` (to retrieve merchant VPA, gateway name, and sandbox currency).

---

## 5. Field-Level Security (FLS) Matrix

FLS ensures that users can only see and edit fields relevant to their job, preventing unauthorized visibility of financial or confidential information.

| Object | Field Name | Manager | Organizer | Finance | Reg Team | Speaker Coord | Attendee |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`Event__c`** | `Proposed_Budget__c` | **Read/Edit** | **Read/Edit** | **Read Only** | No Access | No Access | No Access |
| **`Event__c`** | `Total_Budget__c` | Read/Edit | Read/Edit | Read Only | No Access | No Access | No Access |
| **`Event__c`** | `Approved_By__c` | Read/Edit | Read Only | Read Only | No Access | No Access | No Access |
| **`Event__c`** | `Approval_Status__c` | Read/Edit | Read Only | Read Only | Read Only | Read Only | Read Only |
| **`Event__c`** | `Total_Revenue__c` | Read Only (Rollup) | Read Only | Read Only | No Access | No Access | No Access |
| **`Attendee__c`** | `Email__c` / `Phone__c` | Read/Edit | Read/Edit | Read Only | Read/Edit | No Access | Read/Edit |
| **`Registration__c`** | `Discount_Code__c` | Read/Edit | Read/Edit | Read Only | Read/Edit | No Access | Read/Edit |
| **`Payment__c`** | `Transaction_Id__c` | Read/Edit | Read Only | Read/Edit | Read Only | No Access | Read Only |
| **`Payment__c`** | `Payment_Status__c` | Read/Edit | Read Only | Read/Edit | Read Only | No Access | Read Only |
| **`Speaker__c`** | `Email__c` / `Bio__c` | Read/Edit | Read/Edit | No Access | No Access | Read/Edit | No Access |

> **Special Architectural Rule on Universally Required Fields:**  
> In Salesforce metadata, fields defined with `<required>true</required>` (e.g., `Event__c.Category__c`, `Event__c.Venue__c`, `Event__c.Start_Date_Time__c`, `Event__c.End_Date_Time__c`) or Master-Detail relationship fields (`Payment__c.Registration__c`) **cannot** be explicitly listed under `<fieldPermissions>` in permission set XML files.  
> If an administrator tries to declare them in permission sets, Salesforce rejects the deployment with:  
> `Cannot specify field permissions for universally required field`.  
> In Salesforce, access to universally required fields is automatically inherited whenever a user has Object-Level Security (OLS) on that object.

---

## 6. Custom Metadata Type Security (`<customMetadataTypeAccesses>`)

In modern Salesforce releases (Spring '20 onwards), Salesforce enforces the critical org-wide security setting:  
**"Require Customize Application permission for direct read access to custom metadata types"**.

When this setting is enabled, standard/non-admin users **cannot query Custom Metadata records** via SOQL or Apex unless explicit access is granted on their Profile or Permission Set.

| Custom Metadata Type | Description | Granted To | Justification |
| :--- | :--- | :--- | :--- |
| **`Approval_Matrix__mdt`** | Multi-Tier dynamic budget approval thresholds per category | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions`<br>`Event_Finance_Permissions` | Organizers submit events against thresholds; Managers and Finance review category-specific approval rules. |
| **`Approval_Settings__mdt`** | Global approval rules & flags | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions` | Checked by `EventApprovalService` to determine whether approval routing is globally active. |
| **`Payment_Gateway_Config__mdt`**| UPI VPA, Merchant Name, Sandbox credentials | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions`<br>`Event_Finance_Permissions`<br>`Event_Attendee_Permissions`<br>`Event_Registration_Team_Permissions` | Attendees and Registration staff need to render dynamic UPI QR codes and retrieve active merchant configuration. |

---

## 7. Sharing Enforcement in Apex Code (`with sharing` vs `without sharing`)

A critical security question in any project review is how programmatic code respects or bypasses sharing settings:

1. **`OrganizerDashboardController.cls` -> `public with sharing class`**:
   - **Why?** Enforces record-level security. When an Organizer logs in, the SOQL query automatically scopes to records they own or have explicit sharing access to. When an Event Manager logs in, Role Hierarchy automatically allows them to see all records.
2. **`EventApprovalService.cls` -> `public with sharing class`**:
   - **Why?** Ensures that only users who have permission to view or edit the `Event__c` record can evaluate its approval status or submit it for review.
3. **`PaymentGatewayService.cls` -> `public with sharing class`**:
   - **Why?** Adheres to least privilege when reading payment metadata and generating secure cryptographic webhook HMAC signatures.
4. **`EventBookingController.cls` -> `public without sharing class`**:
   - **Why?** Attendees booking tickets through the public or guest portal do not own the `Event__c`, `Ticket_Type__c`, or `Registration__c` records. If `with sharing` were used, guest users would receive an authorization fault when attempting to query remaining capacity or create registration records. The controller uses strict input validation and server-side verification to maintain data integrity safely.

---

## 8. Viva Q&A Cheat Sheet (Security & Permissions)

### Q1: "What is the difference between Role Hierarchy and Profiles?"
> **Answer:**  
> *"Profiles determine **what actions** a user can perform on an object (Create, Read, Edit, Delete, View All, Modify All) and which fields they can see (FLS).  
> Role Hierarchy determines **which records** a user can view and edit based on who owns the record. It opens up record visibility vertically upwards in the hierarchy for records with Private or Public Read-Only OWD."*

### Q2: "Why did you use Permission Sets instead of giving permissions on Profiles?"
> **Answer:**  
> *"Sir, Salesforce is retiring permissions on profiles in favor of Permission Sets. Following modern Salesforce best practices, we kept profiles minimal and used Permission Sets to grant functional permissions. This allows modular assignment—for example, an Organizer who also handles finance tasks can be assigned `Event_Organizer_Permissions` and `Event_Finance_Permissions` without needing a new profile."*

### Q3: "What happens if a field is hidden via FLS, but is displayed in an LWC?"
> **Answer:**  
> *"If the Apex controller or UI API enforces FLS (e.g. through `WITH USER_MODE` or `Schema.sObjectType...isAccessible()`), the field value will be stripped or nullified before being rendered in the LWC. If Apex runs in `without sharing` or system mode without checks, it queries the field, which is why explicit controller checks are vital."*

### Q4: "Can an Event Organizer see events created by another Event Organizer?"
> **Answer:**  
> *"No, Sir. Because the OWD for `Event__c` is set to **Private**, and Organizers sit at the same peer level in the Role Hierarchy. Neither organizer reports to the other. Therefore, they only see events where they are the designated record Owner. Only the Event Manager above them sees both."*

### Q5: "Why did you add `<customMetadataTypeAccesses>` in Permission Sets?"
> **Answer:**  
> *"In modern Salesforce orgs, non-admin users cannot query Custom Metadata records unless explicit access is granted via Profiles or Permission Sets. Since our dynamic approval thresholds and payment gateway configuration reside in Custom Metadata (`Approval_Matrix__mdt` and `Payment_Gateway_Config__mdt`), we granted explicit access in our permission sets so that organizers and attendees can access them smoothly without requiring administrator privileges."*

### Q6: "Why is `Ticket_Type__c` OWD set to 'Controlled by Parent' instead of 'Private'?"
> **Answer:**  
> *"Sir, `Ticket_Type__c` is the child object in a Master-Detail relationship with `Event__c`. In Salesforce, detail objects cannot have their own independent OWD; their sharing and record visibility are strictly inherited from the Master object (`Event__c`)."*
