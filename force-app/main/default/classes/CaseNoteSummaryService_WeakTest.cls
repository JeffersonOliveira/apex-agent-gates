// gates:allow-system-mode: lab test data setup runs as the admin who executes the tests
/**
 * Lab case T3, the weak test the agent wrote.
 * 90% coverage, zero proof: the only assert is "the list is not empty".
 * It says nothing about who is allowed to see Internal_Notes__c.
 */
@IsTest
private class CaseNoteSummaryService_WeakTest {

    @IsTest
    static void summarizeReturnsSomething() {
        Case c = new Case(
            Subject = 'Demo',
            Description = 'desc',
            Internal_Notes__c = 'SECRET',
            Status = 'New',
            Origin = 'Web'
        );
        insert c;

        List<CaseNoteSummaryService.Summary> r = CaseNoteSummaryService.summarize(new Set<Id>{ c.Id });

        Assert.isTrue(r.size() > 0);
    }
}
