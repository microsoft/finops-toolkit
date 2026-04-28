# Known issues and workarounds for FinOps SRE Agent scheduled tasks

Use this guidance when executing scheduled tasks or investigating task execution failures. These issues were identified during UAT of all 9 scheduled tasks on April 28, 2026.

## 1. Teams tool discovery

**Symptom:** Subagents report "PostTeamsChannelMessage tool wasn't available" or "couldn't locate the Teams posting function."

**Cause:** When invoked via `srectl thread new --agent <subagent>`, the subagent does not inherit the Teams connector tools. The connector tools (PostTeamsMessage, ReplyToTeamsThread, GetTeamsMessages) are only available to the base agent or when the platform triggers a scheduled task.

**Workaround:**
- Scheduled tasks triggered by the platform cron schedule have full access to connector tools — this is the production path.
- For manual testing, invoke from the base agent (no `--agent` flag) and use `@subagent` delegation in the prompt.
- Always use the built-in `PostTeamsMessage` tool name — do NOT call Graph API or dynamicInvoke endpoints directly (results in 403).

**Status:** Platform behavior, not a bug. Documented for operator awareness.

## 2. Data pipeline freshness gap

**Symptom:** Tasks report March 2026 data is incomplete (~17 of 31 days) and April 2026 returns zero rows. Forecasting models produce distorted projections.

**Cause:** The Cost Management export pipeline has been broken since mid-March 2026. The FinOps Hub ADX cluster has stale data.

**Workaround:**
- Tasks should detect stale data and flag it prominently in the report (all 9 tasks did this correctly).
- The HubsHealthCheck task specifically checks data freshness and recommends investigating the export pipeline.
- Fix the actual pipeline: check Cost Management exports at https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/exports and ADF pipelines at https://adf.azure.com/monitoring/pipelineruns

**Status:** Environment issue, not an agent bug. Tasks handle it gracefully.

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
