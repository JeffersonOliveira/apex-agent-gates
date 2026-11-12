/**
 * Lab case T1, reviewed version.
 * Runs with sharing and queries in user mode, so record sharing, object permissions and
 * field-level security of the running user are enforced by the platform.
 * Fails closed: when the running user has no read access to Case.Internal_Notes__c,
 * the query throws a QueryException that names the field, instead of returning the data.
 */
public with sharing class CaseNoteSummaryServiceSafe {

    public class Summary {
        public Id caseId;
        public String subject;
        public String description;
        public String internalNotes;

        public Summary(Case c) {
            this.caseId = c.Id;
            this.subject = c.Subject;
            this.description = c.Description;
            this.internalNotes = c.Internal_Notes__c;
        }
    }

    /**
     * @throws QueryException when the user lacks FLS on a queried field (message contains the field name)
     */
    public static List<Summary> summarize(Set<Id> caseIds) {
        List<Summary> result = new List<Summary>();
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
            result.add(new Summary(c));
        }
        return result;
    }
}
