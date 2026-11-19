# FinOps toolkit SRE Agent deployment requirements

**Status:** Both profiles passed deployment UAT. Teams authorization and delivery are out of scope. See the [implementation plan](PLAN.md) for acceptance checks.

Build one self-contained release package that deploys one Azure SRE Agent. At deployment time, choose **Native Azure Cost Management** or **FinOps hubs** as the primary cost data source. Both profiles are maintained here. Optional [FinOps hubs Live Reports](live-reports/README.md) are available separately from agent deployment.

## Build and validate

From this directory, install Python with PyYAML and the Bicep CLI, then run:

```bash
python3 bin/build-package.py
python3 -m unittest discover -s tests
```

The build produces `dist/sre-agent-recipe.zip`, `dist/azuredeploy.json`, and `dist/createUiDefinition.json`. The ZIP contains the CLI, shared infrastructure template, applicator, and both resolved profiles. To deploy outside a repository checkout, extract `deploy.py` next to the ZIP and use Azure CLI and PowerShell 7:

```bash
python3 deploy.py --mode native --subscription <subscription-id> \
  --resource-group <agent-resource-group> --name <agent-base-name> \
  --location <region> --dry-run
```

Use `--validate` to ask Azure to validate without provisioning, or omit both validation flags to deploy. In `hubs` mode, pass `--cluster-uri` ending in `/Hub` and the matching `--cluster-resource-id`. Use `--subscription-reader` and `--subscription-cost-reader` only when the workflows need access across the deployment subscription. An enrollment writer can request the separate billing grant with `--ea-enrollment`.

If the CLI stops while Azure Resource Manager is still provisioning, run the same command with `--resume <deployment-name>`. The CLI checks the original parameters and waits for that deployment instead of starting another one.

Recreating a deleted agent gives it a new managed identity. Subscription and ADX assignments are named for the current identity so the deployment can create new grants without trying to update the old assignments. Resource group deletion doesn't clean up grants at subscription, ADX, or EA scopes. Review assignments to the retired identity separately before removing them.

For portal deployment, publish the three artifacts together using the release process and select **Cost data source** in the deployment form. The portal uses the same profile payloads and infrastructure. Complete any EA enrollment grant separately with an enrollment writer. For both entry points, the physical agent name is `<agent-base-name>-<mode>`.

## Compare live deployments

Use `bin/capture-evidence.py` to read a deployed agent and its reference. Supply the two agent resource IDs, the reference Teams connection name, the deployment subscription and name, and a local output path. The output includes the ARM deployment record, identity and access configuration, the live inventory, and a name-by-name diff. It excludes credentials, report bodies, and financial data. Store the report in the ignored `evidence/` folder.

Pass the exact deployment ZIP with `--package` and select `--profile native` or `--profile hubs` to also audit against the release. The audit checks for missing, unexpected, and duplicate items, enabled runtime tools, subagent bindings, schedule configuration, and tool permissions. It checks Teams bindings only, not authorization or delivery.

Compare inventory separately from runtime traces. Confirm which tools actually ran and which returned errors; a generated summary alone isn't proof of execution.

Use `bin/run-smoke.py` against a UAT agent to start a read-only test and capture a sanitized trace. Run it with `--agent-id`, `--mode`, `--enrollment`, and `--output`. The Native test requires successful tool records at the requested subscription and EA scopes. The `hub-probe` mode tests a fixed nonfinancial Kusto query; its marker alone doesn't prove financial data access. Teams delivery requires a separate authorized test.

## Deployment contract

- Expose the same required mode selector in the Azure portal and CLI (`native` or `hubs`). Reject missing or incompatible inputs before provisioning. Record the selected mode in the deployed configuration.
- Use one shared infrastructure and configuration pipeline for the agent, telemetry, runtime identity, role assignments, and post-deployment verification. Package both profiles, shared skills, prompts, knowledge, and tool definitions in one versioned release artifact. Builds use the [local profile sources](profiles/README.md) and the canonical repository query catalog and output style. Deployment doesn't need a source checkout, a sibling recipe, or a marketplace install.
- Share common configuration and keep mode-specific tools, task prompts, and data routing separate. The original deployed agents are comparison references, not dependencies.
- Keep same-mode redeployments idempotent. Verify the resulting configuration without duplicating schedules, connectors, or grants. Reject in-place mode switches in the first release instead of leaving stale configuration or silently removing resources.
- Deploy with **Low** access and **Review** action mode. Keep write tools and elevated roles out of the default profile. Scheduled workflows must be read-only by default; don't rely on interactive Review mode to protect unattended runs. Require an explicit opt-in and scoped permissions for any future write workflow.
- Configure Microsoft Teams consistently in both profiles. Complete OAuth interactively after deployment. If Teams isn't configured, return reports in the run output and identify delivery as unavailable. Don't package credentials or log financial data or access tokens.

