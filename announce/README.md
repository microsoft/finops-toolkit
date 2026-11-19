# Announcements

FinOps toolkit blog posts and announcements published to the [FinOps Tech Community blog](https://techcommunity.microsoft.com/tag/finops%20toolkit?nodeId=board%3AFinOpsBlog) and other channels. Used as a reference for tone, structure, and what's already been published.

## Folder layout

Files are organized by year, named `YYYY-MM_kebab-cased-name.md`. The name is usually the version (e.g., `v14`) for release announcements or a short topic for everything else.

```
announce/
├── 2025/
│   └── 2025-08_v12.md
└── 2026/
    ├── 2026-01_azure-openai-costs.md
    └── 2026-02_v13.md
```

## Creating a new announcement

Run `/announce` in Claude Code. Pass a topic (e.g., `/announce v14 release`) or invoke without arguments to have Claude scan the [changelog](../docs-mslearn/toolkit/changelog.md) and [recent blog posts](https://techcommunity.microsoft.com/tag/finops%20toolkit?nodeId=board%3AFinOpsBlog) to suggest the top candidates that haven't been announced yet.

The command walks through three phases:

1. **Discovery** — gather context from the changelog, MS Learn docs, and code (in that order), asking clarifying questions only when needed.
2. **Scoping** — propose an outline. Release announcements use a fixed structure documented in the command; other posts adapt based on the topic.
3. **Drafting** — write the post under `announce/{year}/`, including a short social media blurb appendix that links back to the published post.
