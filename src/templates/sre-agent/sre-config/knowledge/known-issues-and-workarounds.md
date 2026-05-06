# Known issues and workarounds for FinOps toolkit SRE Agent scheduled tasks

Use this guidance when executing scheduled tasks or investigating task execution failures. These issues were identified during UAT of all 9 scheduled tasks on April 28, 2026.

## 0. Source control and credential safety

**CRITICAL:** Fork pull requests are allowed when a scheduled task identifies a durable product improvement, but credentials must never be embedded in commands, remotes, transcript text, Teams posts, memory files, commit messages, or PR bodies.

Allowed source-control flow:
- Create commits only for repo-defined, reusable improvements such as query fixes, scheduled-task prompt fixes, knowledge corrections, or tool hardening.
- Push only to the configured fork repository. Do not push to the upstream Microsoft repository unless the user explicitly asks for that target.
- Open pull requests from the fork branch to the configured fork base branch.
- Use the configured GitHub connector, credential helper, or platform-provided repository credentials. Do not put tokens in `git remote set-url`, clone URLs, shell variables that are echoed, command arguments, or generated documentation.
- Personal access tokens (PATs) are forbidden. Do not create, request, store, paste, or use PATs for SRE Agent GitHub operations.

If push credentials are unavailable:
- Check once using a non-secret-bearing mechanism such as the configured GitHub connector status or `gh auth status` if available.
- If credentials are still unavailable, stop the PR path and report that the commit could not be pushed because no safe credential provider is configured.
- Do not loop over credential checks, scrape `git config` for token values, or ask the user to paste tokens into the thread.

Use the SRE Agent memory system for operational learnings:
- **`#remember`** — save discrete operational facts (e.g., "quota API requires az vm list-usage fallback")
- **`memories/synthesizedKnowledge/`** — the agent's persistent knowledge files, updated automatically after each session
- **Session insights** — automatically captured 30 minutes after a thread goes quiet
- **Teams channel** — the delivery destination for all financial reports and status results

The split is:
- **Financial data (costs, savings, forecasts, grades)** → Teams channel only. Never persist financial figures.
- **Operational learnings (tool errors, workarounds, patterns)** → `#remember` or synthesized knowledge. Never include dollar amounts.

## 1. Teams tool discovery and availability

**Symptom:** Subagents report "PostTeamsChannelMessage tool was not available," "PostTeamsMessage tool was not available," or "could not locate the Teams posting function."

**Cause:** Teams delivery depends on the Teams notification connector, its configured channel, and the Teams tools exposed in the current run. Scheduled-task entrypoint agents must list `PostTeamsMessage`, `ReplyToTeamsMessage`, and `GetTeamsMessages`. A run can still start without usable Teams delivery if no connector/channel is configured, or if configured connector delivery fails.

**Workaround:**
- Check available tools exactly once per run. Treat Teams delivery as available only when `PostTeamsMessage` is present.
- Do not call `PostTeamsMessage`, Microsoft Graph, `dynamicInvoke`, raw webhooks, or connector APIs just to probe availability.
- If no Teams connector/channel is configured and `PostTeamsMessage` is unavailable, finish the report in the run output, note that Teams delivery was unavailable, and do not retry or use alternate delivery paths.
- If a Teams connector/channel is configured, delivery through that configured Teams channel is mandatory. Use `PostTeamsMessage` for one final delivery attempt after the report is complete. If configured Teams delivery fails because the connector/tool is missing, unauthorized, unavailable, or otherwise unsuccessful, mark the task/run failed. Do not degrade to local output, do not mark the report as delivered, and do not retry.

**Status:** Prompt-level and tool-assignment guardrail. Production delivery remains the built-in `PostTeamsMessage` path when the connector/channel is configured.

## 2. Superseded data freshness conclusions

**Symptom:** Older memory, session notes, or raw KQL checks may claim FinOps Hub cost data is stale by months or about a year, even when a current `data-freshness-check` result shows recent `Costs()` data, such as Costs current through 2026-05-01.

