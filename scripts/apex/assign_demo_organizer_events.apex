User demoOrganizer = [SELECT Id, Name, Username FROM User WHERE Username LIKE 'organizer%demo@evmos.com' LIMIT 1];
System.debug('Found Demo Organizer: ' + demoOrganizer.Username + ' (Id: ' + demoOrganizer.Id + ')');

List<Event__c> eventsToAssign = [
    SELECT Id, Name, Organizer__c 
    FROM Event__c 
    WHERE Name IN (
        'Cloud & AI World Summit 2026',
        'Salesforce Agentforce Deep Dive Workshop',
        'Global DevOps & Kubernetes Masterclass'
    )
];

for (Event__c e : eventsToAssign) {
    e.Organizer__c = demoOrganizer.Id;
}
update eventsToAssign;

System.debug('Successfully assigned ' + eventsToAssign.size() + ' events to Demo Organizer.');
