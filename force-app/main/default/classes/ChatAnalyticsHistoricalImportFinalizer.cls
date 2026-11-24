/** Development/setup helper: closes a fully reconciled historical extract only after deterministic validation. */
public without sharing class ChatAnalyticsHistoricalImportFinalizer {
    public class Result { public Integer conversationCount; public List<Integer> messageCounts; public Boolean closed; }
    public static Result finalizeExtract(Set<Id> conversationIds) {
        if (conversationIds == null || conversationIds.size() != 4) throw new HistoricalImportException('Exactly four reconciled historical conversations are required.');
        Database.update(openUpdates(conversationIds), AccessLevel.SYSTEM_MODE);
        ChatTranscriptBuilder.refresh(conversationIds);
        List<Chat_Conversation__c> conversations = load(conversationIds);
        Set<Integer> expectedCounts = new Set<Integer>{7,15,28,49}; Set<Integer> actualCounts = new Set<Integer>();
        for (Chat_Conversation__c conversation : conversations) {
            if (String.isBlank(conversation.Transcript__c) || String.isBlank(conversation.Transcript_Hash__c)) throw new HistoricalImportException('Transcript preparation is incomplete for ' + conversation.Id + '.');
            actualCounts.add(Integer.valueOf(conversation.Message_Count__c));
        }
        if (conversations.size() != 4 || actualCounts != expectedCounts) throw new HistoricalImportException('Historical extract counts do not match the expected 7, 15, 28, and 49 message distribution.');
        List<Chat_Conversation__c> closeUpdates = new List<Chat_Conversation__c>();
        for (Chat_Conversation__c conversation : conversations) closeUpdates.add(new Chat_Conversation__c(Id=conversation.Id, Conversation_Status__c='Closed', Closed_At__c=conversation.Last_Message_At__c, Analysis_Status__c='Pending', Last_Analysis_Error__c=null));
        Database.update(closeUpdates, AccessLevel.SYSTEM_MODE);
        Result result = new Result(); result.conversationCount=conversations.size(); result.messageCounts=new List<Integer>(actualCounts); result.messageCounts.sort(); result.closed=true; return result;
    }
    public static List<String> processingReport() {
        List<String> output = new List<String>();
        for (SObject record : Database.queryWithBinds('SELECT Conversation_Identifier__c, Conversation_Status__c, Analysis_Status__c, Analysis_Attempts__c, Last_Analysis_Error__c, Transcript_Hash__c FROM Chat_Conversation__c ORDER BY Conversation_Identifier__c', new Map<String,Object>(), AccessLevel.SYSTEM_MODE)) {
            Chat_Conversation__c conversation=(Chat_Conversation__c)record;
            output.add(conversation.Conversation_Identifier__c + '|status=' + conversation.Conversation_Status__c + '|analysis=' + conversation.Analysis_Status__c + '|attempts=' + conversation.Analysis_Attempts__c + '|hash=' + (String.isBlank(conversation.Transcript_Hash__c) ? 'missing' : 'present') + '|error=' + conversation.Last_Analysis_Error__c);
        }
        return output;
    }
    /** Clears only validation failures caused by a replaced deployment defect. */
    public static Integer resetTransientProcessingFailures(Set<Id> conversationIds) {
        if (conversationIds == null || conversationIds.isEmpty()) return 0;
        List<Chat_Conversation__c> resets = new List<Chat_Conversation__c>();
        for (SObject record : Database.queryWithBinds('SELECT Id FROM Chat_Conversation__c WHERE Id IN :conversationIds AND Conversation_Status__c = :closed', new Map<String,Object>{'conversationIds'=>conversationIds,'closed'=>'Closed'}, AccessLevel.SYSTEM_MODE)) {
            resets.add(new Chat_Conversation__c(Id=((Chat_Conversation__c)record).Id, Analysis_Status__c='Pending', Analysis_Attempts__c=0, Last_Analysis_Error__c=null));
        }
        if (!resets.isEmpty()) Database.update(resets, AccessLevel.SYSTEM_MODE);
        return resets.size();
    }
    public static List<String> analyticsReport() {
        List<String> output = new List<String>();
        for (SObject record : Database.queryWithBinds('SELECT Conversation_Identifier__c, Bot_Resolution_Status__c, Escalated_To_Human__c, Final_Resolution_By__c, Confidence__c, Agent_Session_Id__c FROM Chat_Analytics__c ORDER BY Conversation_Identifier__c', new Map<String,Object>(), AccessLevel.SYSTEM_MODE)) {
            Chat_Analytics__c analytics = (Chat_Analytics__c)record;
            output.add(analytics.Conversation_Identifier__c + '|bot=' + analytics.Bot_Resolution_Status__c + '|escalated=' + analytics.Escalated_To_Human__c + '|final=' + analytics.Final_Resolution_By__c + '|confidence=' + analytics.Confidence__c + '|session=' + (!String.isBlank(analytics.Agent_Session_Id__c)));
        }
        return output;
    }
    private static List<Chat_Conversation__c> openUpdates(Set<Id> ids) { List<Chat_Conversation__c> updates=new List<Chat_Conversation__c>(); for(Id id:ids) updates.add(new Chat_Conversation__c(Id=id,Conversation_Status__c='Open')); return updates; }
    private static List<Chat_Conversation__c> load(Set<Id> ids) { List<Chat_Conversation__c> output=new List<Chat_Conversation__c>(); for(SObject record:Database.queryWithBinds('SELECT Id, Transcript__c, Transcript_Hash__c, Message_Count__c, Last_Message_At__c FROM Chat_Conversation__c WHERE Id IN :ids',new Map<String,Object>{'ids'=>ids},AccessLevel.SYSTEM_MODE)) output.add((Chat_Conversation__c)record); return output; }
    public class HistoricalImportException extends Exception {}
}