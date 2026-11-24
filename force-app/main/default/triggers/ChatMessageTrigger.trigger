trigger ChatMessageTrigger on Chat_Message__c (before insert, before update, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore) ChatMessageTriggerHandler.linkConversations(Trigger.new, Trigger.isInsert);
    else if (Trigger.isDelete) ChatMessageTriggerHandler.requestRefresh(Trigger.old, Trigger.oldMap);
    else ChatMessageTriggerHandler.requestRefresh(Trigger.new, Trigger.oldMap);
}