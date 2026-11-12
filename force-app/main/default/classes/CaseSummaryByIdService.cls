/**
 * Returns a summary (subject, description and internal notes) for each requested Case,
 * keyed by Case Id.
 * Runs with sharing, so record sharing of the running user is enforced and Cases the user
 * cannot see are simply absent from the result map.
 * The query runs in system mode: object permissions and field-level security are NOT
 * enforced, so Case.Internal_Notes__c is returned even to users without read access to it.
 * Callers are responsible for deciding who may see the internal notes.
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
     */
    public static Map<Id, CaseSummary> summarize(Set<Id> caseIds) {
        Map<Id, CaseSummary> result = new Map<Id, CaseSummary>();
        if (caseIds == null || caseIds.isEmpty()) {
            return result;
        }
        // gates:allow-system-mode: owner decided this query does not need user mode (requested explicitly, November 12, 2026)
        List<Case> cases = [
            SELECT Id, Subject, Description, Internal_Notes__c
            FROM Case
            WHERE Id IN :caseIds
        ];
        for (Case c : cases) {
            result.put(c.Id, new CaseSummary(c));
        }
        return result;
    }
}
