---
title: Deploy Azure SRE Agent with the FinOps toolkit
description: Deploy the FinOps toolkit's Azure SRE Agent template, connect it to FinOps hubs, and configure notifications for scheduled cost and capacity reports.
author: msbrett
ms.author: brettwil
ms.date: 05/06/2026
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to deploy and configure the FinOps toolkit's Azure SRE Agent so that I can receive scheduled cost reports, anomaly detection, and capacity monitoring.
---

<!-- markdownlint-disable heading-increment MD024 -->

# Deploy Azure SRE Agent with the FinOps toolkit

In this tutorial, you learn how to deploy the [FinOps toolkit's Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent), connect it to a [FinOps hub](../hubs/finops-hubs-overview.md), and configure notifications for scheduled cost and capacity reports. This article helps you:

<!-- prettier-ignore-start -->
> [!div class="checklist"]
> - Apply the prerequisites. <!-- markdownlint-disable-line MD032 -->
> - Deploy the agent with Azure Developer CLI.
> - Verify the agent configuration.
> - Configure Microsoft Teams and Outlook notifications.
> - Validate post-provision configuration with dry-run mode.
<!-- prettier-ignore-end -->

<br>

## Prerequisites

- [Deployed a FinOps hub instance](../hubs/finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](../hubs/configure-scopes.md) and ingested data successfully.
- An Azure subscription where you have the **Owner** or **User Access Administrator** role. [Learn more](/azure/role-based-access-control/built-in-roles).
- The `Microsoft.App` resource provider [registered](/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) on the subscription.
- [Azure Developer CLI (`azd`)](/azure/developer/azure-developer-cli/install-azd) 1.9 or later.
- [Azure CLI](/cli/azure/install-azure-cli) 2.60 or later.
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) for [`srectl`](/azure/sre-agent/tools).
- `python3` and `bash` available locally for the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts).
- For zone mapping: The `AvailabilityZonePeering` feature must be registered on the subscription. Register it at the management group level if the agent manages capacity across multiple subscriptions.

  ```bash
  az feature register --namespace Microsoft.Resources --name AvailabilityZonePeering
  az provider register --namespace Microsoft.Resources
  ```

<br>

## Deploy the agent

The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts) creates the [Azure Developer CLI (`azd`)](/azure/developer/azure-developer-cli/overview) environment, sets required values, and runs `azd up`.

### [Bash](#tab/bash)

```bash
cd src/templates/sre-agent

bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --subscription <subscription-id> \
  --finops-hub-cluster-uri https://<your-cluster>.kusto.windows.net
```

### [PowerShell](#tab/powershell)

```powershell
cd src/templates/sre-agent

pwsh ./scripts/deploy.ps1 `
  -Environment <environment-name> `
  -Subscription <subscription-id> `
  -FinopsHubClusterUri https://<your-cluster>.kusto.windows.net
```

---

Replace `<environment-name>` with a name for your deployment, such as `ftk-sre-prod`; `<subscription-id>` with the Azure subscription that hosts the agent; and `<your-cluster>` with your FinOps hub Data Explorer cluster hostname.

The deployment script:

1. Creates or selects an `azd` environment.
2. Sets the `az` CLI context to the target subscription.
3. Runs `azd up`, which deploys Bicep infrastructure and starts the `postprovision` hook from [`azure.yaml`](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/azure.yaml).
4. Installs [`srectl`](/azure/sre-agent/tools), then applies the FinOps skills, agents, tools, knowledge documents, and scheduled tasks.

The template deploys one Azure SRE Agent in autonomous mode, a user-assigned managed identity, Log Analytics, Application Insights, subscription RBAC assignments, FinOps and capacity subagents, FinOps skills, Kusto tools, scheduled tasks, knowledge documents, and, when `finopsHubClusterUri` is provided, a Bicep-created Kusto connector to your FinOps hub.

<br>

## Verify the deployment

After `azd up` completes, verify the deployment before configuring notifications.

1. Confirm the ARM deployment succeeded and the `postprovision` hook completed without errors.
2. Open [sre.azure.com](https://sre.azure.com), switch to the directory that contains your subscription, and select your agent.
3. Confirm the FinOps subagents, skills, tools, and `finops-hub-kusto` connector appear in **Builder**.
4. Go to **Scheduled tasks** and confirm tasks are listed and active.
5. Ask the agent: `What knowledge documents do you have?`
6. Confirm the base agent has workspace tools and visualization enabled.
7. If you enabled the Data Explorer role assignment, confirm the target cluster shows an `AllDatabasesViewer` principal assignment for the agent managed identity.

> [!TIP]
> If [sre.azure.com](https://sre.azure.com) shows the agent correctly but `srectl` returns `401`, `403`, or `Forbidden: Access denied by PDP`, confirm the active Azure CLI context points to the subscription that owns the SRE Agent resource. Browser success with CLI failure usually means the CLI token was issued for the wrong tenant.

<br>

## Configure notifications

Scheduled tasks can send reports to Microsoft Teams and Outlook through Azure SRE Agent notification connectors. Connectors require interactive OAuth setup in [sre.azure.com](https://sre.azure.com), so `azd up` and the post-provision scripts don't create them.

### Configure Teams

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Send notification (Microsoft Teams)**.
3. Sign in with your Microsoft 365 account.
4. Paste the channel URL from **Get link to channel** in Teams.
5. Select the agent's managed identity and save.
6. Test from chat: `Post a test message to our Teams channel saying "Azure SRE Agent connected via the FinOps toolkit."`

Use the built-in `PostTeamsMessage` tool from the [Teams notification guidance](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/sre-config/knowledge/teams-notification-guide.md). Don't call the Microsoft Graph API or the connection's `dynamicInvoke` endpoint directly because that path returns a 403 error for this connector configuration.

### Configure Outlook

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Outlook Tools (Office 365 Outlook)**.
3. Sign in with a Microsoft 365 account that has mailbox access.
4. Select the agent's managed identity and save.
5. Test from chat: `Send an email to <recipient> with subject "SRE Agent test" and body "Outlook connector is working."`

For more information, see [Send notifications in Azure SRE Agent](/azure/sre-agent/send-notifications).

<br>

## Dry-run validation

Use dry-run mode to validate post-provision configuration before applying it to an agent. Dry-run mode logs the skills, subagents, tools, knowledge documents, and scheduled tasks that would be applied. It doesn't validate the endpoint, install `srectl`, call Azure CLI, initialize `srectl`, or apply changes.

### [Bash](#tab/bash)

```bash
cd src/templates/sre-agent

