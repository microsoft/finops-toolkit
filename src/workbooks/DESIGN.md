# Dashboard design system

This file records the design system for the 12 FinOps toolkit Grafana dashboards
(`ftk-*.json`). It is written from the shipped files, not from intentions.

## Scope

The system covers color only. It does not change queries, panel layout, titles,
or descriptions. A verification gate proves all 240 query strings stay byte-identical.

## Source of the design language

The toolkit already contains three design sources. The system uses all three.

| Source | Role | What the system takes |
|---|---|---|
| `src/templates/finops-hub/dashboard.json` | The toolkit's own ADX dashboard. The closest sibling. | Color the value, not the tile. Tie color to meaning. Prefer named colors. |
| `src/power-bi/FinOpsToolkitLight.json` | Report theme | The `good`, `warning`, and `bad` hex values |
| `src/web/FinOpsToolkitTheme.ts` | Application brand | The dark-surface brand color |

The ADX dashboard uses `colorStyle: light` 57 times and `bold` 11 times. It
tints the value and does not fill the tile. It holds 43 `colorRules` arrays, which
carry 25 rules. All 25 are conditional and read a real column. The dashboard contains
zero custom hex colors.

## Tokens

Grafana renders these dashboards on the dark canvas `#111217`. The Power BI
purple `#6f4bb2` gives a contrast ratio of 2.96:1 on that canvas. That value
fails the 3:1 floor for large text. The toolkit already solves this problem:
`FinOpsToolkitTheme.ts` sets `darkTheme.colorBrandForeground1` to `ftk[110]`.
The system uses that value.

| Token | Value | Count | Contrast | Source |
|---|---|---|---|---|
| Accent | `#9C7ECA` | 53 | 5.57:1 | `FinOpsToolkitTheme.ts`, `ftk[110]` |
| Good | `#57a300` | 30 | 5.92:1 | `FinOpsToolkitLight.json` |
| Bad | `#e00b1c` | 17 | 3.77:1 | `FinOpsToolkitLight.json` |
| Muted | `#CCCCDC` | 16 | — | Incumbent neutral |
| Warning | `#db7500` | 8 | 5.84:1 | `FinOpsToolkitLight.json` |

The 12 files contain no other hex color. Use `#e00b1c` for large text only.

### Named colors

The files also hold 112 named Grafana colors. These are not strays. They sit in
threshold steps (50) and field overrides (37), where color reports a data condition.
The toolkit's ADX dashboard works the same way: it ties color to a condition and uses
named colors rather than custom hex.

The two layers divide as follows.

| Layer | Form | Role |
|---|---|---|
| Brand | The five hex tokens | Fixed emphasis and the brand accent |
| State | Named Grafana colors | Conditional color that follows the data |

Do not convert a named color to a hex token when the color reports a condition. A
conversion can merge two threshold steps into one and delete a boundary.

## Rules

1. **Color the value, not the tile.** All 44 stat panels use
   `colorMode: value`. No panel uses `background`.
2. **Color that does not change with the value is decoration.** Decoration
   becomes the accent.
3. **Color that changes with the value carries meaning.** Meaning uses the
   good, warning, and bad tokens.
4. **Remove a threshold that never changes color.** A single-step threshold
   adds no information.
5. **Keep a monochrome intensity ramp.** The toolkit has one green. A ramp that
   needs three greens keeps the named Grafana colors, as the ADX dashboard
   does.

## Field color mode

Grafana derives a per-row color from the field display processor:

```js
getColor = (seriesIdx, valueIdx) => disp(color.values[valueIdx]).color
```

Source: `public/app/plugins/panel/barchart/utils.ts` in `grafana/grafana`.

`palette-classic` walks the palette by index. Adjacent series get distinct
colors. `palette-classic-by-name` hashes the series name. Unrelated names can
hash to adjacent hues, and a chart can then show one hue.

Use `palette-classic` for a panel that must separate its series or slices. Use
`palette-classic-by-name` only when a series must hold one color across panels.
The shipped files use `palette-classic` 34 times and
`palette-classic-by-name` 16 times.

A ranked bar chart keeps one color. Color there would decorate, not inform.

## Verification gates

Run these gates before and after a bulk color edit.

1. **Round trip.** `json.dumps(obj, indent=2, ensure_ascii=False)`, then replace
   `\n` with `\r\n`, then add a trailing `\r\n`. This reproduces all 12 files
   byte-identical. Run this gate first. It proves a later diff holds only
   intended changes.
2. **Format.** Each file keeps CRLF line endings and no BOM.
3. **Queries.** Every query string stays byte-identical.
4. **Ramps.** No threshold ramp loses a distinct color. A ramp that loses a
   color loses a boundary.
