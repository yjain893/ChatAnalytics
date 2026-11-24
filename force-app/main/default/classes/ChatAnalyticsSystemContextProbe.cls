public without sharing class ChatAnalyticsSystemContextProbe {
    public static String probe() {
        String key = 'probe-' + String.valueOf(System.now().getTime());
        try {
            Chat_Conversation__c conversation = new Chat_Conversation__c(Conversation_Identifier__c=key, Transcript__c='probe transcript', Transcript_Hash__c='a'.repeat(64), Analysis_Status__c='Pending', Message_Count__c=1, Has_Human_Agent__c=false, Last_Prepared_At__c=System.now());
            Database.insert(conversation, AccessLevel.SYSTEM_MODE);
            Chat_Conversation__c loaded = (Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Transcript__c, Transcript_Hash__c, Analysis_Status__c, Message_Count__c, Has_Human_Agent__c, Last_Prepared_At__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
            loaded.Transcript__c = 'updated probe transcript'; loaded.Analysis_Status__c = 'Completed'; Database.update(loaded, AccessLevel.SYSTEM_MODE);
            Chat_Conversation__c updated = (Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Transcript__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
            Database.delete(conversation, AccessLevel.SYSTEM_MODE);
            return 'SUCCESS|' + updated.Analysis_Status__c + '|' + updated.Transcript__c;
        } catch (Exception error) { return 'ERROR|' + error.getTypeName() + '|' + error.getMessage(); }
    }
    public static String messageProbe() {
        String key = 'probe-message-' + String.valueOf(System.now().getTime());
        try {
            Chat_Message__c message = new Chat_Message__c(Source_Message_Id__c=key, Conversation_Identifier__c=key, Message_Text__c='message body', Message_Category__c='Customer Message', Available_Options__c='One | Two', Participant_Role__c='EndUser', Participant_Display_Name__c='Probe User');
            Database.insert(message, AccessLevel.SYSTEM_MODE);
            Chat_Message__c loaded = (Chat_Message__c)Database.queryWithBinds('SELECT Id, Message_Text__c, Message_Category__c, Available_Options__c, Participant_Role__c, Participant_Display_Name__c, Chat_Conversation__c FROM Chat_Message__c WHERE Id=:id',new Map<String,Object>{'id'=>message.Id},AccessLevel.SYSTEM_MODE)[0];
            String result = 'SUCCESS|' + loaded.Message_Category__c + '|' + loaded.Chat_Conversation__c;
            Database.delete(message, AccessLevel.SYSTEM_MODE);
            return result;
        } catch (Exception error) { return 'ERROR|' + error.getTypeName() + '|' + error.getMessage(); }
    }
}