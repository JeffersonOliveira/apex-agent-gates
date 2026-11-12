/**
 * Returns a summary (subject, description and internal notes) for each requested Case,
 * keyed by Case Id.
 * Runs with sharing and queries in user mode, so record sharing, object permissions and
 * field-level security of the running user are enforced by the platform.
 * Fails closed: when the running user has no read access to Case.Internal_Notes__c,
 * the query throws a QueryException instead of returning the data.
 * Cases the user cannot see are simply absent from the result map.
 */
public with sharing class CaseSummaryByIdService {

    public class CaseSummary {
        public Id caseId;
        public String subject;
        public String description;
        public String internalNotes;

        public CaseSummary(Case c) {
            this.caseId = c.Id;
            this.subject = c.Subject;
            this.description = c.Description;
            this.internalNotes = c.Internal_Notes__c;
        }
    }

    /**
     * @param caseIds Ids of the Cases to summarize. Null or empty returns an empty map.
     * @return one CaseSummary per visible Case, keyed by Case Id
     * @throws QueryException when the running user lacks read access to a queried field
     */
    public static Map<Id, CaseSummary> summarize(Set<Id> caseIds) {
        Map<Id, CaseSummary> result = new Map<Id, CaseSummary>();
        if (caseIds == null || caseIds.isEmpty()) {
            return result;
        }
        // Query into a list first. In a SOQL for loop, a user mode FLS failure reports
        // "Variable does not exist: tmpVar1" instead of naming the protected field.
        List<Case> cases = [
            SELECT Id, Subject, Description, Internal_Notes__c
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ];
        for (Case c : cases) {
            result.put(c.Id, new CaseSummary(c));
        }
        return result;
    }
}