**Cause:** The stale conclusions used historical memory, ad hoc raw KQL, partial report queries, or Kusto ingestion timestamp checks instead of the direct REST-backed data freshness tool. Those conclusions are historical observations, not a durable source of truth.

**Workaround:**
- Treat `data-freshness-check` as the authoritative source for hub data freshness because it queries `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()` directly through Azure Data Explorer REST.
- Treat `Costs()` as the primary freshness signal. If the latest `Costs()` data is 3 days old or newer, do not report the hub as stale and do not recommend stale-data remediation.
- Mark conflicting stale-memory, raw-KQL, or ingestion timestamp conclusions as superseded and unsafe unless revalidated by `data-freshness-check`.
- Only recommend export or pipeline remediation when `data-freshness-check` reports that `Costs()` has no rows, has a query error, or is more than 3 days old.
- Report empty `Prices()` or `Recommendations()` as follow-up checks, not as proof that the hub cost pipeline is stale. Report empty `Transactions()` with the `TRANSACTIONS_ZERO_ROWS` diagnostic described below.

**Status:** Superseded historical finding. Do not reuse stale-memory or raw-KQL freshness claims without revalidation from `data-freshness-check`.

## 2a. Transaction tool zero-row sentinel

**Symptom:** `top-other-transactions` or `top-commitment-transactions` returns the literal string `ZERO_ROWS_RETURNED`.

**Cause:** The Kusto tool found no rows for its filters, or the backing transaction-related dataset may be unavailable. A zero-row sentinel is not enough evidence to conclude there were no purchases when `Transactions()` has dropped to zero rows.

**Workaround:**
- Treat `ZERO_ROWS_RETURNED` as a completed tool call, not a parser error.
- Immediately run `data-freshness-check` and inspect `Transactions()` `row_count`, `schema_status`, and `diagnostic_code`.
- If `TRANSACTIONS_ZERO_ROWS` appears, report the export / ingestion / stored-function diagnostic as a data quality limitation.
- Only state that no matching transactions were found when the transaction diagnostics are clear.

**Status:** Expected sentinel plus required diagnostic follow-up for transaction reports.

## 2b. Raw full-month cost detail result truncation

**Symptom:** A scheduled report or ad hoc drill-down that runs `costs-enriched-base` over a full month can fail with Azure Data Explorer result truncation, including `E_QUERY_RESULT_SET_TOO_LARGE` or a 64 MB result-size message.

**Cause:** `costs-enriched-base` returns row-level enriched cost details. Full-month cost datasets can exceed Azure Data Explorer's default 500,000-record or 64 MB client result limits.

**Workaround:**
- Use aggregate Kusto tools for reporting windows: `monthly-cost-trend`, `cost-by-financial-hierarchy`, `top-services-by-cost`, `top-resource-groups-by-cost`, `top-resource-types-by-cost`, and related summary tools.
- Use `data-freshness-check` for freshness checks instead of raw cost detail queries.
- Use `costs-enriched-base` only after an aggregate result identifies a narrow drill-down scope. Keep the raw detail window to one day or less.
- Do not use `set notruncation` for scheduled reports. If bulk row export is required, use an explicit data export workflow instead of an agent report.

**Microsoft Learn references:**
- https://learn.microsoft.com/kusto/concepts/query-limits

**Status:** Tool-level guardrail and scheduled-task prompt guardrail.

## 3. Azure Resource Graph query failures

**Symptom:** `az graph query` returns "Unknown error" for complex queries. Orphaned resource detection and Resource Graph-based analysis fails.

**Cause:** The SRE Agent's managed identity may lack Resource Graph Reader permissions, or complex JMESPath queries fail due to shell escaping in the code interpreter environment.

**Workaround:**
- Tasks should fall back to scoped `az resource list` queries against specific subscriptions when Resource Graph fails.
- Ensure the agent managed identity has Reader at the management group or subscription scope.
- Simplify JMESPath queries — avoid backtick escaping that conflicts with the shell environment.

**Status:** Intermittent. Agents recover by trying alternative approaches.

## 4. Quota CLI command failures

