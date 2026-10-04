# Task Documentation: Phase 10 — Salesforce Deployment Guide & Manifest Configuration

**Status:** ✅ Completed  
**Relevant Folders:** [`manifest/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/manifest/), [`docxx/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/docxx/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Establish a complete, validated deployment pipeline and developer guide for transferring the entire Event Management & Ticketing platform into the connected Salesforce org (`my-org`):
- Created canonical `manifest/package.xml` covering all 18 metadata types.
- Configured `.forceignore` to keep development and scratch folders isolated from source tracking.
- Pre-flight validated all Custom Objects, Custom Fields, Validation Rules, and Metadata against the live Salesforce org.
- Provided a step-by-step GUI and CLI deployment guide in [`docxx/deployment-guide.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/docxx/deployment-guide.md).

---

## 2. Key Metadata Deliverables & Changes

| Deliverable | Path | Description |
|---|---|---|
| Manifest Package | [`manifest/package.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/manifest/package.xml) | XML catalog mapping all objects, classes, triggers, LWCs, flows, permissions, layouts, and apps. |
| Force Ignore | [`.forceignore`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/.forceignore) | Excludes non-source directories from build payloads. |
| Deployment Guide | [`docxx/deployment-guide.md`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/docxx/deployment-guide.md) | Step-by-step developer and administrator deployment runbook with exact commands. |

---

## 3. Metadata Fixes Applied During Validation
1. **`Approval_Settings__mdt.Budget_Threshold__c`**: Adjusted field type from `Currency` to `Number` (Salesforce Metadata schema requirement for `__mdt`).
2. **`Event_Compact_Layout` & `Venue_Compact_Layout`**: Removed unsupported `<description>` node from `CompactLayout` schema.
3. **`Payment__c` Validation Rule**: Shortened API name to `Txn_Ref_Required_When_Successful` (within Salesforce 40-character limit).
4. **`Registration__c` Validation Rule**: Shortened API name to `No_Reg_On_Unpublished_Or_Closed_Event` (within Salesforce 40-character limit).
5. **`Event__c.Organizer__c`**: Changed `deleteConstraint` to `SetNull` and `required` to `false` (required for standard `User` lookups in Salesforce).
