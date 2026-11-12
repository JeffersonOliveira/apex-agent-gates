// Inserts one Case with a secret in Internal_Notes__c and prints its Id.
// Run with: sf apex run --target-org lab --file scripts/apex/seed-case.apex
Case c = new Case(
    Subject = 'Demo',
    Description = 'desc',
    Internal_Notes__c = 'SECRET',
    Status = 'New',
    Origin = 'Web'
);
insert c;
System.debug('SEEDED CASE ID: ' + c.Id);
