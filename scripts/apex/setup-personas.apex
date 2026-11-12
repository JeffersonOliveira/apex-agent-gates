// Creates the two lab personas as real users in the org.
// Run with: sf apex run --target-org lab --file scripts/apex/setup-personas.apex
// Prerequisite: force-app is deployed (the permission sets must exist) and the org has 2 free Salesforce licenses.
// Anonymous Apex has no mixed DML problem here: User and PermissionSetAssignment are both setup objects.

Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
Map<String, PermissionSet> permissionSets = new Map<String, PermissionSet>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('Persona_Restricted', 'Persona_Manager')]) {
    permissionSets.put(ps.Name, ps);
}
if (permissionSets.size() != 2) {
    throw new IllegalArgumentException('Deploy force-app first: Persona_Restricted and Persona_Manager were not found.');
}

String unique = String.valueOf(System.currentTimeMillis());
Map<String, String> personas = new Map<String, String>{
    'restricted' => 'Persona_Restricted',
    'manager' => 'Persona_Manager'
};

List<User> users = new List<User>();
for (String key : personas.keySet()) {
    String username = 'persona.' + key + '.' + unique + '@agentgates.lab';
    users.add(new User(
        FirstName = 'Persona',
        LastName = key,
        Alias = 'p' + key.left(3) + unique.right(3),
        Email = username,
        Username = username,
        ProfileId = standardUser.Id,
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Sao_Paulo'
    ));
}
insert users;

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User u : users) {
    String permissionSetName = personas.get(u.LastName);
    assignments.add(new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = permissionSets.get(permissionSetName).Id
    ));
    System.debug('Created ' + u.Username + ' with ' + permissionSetName);
}
insert assignments;
