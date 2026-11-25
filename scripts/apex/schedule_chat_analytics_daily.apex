// Schedules (or re-schedules) the daily Chat Analytics batch job in the target org.
// CronTrigger/scheduled-job state is runtime data, not deployable metadata, so this
// must be run once after deploying the metadata to a new org.
Id jobId = ChatAnalyticsScheduler.scheduleDaily();
System.debug('Scheduled ChatAnalyticsSchedulerDaily, CronTrigger Id: ' + jobId);
