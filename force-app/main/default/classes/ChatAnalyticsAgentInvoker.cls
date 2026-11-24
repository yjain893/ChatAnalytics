public without sharing class ChatAnalyticsAgentInvoker implements ChatAnalyticsAgentProvider {
    private static final String AGENT_LABEL = 'Chat Analytics Agent';
    public class InvocationResult {
        public Boolean success;
        public String sessionId;
        public Map<String, Object> structuredResponse;
        public String errorMessage;
        public Map<String, Object> rawOutputs;
        public Boolean usedMessageJsonFallback;
    }
    public InvocationResult invoke(Id conversationId) {
        InvocationResult output = new InvocationResult();
        try {
            Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', null, discoverPublishedAgentApiName(), '1.1.0');
            action.setInvocationParameter('userMessage', 'Analyze Chat Conversation Salesforce record Id: ' + conversationId + '. Retrieve the prepared closed conversation using Get Chat Conversation Context and return the required structured chat analytics.');
            List<Invocable.Action.Result> results = action.invoke();
            if (results.isEmpty() || !results[0].isSuccess()) { output.success = false; output.errorMessage = results.isEmpty() ? 'Agentforce returned no invocation result.' : String.valueOf(results[0].getErrors()); return output; }
            output.rawOutputs = results[0].getOutputParameters();
            output.sessionId = stringValue(output.rawOutputs.get('sessionId'));
            output.structuredResponse = mapValue(output.rawOutputs.get('structuredAgentResponse'));
            if (output.structuredResponse == null) {
                Map<String, Object> envelope = mapValue(output.rawOutputs.get('agentResponse'));
                Map<String, Object> value = envelope == null ? null : mapValue(envelope.get('value'));
                output.structuredResponse = value == null ? null : mapValue(value.get('message'));
                output.usedMessageJsonFallback = output.structuredResponse != null;
            }
            if (output.structuredResponse == null) { output.success = false; output.errorMessage = 'Agentforce did not return structuredAgentResponse. Outputs: ' + output.rawOutputs.keySet(); }
            else output.success = true;
        } catch (Exception error) { output.success = false; output.errorMessage = error.getTypeName() + ': ' + error.getMessage(); }
        return output;
    }
    @TestVisible private static String discoverPublishedAgentApiName() {
        List<GenAiPlannerDefinition> planners = [SELECT DeveloperName FROM GenAiPlannerDefinition WHERE MasterLabel = :AGENT_LABEL ORDER BY CreatedDate DESC LIMIT 1];
        if (planners.isEmpty()) throw new ChatAnalyticsException('No published Agentforce planner was found for ' + AGENT_LABEL + '.');
        String plannerName = planners[0].DeveloperName;
        Integer versionMarker = plannerName.lastIndexOf('_v');
        return versionMarker > 0 ? plannerName.substring(0, versionMarker) : plannerName;
    }
    private static String stringValue(Object value) { return value == null ? null : String.valueOf(value); }
    @TestVisible private static Map<String, Object> mapValue(Object value) {
        if (value == null) return null;
        if (value instanceof Map<String, Object>) return (Map<String, Object>)value;
        if (value instanceof String) { try { Object parsed = JSON.deserializeUntyped((String)value); return parsed instanceof Map<String, Object> ? (Map<String, Object>)parsed : null; } catch (Exception ignored) { return null; } }
        return null;
    }
    public class ChatAnalyticsException extends Exception {}
}