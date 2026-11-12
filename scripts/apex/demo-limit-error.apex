// Shows the T2 failure. THIS SCRIPT FAILS ON PURPOSE.
// Run with: sf apex run --target-org lab --file scripts/apex/demo-limit-error.apex
// Expected: System.LimitException: Too many SOQL queries: 101
// The unsafe OpportunityLineTotals.recalc runs 2 queries per line item, so it dies around item 51.
// The transaction is rolled back, so no data is left in the org.
// To see the fixed version succeed, replace the last line with OpportunityLineTotalsSafe.recalc(items).

Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

Account acc = new Account(Name = 'Lab Limit Demo');
insert acc;

Product2 product = new Product2(Name = 'Lab Limit Product', IsActive = true);
insert product;

PricebookEntry entry = new PricebookEntry(
    Pricebook2Id = standardPricebook.Id,
    Product2Id = product.Id,
    UnitPrice = 10,
    IsActive = true
);
insert entry;

List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < 200; i++) {
    opps.add(new Opportunity(
        Name = 'Limit Demo ' + i,
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Pricebook2Id = standardPricebook.Id
    ));
}
insert opps;

List<OpportunityLineItem> items = new List<OpportunityLineItem>();
for (Opportunity o : opps) {
    items.add(new OpportunityLineItem(
        OpportunityId = o.Id,
        PricebookEntryId = entry.Id,
        Quantity = 2,
        UnitPrice = 10
    ));
}
insert items;

OpportunityLineTotals.recalc(items);
