@IsTest private class ChatAnalyticsProcessingTest {
    private static Integer sequence = 0;
    private static Chat_Message__c message(String conversation, Integer rowNumber, String role, String category, String text, String options) {
        sequence++; return new Chat_Message__c(Source_Message_Id__c='test-message-'+sequence, Conversation_Identifier__c=conversation, Source_Row_Number__c=rowNumber, Participant_Role__c=role, Speaker__c=role, Message_Category__c=category, Message_Text__c=text, Available_Options__c=options, Client_Timestamp_Raw__c='2026-01-07 18:05:' + String.valueOf(10+rowNumber), Client_Timestamp__c=DateTime.newInstance(2026,1,7,18,5,10+rowNumber));
    }
    @IsTest static void messagesCreateOneParentLinkAndPreparedTranscript() {
        List<Chat_Message__c> rows = new List<Chat_Message__c>{message('conv-a',2,'Chatbot','Bot Options','How can I help?','Order Status | Return'),message('conv-a',3,'EndUser','Customer Selection',null,null),message('conv-a',4,'Agent','Agent Message','I can help with the return.',null),message('conv-a',1,'System','System',null,null),message('conv-b',1,'EndUser','Customer Message','A separate conversation',null)};
        Test.startTest(); Database.insert(rows, AccessLevel.SYSTEM_MODE); Test.stopTest();
        List<SObject> conversations = Database.queryWithBinds('SELECT Id, Conversation_Identifier__c, Transcript__c, Transcript_Hash__c, Analysis_Status__c, Message_Count__c, Has_Human_Agent__c FROM Chat_Conversation__c ORDER BY Conversation_Identifier__c', new Map<String,Object>(), AccessLevel.SYSTEM_MODE);
        System.assertEquals(2, conversations.size());
        Chat_Conversation__c conversationA = (Chat_Conversation__c)conversations[0];
        System.assertEquals('conv-a', conversationA.Conversation_Identifier__c);
        System.assertEquals(4, conversationA.Message_Count__c);
        System.assertEquals(true, conversationA.Has_Human_Agent__c);
        System.assertEquals('Pending', conversationA.Analysis_Status__c);
        System.assertNotEquals(null, conversationA.Transcript_Hash__c);
        System.assert(conversationA.Transcript__c.contains('Available options: Order Status | Return'));
        System.assert(conversationA.Transcript__c.contains('selected option is unavailable'));
        System.assert(!conversationA.Transcript__c.contains('System [System]'));
        System.assert(conversationA.Transcript__c.contains('Agent [Agent Message]'));
        for (SObject record : Database.queryWithBinds('SELECT Id, Chat_Conversation__c FROM Chat_Message__c', new Map<String,Object>(), AccessLevel.SYSTEM_MODE)) System.assertNotEquals(null, ((Chat_Message__c)record).Chat_Conversation__c);
    }
    @IsTest static void correctionsResetAnalysisAndContextActionIsSafe() {
        Chat_Message__c row=message('conv-c',1,'EndUser','Customer Message','Need an address change',null); Database.insert(new List<Chat_Message__c>{row},AccessLevel.SYSTEM_MODE);
        Chat_Conversation__c conversation=(Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Conversation_Identifier__c = :identifier',new Map<String,Object>{'identifier'=>'conv-c'},AccessLevel.SYSTEM_MODE)[0];
        ChatTranscriptBuilder.refresh(new Set<Id>{conversation.Id});
        conversation=(Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id = :id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
        Database.update(new Chat_Conversation__c(Id=conversation.Id, Conversation_Status__c='Closed'), AccessLevel.SYSTEM_MODE);
        String originalHash=conversation.Transcript_Hash__c;
        Database.update(new List<Chat_Message__c>{new Chat_Message__c(Id=row.Id,Message_Text__c='Need to change the shipping address')},AccessLevel.SYSTEM_MODE);
        ChatTranscriptBuilder.refresh(new Set<Id>{conversation.Id});
        Chat_Conversation__c refreshed=(Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id = :id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
        System.assertNotEquals(originalHash,refreshed.Transcript_Hash__c); System.assertEquals('Pending',refreshed.Analysis_Status__c);
        GetChatConversationContextAction.Request existing=new GetChatConversationContextAction.Request(); existing.conversationRecordId=conversation.Id; GetChatConversationContextAction.Response context=GetChatConversationContextAction.getContext(new List<GetChatConversationContextAction.Request>{existing})[0]; System.assertEquals('SUCCESS',context.status); System.assert(context.transcript.contains('shipping address'));
        GetChatConversationContextAction.Request missing=new GetChatConversationContextAction.Request();missing.conversationRecordId=null;System.assertEquals('NOT_FOUND',GetChatConversationContextAction.getContext(new List<GetChatConversationContextAction.Request>{missing})[0].status);
    }
    @IsTest static void repeatedIdentifierDoesNotCreateDuplicateParents() {
        List<Chat_Message__c> rows=new List<Chat_Message__c>{new Chat_Message__c(Source_Message_Id__c='required-d-one',Conversation_Identifier__c='conv-d'),new Chat_Message__c(Source_Message_Id__c='required-d-two',Conversation_Identifier__c='conv-d')};Test.startTest();Database.insert(rows,AccessLevel.SYSTEM_MODE);Test.stopTest();System.assertEquals(1,Database.queryWithBinds('SELECT Id FROM Chat_Conversation__c WHERE Conversation_Identifier__c=:identifier',new Map<String,Object>{'identifier'=>'conv-d'},AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void developmentImporterUsesSystemContextAndIsIdempotent() {
        Map<String,Object> row=new Map<String,Object>{'Source_Message_Id__c'=>'import-test-one','Conversation_Identifier__c'=>'import-conversation','Participant_Role__c'=>'EndUser','Client_Timestamp_Raw__c'=>'07/01/2026 18:05:27','Client_Duration__c'=>'0','Message_Text__c'=>'Need help with a return','Message_Category__c'=>'Customer Message','Conversation_Date__c'=>'07/01/2026','Source_Row_Number__c'=>2,'Import_Batch_Id__c'=>'test'};
        ChatMessageSystemImporter.ImportResult first=ChatMessageSystemImporter.importJson(JSON.serialize(new List<Object>{row})); System.assertEquals(1,first.insertedCount); System.assertEquals(0,first.updatedCount);
        row.put('Message_Text__c','Need help with an updated return'); ChatMessageSystemImporter.ImportResult second=ChatMessageSystemImporter.importJson(JSON.serialize(new List<Object>{row})); System.assertEquals(0,second.insertedCount); System.assertEquals(1,second.updatedCount);
        Chat_Message__c imported=(Chat_Message__c)Database.queryWithBinds('SELECT Message_Text__c, Client_Timestamp__c, Source_Row_Number__c FROM Chat_Message__c WHERE Source_Message_Id__c=:sourceId',new Map<String,Object>{'sourceId'=>'import-test-one'},AccessLevel.SYSTEM_MODE)[0]; System.assertEquals('Need help with an updated return',imported.Message_Text__c); System.assertNotEquals(null,imported.Client_Timestamp__c); System.assertEquals(2,imported.Source_Row_Number__c);
    }
}