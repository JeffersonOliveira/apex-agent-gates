// gates:allow-system-mode: lab test data setup runs as the admin who executes the tests
/**
 * Lab case T2. The safe version is tested with 200 items, the volume of a real batch.
 * A System.LimitException cannot be caught in Apex, so the overflow of the unsafe version
 * is NOT asserted here. It is demonstrated by scripts/apex/demo-limit-error.apex.
 */
@IsTest
private class OpportunityLineTotals_Test {

    private static final Integer VOLUME = 200;

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Lab Account');
        insert acc;

        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(Name = 'Lab Product', IsActive = true);
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 10,
            IsActive = true
        );
        insert entry;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < VOLUME; i++) {
            opps.add(new Opportunity(
                Name = 'Lab Opp ' + i,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = standardPricebookId
            ));
        }
        insert opps;

        // One line item per Opportunity: 2 x 10 = 20 each.
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
    }

    private static List<OpportunityLineItem> loadLines() {
        return [SELECT Id, OpportunityId, Quantity, UnitPrice, TotalPrice FROM OpportunityLineItem];
    }

    @IsTest
    static void safeVersionHandles200ItemsInFewQueries() {
        List<OpportunityLineItem> lines = loadLines();
        Assert.areEqual(VOLUME, lines.size(), 'Test data should have 200 line items');

        Test.startTest();
        OpportunityLineTotalsSafe.recalc(lines);
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.isTrue(queriesUsed <= 5, 'Expected a bulk-safe number of queries but used ' + queriesUsed);

        List<Opportunity> result = [SELECT Id, Lines_Total__c FROM Opportunity];
        Assert.areEqual(VOLUME, result.size());
        for (Opportunity o : result) {
            Assert.areEqual(20.00, o.Lines_Total__c, 'Lines_Total__c should be 2 x 10');
        }
    }

    /**
     * This is the test the agent wrote for the unsafe version: it passes with 1 item,
     * production breaks with 200. Do not raise the volume here, see the class comment.
     */
    @IsTest(SeeAllData=false)
    static void unsafeVersionPassesWithOneItem() {
        OpportunityLineItem first = loadLines()[0];

        Test.startTest();
        OpportunityLineTotals.recalc(new List<OpportunityLineItem>{ first });
        Test.stopTest();

        Opportunity o = [SELECT Id, Lines_Total__c FROM Opportunity WHERE Id = :first.OpportunityId];
        Assert.areEqual(20.00, o.Lines_Total__c, 'It works with 1 item. That is the trap.');
    }
}
