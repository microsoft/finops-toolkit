<!-- markdownlint-disable MD041 -->

On this page:

- [ℹ️ General guidelines](#ℹ️-general-guidelines)
- [🔤 Content (strings and microcopy)](#-content-strings-and-microcopy)
- [📋 Changelog](#-changelog)

---

## ℹ️ General guidelines

We strive to auto-enforce coding standards as much as possible and follow common practices you'll find in other projects to simplify onboarding.

Here's a quick run-down of the main points:

- Install the recommended extensions in VS Code to apply guidelines and auto-format code on save.
- Document everything.
- Documentation should be inline, with the code.
- Every folder should have a README.
- Add inline comments to all major code blocks.
- Resolve all lint errors before submitting PRs.
- Follow standard language conventions:
  - [PowerShell guidelines](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
  - [Bicep lint rules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)

<br>

## 🔤 Content (strings and microcopy)

We adhere to the [Microsoft style guide](https://docs.microsoft.com/style-guide/welcome). There's a ton to keep in mind in this space, from capitalization to terms to specific phrasing and more. A few quick tips to be aware of:

- Use bigger ideas, fewer words
- Write like you speak
- Project friendliness
- Get to the point fast
- Be brief
- When in doubt, don't capitalize – Always use sentence casing, not Title Casing, unless it's a product name.
- Avoid end punctuation on titles, headings, subheads, UI titles, and items in a list that are three or fewer words.
- Remember the last comma – Always use a comma before "and" and "or" in a list of 3 or more items.
- Don't be spacey
- Revise weak writing

[Learn more](https://docs.microsoft.com/style-guide/welcome)

<br>

## 📋 Changelog

The [changelog](../docs-mslearn/toolkit/changelog.md) documents user-facing changes for each release. It follows [Keep a Changelog](https://keepachangelog.com) conventions adapted for this project's multi-tool structure.

### Structure

```markdown
## v{version}

_Released {Month} {Year}_

### [{Tool name}]({doc-link}) v{version}

- **Added**
  - Entry text ([#{issue}](url)).
- **Changed**
  - Entry text ([#{issue}](url)).
- **Fixed**
  - Entry text ([#{issue}](url)).
- **Deprecated**
  - Entry text ([#{issue}](url)).
- **Removed**
  - Entry text ([#{issue}](url)).
```

### Rules

- **One version section.** All changes for the upcoming release go in a single version section. Do not create duplicate sections.
- **Unreleased section.** Only for changes merged to feature branches that are not yet in `dev`. Once in `dev`, move to the version section.
- **Category order.** Added, Changed, Fixed, Deprecated, Removed. Omit empty categories.
- **Tool sections.** Group by tool using H3 headings with a link to the tool's doc page and the version number (e.g., `### [FinOps hubs](...) v14`). Match the tool order from previous releases.
- **Entry format.** Start with a past-tense verb (Added, Changed, Fixed, Removed, Updated). End with a period. Follow the [content guidelines](#-content-strings-and-microcopy).
- **Issue links.** Link to the GitHub issue when one exists: `([#{number}]({url}))`. Omit when no issue applies (e.g., minor doc fixes).
- **One line per change.** Each entry should be a single concise sentence. Sub-bullets can provide context but keep the overall entry brief.
- **No filler.** Omit entries like "Various bug fixes and improvements" or "Minor code cleanup." Every entry should describe a specific, user-facing change.
- **No implementation details.** Write for users, not developers. "Fixed dashboard freezes during large report generation" not "Fixed async loop timing in render pipeline."
- **Breaking changes.** Prefix with `**Breaking:**` and list first within the category.
- **Within-category ordering.** Breaking changes first, then by importance to users.
- **Brevity over verbosity.** Aim for the minimum words that convey the change and its impact. A changelog is a summary, not documentation.

<br>
