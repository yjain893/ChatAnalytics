public without sharing class ChatAnalyticsOrchestrator {
    public static final Integer MAX_DAILY_ENQUEUES = 20;
    public static Id enqueueConversation(Id conversationId) {
        Chat_Conversation__c conversation = load(conversationId);
        if (!ChatAnalyticsService.isEligible(conversation)) throw new ChatAnalyticsOrchestratorException(conversation == null || conversation.Conversation_Status__c != 'Closed' ? 'Conversation is still open and is not eligible for analysis.' : 'Conversation is not eligible for analysis.');
        return System.enqueueJob(new ChatAnalyticsQueueable(new List<Id>{conversationId}));
    }
    public static List<Id> enqueueEligible(Integer maximum) {
        List<Id> ids = eligibleIds(maximum == null ? MAX_DAILY_ENQUEUES : maximum);
        if (!ids.isEmpty()) System.enqueueJob(new ChatAnalyticsQueueable(ids));
        return ids;
    }
    @TestVisible static List<Id> eligibleIds(Integer maximum) {
        List<Id> ids = new List<Id>();
        Integer candidateLimit = Math.min(200, maximum * 10);
        for (SObject record : Database.queryWithBinds('SELECT Id, Transcript__c, Conversation_Status__c, Analysis_Status__c, Analysis_Attempts__c FROM Chat_Conversation__c WHERE Conversation_Status__c = :closed AND (Analysis_Status__c = :pending OR (Analysis_Status__c = :failed AND Analysis_Attempts__c < :maxAttempts)) ORDER BY Last_Prepared_At__c ASC LIMIT :candidateLimit', new Map<String,Object>{'closed'=>'Closed','pending'=>'Pending','failed'=>'Failed','maxAttempts'=>3,'candidateLimit'=>candidateLimit}, AccessLevel.SYSTEM_MODE)) {
            Chat_Conversation__c conversation = (Chat_Conversation__c)record;
            if (ChatAnalyticsService.isEligible(conversation)) ids.add(conversation.Id);
            if (ids.size() == maximum) break;
        }
        return ids;
    }
    private static Chat_Conversation__c load(Id conversationId) {
        List<SObject> records = Database.queryWithBinds('SELECT Id, Conversation_Status__c, Transcript__c, Analysis_Status__c, Analysis_Attempts__c FROM Chat_Conversation__c WHERE Id = :conversationId', new Map<String,Object>{'conversationId'=>conversationId}, AccessLevel.SYSTEM_MODE);
        return records.isEmpty() ? null : (Chat_Conversation__c)records[0];
    }
    public class ChatAnalyticsOrchestratorException extends Exception {}
}