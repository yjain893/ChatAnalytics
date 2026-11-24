@IsTest private class ChatAnalyticsDashboardControllerTest {
    @testSetup static void setupData() {
        List<Chat_Conversation__c> conversations=new List<Chat_Conversation__c>();
        for(Integer i=0;i<4;i++) conversations.add(new Chat_Conversation__c(Conversation_Identifier__c='dashboard-'+i,Transcript__c='[2026-01-01] Chatbot: Hello\n[2026-01-01] EndUser: Need help '+i,Transcript_Hash__c=String.valueOf(i).leftPad(64,'0'),Conversation_Status__c='Closed',Message_Count__c=i+1,Has_Human_Agent__c=i>1,Start_Timestamp__c=System.now().addHours(-2),End_Timestamp__c=System.now().addHours(-1),Analysis_Status__c='Completed'));
        Database.insert(conversations,AccessLevel.SYSTEM_MODE);
        List<Chat_Analytics__c> analytics=new List<Chat_Analytics__c>();
        List<String> botStatuses=new List<String>{'Resolved','Partially Resolved','Not Resolved','Indeterminate'};
        List<String> finalStatuses=new List<String>{'Bot','Human Agent','Unresolved','Indeterminate'};
        List<String> issues=new List<String>{'Order Status / Tracking','Returns / Refunds','Address / Order Change','Other'}; List<String> reasons=new List<String>{'No Escalation','No Escalation','Missing Transaction Capability','Other'}; List<String> improvements=new List<String>{'None','Response Quality','Missing Action / Automation','Other'};
        for(Integer i=0;i<4;i++) { Chat_Analytics__c record=new Chat_Analytics__c(Chat_Conversation__c=conversations[i].Id,Conversation_Identifier__c='dashboard-'+i,Customer_Problem__c='Problem '+i,Customer_Intent__c='Intent '+i,Bot_Resolution_Status__c=botStatuses[i],Escalated_To_Human__c=i>1,Final_Resolution_By__c=finalStatuses[i],Bot_Failure_Reason__c='Reason '+i,Analysis_Summary__c='Summary '+i,Confidence__c=Decimal.valueOf('0.'+(5+i)),Evidence__c='Evidence '+i,Analyzed_At__c=System.now()); record.put('Issue_Category__c',issues[i]);record.put('Escalation_Reason__c',reasons[i]);record.put('Bot_Improvement_Opportunity__c',improvements[i]);record.put('Bot_Turns_Before_Escalation__c',i>1?i:null);analytics.add(record); }
        Database.insert(analytics,AccessLevel.SYSTEM_MODE);
        Database.insert(new Chat_Message__c(Source_Message_Id__c='dashboard-message',Conversation_Identifier__c='dashboard-0',Chat_Conversation__c=conversations[0].Id,Source_Row_Number__c=1,Participant_Role__c='EndUser',Participant_Display_Name__c='Customer',Message_Category__c='Customer Message',Message_Text__c='Need help',Client_Timestamp_Raw__c='2026-01-01 10:00:00'),AccessLevel.SYSTEM_MODE);
    }
    @IsTest static void summaryRowsAndFiltersAreAccurate() {
        ChatAnalyticsDashboardController.DashboardData all=ChatAnalyticsDashboardController.getDashboard(null,null,null,null,null,null,null,null);
        System.assertEquals(4,all.summary.totalConversations); System.assertEquals(1,all.summary.botResolvedCount); System.assertEquals(1,all.summary.partiallyResolvedCount); System.assertEquals(1,all.summary.botNotResolvedCount); System.assertEquals(2,all.summary.escalatedCount); System.assertEquals(1,all.summary.humanResolvedCount); System.assertEquals(1,all.summary.unresolvedCount); System.assertEquals(25,all.summary.botResolvedPercent); System.assertEquals(50,all.summary.escalatedPercent); System.assertEquals(.65,all.summary.averageConfidence); System.assertEquals(2.5,all.summary.averageBotTurnsBeforeEscalation); System.assertEquals(2,all.summary.botTurnsSampleSize); System.assertEquals(4,all.rows.size()); System.assertEquals(4,all.issueCategories.size());
        ChatAnalyticsDashboardController.DashboardData filtered=ChatAnalyticsDashboardController.getDashboard(null,null,'Not Resolved','true','Unresolved','Address / Order Change','Missing Transaction Capability','Missing Action / Automation'); System.assertEquals(1,filtered.rows.size()); System.assertEquals('dashboard-2',filtered.rows[0].conversationIdentifier); System.assertEquals('Address / Order Change',filtered.rows[0].issueCategory);
    }
    @IsTest static void detailUsesSystemModeAndIncludesTranscriptAndRawAudit() {
        Id id=((Chat_Conversation__c)Database.queryWithBinds('SELECT Id FROM Chat_Conversation__c WHERE Conversation_Identifier__c=:key',new Map<String,Object>{'key'=>'dashboard-0'},AccessLevel.SYSTEM_MODE)[0]).Id;
        ChatAnalyticsDashboardController.ConversationDetail detail=ChatAnalyticsDashboardController.getConversationDetail(id);
        System.assertEquals('dashboard-0',detail.conversationIdentifier); System.assertNotEquals(null,detail.transcript); System.assertEquals('Resolved',detail.botResolutionStatus); System.assertEquals(1,detail.messages.size()); System.assertEquals('Need help',detail.messages[0].messageText); System.assertEquals(null,ChatAnalyticsDashboardController.getConversationDetail(null));
    }
    @IsTest static void emptyDataFilterDoesNotDivideByZero() {
        ChatAnalyticsDashboardController.DashboardData none=ChatAnalyticsDashboardController.getDashboard(String.valueOf(Date.today().addDays(1)),null,null,null,null,null,null,null);
        System.assertEquals(0,none.summary.totalConversations); System.assertEquals(0,none.summary.averageConfidence); System.assertEquals(0,none.rows.size());
    }
}