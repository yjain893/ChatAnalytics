public without sharing class ChatAnalyticsScheduler implements Schedulable {
    public static final String CRON = '0 0 1 * * ?';
    public void execute(SchedulableContext context) { ChatAnalyticsOrchestrator.enqueueEligible(ChatAnalyticsOrchestrator.MAX_DAILY_ENQUEUES); }
    public static String scheduleDaily() {
        for (CronTrigger existing : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'ChatAnalyticsSchedulerDaily' AND State != 'DELETED']) System.abortJob(existing.Id);
        return System.schedule('ChatAnalyticsSchedulerDaily', CRON, new ChatAnalyticsScheduler());
    }
}