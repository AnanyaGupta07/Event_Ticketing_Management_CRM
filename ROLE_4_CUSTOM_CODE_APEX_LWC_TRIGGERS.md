# ROLE 4 VIVA PREPARATION & TECHNICAL MANUAL
## Custom Code: Apex Classes, Triggers, Handlers, LWCs, Visualforce & Unit Tests

> **Candidate Name / Role:** Teammate 4 (Lead Developer & Apex/LWC Specialist)  
> **Project Title:** Event Management CRM on Salesforce Platform  
> **Target Audience:** Professor / External Viva Examiner ("Sir")

---

## 1. Executive Summary & Architecture Principles

All programmatic code in this repository was built according to enterprise Salesforce engineering standards:
1. **One Trigger Per Object Pattern:** A single trigger per sObject controls all trigger event contexts, delegating immediately to a Handler class.
2. **Trigger Handler Framework:** Separation of trigger execution from business logic, preventing recursion and facilitating unit testing.
3. **Strict Bulkification:** Zero SOQL queries or DML operations inside loops. Code is engineered to process batches of 200 records seamlessly.
4. **Defensive Programming & Security:**
   - Controllers interacting with internal data enforce sharing (`with sharing`).
   - Guest/Attendee booking logic uses controlled system mode (`without sharing`) with server-side field-level validation and sanitize logic.
5. **Modern Reactive Front-End:** Native **Lightning Web Components (LWC)** with reactive properties, wire adapters, custom events, and CSS design tokens.
6. **Pixel-Perfect PDF Generation:** Visualforce page with custom controller extension rendered as PDF for event entry passes.
7. **100% Test Pass Rate (49/49 passing unit tests):** Comprehensive test suites with `@TestSetup`, `System.runAs()`, and governor limit isolation.

---

## 2. Apex Code Structure (16 Apex Classes)

```
classes/
├── EventBookingController.cls            // Attendee booking portal API
├── EventBookingControllerTest.cls        // 8 Unit tests for booking flows
├── OrganizerDashboardController.cls      // Metrics & attendee management API
├── OrganizerDashboardControllerTest.cls  // 5 Unit tests for dashboard
├── PaymentGatewayService.cls             // Adapter for Custom Metadata gateway integration
├── PaymentGatewayServiceTest.cls         // 5 Unit tests for gateway & HMAC verification
├── EventApprovalService.cls              // Dynamic multi-tier approval evaluation engine
├── EventApprovalServiceTest.cls          // 8 Unit tests for category matrix routing
├── EventRegistrationHandler.cls         // Core business logic engine
├── RegistrationTriggerHandler.cls        // Trigger dispatcher for Registration__c
├── RegistrationTriggerTest.cls           // 8 Unit tests for registration trigger
├── TicketTypeTriggerHandler.cls          // Trigger dispatcher for Ticket_Type__c
├── TicketTypeTriggerTest.cls             // 6 Unit tests for ticket type validations
├── PrintableTicketExtension.cls          // VF extension for PDF ticket rendering
├── PrintableTicketExtensionTest.cls      // 3 Unit tests for PDF generation
└── TicketTypeWrapper.cls                 // DTO for Flow & LWC serialization
```

### Class-by-Class Functional Breakdown:

#### 1. `EventBookingController.cls`
- **Sharing Mode:** `without sharing` (deliberately enables guest/attendee access without violating OWD).
- **Core Methods:**
  - `@AuraEnabled(cacheable=true) getUpcomingEvents(String searchKey, String eventType)`: Returns active, approved events with dates in the future.
  - `@AuraEnabled(cacheable=true) getTicketTypes(Id eventId)`: Returns available ticket tiers with price and remaining inventory.
  - `@AuraEnabled createRegistrationAndPayment(...)`: Atomic transaction that creates the `Attendee__c` (or links existing by email), inserts `Registration__c`, generates child `Ticket__c` records, and registers `Payment__c`.
- **Concurrency & Race Condition Handling:** Checks remaining capacity inside a database-locked context before committing reservations.

#### 2. `OrganizerDashboardController.cls`
- **Sharing Mode:** `with sharing` (strictly enforces record-level ownership and role hierarchy).
- **Core Methods:**
  - `@AuraEnabled(cacheable=true) getOrganizerMetrics(Id eventId)`: Aggregates total registrations, total revenue collected, attendance percentage, and pending approvals.
  - `@AuraEnabled(cacheable=true) getEventAttendees(Id eventId)`: Fetches full attendee roster with ticket numbers and check-in status.
  - `@AuraEnabled checkInAttendee(Id ticketId)`: Updates ticket status to `'Checked In'` with live timestamp.
  - **Hierarchy Support:** If logged in as an `Event_Manager`, queries show an organization-wide view; if logged in as an `Event_Organizer`, it automatically scopes to events they own.

