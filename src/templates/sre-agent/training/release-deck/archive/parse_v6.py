#!/usr/bin/env python3
"""Parse V6 markdown deck table into a structured deck spec.

V6 row schema (from the markdown table):
  | # | Stage | Title | Content | Speaker notes | Layout | Screenshots needed |

Outputs a list of dicts, one per slide row, with all 7 columns parsed.
The first row of the table is the header; the second is the column-rule;
data rows follow until the next non-table block.
"""
import re
import json
import sys
from pathlib import Path

V6 = Path(__file__).resolve().parent / "deck-outline-v7.md"


def parse_table_cells(line):
    """Split a markdown table row into cell strings, stripping leading/trailing pipes."""
    if not line.startswith("|") or not line.endswith("|"):
        return None
    inner = line[1:-1]
    return [c.strip() for c in inner.split("|")]


def html_br_to_lines(s):
    """Split a cell on <br/> into individual paragraph strings."""
    parts = re.split(r"<br\s*/?>", s)
    return [p.strip() for p in parts if p.strip()]


def strip_md_emphasis(s):
    """Remove **bold** and [[wikilink]] decorators for plain text rendering."""
    # [[Wiki Link]] → Wiki Link
    s = re.sub(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]", r"\1", s)
    # **bold**
    s = re.sub(r"\*\*([^*]+)\*\*", r"\1", s)
    # *italic*
    s = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"\1", s)
    # `code`
    s = re.sub(r"`([^`]+)`", r"\1", s)
    # [link text](url) → link text (url)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", s)
    return s


def strip_bullet(line):
    """Remove leading •  / -  bullet glyph if present."""
    return re.sub(r"^[•·\-\*]\s+", "", line.strip())


def parse_v6():
    text = V6.read_text(encoding="utf-8")
    lines = text.split("\n")

    # Find the start of the slide-scaffold table
    table_start = None
    for i, ln in enumerate(lines):
        if ln.startswith("| # | Stage | Title |"):
            table_start = i
            break
    if table_start is None:
        sys.exit("Could not find slide-scaffold table header in V6.")

    # Parse rows
    rows = []
    i = table_start + 2  # skip header + rule line
    while i < len(lines):
        ln = lines[i]
        if not ln.startswith("|"):
            break
        cells = parse_table_cells(ln)
        if not cells or len(cells) < 7:
            i += 1
            continue
        num, stage, title, content, notes, layout, screens = cells[:7]

        # Skip section-divider markers like "─" or "─── APPENDIX..."
        if re.match(r"^\*?─+\*?$", num) or "APPENDIX" in (stage or ""):
            i += 1
            continue
        if not re.match(r"^[\d.A-Z]+$", num):
            i += 1
            continue

        # Decompose content into bullet paragraphs
        bullets = [strip_md_emphasis(strip_bullet(b)) for b in html_br_to_lines(content)]
        # Speaker notes — usually one paragraph, may have <br/>
        notes_text = "\n\n".join(strip_md_emphasis(p) for p in html_br_to_lines(notes))
        if not notes_text:
            notes_text = strip_md_emphasis(notes)
        # Layout description
        layout_desc = strip_md_emphasis(layout)
        # Screenshot directive
        screens_desc = strip_md_emphasis(screens)

        rows.append({
            "num": num,
            "stage": strip_md_emphasis(stage),
            "title": strip_md_emphasis(title),
            "bullets": bullets,
            "notes": notes_text,
            "layout": layout_desc,
            "screens": screens_desc,
        })
        i += 1

    return rows


if __name__ == "__main__":
    rows = parse_v6()
    print(f"Parsed {len(rows)} slide rows from V6", file=sys.stderr)
    print(json.dumps(rows, indent=2))
