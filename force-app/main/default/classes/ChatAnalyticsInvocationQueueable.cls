public without sharing class ChatAnalyticsInvocationQueueable implements Queueable, Database.AllowsCallouts {
    private ChatAnalyticsService.Claim claim;
    private List<Id> remainingConversationIds;
    public ChatAnalyticsInvocationQueueable(ChatAnalyticsService.Claim claim, List<Id> remainingConversationIds) {
        this.claim = claim;
        this.remainingConversationIds = remainingConversationIds == null ? new List<Id>() : new List<Id>(remainingConversationIds);
    }
    public void execute(QueueableContext context) {
        ChatAnalyticsService.invokeClaimed(claim);
        if (!remainingConversationIds.isEmpty()) System.enqueueJob(new ChatAnalyticsQueueable(remainingConversationIds));
    }
}