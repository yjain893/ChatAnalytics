@IsTest private class ChatAnalyticsNormalizedAnalyticsTest {
    private class Provider implements ChatAnalyticsAgentProvider {
        private Boolean escalated; private Boolean valid;
        Provider(Boolean escalated, Boolean valid){this.escalated=escalated;this.valid=valid;}
        public ChatAnalyticsAgentInvoker.InvocationResult invoke(Id conversationId){
            ChatAnalyticsAgentInvoker.InvocationResult r=new ChatAnalyticsAgentInvoker.InvocationResult();r.success=true;r.sessionId='normalized-test';r.structuredResponse=new Map<String,Object>{'customerProblem'=>'Address change','customerIntent'=>'Change shipping address','issueCategory'=>valid?'Address / Order Change':'Unsupported issue','botResolutionStatus'=>'Not Resolved','escalatedToHuman'=>escalated,'escalationReason'=>valid?'Missing Transaction Capability':'Unsupported reason','finalResolutionBy'=>escalated?'Human Agent':'Unresolved','botImprovementOpportunity'=>valid?'Missing Action / Automation':'Unsupported improvement','botFailureReason'=>'Cannot complete requested transaction','analysisSummary'=>'Test response','confidence'=>.8,'evidence'=>'Test evidence'};return r;
        }
    }
    private static Integer sequence=0;
    private static Chat_Conversation__c conversationWithOrderedMessages(Boolean includeHuman){
        sequence++;String key='normalized-'+sequence;Chat_Conversation__c c=new Chat_Conversation__c(Conversation_Identifier__c=key,Transcript__c='prepared transcript',Transcript_Hash__c=String.valueOf(sequence).leftPad(64,'0'),Conversation_Status__c='Closed',Analysis_Status__c='Pending');Database.insert(c,AccessLevel.SYSTEM_MODE);
        List<Chat_Message__c> messages=new List<Chat_Message__c>{new Chat_Message__c(Source_Message_Id__c=key+'-1',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=1,Participant_Role__c='System'),new Chat_Message__c(Source_Message_Id__c=key+'-2',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=2,Participant_Role__c='Chatbot'),new Chat_Message__c(Source_Message_Id__c=key+'-3',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=3,Participant_Role__c='EndUser'),new Chat_Message__c(Source_Message_Id__c=key+'-4',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=4,Speaker__c='Chatbot')};
        if(includeHuman){messages.add(new Chat_Message__c(Source_Message_Id__c=key+'-5',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=5,Participant_Role__c='Agent'));messages.add(new Chat_Message__c(Source_Message_Id__c=key+'-6',Conversation_Identifier__c=key,Chat_Conversation__c=c.Id,Source_Row_Number__c=6,Participant_Role__c='Chatbot'));}
        Database.insert(messages,AccessLevel.SYSTEM_MODE);Database.update(new Chat_Conversation__c(Id=c.Id,Conversation_Status__c='Closed',Analysis_Status__c='Pending'),AccessLevel.SYSTEM_MODE);return (Chat_Conversation__c)Database.queryWithBinds('SELECT Id FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>c.Id},AccessLevel.SYSTEM_MODE)[0];
    }
    private static Chat_Conversation__c simpleConversation(){
        sequence++; String key='normalized-simple-'+sequence;
        Chat_Conversation__c c=new Chat_Conversation__c(Conversation_Identifier__c=key,Transcript__c='prepared transcript',Transcript_Hash__c=String.valueOf(sequence).leftPad(64,'0'),Conversation_Status__c='Closed',Analysis_Status__c='Pending');
        Database.insert(c,AccessLevel.SYSTEM_MODE);
        return c;
    }
    @IsTest static void deterministicTurnCounterExcludesSystemCustomerAndStopsAtHuman(){
        Chat_Conversation__c escalated=conversationWithOrderedMessages(true);
        Chat_Conversation__c botOnly=conversationWithOrderedMessages(false);
        System.assertEquals(2,ChatAnalyticsService.botTurnsBeforeFirstHuman(escalated.Id));
        System.assertEquals(null,ChatAnalyticsService.botTurnsBeforeFirstHuman(botOnly.Id));
    }
    @IsTest static void validDimensionsPersistAndInvalidDimensionsMapOther(){
        Chat_Conversation__c valid=simpleConversation();
        ChatAnalyticsService.process(valid.Id,new Provider(true,true));
        Chat_Analytics__c validAnalytics=(Chat_Analytics__c)Database.queryWithBinds('SELECT Issue_Category__c,Escalation_Reason__c,Bot_Improvement_Opportunity__c,Bot_Turns_Before_Escalation__c FROM Chat_Analytics__c WHERE Chat_Conversation__c=:id',new Map<String,Object>{'id'=>valid.Id},AccessLevel.SYSTEM_MODE)[0];
        System.assertEquals('Address / Order Change',(String)validAnalytics.get('Issue_Category__c'));
        System.assertEquals('Missing Transaction Capability',(String)validAnalytics.get('Escalation_Reason__c'));
        System.assertEquals('Missing Action / Automation',(String)validAnalytics.get('Bot_Improvement_Opportunity__c'));
        System.assertEquals(null,(Decimal)validAnalytics.get('Bot_Turns_Before_Escalation__c'));
        Chat_Conversation__c invalid=simpleConversation();
        ChatAnalyticsService.process(invalid.Id,new Provider(false,false));
        Chat_Analytics__c invalidAnalytics=(Chat_Analytics__c)Database.queryWithBinds('SELECT Issue_Category__c,Escalation_Reason__c,Bot_Improvement_Opportunity__c FROM Chat_Analytics__c WHERE Chat_Conversation__c=:id',new Map<String,Object>{'id'=>invalid.Id},AccessLevel.SYSTEM_MODE)[0];
        System.assertEquals('Other',(String)invalidAnalytics.get('Issue_Category__c'));
        System.assertEquals('No Escalation',(String)invalidAnalytics.get('Escalation_Reason__c'));
        System.assertEquals('Other',(String)invalidAnalytics.get('Bot_Improvement_Opportunity__c'));
    }
}