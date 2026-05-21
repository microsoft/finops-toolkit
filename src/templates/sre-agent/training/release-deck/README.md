# SRE Agent release training deck

Source-controlled build pipeline for the FinOps Toolkit + Azure SRE Agent
release training deck. Single source of truth: `deck-outline.md` (V6 lifecycle scaffold).

## Files

| File | Purpose |
|---|---|
| `deck-outline.md` | Master scaffold table — every slide's title, content bullets, speaker notes, layout kind, asset directives |
| `source-template.pptx` | Microsoft-branded template that supplies layouts, masters, theme |
| `build.py` | End-to-end build: parse outline → clone template layouts → render slides → embed assets → save deck |
| `parse_v6.py` | Standalone outline parser (importable) |
| `assets/` | Chrome screenshots and rendered SVG charts referenced from `assets:` directives |
| `finops-toolkit-sre-agent-release-training.pptx` | Generated output deck |

## How to iterate

1. Edit `deck-outline.md` — fix titles, bullets, speaker notes, layout `kind=`, `assets:` directives
2. Run the build:

   ```bash
   cd src/templates/sre-agent/training/release-deck
   python3 build.py
   ```

3. The deck is written to `finops-toolkit-sre-agent-release-training.pptx` next to this README.

## Layout kinds

Every row in the outline table has a `kind=KIND` directive in its Layout cell.
The build dispatches to a renderer per kind:

| Kind | Renderer |
|---|---|
| `TITLE` | Title slide with co-brand strip |
| `BULLETS` | Title + bullet body |
| `WHEEL_STATS` | Lifecycle wheel left + counter cards right |
| `WHEEL_LARGE` | Large centered lifecycle wheel + tagline |
| `MATRIX` | 6×3 lifecycle × FinOps phase matrix table |
| `SECTION_TWOCOL` | Section divider with capacity/cost anchor cards (+ optional v1/v2 banner) |
| `SECTION_HEADLINE` | Section divider with white headline panel |
| `TWOUP_IMAGES` | Two-column worked example, supports image embed via `assets: left=… right=…` |
| `TWOCOL_LISTS` | Two-column scheduled-task list with cadence pill chips |
| `CARDS_2`, `CARDS_3`, `CARDS_4` | Card grid (2 / 3 / 4 cards) drawn as rectangle shapes |
| `TABLE` | Real python-pptx table |
| `THREE_BLOCK` | Three connected diagram blocks + RBAC sub-block |

## Assets directive

Add to a row's Screenshots cell to embed an image:

```
| ... | assets: left=capacity-health-overview.svg right=hub-data-freshness.svg |
| ... | assets: image=architecture-diagram.png |
```

SVGs are auto-rasterized via `rsvg-convert` on first use.

## Dependencies

- python-pptx
- rsvg-convert (for SVG → PNG rasterization)
- LibreOffice headless (only for visual QA via `soffice + pdftoppm`; not required for build)
