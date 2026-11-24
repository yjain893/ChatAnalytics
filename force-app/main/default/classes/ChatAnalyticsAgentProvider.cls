public interface ChatAnalyticsAgentProvider {
    ChatAnalyticsAgentInvoker.InvocationResult invoke(Id conversationId);
}