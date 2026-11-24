@IsTest private class ChatAnalyticsOrchestrationTest {
    private static Integer sequence = 0;
    private class SuccessProvider implements ChatAnalyticsAgentProvider {
        private String botStatus; private String finalBy; private Object confidence;
        SuccessProvider(String botStatus, String finalBy, Object confidence) { this.botStatus=botStatus; this.finalBy=finalBy; this.confidence=confidence; }
        public ChatAnalyticsAgentInvoker.InvocationResult invoke(Id conversationId) {
            ChatAnalyticsAgentInvoker.InvocationResult result=new ChatAnalyticsAgentInvoker.InvocationResult(); result.success=true; result.sessionId='session-test'; result.structuredResponse=new Map<String,Object>{'customerProblem'=>'Return timing','customerIntent'=>'Refund status','issueCategory'=>'Returns / Refunds','botResolutionStatus'=>botStatus,'escalatedToHuman'=>true,'escalationReason'=>'Repeated / Irrelevant Responses','finalResolutionBy'=>finalBy,'botImprovementOpportunity'=>'Response Quality','botFailureReason'=>'Repeated menu responses','analysisSummary'=>'A human ultimately addressed the issue.','confidence'=>confidence,'evidence'=>'Agent participation after unresolved bot responses.'}; return result;
        }
    }
    private class FailureProvider implements ChatAnalyticsAgentProvider { public ChatAnalyticsAgentInvoker.InvocationResult invoke(Id conversationId) { ChatAnalyticsAgentInvoker.InvocationResult result=new ChatAnalyticsAgentInvoker.InvocationResult(); result.success=false; result.errorMessage='Simulated invocation failure'; return result; } }
    private class StaleProvider implements ChatAnalyticsAgentProvider {
        public ChatAnalyticsAgentInvoker.InvocationResult invoke(Id conversationId) {
            sequence++; Database.insert(new Chat_Message__c(Source_Message_Id__c='late-'+sequence,Conversation_Identifier__c=identifier(conversationId),Message_Text__c='A newly received event',Message_Category__c='Customer Message',Participant_Role__c='EndUser'),AccessLevel.SYSTEM_MODE); ChatTranscriptBuilder.refresh(new Set<Id>{conversationId});
            ChatAnalyticsAgentInvoker.InvocationResult result=new SuccessProvider('Resolved','Bot',.7).invoke(conversationId); return result;
        }
    }
    private static Chat_Conversation__c prepared(Boolean closed, String status, Integer attempts) {
        sequence++; String identifier='test-'+sequence; Chat_Message__c message=new Chat_Message__c(Source_Message_Id__c='source-'+sequence,Conversation_Identifier__c=identifier,Source_Row_Number__c=2,Participant_Role__c='EndUser',Speaker__c='EndUser',Message_Category__c='Customer Message',Message_Text__c='Need a refund update',Client_Timestamp__c=DateTime.newInstance(2026,1,7,18,5,sequence),Client_Timestamp_Raw__c='07/01/2026 18:05:00'); Database.insert(message,AccessLevel.SYSTEM_MODE);
        Chat_Conversation__c conversation=(Chat_Conversation__c)Database.queryWithBinds('SELECT Id FROM Chat_Conversation__c WHERE Conversation_Identifier__c=:identifier',new Map<String,Object>{'identifier'=>identifier},AccessLevel.SYSTEM_MODE)[0]; ChatTranscriptBuilder.refresh(new Set<Id>{conversation.Id});
        Database.update(new Chat_Conversation__c(Id=conversation.Id,Conversation_Status__c=closed?'Closed':'Open',Analysis_Status__c=status,Analysis_Attempts__c=attempts),AccessLevel.SYSTEM_MODE);
        return (Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Conversation_Identifier__c, Conversation_Status__c, Transcript__c, Transcript_Hash__c, Analysis_Status__c, Analysis_Attempts__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
    }
    private static String identifier(Id conversationId) { return ((Chat_Conversation__c)Database.queryWithBinds('SELECT Conversation_Identifier__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversationId},AccessLevel.SYSTEM_MODE)[0]).Conversation_Identifier__c; }
    @IsTest static void eligibilityAndOpenContextProtection() {
        Chat_Conversation__c open=prepared(false,'Pending',0), pending=prepared(true,'Pending',0), retry=prepared(true,'Failed',2), exhausted=prepared(true,'Failed',3), completed=prepared(true,'Completed',1);
        System.assert(!ChatAnalyticsService.isEligible(open)); System.assert(ChatAnalyticsService.isEligible(pending)); System.assert(ChatAnalyticsService.isEligible(retry)); System.assert(!ChatAnalyticsService.isEligible(exhausted)); System.assert(!ChatAnalyticsService.isEligible(completed));
        GetChatConversationContextAction.Request request=new GetChatConversationContextAction.Request(); request.conversationRecordId=open.Id; System.assertEquals('NOT_CLOSED',GetChatConversationContextAction.getContext(new List<GetChatConversationContextAction.Request>{request})[0].status);
        System.assertEquals(2,ChatAnalyticsOrchestrator.eligibleIds(20).size());
    }
    @IsTest static void successNormalizesAndUpsertsIdempotently() {
        Chat_Conversation__c conversation=prepared(true,'Pending',0); ChatAnalyticsService.process(conversation.Id,new SuccessProvider('Bad value','Unknown',2));
        Chat_Conversation__c completed=(Chat_Conversation__c)Database.queryWithBinds('SELECT Analysis_Status__c, Analysis_Attempts__c, Last_Analyzed_At__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0]; System.assertEquals('Completed',completed.Analysis_Status__c); System.assertEquals(1,completed.Analysis_Attempts__c); System.assertNotEquals(null,completed.Last_Analyzed_At__c);
        Chat_Analytics__c analytics=(Chat_Analytics__c)Database.queryWithBinds('SELECT Bot_Resolution_Status__c, Final_Resolution_By__c, Issue_Category__c, Escalation_Reason__c, Bot_Improvement_Opportunity__c, Bot_Turns_Before_Escalation__c, Confidence__c, Agent_Session_Id__c FROM Chat_Analytics__c WHERE Chat_Conversation__c=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0]; System.assertEquals('Indeterminate',analytics.Bot_Resolution_Status__c);System.assertEquals('Indeterminate',analytics.Final_Resolution_By__c);System.assertEquals('Returns / Refunds',(String)analytics.get('Issue_Category__c'));System.assertEquals('Repeated / Irrelevant Responses',(String)analytics.get('Escalation_Reason__c'));System.assertEquals('Response Quality',(String)analytics.get('Bot_Improvement_Opportunity__c'));System.assertEquals(null,(Decimal)analytics.get('Bot_Turns_Before_Escalation__c'));System.assertEquals(1,analytics.Confidence__c);System.assertEquals('session-test',analytics.Agent_Session_Id__c);
        Database.update(new Chat_Conversation__c(Id=conversation.Id,Analysis_Status__c='Pending'),AccessLevel.SYSTEM_MODE); ChatAnalyticsService.process(conversation.Id,new SuccessProvider('Not Resolved','Human Agent',.6)); System.assertEquals(1,Database.queryWithBinds('SELECT Id FROM Chat_Analytics__c WHERE Chat_Conversation__c=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void failuresAndStaleResponsesDoNotComplete() {
        Chat_Conversation__c failed=prepared(true,'Pending',0); ChatAnalyticsService.process(failed.Id,new FailureProvider()); Chat_Conversation__c failedResult=(Chat_Conversation__c)Database.queryWithBinds('SELECT Analysis_Status__c, Last_Analysis_Error__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>failed.Id},AccessLevel.SYSTEM_MODE)[0];System.assertEquals('Failed',failedResult.Analysis_Status__c);System.assert(failedResult.Last_Analysis_Error__c.contains('Simulated'));
        Chat_Conversation__c stale=prepared(true,'Pending',0); ChatAnalyticsService.process(stale.Id,new StaleProvider()); Chat_Conversation__c staleResult=(Chat_Conversation__c)Database.queryWithBinds('SELECT Conversation_Status__c, Analysis_Status__c, Transcript_Hash__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>stale.Id},AccessLevel.SYSTEM_MODE)[0];System.assertEquals('Open',staleResult.Conversation_Status__c);System.assertEquals('Pending',staleResult.Analysis_Status__c);System.assertEquals(0,Database.queryWithBinds('SELECT Id FROM Chat_Analytics__c WHERE Chat_Conversation__c=:id',new Map<String,Object>{'id'=>stale.Id},AccessLevel.SYSTEM_MODE).size());
    }
    @IsTest static void newMessageAfterClosureReopensConversation() {
        Chat_Conversation__c conversation=prepared(true,'Completed',1); String originalHash=conversation.Transcript_Hash__c; sequence++; Database.insert(new Chat_Message__c(Source_Message_Id__c='after-close-'+sequence,Conversation_Identifier__c=conversation.Conversation_Identifier__c,Message_Text__c='Additional customer response',Message_Category__c='Customer Message',Participant_Role__c='EndUser'),AccessLevel.SYSTEM_MODE); ChatTranscriptBuilder.refresh(new Set<Id>{conversation.Id});
        Chat_Conversation__c reopened=(Chat_Conversation__c)Database.queryWithBinds('SELECT Conversation_Status__c, Analysis_Status__c, Transcript_Hash__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0]; System.assertEquals('Open',reopened.Conversation_Status__c);System.assertEquals('Pending',reopened.Analysis_Status__c);System.assertNotEquals(originalHash,reopened.Transcript_Hash__c);
    }
    @IsTest static void claimedConversationCanBeInvokedAndPersisted() {
        Chat_Conversation__c conversation=prepared(true,'Pending',0);
        ChatAnalyticsService.Claim claim=ChatAnalyticsService.claimForProcessing(conversation.Id);
        System.assertNotEquals(null,claim);
        ChatAnalyticsService.invokeClaimed(claim,new SuccessProvider('Not Resolved','Human Agent',.8));
        Chat_Conversation__c completed=(Chat_Conversation__c)Database.queryWithBinds('SELECT Analysis_Status__c, Analysis_Attempts__c FROM Chat_Conversation__c WHERE Id=:id',new Map<String,Object>{'id'=>conversation.Id},AccessLevel.SYSTEM_MODE)[0];
        System.assertEquals('Completed',completed.Analysis_Status__c);
        System.assertEquals(1,completed.Analysis_Attempts__c);
    }
}