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
- **Agentforce Agent (prompt templates)**: the `Chat_Analytics_Agent` Bot and its 4 `GenAiPlannerBundle` versions (`Chat_Analytics_Agent_v1`–`v4`). This is where the actual prompt/topic instructions for analyzing chat transcripts live (`genAiPluginInstructions` in each bundle), along with the agent graph, agent script, and the `get_chat_conversation_context` local action wired to the `GetChatConversationContextAction` Apex class. `v4` is the active version; `v1`–`v3` are retained as history. The CLI's source-format retrieve only decomposes the active bot version automatically — the `v1`–`v3` `BotVersion` files in this repo were reconstructed from the raw metadata API payload to preserve the full history.

No Flows, Validation Rules, Workflow Rules, or custom metadata types (`__mdt`) were found tied to these 5 objects in the source org — the `Module_Parameter__mdt` and `Dashboard_User__mdt` records found during the search belong to unrelated features (a different chatbot's handoff text, and a sales dashboard recipient list) and were intentionally excluded. `Chatbot_Input__c` and `Chat_Survey__c` have no dedicated Custom Tab in the source org, and no standalone `GenAiPromptTemplate` records reference these objects.

### Note on validating with a dry-run deploy

Running `sf project deploy start --dry-run` **against the same `chatAnalyticsOrg` sandbox** will show ~41 expected failures: the scheduled Apex classes report pending/in-progress jobs, and `BotVersion v4` / `GenAiPlannerBundle v4` fail because that agent version is already active in that org. These are state conflicts from redeploying on top of the live source org, not metadata defects — 116+ other components validate cleanly, and a fresh target org (with no conflicting scheduled jobs or an already-active agent) will not hit them.

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
