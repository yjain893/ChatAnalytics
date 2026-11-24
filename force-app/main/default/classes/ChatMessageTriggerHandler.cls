public without sharing class ChatMessageTriggerHandler {
    public static void linkConversations(List<Chat_Message__c> messages, Boolean reopenForNewMessages) {
        Set<String> identifiers = new Set<String>();
        for (Chat_Message__c message : messages) if (!String.isBlank(message.Conversation_Identifier__c)) identifiers.add(message.Conversation_Identifier__c.trim());
        if (identifiers.isEmpty()) return;
        Map<String, Id> parents = new Map<String, Id>();
        Map<String, Chat_Conversation__c> existingByIdentifier = new Map<String, Chat_Conversation__c>();
        for (SObject record : Database.queryWithBinds('SELECT Id, Conversation_Identifier__c, Conversation_Status__c FROM Chat_Conversation__c WHERE Conversation_Identifier__c IN :identifiers', new Map<String, Object>{'identifiers'=>identifiers}, AccessLevel.SYSTEM_MODE)) { Chat_Conversation__c conversation=(Chat_Conversation__c)record; parents.put(conversation.Conversation_Identifier__c, conversation.Id); existingByIdentifier.put(conversation.Conversation_Identifier__c, conversation); }
        if (reopenForNewMessages) {
            List<Chat_Conversation__c> reopened = new List<Chat_Conversation__c>();
            for (Chat_Conversation__c conversation : existingByIdentifier.values()) if (conversation.Conversation_Status__c == 'Closed') reopened.add(new Chat_Conversation__c(Id=conversation.Id, Conversation_Status__c='Open', Closed_At__c=null, Analysis_Status__c='Pending'));
            if (!reopened.isEmpty()) Database.update(reopened, AccessLevel.SYSTEM_MODE);
        }
        List<Chat_Conversation__c> missing = new List<Chat_Conversation__c>();
        for (String identifier : identifiers) if (!parents.containsKey(identifier)) missing.add(new Chat_Conversation__c(Conversation_Identifier__c = identifier));
        if (!missing.isEmpty()) { Database.insert(missing, AccessLevel.SYSTEM_MODE); for (Chat_Conversation__c conversation : missing) parents.put(conversation.Conversation_Identifier__c, conversation.Id); }
        for (Chat_Message__c message : messages) if (!String.isBlank(message.Conversation_Identifier__c)) message.Chat_Conversation__c = parents.get(message.Conversation_Identifier__c.trim());
    }
    public static void requestRefresh(List<Chat_Message__c> messages, Map<Id, Chat_Message__c> oldMap) {
        Set<Id> parentIds = new Set<Id>();
        for (Chat_Message__c message : messages) {
            if (message.Chat_Conversation__c != null) parentIds.add(message.Chat_Conversation__c);
            if (oldMap != null && oldMap.containsKey(message.Id) && oldMap.get(message.Id).Chat_Conversation__c != null) parentIds.add(oldMap.get(message.Id).Chat_Conversation__c);
        }
        if (!parentIds.isEmpty()) System.enqueueJob(new ChatConversationRefreshQueueable(parentIds));
    }
}