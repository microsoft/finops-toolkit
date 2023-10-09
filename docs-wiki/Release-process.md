<!-- markdownlint-disable MD041 -->

The following outlines the release process after all work is completed and merging a feature brach to `dev` for the next release or when merging `dev` to `main` for a public release.

On this page:

- [🌿 Promoting a feature branch](#-promoting-a-feature-branch)
- [📜 Changelog guidance](#-changelog-guidance)

---

## 🌿 Promoting a feature branch

When a feature branch is code-complete, it can be merged into `dev`. Before proceeding, ensure the following requirements have been met:

1. All tests pass.
   > _The PR will be blocked if they don't._
2. Any new features are code complete and not missing any functionality required for release.
   > _Once in `dev`, the feature is considered part of the next release and can be pushed out at any time. Any broken features will be reverted._
3. All new or updated functionality must be documented in the [changelog](https://github.com/microsoft/finops-toolkit/blob/dev/docs/changelog.md).
   > _See [Changelog guidance](#-changelog-guidance) for details about changelog requirements._
4. All new or updated functionality must be documented in the [documentation](https://github.com/microsoft/finops-toolkit/blob/dev/docs).
5. Update the [list of available tools](https://github.com/microsoft/finops-toolkit/tree/dev/docs#-available-tools) on the documentation home page.

<br>

## 📜 Changelog guidance

Our changelog is written for our customers, not developers. It should be easy to read and understand and should not include any technical details. It should be written in a way that a customer can read it and understand what's new in the release without requiring any additional context or internal details about how solutions were designed or built.

We follow a simplified version of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Specifically:

- Every major, customer-impacting change should be called out in the changelog.
- Unreleased features are in an "Unreleased" section, which is at the top of the changelog.
  - This is typically only available in `dev` and is generally not released to the public documentation.
  - Before we release, we rename "Unreleased" to the desired version number.
- Each version should be in its own section, formatted as `vX.X` (e.g., `v0.1`) and prepended with an emoji to indicate the type of release:
  - 🚀 for major releases (e.g., 2.0).
  - 🚚 for minor releases (e.g., 1.1).
  - 🛠️ for patch releases (e.g., 1.0.1).
  - 🪛 for update releases (e.g., 1.0.0-preview.2).
- Changes within a version should be grouped into one of the following sections (in order):
  <!-- Consider icons: ➕✏️✖️🗑️🛠️🔒 -->
  - `Added` for new features.
  - `Changed` for changes in existing functionality.
  - `Deprecated` for soon-to-be removed features.
  - `Removed` for now removed features.
  - `Fixed` for any bug fixes.
  - `Security` in case of vulnerabilities.
- Within each section, create a numbered list of the tool that changed (e.g., FinOps hubs, cost optimization workbook).
- Under each tool bullet, add a numbered list of all changes of that type to that tool.
  - Keep updates short and to the point. Limit to one line.
  - Link to the documentation, when applicable.
  - Link to issues, when available.
- Below the list of changes, add a link to the release downloads.

<br>
