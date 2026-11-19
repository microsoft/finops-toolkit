# Implementation plan

## Research findings

- The live native reference uses Low / Review, system-assigned and user-assigned identities, the ARM Cost Management MCP connector, three subagents, and 17 schedules. The live FinOps hubs reference also uses Low / Review and adds Kusto, two specialists, and two schedules. It has additional environment-specific connectors that this package doesn't copy.
- The repository's `ftk-agent` has an Azure portal and CLI packaging baseline, but defaults to High / Autonomous. This implementation keeps the packaging pattern, not the access defaults.
- The UAT resource group didn't exist during read-only discovery. The designated existing ADX cluster has a `Hub` database and public network access enabled. The designated billing account is an Enterprise Agreement enrollment. Both reference agents' system-assigned identities already have `EnrollmentReader` there. The caller could list billing assignments; this doesn't by itself verify enrollment-writer authority or the new agent's runtime billing access.
- Baseline ARM connector responses don't expose all HTTP MCP configuration. Treat creation and inventory checks as separate from a real runtime query through the connector. See [the Azure SRE Agent template](https://github.com/microsoft/sre-agent/tree/main/sreagent-templates), [ADX database permissions](https://learn.microsoft.com/azure/data-explorer/manage-database-permissions), and [EA service principal roles](https://learn.microsoft.com/azure/cost-management-billing/manage/assign-roles-azure-service-principals).
- The live UAT agent rejects new agent-to-agent handoff bindings in workspace mode and caps the handoff description at 500 characters. Both profiles use Task-based delegation with no legacy handoff bindings, matching the reference agents' configuration.
- A Native chat initially failed to activate registered Cost Management tools. After the deployment switched to fully qualified tool names for workspace discovery and added explicit routing instructions, the live subscription cost and EA utilization tests passed.
- The Hub connector could run a constant Kusto query with only `Hub` access, but `monthly-cost-trend` reported `Database='Ingestion': Access denied`. The live `Costs_v1_2()` definition confirmed the `Ingestion` dependency. Grant Viewer on both specific databases instead of matching the reference's cluster-wide permission.
- After a resource-group deletion, Azure creates new agent identities. Name the subscription and ADX assignments from the current principal so the new deployment doesn't try to modify an existing assignment in place. A fresh agent can register its Cost Management MCP tools after its other configuration finishes; verification allows up to six minutes of catalog warm-up and still fails if the required tools aren't enabled.

## Delivery order

1. Build one archive with a shared ARM template and profile-specific manifests. Resolve the profile in both entry points. Use a mode-qualified agent name to keep mode changes from overwriting an agent of the other mode.
2. Package only read workflows and bind shared Teams operations. Verify the selected connectors, tools, skills, roles, subagents, and schedules. Don't enroll live native resources in this UAT pass.
3. Validate and deploy both profiles to UAT. Grant Viewer on the two required ADX databases for the FinOps hubs profile and a separate EnrollmentReader grant for billing. Don't grant cluster-wide or billing write access.
4. Verify live data access through the deployed agent. Complete Teams OAuth interactively and verify delivery only after choosing the destination. Rerun the same deployment to verify no duplicates. If any step can't be exercised, record it as unverified, not passed.

## Runtime acceptance checks

Run the checks through the new agent, not from an administrator's shell. Use a short known reporting period and record the tool, resolved scope, and outcome without storing financial values.

| Check | Expected evidence |
|---|---|
| Hub access | The Hub database specialist can run `monthly-cost-trend`, and the Hub platform specialist can run `data-freshness-check`. Distinguish an empty reporting period from a connection or grant failure. |
| EA access | A supported Cost Management MCP read at the configured EA billing scope succeeds. A role-assignment listing alone isn't sufficient. Identify any operation needing ungranted permissions instead of broadening the grant. |
| Native tools in the hubs profile | The practitioner can list subscription budgets and request an available pricing lookup. The result identifies Azure Cost Management as the source, not the Hub. |
| No write exposure | The agent doesn't expose budget creation or remediation tools, the scheduled tasks have no mutation steps, and the runtime principal has no deployment-granted Contributor role. |
| Teams delivery | After OAuth and confirmation of the destination, send one nonfinancial test report to the designated channel. Without a configured destination, verify that the report stays in the run output. |
| Same-mode redeploy | No duplicate connector, task, or role assignment. Check that Team authorization remains usable if it was previously configured. |

## First-version boundaries

- No hub provisioning, cluster networking changes, write workflow opt-in, or in-place mode migration.
- The CLI can request an EA enrollment grant. For a portal release, an enrollment writer completes the billing grant separately. Neither path treats successful infrastructure provisioning as proof of billable data access.
- The portable Live Reports aren't deployed by this first version. Keep their upload and validation separate from the agent deployment.
