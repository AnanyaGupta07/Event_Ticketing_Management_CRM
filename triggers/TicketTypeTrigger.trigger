trigger TicketTypeTrigger on Ticket_Type__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            TicketTypeTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TicketTypeTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
