# FinOps toolkit SRE Agent knowledge document index

This document is the canonical index for the repository-provided knowledge base. It is also a deployment verification sentinel: after `sre-config/knowledge/` is uploaded, `srectl doc get` must list `document-index.md`.

## Document inventory

| Document | Purpose |
|---|---|
| `chart-artifact-verification.md` | Non-visual checks for validating chart artifacts in scheduled task outputs. |
| `document-index.md` | Index of repository-provided knowledge documents and verification sentinel for document-list checks. |
| `known-issues-and-workarounds.md` | Operational issues, failure modes, and workarounds learned from scheduled task UAT. |
| `onboarding-recommendations.md` | First-run and connector setup guidance for teams deploying the FinOps toolkit SRE Agent. |
| `teams-notification-guide.md` | Correct Teams notification tool usage and delivery rules for scheduled reports. |

## Listing contract

- `srectl doc get` is the documented CLI command for listing uploaded knowledge documents.
- `srectl doc search --query ...` searches document contents and is not a reliable replacement for listing uploaded documents.
- If `srectl doc get` returns no output after post-provision upload, treat it as an upload visibility failure or an empty knowledge base, not as evidence that a different document-list command is required.

## Source

- Repository source: `src/templates/sre-agent/sre-config/knowledge/`
- Local CLI source: `srectl doc --help` and `srectl doc get --help` describe `doc get` as "List uploaded documents".
- Microsoft Learn source: https://learn.microsoft.com/azure/sre-agent/memory documents Azure SRE Agent knowledge base uploads and supported document usage.
