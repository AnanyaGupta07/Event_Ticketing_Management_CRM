# Task Documentation: Phase 7 — Approval Process

**Status:** ✅ Completed  
**Relevant Folder:** [`Approval_Process/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Implement the Salesforce declarative Approval Process metadata for `Event__c` to handle budget governance:
- Events submitted through `Event_Creation_Screen_Flow` with `Proposed_Budget__c` exceeding the threshold defined in `Approval_Settings__mdt` are submitted to this process.
- Single-step approval routed exclusively to the **Event Manager** role (preventing self-approval per `owd.md §5` and `validationrules.md`).
- Automates status transitions for initial submission (`Pending Approval`), final approval (`Approved`), final rejection (`Rejected`), and recall (`Draft`).

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`Event__c.Event_Budget_Approval.approvalProcess-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/Event__c.Event_Budget_Approval.approvalProcess-meta.xml) | Approval Process Metadata XML | `Approval_Process/` | Defines entry criteria, single-step review assigned to Event Manager role, and lifecycle actions. |
| [`Event__c.Set_Status_Pending_Approval.workflowFieldUpdate-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/Event__c.Set_Status_Pending_Approval.workflowFieldUpdate-meta.xml) | Workflow Field Update XML | `Approval_Process/` | Sets `Approval_Status__c = 'Pending Approval'` upon initial submission. |
| [`Event__c.Set_Status_Approved.workflowFieldUpdate-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/Event__c.Set_Status_Approved.workflowFieldUpdate-meta.xml) | Workflow Field Update XML | `Approval_Process/` | Sets `Approval_Status__c = 'Approved'` upon final approval. |
| [`Event__c.Set_Status_Rejected.workflowFieldUpdate-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/Event__c.Set_Status_Rejected.workflowFieldUpdate-meta.xml) | Workflow Field Update XML | `Approval_Process/` | Sets `Approval_Status__c = 'Rejected'` upon final rejection. |
| [`Event__c.Set_Status_Draft.workflowFieldUpdate-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/Approval_Process/Event__c.Set_Status_Draft.workflowFieldUpdate-meta.xml) | Workflow Field Update XML | `Approval_Process/` | Resets `Approval_Status__c = 'Draft'` if approval request is recalled. |

---

## 3. Configuration & Logic Architecture

### Entry Criteria
```xml
ISBLANK(TEXT(Approval_Status__c)) || ISPICKVAL(Approval_Status__c, "Draft")
```

### Routing & Approver Assignment
- **Approval Step:** `Manager_Review`
- **Assigned Approver:** Role `Event_Manager`
- **Multiple Approvers Setting:** `FirstResponse`
- **Self-Approval Guard:** Because the approver target is the `Event_Manager` role and Organizer users belong to the subordinate Event Organizer role in the hierarchy, organizers cannot approve their own submissions.

### Action Matrix
1. **Initial Submission Actions**:
   - Field update: `Set_Status_Pending_Approval` (`Approval_Status__c = 'Pending Approval'`).
   - Locks record from standard user edits.
2. **Final Approval Actions**:
   - Field update: `Set_Status_Approved` (`Approval_Status__c = 'Approved'`).
   - Unlocks record.
3. **Final Rejection Actions**:
   - Field update: `Set_Status_Rejected` (`Approval_Status__c = 'Rejected'`).
   - Backstopped by Validation Rule `VR: Rejection_Reason_Required` ensuring `Rejection_Reason__c` is filled when rejected.
   - Unlocks record.
4. **Recall Actions**:
   - Field update: `Set_Status_Draft` (`Approval_Status__c = 'Draft'`).
   - Unlocks record.
