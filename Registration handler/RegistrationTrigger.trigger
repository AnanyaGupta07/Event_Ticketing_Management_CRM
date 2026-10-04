trigger RegistrationTrigger on Registration__c (before insert) {
    RegistrationTriggerHandler.beforeInsert(Trigger.new);
}
