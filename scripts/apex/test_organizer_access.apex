User orgUser = [SELECT Id, Name, Username FROM User WHERE Username LIKE '%organizer%' LIMIT 1];
System.debug('Checking user: ' + orgUser.Username + ' (Id: ' + orgUser.Id + ')');

List<SetupEntityAccess> sea = [
    SELECT SetupEntityId, SetupEntityType 
    FROM SetupEntityAccess 
    WHERE Parent.Name IN ('Event_Organizer_Permissions', 'Event_Manager_Permissions')
];
System.debug('SEA entries for Organizer/Manager perm sets: ' + sea.size());

// Check if Organizer has class access to OrganizerDashboardController
List<ApexClass> cls = [SELECT Id, Name FROM ApexClass WHERE Name = 'OrganizerDashboardController'];
if (!cls.isEmpty()) {
    List<SetupEntityAccess> classAccess = [
        SELECT Id, Parent.Name 
        FROM SetupEntityAccess 
        WHERE SetupEntityId = :cls[0].Id 
          AND Parent.Name IN ('Event_Organizer_Permissions', 'Event_Manager_Permissions')
    ];
    System.debug('Class access entries for OrganizerDashboardController: ' + classAccess.size());
}
