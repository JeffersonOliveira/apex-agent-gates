/**
 * INTENTIONALLY UNSAFE (lab case T2, "volume").
 * This is what the agent wrote for "keep Opportunity.Lines_Total__c up to date when a line item is saved".
 * It passes a test with 1 record. With 200 line items in one transaction it runs 2 SOQL queries
 * and 1 DML per item, so the 101st query throws System.LimitException: Too many SOQL queries: 101.
 * The fixed version is OpportunityLineTotalsSafe.
 */
public with sharing class OpportunityLineTotals {

    public static void recalc(List<OpportunityLineItem> lines) {
        for (OpportunityLineItem li : lines) {
            AggregateResult ar = [
                SELECT SUM(TotalPrice) total
                FROM OpportunityLineItem
                WHERE OpportunityId = :li.OpportunityId
            ];
            Opportunity o = [
                SELECT Id
                FROM Opportunity
                WHERE Id = :li.OpportunityId
            ];
            o.Lines_Total__c = (Decimal) ar.get('total');
            update o;
        }
    }
}
