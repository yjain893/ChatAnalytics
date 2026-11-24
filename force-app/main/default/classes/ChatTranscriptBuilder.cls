public without sharing class ChatTranscriptBuilder {
    public static void refresh(Set<Id> conversationIds) {
        if (conversationIds == null || conversationIds.isEmpty()) return;
        Map<Id, Chat_Conversation__c> conversations = new Map<Id, Chat_Conversation__c>();
        for (SObject record : Database.queryWithBinds('SELECT Id, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id IN :conversationIds', new Map<String, Object>{'conversationIds'=>conversationIds}, AccessLevel.SYSTEM_MODE)) { Chat_Conversation__c conversation=(Chat_Conversation__c)record; conversations.put(conversation.Id, conversation); }
        Map<Id, List<Chat_Message__c>> byConversation = new Map<Id, List<Chat_Message__c>>();
        for (SObject record : Database.queryWithBinds('SELECT Id, Chat_Conversation__c, Source_Row_Number__c, Client_Timestamp__c, Client_Timestamp_Raw__c, Participant_Display_Name__c, Participant_Role__c, Speaker__c, Available_Options__c, Message_Text__c, Message_Category__c, CreatedDate FROM Chat_Message__c WHERE Chat_Conversation__c IN :conversationIds ORDER BY Source_Row_Number__c ASC NULLS LAST, Client_Timestamp__c ASC NULLS LAST, CreatedDate ASC', new Map<String, Object>{'conversationIds'=>conversations.keySet()}, AccessLevel.SYSTEM_MODE)) {
            Chat_Message__c message=(Chat_Message__c)record;
            if (!byConversation.containsKey(message.Chat_Conversation__c)) byConversation.put(message.Chat_Conversation__c, new List<Chat_Message__c>());
            byConversation.get(message.Chat_Conversation__c).add(message);
        }
        List<Chat_Conversation__c> updates = new List<Chat_Conversation__c>();
        for (Id conversationId : conversations.keySet()) {
            List<Chat_Message__c> messages = byConversation.containsKey(conversationId) ? byConversation.get(conversationId) : new List<Chat_Message__c>();
            String transcript = build(messages); String hash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(transcript)));
            DateTime startAt; DateTime endAt; DateTime lastMessageAt; Boolean hasAgent = false;
            for (Chat_Message__c message : messages) {
                if (message.Client_Timestamp__c != null && (startAt == null || message.Client_Timestamp__c.getTime() < startAt.getTime())) startAt = message.Client_Timestamp__c;
                if (message.Client_Timestamp__c != null && (endAt == null || message.Client_Timestamp__c.getTime() > endAt.getTime())) endAt = message.Client_Timestamp__c;
                if (isReliableMessageTimestamp(message.Client_Timestamp__c) && (lastMessageAt == null || message.Client_Timestamp__c.getTime() > lastMessageAt.getTime())) lastMessageAt = message.Client_Timestamp__c;
                if (isAgent(message.Participant_Role__c) || isAgent(message.Speaker__c)) hasAgent = true;
            }
            Chat_Conversation__c conversationUpdate = new Chat_Conversation__c(Id=conversationId, Transcript__c=transcript, Transcript_Hash__c=hash, Message_Count__c=messages.size(), Start_Timestamp__c=startAt, End_Timestamp__c=endAt, Last_Message_At__c=lastMessageAt, Has_Human_Agent__c=hasAgent, Last_Prepared_At__c=System.now());
            if (conversations.get(conversationId).Transcript_Hash__c != hash) conversationUpdate.Analysis_Status__c = 'Pending';
            updates.add(conversationUpdate);
        }
        if (!updates.isEmpty()) Database.update(updates, AccessLevel.SYSTEM_MODE);
    }
    @TestVisible private static String build(List<Chat_Message__c> messages) {
        List<String> lines = new List<String>();
        for (Chat_Message__c message : messages) {
            String text = clean(message.Message_Text__c), options = clean(message.Available_Options__c), category = String.isBlank(message.Message_Category__c) ? 'Message' : message.Message_Category__c;
            Boolean selection = category.toLowerCase().contains('customer selection'); Boolean systemRecord = isSystem(message.Participant_Role__c) || isSystem(message.Speaker__c) || category.toLowerCase() == 'system';
            if (systemRecord && String.isBlank(text)) continue;
            String body;
            if (selection && String.isBlank(text) && String.isBlank(options)) body = '[Customer Selection event — selected option is unavailable in the supplied source data]';
            else { body = text; if (!String.isBlank(options)) body += (String.isBlank(body) ? '' : '\n') + 'Available options: ' + options; }
            if (String.isBlank(body)) continue;
            String actor = !String.isBlank(message.Speaker__c) ? message.Speaker__c : (!String.isBlank(message.Participant_Role__c) ? message.Participant_Role__c : 'Unknown');
            if (isAgent(message.Participant_Role__c) && !String.isBlank(message.Participant_Display_Name__c)) actor += ' (' + message.Participant_Display_Name__c + ')';
            String timestamp = !String.isBlank(message.Client_Timestamp_Raw__c) ? message.Client_Timestamp_Raw__c : (message.Client_Timestamp__c == null ? 'timestamp unavailable' : String.valueOf(message.Client_Timestamp__c));
            lines.add('[' + timestamp + '] ' + actor + ' [' + category + ']:\n' + body);
        }
        return String.join(lines, '\n\n');
    }
    private static String clean(String value) { return String.isBlank(value) ? null : value.trim(); }
    private static Boolean isAgent(String value) { return !String.isBlank(value) && value.toLowerCase().contains('agent'); }
    private static Boolean isSystem(String value) { return !String.isBlank(value) && value.toLowerCase().contains('system'); }
    private static Boolean isReliableMessageTimestamp(DateTime value) { return value != null && value.year() > 1970; }
}