# ChatAnalytics

Salesforce DX project containing the metadata for the Chatbot Conversation Analytics feature (Chat Analytics Dashboard, Chat Conversation, Chat Message, Chat Analytics, Chatbot Input, Chat Survey), retrieved from the `chatAnalyticsOrg` sandbox (`anuj.parashar-cqec@force.com.pcna`) so it can be deployed into a new org.

## What's included

Retrieved via `manifest/package.xml` (see that file for the exact list):

- **Custom Objects** (with all fields, list views): `Chat_Analytics__c`, `Chat_Conversation__c`, `Chat_Message__c`, `Chat_Survey__c`, `Chatbot_Input__c`
- **Page Layouts** for all five objects
- **Apex Classes**: orchestration/service layer for the analytics pipeline
  - `ChatAnalyticsOrchestrator`, `ChatAnalyticsService`, `ChatAnalyticsQueueable`, `ChatAnalyticsInvocationQueueable`, `ChatAnalyticsScheduler`
  - `ChatAnalyticsAgentInvoker`, `ChatAnalyticsAgentProvider`, `ChatAnalyticsSystemContextProbe` (Agentforce/LLM integration)
  - `ChatAnalyticsDashboardController` (+ test) — powers the LWC dashboard
  - `ChatAnalyticsHistoricalImportFinalizer`, `ChatMessageSystemImporter`, `ChatTranscriptBuilder`, `ChatConversationRefreshQueueable`
  - `ChatMessageTriggerHandler`, `GetChatConversationContextAction`
  - Test classes: `ChatAnalyticsNormalizedAnalyticsTest`, `ChatAnalyticsOrchestrationTest`, `ChatAnalyticsProcessingTest`
- **Apex Trigger**: `ChatMessageTrigger` (on `Chat_Message__c`)
- **Lightning Web Component**: `chatAnalyticsDashboard` (the dashboard shown at `/lightning/n/Chat_Analytics_Dashboard`)
- **Custom Tabs**: `Chat_Analytics_Dashboard`, `Chat_Analytics__c`, `Chat_Conversation__c`, `Chat_Message__c`
- **Custom Application**: `Chat_Analytics`
- **Permission Set**: `Chat_Analytics_Access`
- **Remote Site Setting**: `ChatAPi` (external API callout used by the analytics/Agentforce integration — verify the endpoint/credential before deploying to a new org)

No Flows, Validation Rules, or Workflow Rules were found attached to these objects in the source org, so none are included. `Chatbot_Input__c` and `Chat_Survey__c` have no dedicated Custom Tab in the source org.

## Deploying to a new org

1. Authenticate to the target org:
   ```bash
   sf org login web --alias targetOrg
   ```
2. Validate/deploy using the manifest:
   ```bash
   sf project deploy start --manifest manifest/package.xml --target-org targetOrg --dry-run
   sf project deploy start --manifest manifest/package.xml --target-org targetOrg
   ```
3. Confirm the `ChatAPi` remote site setting's endpoint is valid for the target environment, and assign the `Chat_Analytics_Access` permission set to the relevant users.
4. Run the included Apex test classes (`ChatAnalyticsDashboardControllerTest`, `ChatAnalyticsNormalizedAnalyticsTest`, `ChatAnalyticsOrchestrationTest`, `ChatAnalyticsProcessingTest`) to validate the deployment:
   ```bash
   sf apex run test --target-org targetOrg --code-coverage --result-format human --synchronous
   ```

## Source org

- Alias: `chatAnalyticsOrg`
- Username: `anuj.parashar-cqec@force.com.pcna`
- Type: Sandbox
