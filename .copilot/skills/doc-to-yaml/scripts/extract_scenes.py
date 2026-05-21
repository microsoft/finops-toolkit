#!/usr/bin/env python3
"""Extract scenes from a Microsoft Learn markdown doc.

Each H2 section becomes one scene. The intro (H1 + paragraphs before first H2)
becomes scene 0. Sections like "Give feedback", "Related content", "Next steps",
and "Learn more" are dropped — they're navigation, not training content.

Each scene is classified into a layout kind based on simple heuristics:
- TITLE: scene 0 (the intro/hero)
- TABLE: section dominated by markdown tables
- CODE: section dominated by fenced code blocks
- CALLOUT: short single-paragraph section
- BULLETS: everything else (default)

Output: JSON to stdout with shape:
{
    "h1": "Doc title",
    "doc_path": "/path/to/source.md",
    "scenes": [
        {
            "id": 1,
            "heading": "Intro" | "## H2 text",
            "layout": "TITLE" | "BULLETS" | "TABLE" | "CODE" | "CALLOUT" | "OUTRO",
            "text": "narration-bearing prose (after markdown stripping)",
            "raw_markdown": "the original markdown of this section",
            "has_table": bool,
            "has_code": bool,
            "narration_only": bool,    # True if no prose worth narrating (table/code only)
        },
        ...
    ]
}
"""
import json
import re
import sys
from pathlib import Path


SKIP_HEADINGS = {
    "give feedback",
    "related content",
    "next steps",
    "learn more",
}


