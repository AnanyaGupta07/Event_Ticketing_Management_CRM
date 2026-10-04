/**
 * Apex-Defined Data Type — NOT an SObject. Exists purely so the Flow
 * variable that receives ticketTypeCollector's output collection has a
 * concrete shape to bind to (Flow > New Resource > Variable >
 * Data Type: Apex-Defined > TicketTypeWrapper, Allow multiple values: on).
 *
 * The Flow still has to loop over a collection of these and build real
 * Ticket_Type__c records (stamping Event__c) before the bulk Create Records
 * element — see the wiring notes in ticketTypeCollector's SKILL/README.
 */
public class TicketTypeWrapper {
    @AuraEnabled public String name;
    @AuraEnabled public Decimal price;
    @AuraEnabled public Decimal quota;
    @AuraEnabled public String description;
}
