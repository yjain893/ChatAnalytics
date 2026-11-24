public without sharing class ChatConversationRefreshQueueable implements Queueable {
    private Set<Id> conversationIds;
    public ChatConversationRefreshQueueable(Set<Id> conversationIds) { this.conversationIds = conversationIds == null ? new Set<Id>() : conversationIds; }
    public void execute(QueueableContext context) { ChatTranscriptBuilder.refresh(conversationIds); }
}