def clean_for_narration(text: str) -> str:
    """Strip markdown so the text can be spoken aloud without bracket noise.

    Keeps the source author's words verbatim. Only removes markdown machinery
    (link syntax, code backticks, callout markers, table rows, code fences).
    """
    # Strip note/tip/warning/important callout blocks entirely
    text = re.sub(
        r"^>\s*\[![A-Z]+\][^\n]*\n(>[^\n]*\n?)*",
        "",
        text,
        flags=re.MULTILINE,
    )
    # Strip nextstepaction CTA blocks
    text = re.sub(
        r"^>\s*\[!div[^\]]*\]\n>\s*\[[^\]]+\]\([^)]+\)\n?",
        "",
        text,
        flags=re.MULTILINE,
    )
    # Strip remaining blockquote lines (feedback prompts etc.)
    text = re.sub(r"^>.*$\n?", "", text, flags=re.MULTILINE)
    # Strip table rows (the slide will render the table; narration speaks the prose around it)
    text = re.sub(r"^\|.*\|.*$\n?", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[-:|\s]+$\n?", "", text, flags=re.MULTILINE)
    # Strip fenced code blocks
    text = re.sub(r"```[a-z]*\n.*?\n```", "", text, flags=re.DOTALL)
    # Convert links to their visible text: [text](url) → text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Drop inline code backticks (TTS reads code identifiers more naturally without them)
    text = text.replace("`", "")
    # Bullets: "- **Label**: text" → "Label: text" (keeps the label, drops the bullet glyph)
    text = re.sub(r"^\s*-\s+\*\*([^*]+)\*\*\s*[—:]?\s*", r"\1: ", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*-\s+", "", text, flags=re.MULTILINE)
    # Numbered lists
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    # Bold/italic
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)
    # Heading markers
    text = re.sub(r"^#+\s+", "", text, flags=re.MULTILINE)
    # HTML <br>
    text = re.sub(r"<br\s*/?>", "", text)
    # HTML comments
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
    # Collapse whitespace
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def classify_layout(raw: str, cleaned: str, scene_index: int) -> str:
    """Pick a layout kind based on the section's markdown shape."""
    if scene_index == 0:
        return "TITLE"
    has_table = bool(re.search(r"^\|.*\|.*$", raw, flags=re.MULTILINE))
    has_code = bool(re.search(r"```", raw))
    table_line_count = len(re.findall(r"^\|.*\|.*$", raw, flags=re.MULTILINE))
    code_block_count = len(re.findall(r"```[a-z]*\n.*?\n```", raw, flags=re.DOTALL))
    cleaned_words = len(cleaned.split())
    raw_lines = len([l for l in raw.split("\n") if l.strip()])
    # If the cleaned prose is tiny but the section has a substantial table, it's a TABLE scene
    if has_table and table_line_count >= 3 and cleaned_words < 50:
        return "TABLE"
    # If the cleaned prose is tiny but there's code, it's a CODE scene
    if has_code and code_block_count >= 1 and cleaned_words < 40:
        return "CODE"
    # Single short paragraph → CALLOUT
    if cleaned_words < 50 and raw_lines <= 4:
        return "CALLOUT"
    return "BULLETS"


def extract(path: Path) -> dict:
    src = path.read_text(encoding="utf-8")
    # Strip YAML frontmatter
    src = re.sub(r"^---.*?---\n", "", src, count=1, flags=re.DOTALL)
    # H1
    h1_match = re.search(r"^#\s+(.+)$", src, flags=re.MULTILINE)
    h1 = h1_match.group(1).strip() if h1_match else path.stem
    # Split on H2
    parts = re.split(r"\n##\s+(.+)\n", src)
    # parts[0] = preamble (H1 + intro), then [heading, body, heading, body, ...]
    intro_raw = parts[0]
    intro_clean = clean_for_narration(intro_raw)
    # Drop the H1 line from the intro narration — the visual carries it
    intro_clean = re.sub(rf"^{re.escape(h1)}\s*\n+", "", intro_clean, count=1)
    scenes = []
    scenes.append({
        "id": 1,
        "heading": "Intro",
        "raw_markdown": intro_raw.strip(),
        "text": intro_clean,
        "layout": classify_layout(intro_raw, intro_clean, 0),
        "has_table": bool(re.search(r"^\|.*\|.*$", intro_raw, flags=re.MULTILINE)),
        "has_code": bool(re.search(r"```", intro_raw)),
        "narration_only": False,
    })
    next_id = 2
    for i in range(1, len(parts), 2):
        heading = parts[i].strip()
        body_raw = parts[i + 1] if i + 1 < len(parts) else ""
        if heading.lower() in SKIP_HEADINGS:
            continue
        # H3 awareness: if this H2 contains 3+ H3 subsections AND the H2's
        # own intro prose is short, split into one scene per H3. This handles
        # reference docs like kusto-tools.md where each tool is an H3 under a
        # category H2 — we want one slide per tool, not one per category.
        h3_split = should_split_on_h3(body_raw)
        if h3_split:
            sub_parts = re.split(r"\n###\s+(.+)\n", body_raw)
            # sub_parts[0] = the H2's intro before any H3
            h2_intro_raw = sub_parts[0]
            h2_intro_clean = clean_for_narration(h2_intro_raw)
            # Emit one scene for the H2 intro (uses H2 heading)
            if h2_intro_clean.strip() and len(h2_intro_clean.split()) >= 5:
                scenes.append({
                    "id": next_id,
                    "heading": heading,
                    "raw_markdown": (f"## {heading}\n\n" + h2_intro_raw).strip(),
                    "text": h2_intro_clean,
                    "layout": "CALLOUT" if len(h2_intro_clean.split()) < 50 else "BULLETS",
                    "has_table": bool(re.search(r"^\|.*\|.*$", h2_intro_raw, flags=re.MULTILINE)),
                    "has_code": bool(re.search(r"```", h2_intro_raw)),
                    "narration_only": False,
                })
                next_id += 1
            # Emit one scene per H3
            for j in range(1, len(sub_parts), 2):
                sub_heading = sub_parts[j].strip()
                sub_body_raw = sub_parts[j + 1] if j + 1 < len(sub_parts) else ""
                sub_body_clean = clean_for_narration(sub_body_raw)
                sub_layout = classify_layout(sub_body_raw, sub_body_clean, next_id - 1)
                sub_narration_only = sub_layout in ("TABLE", "CODE") and len(sub_body_clean.split()) < 20
                scenes.append({
                    "id": next_id,
                    "heading": sub_heading,
                    "raw_markdown": (f"### {sub_heading}\n\n" + sub_body_raw).strip(),
                    "text": sub_body_clean,
                    "layout": sub_layout,
                    "has_table": bool(re.search(r"^\|.*\|.*$", sub_body_raw, flags=re.MULTILINE)),
                    "has_code": bool(re.search(r"```", sub_body_raw)),
                    "narration_only": sub_narration_only,
                    "parent_section": heading,
                })
                next_id += 1
        else:
            body_clean = clean_for_narration(body_raw)
            layout = classify_layout(body_raw, body_clean, next_id - 1)
            narration_only = layout in ("TABLE", "CODE") and len(body_clean.split()) < 20
            scenes.append({
                "id": next_id,
                "heading": heading,
                "raw_markdown": body_raw.strip(),
                "text": body_clean,
                "layout": layout,
                "has_table": bool(re.search(r"^\|.*\|.*$", body_raw, flags=re.MULTILINE)),
                "has_code": bool(re.search(r"```", body_raw)),
                "narration_only": narration_only,
            })
            next_id += 1

    # Always emit a final OUTRO scene so the artifact set is 1:1 with the deck.
    # The downstream caller can pass the next-doc title via build_pptx --next.
    scenes.append({
        "id": next_id,
        "heading": "Closing",
        "raw_markdown": "",
        "text": f"That concludes {h1}. Find related modules on Microsoft Learn under FinOps Toolkit.",
        "layout": "OUTRO",
        "has_table": False,
        "has_code": False,
        "narration_only": False,
    })
    return {
        "h1": h1,
        "doc_path": str(path),
        "scenes": scenes,
    }


def should_split_on_h3(body_raw: str) -> bool:
    """Decide whether this H2 section should be expanded into per-H3 scenes.

    Heuristic: split when the H2 contains 3+ H3 headings AND the H2's own
    intro prose (before the first H3) is short. This catches reference docs
    where each H3 is a distinct entity (one tool, one parameter, one task).
    Avoids splitting overview-style sections that have 1-2 H3s used as
    sub-points within a longer narrative.
    """
    h3_headings = re.findall(r"^###\s+.+$", body_raw, flags=re.MULTILINE)
    if len(h3_headings) < 3:
        return False
    # Get the prose before the first H3
    pre_h3 = re.split(r"\n###\s+", body_raw, maxsplit=1)[0]
    pre_h3_words = len(clean_for_narration(pre_h3).split())
    return pre_h3_words < 80


def main():
    if len(sys.argv) < 2:
        print("Usage: extract_scenes.py <doc.md>", file=sys.stderr)
        sys.exit(2)
    doc = Path(sys.argv[1])
    if not doc.exists():
        print(f"File not found: {doc}", file=sys.stderr)
        sys.exit(2)
    result = extract(doc)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