**Symptom:** `az quota usage list` and `az vm list-usage` commands fail in the agent's execution environment.

**Cause:** The `az quota` extension may not be installed in the agent's code interpreter environment, or the managed identity lacks quota read permissions.

**Workaround:**
- Use `az vm list-usage --location <region>` as a fallback for compute quota — this uses the core Azure CLI.
- For comprehensive quota analysis, the capacity manager agent should use the Azure REST API directly via code interpreter.
- Consider adding a custom Kusto tool or Python tool for quota queries if CLI reliability remains poor.

**Status:** Known gap. The `Get-AzQuota.ps1` tool is on the UAT backlog.

## 5. JMESPath escaping in code interpreter

**Symptom:** JMESPath queries with special characters (backticks, brackets, dots in property names) fail when the agent constructs `az` CLI commands in the code interpreter.

**Cause:** Shell escaping conflicts between the Python code interpreter environment and JMESPath query syntax.

**Workaround:**
- Prefer `--output json` and parse with Python instead of using complex `--query` JMESPath expressions.
- When JMESPath is needed, use simple field selections only (e.g., `--query "[].{name:name, id:id}"`).
- Avoid nested JMESPath expressions with backtick-escaped property names.

**Status:** Platform limitation. Agents learn to work around it after the first failure.

## 6. Memory file write conflicts

**Symptom:** "File write failed: memory: <filename> - File already exists. You must use an edit tool."

**Cause:** When a scheduled task runs more than once in a session, it tries to create the same memory file again. The memory system does not allow overwriting with the create tool.

**Workaround:**
- Agents should use ReplaceStringInFile or an edit tool for subsequent writes to the same memory file.
- First run uses file creation; subsequent runs detect the conflict and switch to edit mode.
- This is self-healing — agents recover automatically after the first error.

**Status:** Expected behavior. Agents handle it correctly.

## 7. Kusto query errors

**Symptom:** "Error executing query on cluster" — specific KQL queries fail against the FinOps Hub ADX cluster.

**Cause:** Some Kusto tool queries reference functions or columns that don't exist in this Hub version, or the query syntax has version-specific issues.

**Workaround:**
- Agents should catch Kusto errors and try simplified queries.
- Check the Hub version (the HubsHealthCheck task does this) and ensure tool queries are compatible.
- Report the specific failing query in the task output so it can be fixed in the tool YAML.

**Status:** Some tools may need query updates for specific Hub versions.

## 8. Kusto REST authentication path

**Symptom:** Direct `az rest` calls to Azure Data Explorer query or management endpoints, such as `https://<cluster>.kusto.windows.net/v1/rest/query` or `/v2/rest/query`, fail even when the agent managed identity can read the Hub database through configured Kusto tools.

**Cause:** `az rest` is optimized for Azure Resource Manager calls and can acquire the wrong token audience for Azure Data Explorer data-plane endpoints. Cluster URIs can also include the Hub database path, which creates malformed query URLs if agents append `/v1/rest/query` or `/v2/rest/query` without normalizing the host.

**Workaround:**
- Use the configured FinOps Hub Kusto tools through the `finops-hub-kusto` connector for catalog queries.
- Use `data-freshness-check` for Hub data staleness and function coverage checks.
- If a direct fallback is required, use `execute_python` with `azure.identity.ManagedIdentityCredential` and `requests`. Request the `https://api.kusto.windows.net/.default` scope and POST JSON to `https://<cluster-host>/v2/rest/query` with `db` and `csl` fields.
- Never print, save, or echo bearer tokens. Do not use `az rest` for Kusto query or management endpoints.

**Microsoft Learn references:**
- https://learn.microsoft.com/kusto/api/rest/authentication?view=microsoft-fabric
- https://learn.microsoft.com/kusto/api/rest/request?view=microsoft-fabric

**Status:** Product guardrail. Prefer repository tools over ad-hoc CLI calls for FinOps Hub Kusto access.

## 9. Azure Data Explorer SKU not supported in target region

