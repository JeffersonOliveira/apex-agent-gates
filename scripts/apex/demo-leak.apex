// Shows the T1 leak. Run seed-case.apex first.
// Run with: sf apex run --target-org lab --file scripts/apex/demo-leak.apex
// Anonymous Apex runs as the CLI user (an admin), so the output shows SECRET.
// To see the same call as a persona, use "Login As" on the restricted user in Setup and run this
// snippet in the Developer Console, or run the Apex test CaseNoteSummaryServiceSafe_Test,
// where System.runAs does it for you. See ROTEIRO_CENARIOS.md, scenario T1.

Case seeded = [SELECT Id FROM Case WHERE Subject = 'Demo' ORDER BY CreatedDate DESC LIMIT 1];

System.debug('--- UNSAFE service (system mode) ---');
for (CaseNoteSummaryService.Summary s : CaseNoteSummaryService.summarize(new Set<Id>{ seeded.Id })) {
    System.debug('unsafe internalNotes = ' + s.internalNotes);
}

System.debug('--- SAFE service (user mode) ---');
for (CaseNoteSummaryServiceSafe.Summary s : CaseNoteSummaryServiceSafe.summarize(new Set<Id>{ seeded.Id })) {
    System.debug('safe internalNotes = ' + s.internalNotes);
}
