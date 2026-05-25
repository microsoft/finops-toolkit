# FinOps toolkit SRE Agent knowledge document index

This document is the canonical index for the repository-provided knowledge base. It is also a deployment verification sentinel after `recipes/finops-hub/knowledge/` is uploaded as SRE Agent KnowledgeFile sources through `bin/post-provision.sh`.

## Document inventory

| Document | Purpose |
|---|---|
| `chart-artifact-verification.md` | Non-visual checks for validating chart artifacts in scheduled task outputs. |
| `document-index.md` | Index of repository-provided knowledge documents and verification sentinel for Knowledge Sources checks. |
| `ftk-output-style.md` | Shared FinOps Toolkit output style for evidence-backed financial and capacity-management reports. Uploaded from `src/templates/claude-plugin/output-styles/ftk-output-style.md`. |
| `known-issues-and-workarounds.md` | Operational issues, failure modes, and workarounds learned from scheduled task UAT. |
| `onboarding-recommendations.md` | First-run and connector setup guidance for teams deploying the FinOps toolkit SRE Agent. |
| `teams-notification-guide.md` | Correct Teams notification tool usage and delivery rules for scheduled reports. |

## Listing contract

- Knowledge files are uploaded by `bin/post-provision.sh` as portal-visible KnowledgeFile sources.
- `ftk-output-style.md` is uploaded by the same script from the Claude plugin output-style directory so scheduled tasks can apply one shared report style.
- If the knowledge index is not visible in the portal after upload, treat it as an upload visibility failure or an empty knowledge base.

## Source

- Repository source: `src/templates/sre-agent/recipes/finops-hub/knowledge/`
- Microsoft Learn source: https://learn.microsoft.com/azure/sre-agent/memory documents Azure SRE Agent knowledge base uploads and supported document usage.
