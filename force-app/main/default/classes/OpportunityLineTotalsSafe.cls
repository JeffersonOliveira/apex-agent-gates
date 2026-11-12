/**
 * Lab case T2, reviewed version.
 * Bulk-safe: one aggregate query for all Opportunities and one DML for all updates,
 * no matter whether the list has 1 or 200 items. Both run in user mode.
 */
public with sharing class OpportunityLineTotalsSafe {

    public static void recalc(List<OpportunityLineItem> lines) {
        if (lines == null || lines.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem li : lines) {
            if (li.OpportunityId != null) {
                oppIds.add(li.OpportunityId);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totalsByOpp = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT OpportunityId oppId, SUM(TotalPrice) total
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
            WITH USER_MODE
            GROUP BY OpportunityId
        ]) {
            totalsByOpp.put((Id) ar.get('oppId'), (Decimal) ar.get('total'));
        }

        List<Opportunity> opps = new List<Opportunity>();
        for (Id oppId : oppIds) {
            Decimal total = totalsByOpp.containsKey(oppId) ? totalsByOpp.get(oppId) : 0;
            opps.add(new Opportunity(Id = oppId, Lines_Total__c = total));
        }

        Database.update(opps, AccessLevel.USER_MODE);
    }
}
