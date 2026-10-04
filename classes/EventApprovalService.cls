/**
 * @description Enterprise Approval Evaluation Service implementing Dynamic Multi-Tier
 * Delegation of Authority (DOA) driven by Custom Metadata (Approval_Matrix__mdt).
 * Provides category-wise threshold routing for Screen Flows, Apex triggers, and controllers.
 */
public with sharing class EventApprovalService {

    public enum ApprovalDecision {
        AUTO_APPROVED,
        MANAGER_APPROVAL_REQUIRED,
        FINANCE_EXECUTIVE_APPROVAL_REQUIRED
    }

    /**
     * @description Invocable Request wrapper for Lightning Flow integration.
     */
    public class ApprovalRequest {
        @InvocableVariable(label='Event Category' description='Event__c.Category__c picklist value' required=true)
        public String category;

        @InvocableVariable(label='Proposed Budget' description='Event__c.Proposed_Budget__c' required=true)
        public Decimal proposedBudget;

        @InvocableVariable(label='Event Record Id' description='Optional Event__c.Id to submit')
        public Id eventId;
    }

    /**
     * @description Invocable Result wrapper returned to Lightning Flow.
     */
    public class ApprovalResult {
        @InvocableVariable(label='Decision Code' description='AUTO_APPROVED | MANAGER_APPROVAL_REQUIRED | FINANCE_EXECUTIVE_APPROVAL_REQUIRED')
        public String decisionCode;

        @InvocableVariable(label='Is Auto Approved' description='True if budget is within auto-approval threshold')
        public Boolean isAutoApproved;

        @InvocableVariable(label='Requires Manager Approval' description='True if budget requires 1-step manager approval')
        public Boolean requiresManagerApproval;

        @InvocableVariable(label='Requires Finance Signoff' description='True if budget exceeds manager authority and needs CFO/Finance')
        public Boolean requiresFinanceSignoff;

        @InvocableVariable(label='Auto Approve Limit' description='Category threshold ceiling for zero-touch approval')
        public Decimal autoApproveLimit;

        @InvocableVariable(label='Manager Approve Limit' description='Category threshold ceiling for Event Manager')
        public Decimal managerApproveLimit;

        @InvocableVariable(label='Guidance Message' description='Human-readable evaluation explanation')
        public String guidanceMessage;
    }

    /**
     * @description Invocable method exposed directly to Lightning Flow Builder.
     * Evaluates a batch of event requests against Custom Metadata rules.
     * @param requests List of ApprovalRequest items from Flow.
     * @return List of ApprovalResult items mapped 1:1.
     */
    @InvocableMethod(label='Evaluate Event Approval Tier' description='Determines approval routing tier based on Category and Proposed Budget from Approval_Matrix__mdt')
    public static List<ApprovalResult> evaluateForFlow(List<ApprovalRequest> requests) {
        List<ApprovalResult> results = new List<ApprovalResult>();
        if (requests == null) {
            return results;
        }

        for (ApprovalRequest req : requests) {
            results.add(evaluateEventBudget(req.category, req.proposedBudget));
        }
        return results;
    }

    /**
     * @description Core evaluation logic querying Approval_Matrix__mdt.
     * Zero SOQL overhead via Custom Metadata Type methods (Approval_Matrix__mdt.getAll()).
     * @param category The event category string.
     * @param proposedBudget The requested budget amount.
     * @return ApprovalResult Structured evaluation result.
     */
    public static ApprovalResult evaluateEventBudget(String category, Decimal proposedBudget) {
        ApprovalResult result = new ApprovalResult();
        Decimal budget = proposedBudget != null ? proposedBudget : 0.00;
        String cat = String.isNotBlank(category) ? category.trim() : 'Other';

        // Fetch category rule from Custom Metadata
        Approval_Matrix__mdt rule = getMatrixRuleForCategory(cat);

        result.autoApproveLimit = rule.Auto_Approve_Limit__c;
        result.managerApproveLimit = rule.Manager_Approve_Limit__c;

        if (budget <= rule.Auto_Approve_Limit__c) {
            result.decisionCode = ApprovalDecision.AUTO_APPROVED.name();
            result.isAutoApproved = true;
            result.requiresManagerApproval = false;
            result.requiresFinanceSignoff = false;
            result.guidanceMessage = 'Budget of ₹' + budget.format() + ' for ' + cat + 
                ' is within the zero-touch threshold of ₹' + rule.Auto_Approve_Limit__c.format() + '. Auto-Approved!';
        } else if (budget <= rule.Manager_Approve_Limit__c) {
            result.decisionCode = ApprovalDecision.MANAGER_APPROVAL_REQUIRED.name();
            result.isAutoApproved = false;
            result.requiresManagerApproval = true;
            result.requiresFinanceSignoff = false;
            result.guidanceMessage = 'Budget of ₹' + budget.format() + ' for ' + cat + 
                ' exceeds auto-approval (₹' + rule.Auto_Approve_Limit__c.format() + ') and is routed to Event Manager.';
        } else {
            result.decisionCode = ApprovalDecision.FINANCE_EXECUTIVE_APPROVAL_REQUIRED.name();
            result.isAutoApproved = false;
            result.requiresManagerApproval = true;
            result.requiresFinanceSignoff = rule.Requires_Finance_Signoff__c != null ? rule.Requires_Finance_Signoff__c : true;
            result.guidanceMessage = 'High-Value Budget of ₹' + budget.format() + ' for ' + cat + 
                ' exceeds manager ceiling (₹' + rule.Manager_Approve_Limit__c.format() + ') and requires Finance/CFO Executive Signoff.';
        }

        return result;
    }

    /**
     * @description Helper to resolve the matching Custom Metadata rule with safe fallback.
     * @param category Event category name.
     * @return Approval_Matrix__mdt The resolved rule.
     */
    public static Approval_Matrix__mdt getMatrixRuleForCategory(String category) {
        Map<String, Approval_Matrix__mdt> allRules = Approval_Matrix__mdt.getAll();

        // 1. Try exact match on DeveloperName (replacing spaces with underscores)
        String devName = category.replaceAll('[^a-zA-Z0-9]', '_');
        if (allRules.containsKey(devName)) {
            return allRules.get(devName);
        }

        // 2. Iterate through all values matching Category__c case-insensitively
        for (Approval_Matrix__mdt item : allRules.values()) {
            if (String.isNotBlank(item.Category__c) && item.Category__c.equalsIgnoreCase(category)) {
                return item;
            }
        }

        // 3. Fallback to 'Other' rule or system defaults
        if (allRules.containsKey('Other')) {
            return allRules.get('Other');
        }

        // 4. In-memory safety fallback if metadata records are somehow missing
        Approval_Matrix__mdt defaultFallback = new Approval_Matrix__mdt(
            Category__c = 'Other',
            Auto_Approve_Limit__c = 50000.0,
            Manager_Approve_Limit__c = 200000.0,
            Requires_Finance_Signoff__c = true
        );
        return defaultFallback;
    }

    /**
     * @description Submits an Event__c record to the standard Salesforce Approval Process programmatically.
     * @param eventId The record Id of the Event__c.
     * @param comment The submission comment.
     * @return Id The approval work item Id or null on error.
     */
    public static Id submitEventForApproval(Id eventId, String comment) {
        if (eventId == null) {
            return null;
        }

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setComments(String.isNotBlank(comment) ? comment : 'Submitted for budget review via EventApprovalService.');
        req.setObjectId(eventId);
        req.setProcessDefinitionNameOrId('Event_Budget_Approval');
        req.setSkipEntryCriteria(false);

        try {
            Approval.ProcessResult result = Approval.process(req);
            return result.isSuccess() ? result.getInstanceId() : null;
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'EventApprovalService: Approval submission notice: ' + ex.getMessage());
            return null;
        }
    }
}