## Mode requirements

| Requirement | Native Azure Cost Management (`native`) | FinOps hubs (`hubs`) |
|---|---|---|
| Primary cost evidence | Azure Cost Management through the Azure Resource Manager Model Context Protocol (MCP) connector. | Existing FinOps hub in Azure Data Explorer (ADX). Use the connector and catalog-backed queries for historical cost, allocation, savings, and fiscal reporting. |
| Required data connection | No hub inputs, Kusto connector, ADX grants, or hub-only schedules. | Require a database-qualified ADX URI and the resource ID needed for the grant. For UAT, resolve these from the supplied hub resource group or require explicit IDs if discovery is ambiguous. Don't create or upgrade the hub. |
| Native Azure operations | Cost, forecast, budget and alert inspection, pricing, Advisor, and capacity. | Keep native Azure tools where live budget, alert, pricing, billing, Advisor, or capacity evidence is required. Don't silently substitute native results for hub history. |
| Scheduled reporting | Use native cost windows supported by the connector. Report unavailable history instead of presenting short-window trends as year-over-year results. | Add hub health, data freshness, and monitoring-scope checks. Report incomplete ingestion or missing history as limitations, not zero spend. |

Both profiles share reporting conventions, configuration verification, and read-only governance and capacity workflows. Before carrying over optimization prompts, require owner and dependency validation for deletion candidates. The deployment doesn't delete or remediate workload resources.

## Identity and permissions

Resolve the principal for each operation. Keep the deployer or deployment-script identity separate from the agent runtime identity. Don't copy grants from a baseline without checking scope and need.

| Scope | Requirement |
|---|---|
| Azure resource and subscription scopes | Grant the agent runtime principal **Reader** and **Cost Management Reader** only at the scopes needed for the selected read workflows. Verify which identity Python tools actually use; don't grant a second identity access unless it needs it. |
| FinOps hub, `hubs` only | Grant the identity used by the Kusto connector [database `Viewer`](https://learn.microsoft.com/azure/data-explorer/manage-database-permissions) on `Hub` and `Ingestion`. Hub functions such as `Costs_v1_2()` read across database scope. The profile doesn't grant `AllDatabasesViewer`. ADX query permissions are separate from Azure resource discovery permissions. |
| Enterprise Agreement (EA) enrollment | For UAT, grant and verify read access at the designated enrollment for the principal that performs billing queries. Target [`EnrollmentReader`](https://learn.microsoft.com/azure/cost-management-billing/manage/assign-roles-azure-service-principals), not subscription Azure role-based access control. Use an enrollment writer for the assignment, verify that the supported billing assignment flow accepts the selected runtime principal, and test the required API with that principal. Don't grant purchasing access or silently substitute another identity if the grant fails. |

Create only missing grants at authorized scopes. Report access blocks by principal, role, and scope. If an enrollment writer must complete a grant separately, mark billing readiness as blocked until the grant and billing query are verified. If ADX network access prevents connectivity, report the blocker without changing firewall rules or enabling public access.

## Baseline and UAT plan

Keep concrete UAT identifiers in the ignored `uat.local.md` file. Don't use those values as product defaults or include them in the release artifact.

1. **Compare the baselines read-only.** Inventory the two reference agents' access mode, identities, connectors and selected operations, tool policies, skills, subagent handoffs, schedules, and relevant role scopes. Record what to keep, change, or omit. Don't modify either reference resource group or copy secrets or financial results.
2. **Verify both profiles locally.** Build and dry-run the portal and CLI profiles. Confirm the native profile excludes hub assets and the hubs profile rejects missing hub inputs. Check that enabled tasks reference tools available to their assigned agents and that neither default profile exposes unattended write actions.
3. **Deploy the hubs profile to UAT.** Use the new package's deployment entry point. Connect to the existing hub in the designated source resource group. Apply only the required grants to the new agent principal; don't change the source hub's configuration. Verify the selected profile, connector, grants, and schedules.
4. **Test as the runtime principal.** Run read-only smoke tests for hub cost data and freshness, EA billing access, and any native Cost Management operations included in the hubs profile. Record pass, blocked, or failed for each. Check report routing and verify Teams only after OAuth. A missing grant, unusable connector, or unauthorized billing query is not a pass.
5. **Validate redeployment.** Confirm a same-mode redeploy doesn't duplicate grants, connectors, or tasks. Keep live native deployment out of this UAT pass until a separate target or migration plan is specified.

Before deployment, resolve the reference agent names if either resource group contains more than one agent. Also resolve the new agent name, Azure region, ADX cluster resource ID and database URI, enrollment-writer availability, and optional Teams destination.
