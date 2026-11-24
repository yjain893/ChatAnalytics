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
- **Agentforce Agent (prompt templates)**: the `Chat_Analytics_Agent` Bot, its 4 `GenAiPlannerBundle` versions (`Chat_Analytics_Agent_v1`–`v4`), and the matching `AiAuthoringBundle` Agent Script sources (`Chat_Analytics_Agent_1`–`_4`). This is where the actual prompt/topic instructions for analyzing chat transcripts live (`genAiPluginInstructions` / the `system.instructions` block in the `.agent` file), along with the agent graph and the `get_chat_conversation_context` local action wired to the `GetChatConversationContextAction` Apex class. `v4`/`_4` is the active version; `v1`–`v3`/`_1`–`_3` are retained as history. The CLI's source-format retrieve only decomposes the active bot version automatically — the `v1`–`v3` `BotVersion` files in this repo were reconstructed from the raw metadata API payload to preserve the full history.
- **CustomField**: `Account.Benefit_Tier__c`, `Account.PCNA_ID__c`, `Account.Sales_Tier__c` — standard-object fields that 3 of `Chatbot_Input__c`'s formula fields (`Benefit_Level__c`, `PCNA_ID__c`, `Sales_Tier__c`) reference via `ContactId__r.Account.*`. Included as a minimal dependency so those formulas deploy cleanly; the rest of `Account` is not part of this repo.

No Flows, Validation Rules, Workflow Rules, or custom metadata types (`__mdt`) were found tied to these 5 objects in the source org — the `Module_Parameter__mdt` and `Dashboard_User__mdt` records found during the search belong to unrelated features (a different chatbot's handoff text, and a sales dashboard recipient list) and were intentionally excluded. `Chatbot_Input__c` and `Chat_Survey__c` have no dedicated Custom Tab in the source org, and no standalone `GenAiPromptTemplate` records reference these objects.

### Note on validating with a dry-run deploy

Running `sf project deploy start --dry-run` **against the same `chatAnalyticsOrg` sandbox** will show ~41 expected failures: the scheduled Apex classes report pending/in-progress jobs, and `BotVersion v4` / `GenAiPlannerBundle v4` fail because that agent version is already active in that org. These are state conflicts from redeploying on top of the live source org, not metadata defects — 116+ other components validate cleanly, and a fresh target org (with no conflicting scheduled jobs or an already-active agent) will not hit them.

## Deploying to a new org

This repo deploys in **two steps**, because the Agent Script-based Bot needs its `AiAuthoringBundle` source deployed in the *same transaction* as the `Bot`/`GenAiPlannerBundle` metadata, or the deploy fails with "this agent... doesn't include its Agent Script source". Two manifests are provided for this:

- `manifest/package-deploy.xml` — everything except the agent (objects, fields, Apex, trigger, layouts, LWC, tabs, app, permission set, remote site setting, the 3 Account fields)
- `manifest/package-agent.xml` — the Bot + all GenAiPlannerBundle versions + all AiAuthoringBundle sources, deployed together
- `manifest/package.xml` — the full combined list, kept for documentation/reference (don't deploy with it directly — it hits the same Agent Script ordering issue as a single transaction)

```bash
# 1. Authenticate to the target org
sf org login web --alias targetOrg

# 2. Deploy everything except the agent
sf project deploy start --manifest manifest/package-deploy.xml --target-org targetOrg --dry-run
sf project deploy start --manifest manifest/package-deploy.xml --target-org targetOrg

# 3. Deploy the agent (Bot + GenAiPlannerBundle + AiAuthoringBundle together)
sf project deploy start --manifest manifest/package-agent.xml --target-org targetOrg --dry-run
sf project deploy start --manifest manifest/package-agent.xml --target-org targetOrg

# 4. Activate the agent (deployed bot versions are inactive by default)
sf agent activate --api-name Chat_Analytics_Agent --version 4 --target-org targetOrg
```

5. Confirm the `ChatAPi` remote site setting's endpoint is valid for the target environment, and assign the `Chat_Analytics_Access` permission set to the relevant users.
6. Run the included Apex test classes to validate the deployment:
   ```bash
   sf apex run test --target-org targetOrg --class-names ChatAnalyticsDashboardControllerTest \
     --class-names ChatAnalyticsNormalizedAnalyticsTest --class-names ChatAnalyticsOrchestrationTest \
     --class-names ChatAnalyticsProcessingTest --result-format human --wait 10 --code-coverage
   ```

### Deployed to `serviceOrg`

This exact procedure was run against the `serviceOrg` sandbox (`anuj.parashar@accionlabs.com.dev`, a sibling sandbox of the same `app-momentum-4398` org family as the source). All components deployed successfully (131/131 + 13/13), the `v4` agent version was activated, and all 15 included Apex tests passed (100%).

## Source org

- Alias: `chatAnalyticsOrg`
- Username: `anuj.parashar-cqec@force.com.pcna`
- Type: Sandbox
