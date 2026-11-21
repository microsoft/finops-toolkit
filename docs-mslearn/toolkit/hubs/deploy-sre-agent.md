---
title: Deploy Azure SRE Agent for FinOps
description: Deploy Azure SRE Agent to review costs and investigate changes by using Azure Cost Management or an existing FinOps hub.
author: MSBrett
ms.author: brettwil
ms.date: 11/19/2026
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
# customer intent: As a FinOps practitioner, I want to deploy Azure SRE Agent with my preferred cost data source so that I can investigate and review Azure costs.
---

# Tutorial: Deploy Azure SRE Agent for FinOps

Deploy [Azure SRE Agent](/azure/sre-agent/overview) to review spend, investigate cost changes, and run scheduled FinOps reviews. The FinOps toolkit template deploys one agent. At deployment, select **Azure Cost Management** or **FinOps hubs** as its primary cost data source. You don't need a hub to use Azure Cost Management.

## Prerequisites

- An Azure subscription and permission to deploy resources at subscription scope and create role assignments at the required scopes. For example, use the [Contributor](/azure/role-based-access-control/built-in-roles#contributor) and [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) roles at the applicable scopes. Use a [supported Azure SRE Agent region](/azure/sre-agent/supported-regions).
- For **FinOps hubs** only, an [existing FinOps hub](deploy.md) backed by Azure Data Explorer in the same Microsoft Entra tenant, with [configured scopes](configure-scopes.md) and ingested cost data. Gather the cluster resource ID and the query URI ending in `/Hub`. Make sure the agent can reach the cluster and that you can deploy role assignments in the cluster's resource group and grant database Viewer on `Hub` and `Ingestion`. The agent template doesn't create or upgrade your hub.
- The `azuredeploy.json` template and matching `sre-agent-recipe.zip`. To build the files from a FinOps toolkit source checkout that contains `src/templates/sre-agent`, install [Azure Bicep](/azure/azure-resource-manager/bicep/install), Python, and PyYAML. From `src/templates/sre-agent`, run:

  ```bash
  python3 bin/build-package.py
  ```

  The build writes the files to `dist/`. Host `sre-agent-recipe.zip` at an HTTPS URI the Azure deployment script can reach. If the file is private, use a short-lived, read-only [shared access signature](/azure/storage/common/storage-sas-overview) scoped to the blob. Allow enough time for Azure to complete the deployment.

## Deploy the agent template

1. Select [Deploy to Azure](https://portal.azure.com/#create/Microsoft.Template) to open **Deploy a custom template** in the Azure portal. This link opens the template editor workflow; it doesn't preselect the SRE Agent template. If the blade doesn't open, search for **Deploy a custom template** in the portal.
2. Select **Build your own template in the editor** > **Load file**, select the compiled `azuredeploy.json`, and then select **Save**.
3. On the **Basics** tab, select the deployment subscription and **Region**. For **Resource Group Name**, enter the resource group for the agent. Enter an **Agent Name** such as `finops-review` and a supported **Location** for the agent resources.

   :::image type="content" source="./media/deploy-sre-agent/agent-template-parameters.png" alt-text="Azure portal deployment form showing Resource Group Name, Agent Name, Location, Cost Source, Recipe Package Uri, and Apply Packaged Extras." lightbox="./media/deploy-sre-agent/agent-template-parameters.png" :::

4. Enter one of the following values in **Cost Source**:

   - **Azure Cost Management**. The agent queries Azure Cost Management through the Azure Resource Manager Model Context Protocol (MCP) connector.

     ```json
     { "mode": "native" }
     ```

   - **FinOps hubs**. The agent queries the existing hub in Azure Data Explorer for historical cost and allocation data. The profile also keeps the Azure Resource Manager MCP connector for live Azure operations. Replace both placeholders before deploying.

     ```json
     {
       "mode": "hubs",
       "clusterUri": "https://<cluster>.<region>.kusto.windows.net/Hub",
       "clusterResourceId": "<azure-data-explorer-cluster-resource-id>"
     }
     ```

5. In **Recipe Package Uri**, enter the HTTPS URI for `sre-agent-recipe.zip`. Leave **Apply Packaged Extras** set to `true` so the deployment applies the selected profile, including its connectors, tools, and schedules.
6. Enable **Enable Subscription Reader Role** or **Enable Subscription Cost Reader Role** only if the agent needs the corresponding read access across the deployment subscription. Otherwise, grant the agent's system-assigned managed identity read access at the scopes your workflows need. For the FinOps hubs profile, the template grants database Viewer on `Hub` and `Ingestion`, not on the entire cluster.
7. Select **Review + create**. Verify the subscription, resource group, and **Cost Source**, and then select **Create**.

   :::image type="content" source="./media/deploy-sre-agent/agent-template-review.png" alt-text="Review and create summary showing native mode and Apply Packaged Extras set to true. The recipe package URI is masked." lightbox="./media/deploy-sre-agent/agent-template-review.png" :::

8. Wait for **Your deployment is complete**. Expand **Deployment details** and confirm that `apply-extras` succeeded. The deployed agent name includes the selected mode, for example, `finops-review-native` or `finops-review-hubs`.

   :::image type="content" source="./media/deploy-sre-agent/agent-deployment-complete.png" alt-text="Azure portal status showing Your deployment is complete after deploying the agent template." :::

## Verify the deployment

1. Open [Azure SRE Agent](https://sre.azure.com/) and select the new agent. Confirm the expected connectors, tools, and scheduled tasks. The template configures read-only scheduled workflows and excludes resource write tools from the default profile.
2. Run a read-only query on demand:
   - With **Azure Cost Management**, compare costs for two complete days in one authorized subscription and verify the result in Cost Management.
   - With **FinOps hubs**, ask for the monthly cost trend for the most recent complete month with data. Verify that the result came from your hub. If the query returns no data or an access error, check ingestion and database permissions before interpreting the result as zero cost.
3. If you need Enterprise Agreement billing reads, have an enrollment writer assign [`EnrollmentReader`](/azure/cost-management-billing/manage/assign-roles-azure-service-principals) to the agent's billing-query identity at the enrollment scope. Subscription roles don't grant this access. Verify the requested billing read before scheduling it.

## Related content

- [Configure scopes for FinOps hubs](configure-scopes.md)
- [Configure and use AI agents](configure-ai.md)
- [Schedule tasks with Azure SRE Agent](/azure/sre-agent/scheduled-tasks)
