User attendeeUser = [SELECT Id, Name, Username FROM User WHERE Username LIKE '%attendee%' LIMIT 1];
System.debug('Found attendee user: ' + attendeeUser.Username + ' (Id: ' + attendeeUser.Id + ')');

List<PermissionSetAssignment> psas = [
    SELECT PermissionSet.Name, PermissionSet.Label 
    FROM PermissionSetAssignment 
    WHERE AssigneeId = :attendeeUser.Id
];
for (PermissionSetAssignment psa : psas) {
    System.debug('ASSIGNED_PERM_SET: ' + psa.PermissionSet.Name);
}

List<SetupEntityAccess> sea = [
    SELECT SetupEntityId, SetupEntityType 
    FROM SetupEntityAccess 
    WHERE Parent.Name = 'Event_Attendee_Permissions'
];
System.debug('PERM_SET_ENTITIES: ' + sea.size());

List<Event__c> evts = EventBookingController.getPublishedEvents();
System.debug('PUBLISHED_EVENTS_COUNT: ' + evts.size());
for (Event__c e : evts) {
    System.debug('EVENT: ' + e.Name + ' | Reg: ' + e.Registration_Status__c + ' | Pub: ' + e.Publication_Status__c + ' | Appr: ' + e.Approval_Status__c);
}