bash ./scripts/post-provision.sh --dry-run
```

### [PowerShell](#tab/powershell)

```powershell
cd src/templates/sre-agent

pwsh ./scripts/post-provision.ps1 -DryRun
```

---

Use dry-run mode when you change template configuration or want to confirm local prerequisites before running `azd up`.

<br>

## Grant the ADX viewer role

The agent can query your FinOps hub through the Kusto connector. To grant the agent's managed identity the `AllDatabasesViewer` role on your Azure Data Explorer (ADX) cluster, add the optional cluster parameters during deployment.

### [Bash](#tab/bash)

```bash
bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --subscription <subscription-id> \
  --finops-hub-cluster-uri https://<your-cluster>.kusto.windows.net \
  --finops-hub-cluster-name <adx-cluster-name> \
  --finops-hub-cluster-resource-group <adx-resource-group>
```

### [PowerShell](#tab/powershell)

```powershell
pwsh ./scripts/deploy.ps1 `
  -Environment <environment-name> `
  -Subscription <subscription-id> `
  -FinopsHubClusterUri https://<your-cluster>.kusto.windows.net `
  -FinopsHubClusterName <adx-cluster-name> `
  -FinopsHubClusterResourceGroup <adx-resource-group>
```

---

The Data Explorer role assignment is optional. Use it when you want deployment to grant query access to the FinOps hub cluster automatically.

<br>

## Replace or destroy an environment

Use the deployment script to replace or destroy local `azd` environments and deployed Azure resources.

### Replace an environment

Use replace when the deployed environment is in a known-good state but you want to redeploy with current template defaults, fix a drifted resource, or apply parameter changes. Replace removes the existing Azure resources and the local `azd` environment, then deploys again with the same parameters.

### [Bash](#tab/bash)

```bash
bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --clone-env <existing-environment> \
  --replace
```

### [PowerShell](#tab/powershell)

```powershell
pwsh ./scripts/deploy.ps1 `
  -Environment <environment-name> `
  -CloneEnv <existing-environment> `
  -Replace
```

---

Use `--replace` or `-Replace` to delete Azure resources for the target environment, remove the local `azd` environment, and deploy again.

### Destroy an environment

Use destroy when you want to tear down a deployment without redeploying, for example to clean up a test environment or release subscription quota. Destroy removes the Azure resources and the local `azd` environment without redeploying.

### [Bash](#tab/bash)

```bash
bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --destroy
```

### [PowerShell](#tab/powershell)

```powershell
pwsh ./scripts/deploy.ps1 `
  -Environment <environment-name> `
  -Destroy
```

---

Use `--destroy` or `-Destroy` to delete Azure resources and remove the local `azd` environment without redeploying.

<br>

## Supported regions

The agent supports deployment to these Azure regions:

- `australiaeast`
- `eastus2`
- `swedencentral`

The Bicep template restricts the `location` parameter to these regions.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)
- [Azure Developer CLI](/azure/developer/azure-developer-cli/overview)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Configure AI agents for FinOps hubs](../hubs/configure-ai.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)

<br>
