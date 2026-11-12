/**
 * INTENTIONALLY UNSAFE (lab case T1, "permission").
 * This is what the agent wrote when asked for a Case summary with internal notes:
 * it works, it compiles, the test passes, and it leaks Internal_Notes__c to any user,
 * because the class runs in system mode and the query ignores field-level security.
 * The fixed version is CaseNoteSummaryServiceSafe.
 */
public without sharing class CaseNoteSummaryService {

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

    public static List<Summary> summarize(Set<Id> caseIds) {
        List<Summary> result = new List<Summary>();
        if (caseIds == null || caseIds.isEmpty()) {
            return result;
        }
        for (Case c : [
            SELECT Id, Subject, Description, Internal_Notes__c
            FROM Case
            WHERE Id IN :caseIds
        ]) {
            result.add(new Summary(c));
        }
        return result;
    }
}
