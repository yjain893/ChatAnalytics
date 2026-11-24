public without sharing class ChatAnalyticsService {
    public static final String ANALYSIS_VERSION = 'v2-normalized-analytics';
    @TestVisible static ChatAnalyticsAgentProvider providerOverride;
    public static Boolean isEligible(Chat_Conversation__c conversation) {
        return conversation != null && conversation.Conversation_Status__c == 'Closed' && !String.isBlank(conversation.Transcript__c) && (conversation.Analysis_Status__c == 'Pending' || (conversation.Analysis_Status__c == 'Failed' && conversation.Analysis_Attempts__c != null && conversation.Analysis_Attempts__c < 3));
    }
    @TestVisible static void process(Id conversationId, ChatAnalyticsAgentProvider provider) {
        Claim claimed = claimForProcessing(conversationId);
        if (claimed == null) return;
        invokeClaimed(claimed, provider);
    }
    public static Claim claimForProcessing(Id conversationId) {
        Chat_Conversation__c claimed = claim(conversationId);
        return claimed == null ? null : new Claim(claimed.Id, claimed.Transcript_Hash__c);
    }
    public static void invokeClaimed(Claim claimed) {
        invokeClaimed(claimed, providerOverride == null ? new ChatAnalyticsAgentInvoker() : providerOverride);
    }
    @TestVisible static void invokeClaimed(Claim claimed, ChatAnalyticsAgentProvider provider) {
        if (claimed == null || !isCurrentClaim(claimed)) return;
        try {
            // This transaction intentionally performs no DML before Agentforce invocation.
            // The platform action returns UNKNOWN_EXCEPTION when invoked after uncommitted DML.
            ChatAnalyticsAgentInvoker.InvocationResult response = provider.invoke(claimed.conversationId);
            if (response == null || !response.success || response.structuredResponse == null) throw new ChatAnalyticsException(response == null ? 'Agentforce returned no response.' : response.errorMessage);
            persist(claimed.conversationId, claimed.transcriptHash, response);
        } catch (Exception error) { failIfCurrent(claimed.conversationId, claimed.transcriptHash, concise(error.getMessage())); }
    }
    private static Chat_Conversation__c claim(Id conversationId) {
        List<SObject> records = Database.queryWithBinds('SELECT Id, Conversation_Identifier__c, Conversation_Status__c, Transcript__c, Transcript_Hash__c, Analysis_Status__c, Analysis_Attempts__c FROM Chat_Conversation__c WHERE Id = :conversationId FOR UPDATE', new Map<String,Object>{'conversationId'=>conversationId}, AccessLevel.SYSTEM_MODE);
        if (records.isEmpty()) return null;
        Chat_Conversation__c conversation = (Chat_Conversation__c)records[0];
        if (!isEligible(conversation)) return null;
        Integer attempts = conversation.Analysis_Attempts__c == null ? 0 : Integer.valueOf(conversation.Analysis_Attempts__c);
        Database.update(new Chat_Conversation__c(Id=conversation.Id, Analysis_Status__c='Processing', Analysis_Attempts__c=attempts + 1), AccessLevel.SYSTEM_MODE);
        return conversation;
    }
    private static Boolean isCurrentClaim(Claim claimed) {
        List<SObject> records = Database.queryWithBinds('SELECT Id, Conversation_Status__c, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id = :conversationId', new Map<String,Object>{'conversationId'=>claimed.conversationId}, AccessLevel.SYSTEM_MODE);
        if (records.isEmpty()) return false;
        Chat_Conversation__c conversation = (Chat_Conversation__c)records[0];
        return conversation.Conversation_Status__c == 'Closed' && conversation.Analysis_Status__c == 'Processing' && conversation.Transcript_Hash__c == claimed.transcriptHash;
    }
    private static void persist(Id conversationId, String expectedHash, ChatAnalyticsAgentInvoker.InvocationResult result) {
        Chat_Conversation__c conversation = loadForPersistence(conversationId);
        if (conversation.Conversation_Status__c != 'Closed' || conversation.Transcript_Hash__c != expectedHash || conversation.Analysis_Status__c != 'Processing') {
            if (conversation.Conversation_Status__c == 'Closed' && conversation.Transcript_Hash__c != expectedHash) Database.update(new Chat_Conversation__c(Id=conversation.Id, Analysis_Status__c='Pending'), AccessLevel.SYSTEM_MODE);
            return;
        }
        Map<String,Object> value = result.structuredResponse;
        Chat_Analytics__c analytics = existingAnalytics(conversation.Conversation_Identifier__c);
        if (analytics == null) analytics = new Chat_Analytics__c(Conversation_Identifier__c=conversation.Conversation_Identifier__c);
        analytics.Chat_Conversation__c = conversation.Id;
        analytics.Customer_Problem__c = safeText(value.get('customerProblem'));
        analytics.Customer_Intent__c = safeText(value.get('customerIntent'));
        analytics.Bot_Resolution_Status__c = normalized(stringValue(value.get('botResolutionStatus')), new Set<String>{'Resolved','Partially Resolved','Not Resolved','Indeterminate'});
        analytics.Escalated_To_Human__c = booleanValue(value.get('escalatedToHuman'));
        analytics.Final_Resolution_By__c = normalized(stringValue(value.get('finalResolutionBy')), new Set<String>{'Bot','Human Agent','Unresolved','Indeterminate'});
        analytics.put('Issue_Category__c', normalizedOther(stringValue(value.get('issueCategory')), new Set<String>{'Order Status / Tracking','Returns / Refunds','Address / Order Change','Payment / Billing','Product / Service Information','Account / Login','Warranty / Support','Other'}));
        analytics.put('Escalation_Reason__c', analytics.Escalated_To_Human__c ? normalizedOther(stringValue(value.get('escalationReason')), new Set<String>{'Bot Could Not Resolve','Missing Knowledge / Information','Missing Transaction Capability','Policy / Authorization Required','Customer Requested Human','Repeated / Irrelevant Responses','No Escalation','Other'}) : 'No Escalation');
        analytics.put('Bot_Improvement_Opportunity__c', normalizedOther(stringValue(value.get('botImprovementOpportunity')), new Set<String>{'Knowledge / Content Gap','Intent Recognition','Missing Action / Automation','Response Quality','Conversation / Flow Design','Routing / Handoff','None','Other'}));
        analytics.put('Bot_Turns_Before_Escalation__c', botTurnsBeforeFirstHuman(conversation.Id));
        analytics.Bot_Failure_Reason__c = safeText(value.get('botFailureReason'));
        analytics.Analysis_Summary__c = safeText(value.get('analysisSummary'));
        analytics.Confidence__c = confidence(value.get('confidence'));
        analytics.Evidence__c = safeText(value.get('evidence'));
        analytics.Agent_Session_Id__c = result.sessionId;
        analytics.Analyzed_At__c = System.now(); analytics.Analysis_Version__c = ANALYSIS_VERSION;
        if (analytics.Id == null) Database.insert(analytics, AccessLevel.SYSTEM_MODE); else Database.update(analytics, AccessLevel.SYSTEM_MODE);
        Database.update(new Chat_Conversation__c(Id=conversation.Id, Analysis_Status__c='Completed', Last_Analyzed_At__c=System.now(), Last_Analysis_Error__c=null, Analysis_Version__c=ANALYSIS_VERSION), AccessLevel.SYSTEM_MODE);
    }
    private static Chat_Conversation__c loadForPersistence(Id conversationId) {
        return (Chat_Conversation__c)Database.queryWithBinds('SELECT Id, Conversation_Identifier__c, Conversation_Status__c, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id = :conversationId', new Map<String,Object>{'conversationId'=>conversationId}, AccessLevel.SYSTEM_MODE)[0];
    }
    private static Chat_Analytics__c existingAnalytics(String identifier) {
        List<SObject> records = Database.queryWithBinds('SELECT Id FROM Chat_Analytics__c WHERE Conversation_Identifier__c = :identifier', new Map<String,Object>{'identifier'=>identifier}, AccessLevel.SYSTEM_MODE);
        return records.isEmpty() ? null : (Chat_Analytics__c)records[0];
    }
    private static void failIfCurrent(Id conversationId, String expectedHash, String message) {
        List<SObject> records = Database.queryWithBinds('SELECT Id, Conversation_Status__c, Transcript_Hash__c, Analysis_Status__c FROM Chat_Conversation__c WHERE Id = :conversationId', new Map<String,Object>{'conversationId'=>conversationId}, AccessLevel.SYSTEM_MODE);
        if (records.isEmpty()) return;
        Chat_Conversation__c conversation = (Chat_Conversation__c)records[0];
        if (conversation.Conversation_Status__c == 'Closed' && conversation.Transcript_Hash__c == expectedHash && conversation.Analysis_Status__c == 'Processing') Database.update(new Chat_Conversation__c(Id=conversation.Id, Analysis_Status__c='Failed', Last_Analysis_Error__c=message), AccessLevel.SYSTEM_MODE);
    }
    private static String normalized(String value, Set<String> accepted) { return accepted.contains(value) ? value : 'Indeterminate'; }
    private static String normalizedOther(String value, Set<String> accepted) { return accepted.contains(value) ? value : 'Other'; }
    @TestVisible private static Integer botTurnsBeforeFirstHuman(Id conversationId) {
        Integer botTurns = 0; Boolean humanSeen = false;
        for (SObject record : Database.queryWithBinds('SELECT Participant_Role__c, Speaker__c FROM Chat_Message__c WHERE Chat_Conversation__c = :conversationId ORDER BY Source_Row_Number__c ASC NULLS LAST, Client_Timestamp__c ASC NULLS LAST, CreatedDate ASC', new Map<String,Object>{'conversationId'=>conversationId}, AccessLevel.SYSTEM_MODE)) {
            Chat_Message__c message = (Chat_Message__c)record;
            String role = message.Participant_Role__c == null ? '' : message.Participant_Role__c.toLowerCase();
            String speaker = message.Speaker__c == null ? '' : message.Speaker__c.toLowerCase();
            if (role == 'agent' || speaker == 'agent') { humanSeen = true; break; }
            if (role == 'chatbot' || speaker == 'chatbot') botTurns++;
        }
        return humanSeen ? botTurns : null;
    }
    private static Boolean booleanValue(Object value) { return value instanceof Boolean ? (Boolean)value : String.valueOf(value).toLowerCase() == 'true'; }
    private static Decimal confidence(Object value) { Decimal parsed; try { parsed = Decimal.valueOf(String.valueOf(value)); } catch (Exception ignored) { return 0; } return parsed < 0 ? 0 : (parsed > 1 ? 1 : parsed); }
    private static String stringValue(Object value) { return value == null ? null : String.valueOf(value); }
    private static String safeText(Object value) {
        String text = stringValue(value);
        if (String.isBlank(text)) return text;
        text = text.replaceAll('(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}', '[redacted email]');
        text = text.replaceAll('(?i)\\b[A-Z]{1,4}\\d{6,}\\b', '[redacted reference]');
        return text.replaceAll('(?<!\\w)\\+?\\d[\\d .()\\-]{6,}\\d(?!\\w)', '[redacted phone]');
    }
    private static String concise(String value) { return String.isBlank(value) ? 'Unknown Agentforce processing error.' : value.left(32000); }
    public class Claim {
        public Id conversationId { get; private set; }
        public String transcriptHash { get; private set; }
        public Claim(Id conversationId, String transcriptHash) { this.conversationId = conversationId; this.transcriptHash = transcriptHash; }
    }
    public class ChatAnalyticsException extends Exception {}
}