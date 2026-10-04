@IsTest
private class EventApprovalServiceTest {

    @IsTest
    static void testWebinarAutoApproved() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Webinar', 25000.00);
        Test.stopTest();

        System.assertEquals(true, res.isAutoApproved, 'Webinar under 30k should auto-approve');
        System.assertEquals(false, res.requiresManagerApproval, 'Should not require manager');
        System.assertEquals('AUTO_APPROVED', res.decisionCode);
    }

    @IsTest
    static void testWebinarManagerApprovalRequired() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Webinar', 75000.00);
        Test.stopTest();

        System.assertEquals(false, res.isAutoApproved, 'Webinar over 30k should not auto-approve');
        System.assertEquals(true, res.requiresManagerApproval, 'Webinar 75k should require manager approval');
        System.assertEquals(false, res.requiresFinanceSignoff, 'Under 100k should not require finance');
        System.assertEquals('MANAGER_APPROVAL_REQUIRED', res.decisionCode);
    }

    @IsTest
    static void testConcertFinanceExecutiveRequired() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Concert', 2000000.00);
        Test.stopTest();

        System.assertEquals(false, res.isAutoApproved, 'Concert 20L should not auto-approve');
        System.assertEquals(true, res.requiresManagerApproval, 'Requires manager review');
        System.assertEquals(true, res.requiresFinanceSignoff, 'Concert over 15L should require Finance/CFO');
        System.assertEquals('FINANCE_EXECUTIVE_APPROVAL_REQUIRED', res.decisionCode);
    }

    @IsTest
    static void testConcertAutoApproved() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Concert', 250000.00);
        Test.stopTest();

        System.assertEquals(true, res.isAutoApproved, 'Concert under 3L should auto-approve');
        System.assertEquals('AUTO_APPROVED', res.decisionCode);
    }

    @IsTest
    static void testExecutiveSummitAlwaysRequiresReview() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Executive Summit', 10000.00);
        Test.stopTest();

        System.assertEquals(false, res.isAutoApproved, 'Executive Summit should never auto-approve even at 10k');
        System.assertEquals(true, res.requiresManagerApproval, 'Should require manager review');
    }

    @IsTest
    static void testEvaluateForFlowInvocable() {
        List<EventApprovalService.ApprovalRequest> requests = new List<EventApprovalService.ApprovalRequest>();

        EventApprovalService.ApprovalRequest req1 = new EventApprovalService.ApprovalRequest();
        req1.category = 'Hackathon';
        req1.proposedBudget = 120000.00; // <= 150k auto
        requests.add(req1);

        EventApprovalService.ApprovalRequest req2 = new EventApprovalService.ApprovalRequest();
        req2.category = 'Training';
        req2.proposedBudget = 450000.00; // > 300k finance
        requests.add(req2);

        Test.startTest();
        List<EventApprovalService.ApprovalResult> results = EventApprovalService.evaluateForFlow(requests);
        List<EventApprovalService.ApprovalResult> nullResults = EventApprovalService.evaluateForFlow(null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 results');
        System.assertEquals(true, results[0].isAutoApproved, 'Hackathon 120k should be auto-approved');
        System.assertEquals(true, results[1].requiresFinanceSignoff, 'Training 450k should require finance');
        System.assertEquals(0, nullResults.size(), 'Null requests should return empty list');
    }

    @IsTest
    static void testFallbackUnknownCategory() {
        Test.startTest();
        EventApprovalService.ApprovalResult res = EventApprovalService.evaluateEventBudget('Unknown Strange Category', 40000.00);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Should safely resolve fallback rule');
        System.assertEquals(true, res.isAutoApproved, '40k under Other 50k auto limit should pass');
    }

    @IsTest
    static void testSubmitEventForApprovalWithNull() {
        Test.startTest();
        Id workItemId = EventApprovalService.submitEventForApproval(null, null);
        Test.stopTest();

        System.assertEquals(null, workItemId, 'Null event ID should safely return null');
    }
}