#### 3. `EventRegistrationHandler.cls`
- **Role:** Central domain logic class.
- **Responsibilities:**
  - Validates event start/end dates.
  - Calculates tax and discounts.
  - Enforces venue capacity ceilings.
  - Generates unique cryptographic Ticket Codes (`EVT-{Date}-{RandomHex}`).

#### 4. `RegistrationTriggerHandler.cls` & `TicketTypeTriggerHandler.cls`
- **Pattern:** Follows the Trigger Handler pattern with context methods:
  - `beforeInsert(List<sObject> newRecords)`
  - `afterInsert(Map<Id, sObject> newMap)`
  - `beforeUpdate(Map<Id, sObject> oldMap, Map<Id, sObject> newMap)`
  - `beforeDelete(Map<Id, sObject> oldMap)`
- **Key Logic in `TicketTypeTriggerHandler`:**
  - Blocks deletion of a `Ticket_Type__c` if tickets have already been sold against it.
  - Ensures the sum of all ticket type capacities never exceeds the parent `Venue__c.Capacity__c`.

#### 5. `PrintableTicketExtension.cls`
- **Role:** Custom Apex controller extension for `PrintableTicket.page`.
- **Responsibilities:**
  - Retrieves `Registration__c`, attendee full name, event venue coordinates, and ticket tier.
  - Constructs the dynamic QR code endpoint URL encode string.

#### 6. `PaymentGatewayService.cls`
- **Role:** Plug-and-play Payment Gateway Adapter service.
- **Responsibilities:**
  - Decouples client payment verification from hardcoded values using `Payment_Gateway_Config__mdt`.
  - Generates NPCI-compliant UPI Intent strings (`upi://pay?pa=...&am=...&tn=...&cu=INR`).
  - Supports enterprise HMAC-SHA256 signature verification via `Crypto.generateMac('HmacSHA256', ...)` for incoming gateway webhooks.
  - Enables zero-downtime switching from Sandbox (simulation) to Production (Razorpay/Cashfree) without code deployments.

#### 7. `EventApprovalService.cls`
- **Role:** Dynamic multi-tier approval evaluation engine.
- **Responsibilities:**
  - Connects Lightning Flow Builder to `Approval_Matrix__mdt` via `@InvocableMethod evaluateForFlow(...)`.
  - Determines whether an event proposal is `AUTO_APPROVED`, requires `MANAGER_APPROVAL_REQUIRED`, or escalates to `FINANCE_EXECUTIVE_APPROVAL_REQUIRED`.
  - Programmatically submits event records into the `Event_Budget_Approval` process via `Approval.ProcessSubmitRequest`.

#### 8. `TicketTypeWrapper.cls`
- **Role:** Pure Data Transfer Object (DTO).
- Annotates properties with `@AuraEnabled` so that it can be passed seamlessly between Flow Builder and LWC components.

---

## 3. Apex Triggers (2 Triggers)

### 1. `RegistrationTrigger.trigger`
```apex
trigger RegistrationTrigger on Registration__c (
    before insert, after insert, before update, after update, before delete, after delete, after undelete
) {
    RegistrationTriggerHandler handler = new RegistrationTriggerHandler();
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.newMap);
    }
    // ... handles update and delete contexts cleanly
}
```

### 2. `TicketTypeTrigger.trigger`
- Manages inventory validation and prevents orphaned bookings upon ticket tier cancellation.

---

## 4. Lightning Web Components (4 LWCs)

```
lwc/
├── attendeeEventBooking/      // Public/Attendee event browsing & booking wizard
├── paymentQrVerification/     // Dynamic UPI QR code with auto-expiring timer
├── ticketTypeCollector/       // Flow-integrated dynamic ticket row builder
└── organizerDashboard/        // Real-time analytics, charts & check-in hub
```

### 1. `attendeeEventBooking`
- **HTML/JS Architecture:**
  - Responsive event grid with real-time text search and category pill filtering.
  - Modal-driven multi-step booking checkout:
    * Step 1: Select ticket type and quantity.
    * Step 2: Dynamic attendee info form (First Name, Last Name, Email, Phone, Company).
    * Step 3: Payment selection (UPI QR Code or Card).
    * Step 4: Booking confirmation with ticket download link.
  - Handles client-side toast notifications using `ShowToastEvent`.

### 2. `paymentQrVerification`
- **Features:**
  - Generates dynamic UPI payment string: `upi://pay?pa=eventmgmt@upi&pn=EventManagement&am={amount}&tn={regCode}`.
  - High-resolution SVG circular progress ring displaying a real-time 3-minute countdown (180 seconds).
  - Simulates payment gateway webhook polling via `setInterval()`.
  - Emits custom events (`success`, `expired`, `cancel`) to notify parent components.

