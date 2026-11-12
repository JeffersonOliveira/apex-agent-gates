// gates:allow-system-mode: lab test code, personas and data are created as the admin who executes the tests
/**
 * Lab case T3, the test that proves behavior.
 * Uses System.runAs on two personas defined by permission sets (see TestPersonas).
 */
@IsTest
private class CaseNoteSummaryServiceSafe_Test {

    @IsTest
    static void restrictedPersonaFailsClosed() {
        User restricted = TestPersonas.restricted();
        Id caseId = TestPersonas.insertCaseWithSecret();

        Boolean threw = false;
        System.runAs(restricted) {
            try {
                CaseNoteSummaryServiceSafe.summarize(new Set<Id>{ caseId });
                Assert.fail('Expected a QueryException because the restricted persona has no FLS on Internal_Notes__c');
            } catch (QueryException e) {
                threw = true;
                Assert.isTrue(
                    e.getMessage().contains('Internal_Notes__c'),
                    'The exception should name the protected field, but was: ' + e.getMessage()
                );
            }
        }
        Assert.isTrue(threw, 'The restricted persona must not be able to read Internal Notes');
    }

    @IsTest
    static void managerPersonaSeesInternalNotes() {
        User manager = TestPersonas.manager();
        Id caseId = TestPersonas.insertCaseWithSecret();

        List<CaseNoteSummaryServiceSafe.Summary> result;
        System.runAs(manager) {
            result = CaseNoteSummaryServiceSafe.summarize(new Set<Id>{ caseId });
        }

        Assert.areEqual(1, result.size(), 'The manager should get exactly one summary');
        Assert.areEqual('SECRET', result[0].internalNotes, 'The manager has FLS, so the notes must come back');
        Assert.areEqual('Demo', result[0].subject);
    }

    /**
     * This test documents the bug, it does not approve the code.
     * It passes, and what it proves is the leak: the unsafe service hands SECRET
     * to a persona that has no permission on the field. Keep it only as evidence.
     */
    @IsTest
    static void unsafeServiceLeaksToRestrictedPersona() {
        User restricted = TestPersonas.restricted();
        Id caseId = TestPersonas.insertCaseWithSecret();

        List<CaseNoteSummaryService.Summary> leaked;
        System.runAs(restricted) {
            leaked = CaseNoteSummaryService.summarize(new Set<Id>{ caseId });
        }

        Assert.areEqual(1, leaked.size());
        Assert.areEqual(
            'SECRET',
            leaked[0].internalNotes,
            'LEAK: the unsafe service returned Internal Notes to a user without FLS'
        );
    }
}