**Symptom:** A FinOps Hub deployment or upgrade fails in the nested `Microsoft.FinOpsHubs.Analytics` deployment with an Azure Data Explorer / Kusto validation error such as:

> The sku Standard_E4d_v5 is not supported in westus

**Cause:** Azure Data Explorer SKU eligibility is determined by the Microsoft.Kusto resource provider and can differ by Azure region and subscription. A VM size appearing in Microsoft.Compute SKU results does not prove that the equivalent Azure Data Explorer cluster SKU is eligible for Microsoft.Kusto in the target region.

**Workaround:**
- Before upgrading a Hub analytics backend or selecting a FinOps Hub Data Explorer SKU, run the `sku-availability` tool with `resource_provider: kusto`, the target `subscription_id`, target `location`, and the planned SKU in `sku_filter`.
- If `is_available` is `false`, choose one of the SKUs returned by the Microsoft.Kusto regional SKU API for that subscription and region, or deploy to a region where the requested SKU is returned.
- Do not infer ADX/Kusto SKU eligibility from `resource_provider: compute` results.

**Validation surfaces:**
- SRE Agent tool: `sku-availability` with `resource_provider: kusto`.
- ARM REST API: `GET /subscriptions/{subscriptionId}/providers/Microsoft.Kusto/locations/{location}/skus?api-version=2024-04-13`.
- PowerShell: `Get-AzKustoSku -SubscriptionId <subscription-id> -Location <region>` lists eligible region SKUs for the Kusto resource provider.
- Azure SDK: `KustoExtensions.GetSkus` / `Skus_List` uses the Microsoft.Kusto regional SKU request path.

**Microsoft Learn references:**
- https://learn.microsoft.com/powershell/module/az.kusto/get-azkustosku?view=azps-15.5.0
- https://learn.microsoft.com/dotnet/api/azure.resourcemanager.kusto.kustoextensions.getskus?view=azure-dotnet
- https://learn.microsoft.com/azure/data-explorer/manage-cluster-choose-sku

**Status:** Operational preflight requirement for FinOps Hub analytics deployments in regions where the planned ADX SKU may not be eligible.

## 9. Transactions() zero rows

**Symptom:** `Transactions()` drops from a previously populated row count to zero, or transaction tools return `ZERO_ROWS_RETURNED`.

**Cause:** The Hub `Transactions()` function is backed by the Cost Management `reservationtransactions` export, the Data Factory Transactions ingestion path, and the Hub `Transactions()` / `Transactions_v1_2()` stored functions. A zero-row result means one of those surfaces must be verified before concluding there were no reservation or savings plan transactions.

**Workaround:**
- Run `data-freshness-check` and inspect `row_count`, `schema_status`, and `diagnostic_code` for `Transactions()`.
- If the diagnostic is `TRANSACTIONS_ZERO_ROWS`, report it explicitly as a data quality action item. Do not summarize it as a generic empty table or a successful no-op.
- Ask the operator to verify Cost Management `reservationtransactions` exports and Azure Data Factory Transactions ingestion runs.
- If the schema diagnostic fails, treat it as a stored-function or Hub version compatibility issue instead of an export-only issue.

**Status:** Agent/tool hardening requirement. Scheduled reports must surface this as an explicit diagnostic and avoid false success.

## Summary of agent resilience

All 9 scheduled tasks completed despite encountering errors. Key resilience patterns observed:

| Pattern | Behavior |
|---------|----------|
| Stale data detection | All tasks flagged the March/April data gap prominently |
| CLI fallback chains | Agents tried alternative commands when primary approaches failed |
| Self-healing writes | Memory file conflicts resolved automatically by switching to edit |
| Graceful degradation | Reports were generated with available data, noting limitations |
| Teams delivery | All 9 tasks successfully posted final reports to the Teams channel |

## Microsoft Learn references

- https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications
- https://learn.microsoft.com/en-us/azure/sre-agent/tools
- https://learn.microsoft.com/en-us/azure/sre-agent/use-code-interpreter
- https://learn.microsoft.com/en-us/azure/sre-agent/scheduled-tasks