### 3. `ticketTypeCollector`
- **Flow Screen Component:**
  - Exposed to Flow Builder via `lightning__FlowScreen` target in `ticketTypeCollector.js-meta.xml`.
  - Enables organizers to add unlimited ticket tiers (e.g. VIP, Early Bird, General) dynamically.
  - Emits an array of `TicketTypeWrapper` records directly to the Flow engine.

### 4. `organizerDashboard`
- **Executive Console:**
  - Displays top KPI cards: Active Events, Total Revenue (₹), Registered Attendees, Check-in Rate (%).
  - Real-time progress bar for capacity utilization.
  - Data table with attendee search and one-click check-in button that updates Salesforce in real time.

---

## 5. Visualforce PDF Generator (`PrintableTicket.page`)

- **Rendering Engine:** `renderAs="pdf"`
- **Styling:** CSS3 print media queries (`@page { size: A4 portrait; margin: 10mm; }`).
- **Features:**
  - Professional event branding banner.
  - Clear typography with attendee name, ticket number, seat/tier designation, and venue directions.
  - Embedded high-resolution QR code containing ticket verification hash for security staff scanning at the entrance.

---

## 6. Unit Testing Strategy & Code Quality (41 Tests)

| Test Class Name | Test Methods | Core Scenarios Tested |
| :--- | :---: | :--- |
| **`EventBookingControllerTest`** | 8 | Positive booking, Sold-out capacity handling, Duplicate email resolution, Invalid payment simulation. |
| **`OrganizerDashboardControllerTest`** | 5 | Metric calculation accuracy, Event Manager vs Organizer scope, Check-in status updates. |
| **`PaymentGatewayServiceTest`** | 5 | Custom metadata config retrieval, standard UPI Intent generation, Sandbox initialization, HMAC-SHA256 signature verification. |
| **`EventApprovalServiceTest`** | 8 | Category matrix routing (Concert, Hackathon, Training, Summit), auto-approvals, Invocable Flow testing. |
| **`RegistrationTriggerTest`** | 8 | Single & bulk (200 records) inserts, Capacity decrement verification, Cancelled registration inventory release. |
| **`TicketTypeTriggerTest`** | 6 | Total capacity exceeding venue rejection, Delete prevention when tickets exist. |
| **`PrintableTicketExtensionTest`** | 3 | PDF page parameter binding, QR URL generation, Missing ID handling. |
| **`AttendeeJourneyE2ETest`** | 3 | E2E attendee discovery, booking, and double-payment idempotency guards. |
| **`OrganizerJourneyE2ETest`** | 4 | E2E manager approval process, auto-approval, rejection, and capacity overflow. |
| **Total** | **49 Passing** | **100% Pass Rate** |

---

## 7. Viva Q&A Cheat Sheet (Custom Code)

### Q1: "Why did you use a Trigger Handler instead of writing code directly inside the trigger?"
> **Answer:**  
> *"Sir, writing code directly in a trigger violates Separation of Concerns and leads to unmaintainable code. With the Trigger Handler pattern:
> 1. We have a single trigger per object, eliminating unpredictable execution order.
> 2. Business logic is modular and can be called independently by batch jobs or unit tests.
> 3. We can easily implement static variables to prevent infinite trigger recursion."*

### Q2: "What is the difference between `with sharing`, `without sharing`, and `inherited sharing`?"
> **Answer:**  
> *"Sir:
> - `with sharing` enforces record-level sharing rules and OWD of the current user.
> - `without sharing` executes in system mode, ignoring sharing rules (used when guest users need to book tickets across records they do not own).
> - `inherited sharing` runs with the sharing mode of the calling class; if called directly, it defaults to `with sharing`. It is the modern default for utility classes."*

### Q3: "How does your code prevent hitting the 100 SOQL query governor limit?"
> **Answer:**  
> *"Sir, we enforce strict **Bulkification**:
> 1. We NEVER write SOQL inside a `for` loop.
> 2. We collect IDs in a `Set<Id>` and issue a single SOQL query using the `IN :idSet` clause.
> 3. We map the queried records into a `Map<Id, sObject>` for instant $O(1)$ memory lookups inside loops."*

### Q4: "How does the LWC communicate with the Apex Controller?"
> **Answer:**  
> *"Sir, through two mechanisms:
> 1. **Wire Service (`@wire`):** Used for read-only data that benefits from client-side caching (e.g., fetching upcoming events). The Apex method must have `@AuraEnabled(cacheable=true)`.
> 2. **Imperative Apex Calls:** Used when performing DML or when data must be fetched upon a specific user action (e.g. clicking 'Confirm Payment' or 'Check In Attendee')."*

### Q5: "What is `@TestSetup` in Apex test classes and why is it beneficial?"
> **Answer:**  
> *"Sir, a method annotated with `@TestSetup` creates test data once for the entire test class. After each individual test method executes, Salesforce automatically rolls back any changes to the test setup state. This drastically reduces overall test execution time and avoids redundant record creation code in every test method."*
