// Verify SetupEntityAccess (Apex class / page access) across permission sets
List<String> permSetNames = new List<String>{
    'Event_Attendee_Permissions',
    'Event_Organizer_Permissions',
    'Event_Manager_Permissions',
    'Event_Finance_Permissions',
    'Event_Speaker_Coordinator_Permissions',
    'Event_Registration_Team_Permissions'
};

List<SetupEntityAccess> seaList = [
    SELECT Parent.Name, SetupEntityId, SetupEntityType 
    FROM SetupEntityAccess 
    WHERE Parent.Name IN :permSetNames
];

Map<String, Integer> permToEntities = new Map<String, Integer>();
for (SetupEntityAccess sea : seaList) {
    Integer c = permToEntities.containsKey(sea.Parent.Name) ? permToEntities.get(sea.Parent.Name) : 0;
    permToEntities.put(sea.Parent.Name, c + 1);
}

for (String psName : permSetNames) {
    System.debug('PERM_SET: ' + psName + ' -> Entity Accesses: ' + (permToEntities.containsKey(psName) ? permToEntities.get(psName) : 0));
}

// Check Demo Organizer events
User demoOrganizer = [SELECT Id FROM User WHERE Username LIKE 'organizer%demo@evmos.com' LIMIT 1];
List<Event__c> orgEvents = [SELECT Id, Name FROM Event__c WHERE Organizer__c = :demoOrganizer.Id];
System.debug('DEMO_ORGANIZER_EVENTS_COUNT: ' + orgEvents.size());

// Check FieldPermissions for Speaker Coordinator and Finance
Integer spkFields = [SELECT COUNT() FROM FieldPermissions WHERE Parent.Name = 'Event_Speaker_Coordinator_Permissions'];
Integer finFields = [SELECT COUNT() FROM FieldPermissions WHERE Parent.Name = 'Event_Finance_Permissions'];
Integer regFields = [SELECT COUNT() FROM FieldPermissions WHERE Parent.Name = 'Event_Registration_Team_Permissions'];
System.debug('SPEAKER_COORD_FIELD_PERMS: ' + spkFields);
System.debug('FINANCE_FIELD_PERMS: ' + finFields);
System.debug('REG_TEAM_FIELD_PERMS: ' + regFields);
