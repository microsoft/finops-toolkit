# Source manifest

## Authoritative source

| Field | Value |
|---|---|
| Repository | `MicrosoftDocs/microsoft-style-guide-pr` |
| Repository URL | https://github.com/MicrosoftDocs/microsoft-style-guide-pr |
| Pinned commit | `c78a330b932812a342be2ebca0ec8bc3d01fbac2` |
| Commit timestamp | 2026-07-16T18:50:11Z |
| Local synchronization date | 2026-08-22 |
| Latest guide change represented | 2026-07-02 |

The pinned commit is the source of truth for this snapshot. If a local rule
conflicts with that source, use the pinned source. Check the live guide before
relying on this snapshot for a rule changed after the synchronization date.

## Coverage

| Source surface | Authoritative count | Local status |
|---|---:|---|
| TOC-linked non-term pages | 109 | 105 substantive reference-page headings are present in the reference files; brand voice and Top 10 guidance are in `SKILL.md`; Welcome and What's new are source metadata |
| A-Z term pages | 870 | Present across the six `a-z-term-list-*.md` files |
| Shared include files | 45 | Resolved in place; zero `!INCLUDE` directives remain |
| Canonical reference files | 19 | Preserved |

## Resolution policy

* Include payloads retain authoritative prose, examples, tables, and links.
* Source frontmatter and include directives are omitted because they are build
  metadata rather than writing guidance.
* The existing consolidated reference organization is preserved to support
  selective loading.
* `term-index.tsv` is generated from the pinned TOC and maps authoritative
  terms to their consolidated local reference files.
* Two TOC labels lag their page titles. The index uses the authoritative page
  titles `drive resource` and `storage, storage space` while retaining the TOC
  source paths `disk-resource.md` and `storage-storage-device.md`.

## Support artifacts

| Artifact | Role |
|---|---|
| `term-index.tsv` | Canonical A-Z term inventory and local routing |
| `../scripts/validate.py` | Offline structural and freshness validation |
| `../evals/evals.json` | Representative behavior evaluations |
