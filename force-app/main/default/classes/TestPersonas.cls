// gates:allow-system-mode: test helper, creates users and test data as the admin who executes the tests
/**
 * Builds the two lab personas used by System.runAs in the tests.
 * Both are Standard User profile plus one permission set (Persona_Restricted or Persona_Manager).
 * User and PermissionSetAssignment are created inside System.runAs(new User(Id = UserInfo.getUserId()))
 * so that setup objects and regular objects never mix in the same DML context (MIXED_DML_OPERATION).
 */
@IsTest
public class TestPersonas {

    public static User restricted() {
        return buildPersona('restricted', 'Persona_Restricted');
    }

    public static User manager() {
        return buildPersona('manager', 'Persona_Manager');
    }

    /** Inserts a Case with a secret in Internal_Notes__c and returns its Id. */
    public static Id insertCaseWithSecret() {
        Case c = new Case(
            Subject = 'Demo',
            Description = 'desc',
            Internal_Notes__c = 'SECRET',
            Status = 'New',
            Origin = 'Web'
        );
        insert c;
        return c.Id;
    }

    private static User buildPersona(String key, String permissionSetName) {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Assert.isFalse(profiles.isEmpty(), 'Profile "Standard User" was not found in this org');
        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        Assert.isFalse(permissionSets.isEmpty(), 'Permission set ' + permissionSetName + ' was not deployed');

        String unique = String.valueOf(System.currentTimeMillis()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String username = 'persona.' + key + '.' + unique + '@agentgates.lab';
        User u = new User(
            FirstName = 'Persona',
            LastName = key,
            Alias = ('p' + unique.right(6)),
            Email = username,
            Username = username,
            ProfileId = profiles[0].Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Sao_Paulo'
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = permissionSets[0].Id);
        }

        Assert.isNotNull(u.Id, 'The persona user should have been created');
        return u;
    }
}
