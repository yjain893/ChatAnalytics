public without sharing class ChatAnalyticsQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> conversationIds;
    public ChatAnalyticsQueueable(List<Id> conversationIds) { this.conversationIds = conversationIds == null ? new List<Id>() : new List<Id>(conversationIds); }
    public void execute(QueueableContext context) {
        if (conversationIds.isEmpty()) return;
        Id conversationId = conversationIds.remove(0);
        ChatAnalyticsService.Claim claim = ChatAnalyticsService.claimForProcessing(conversationId);
        if (claim == null) {
            if (!conversationIds.isEmpty()) System.enqueueJob(new ChatAnalyticsQueueable(conversationIds));
            return;
        }
        System.enqueueJob(new ChatAnalyticsInvocationQueueable(claim, conversationIds));
    }
}