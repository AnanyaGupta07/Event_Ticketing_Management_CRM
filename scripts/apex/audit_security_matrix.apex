List<String> permSets = new List<String>{
    'Event_Attendee_Permissions',
    'Event_Organizer_Permissions',
    'Event_Manager_Permissions',
    'Event_Registration_Team_Permissions',
    'Event_Finance_Permissions',
    'Event_Speaker_Coordinator_Permissions'
};

List<String> objects = new List<String>{
    'Event__c',
    'Venue__c',
    'Ticket_Type__c',
    'Speaker__c',
    'Attendee__c',
    'Registration__c',
    'Payment__c',
    'Feedback__c'
};

System.debug('========================================');
System.debug('1. OBJECT-LEVEL PERMISSIONS (CRED / VA / MA)');
System.debug('========================================');

List<ObjectPermissions> objPerms = [
    SELECT Parent.Name, SobjectType, PermissionsCreate, PermissionsRead, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
    FROM ObjectPermissions
    WHERE Parent.Name IN :permSets
    ORDER BY Parent.Name, SobjectType
];

Map<String, Map<String, String>> matrix = new Map<String, Map<String, String>>();
for (ObjectPermissions op : objPerms) {
    if (!matrix.containsKey(op.Parent.Name)) {
        matrix.put(op.Parent.Name, new Map<String, String>());
    }
    String crud = (op.PermissionsCreate ? 'C' : '-') +
                 (op.PermissionsRead ? 'R' : '-') +
                 (op.PermissionsEdit ? 'U' : '-') +
                 (op.PermissionsDelete ? 'D' : '-') +
                 ' | VA:' + (op.PermissionsViewAllRecords ? 'Y' : 'N') +
                 ' MA:' + (op.PermissionsModifyAllRecords ? 'Y' : 'N');
    matrix.get(op.Parent.Name).put(op.SobjectType, crud);
}

for (String ps : permSets) {
    System.debug('--- PERMISSION SET: ' + ps + ' ---');
    if (matrix.containsKey(ps)) {
        for (String obj : objects) {
            String p = matrix.get(ps).containsKey(obj) ? matrix.get(ps).get(obj) : 'NO ACCESS (---)';
            System.debug('  ' + obj.rightPad(18) + ' : ' + p);
        }
    }
}

System.debug('========================================');
System.debug('2. FIELD-LEVEL SECURITY COUNTS');
System.debug('========================================');

for (AggregateResult ar : [
    SELECT Parent.Name psName, SobjectType, COUNT(Id) cnt
    FROM FieldPermissions
    WHERE Parent.Name IN :permSets
    GROUP BY Parent.Name, SobjectType
    ORDER BY Parent.Name, SobjectType
]) {
    System.debug('  ' + String.valueOf(ar.get('psName')).rightPad(38) + ' | ' + String.valueOf(ar.get('SobjectType')).rightPad(18) + ' | ' + ar.get('cnt') + ' fields');
}
