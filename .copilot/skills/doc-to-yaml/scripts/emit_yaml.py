#!/usr/bin/env python3
"""Emit per-slide YAML files from a scene plan.

Reads scenes.json from stdin (or --scenes <path>). Applies normalize_text to
prose-bearing scenes. Writes one YAML file per scene at:

    <out_dir>/slides/NNN-<id>-<slug>.yaml

The schema matches release-deck's per-slide YAML exactly, so files can be
consumed by either:
  - narrated-deck/scripts/build_pptx.py (this toolkit's generic builder)
  - src/templates/sre-agent/training/release-deck/build_yaml.py

Filename convention: 3-digit zero-padded ordinal + scene id + slug, like
release-deck does. Example:
    000-Intro-finops-toolkit-sre-agent.yaml
    001-What-you-get.yaml
    005-Closing.yaml
"""
import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))
from normalize_text import normalize  # type: ignore


def slugify(text: str, max_len: int = 60) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")[:max_len]


def to_html_br_paragraphs(text: str) -> str:
    """Render multi-paragraph text as <br/><br/>-separated single line.

    PowerPoint speaker notes and release-deck's parser both handle <br/>:
    - <br/> within a paragraph = soft line break
    - <br/><br/> between paragraphs = paragraph break

    Within each paragraph, soft newlines (from bullet lines) are folded to spaces.
    """
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    rendered = []
    for p in paragraphs:
        # Within paragraph: fold soft newlines to spaces
        p = re.sub(r"\n+", " ", p).strip()
        rendered.append(p)
    return "<br/><br/>".join(rendered)


def build_content_bullets(scene: dict) -> str:
    """Slide body content. Returns <br/>-separated bullet lines.

    Source priority:
    1. Explicit markdown bullets (`-` or numbered `1.`) — preferred when the
       source author chose to bullet-format their content
    2. Sentence split of the cleaned prose — fallback for prose-paragraph
       sections (common in MS Learn reference docs where each H3 subsection
       is 2-4 prose paragraphs rather than a bulleted list)
    3. First sentence as a single bullet — last resort
    """
    raw = scene.get("raw_markdown", "")
    bullet_lines = re.findall(r"^\s*(?:-|\d+\.)\s+(.+)$", raw, flags=re.MULTILINE)
    if bullet_lines:
        cleaned = []
        for line in bullet_lines:
            line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
            line = re.sub(r"\*\*([^*]+)\*\*", r"\1", line)
            line = re.sub(r"\*([^*]+)\*", r"\1", line)
            line = re.sub(r"_([^_\n]+)_", r"\1", line)
            line = re.sub(r"<br\s*/?>", " \u2014 ", line)
            line = re.sub(r"`([^`]+)`", r"\1", line)
            line = re.sub(r"\s+", " ", line).strip()
            cleaned.append(f"\u2022 {line}")
        return "<br/>".join(cleaned)
    # No explicit bullets — split prose into sentence-as-bullets
    text = scene.get("text", "").strip()
    if not text:
        return "(visual only)"
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    # Cap at 6 bullets to avoid overcrowded slides; speaker notes carry the rest
    if len(sentences) >= 2:
        capped = sentences[:6]
        return "<br/>".join(f"\u2022 {s}" for s in capped)
    return f"\u2022 {sentences[0]}" if sentences else "(visual only)"


def build_yaml_entry(scene: dict, order: int, cluster: str, doc_h1: str = "") -> dict:
    """Build the dict that becomes one slide's YAML file.

    For TITLE-layout scenes, the slide title is set to the doc's H1
    (the deck title), not the literal "Intro" heading from the scene plan.
    """
    canonical_id = scene.get("canonical_id") or str(scene["id"])
    text = scene.get("text", "").strip()
    if scene.get("narration_only", False) or not text:
        notes = "(slide-only — no narration)"
    else:
        normalized = normalize(text, with_breaks=False)
        notes = to_html_br_paragraphs(normalized)
    layout = {
        "kind": scene["layout"],
        "addresses": [],
        "verdict": None,
    }
    # TITLE slide uses the doc H1 as its title; intermediate scenes use their heading
    if scene["layout"] == "TITLE" and doc_h1:
        slide_title = doc_h1
    else:
        slide_title = scene["heading"]
    return {
        "id": canonical_id,
        "order": order,
        "cluster": cluster,
        "asks_verbatim": [],
        "title": slide_title,
        "content": build_content_bullets(scene),
        "notes": notes,
        "layout": layout,
        "screens": None,
    }


def yaml_dump(d: dict) -> str:
    """Hand-rolled YAML serializer to match release-deck's output style.

    We avoid PyYAML so the skill has no dependencies. Output is conservative
    (single-line strings unless they contain newlines or quotes) so files diff
    cleanly against hand-edited release-deck slides.
    """
    lines = []
    for key, value in d.items():
        if isinstance(value, dict):
            lines.append(f"{key}:")
            for sub_k, sub_v in value.items():
                lines.append(f"  {sub_k}: {_yaml_value(sub_v)}")
        elif isinstance(value, list):
            if not value:
                lines.append(f"{key}: []")
            else:
                lines.append(f"{key}:")
                for item in value:
                    lines.append(f"  - {_yaml_value(item)}")
        else:
            lines.append(f"{key}: {_yaml_value(value)}")
    return "\n".join(lines) + "\n"


def _yaml_value(v) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v)
    # Strings: quote if they have leading/trailing whitespace, special chars,
    # or look like YAML keywords
    needs_quote = (
        s != s.strip()
        or any(c in s for c in [":", "#", "&", "*", "!", "|", ">", "%", "@", "`"])
        or s.lower() in ("yes", "no", "true", "false", "null", "~", "on", "off")
        or re.match(r"^[\d.\-+]+$", s)
    )
    if "\n" in s:
        # Use literal block style
        indented = "\n".join(f"  {line}" for line in s.split("\n"))
        return f"|\n{indented}"
    if needs_quote:
        # Single-quote style; escape internal single quotes by doubling
        escaped = s.replace("'", "''")
        return f"'{escaped}'"
    return s


def emit_slides(scenes_data: dict, out_dir: Path, cluster: str = None) -> list[Path]:
    """Write one YAML file per scene under out_dir/slides/. Returns paths."""
    slides_dir = out_dir / "slides"
    slides_dir.mkdir(parents=True, exist_ok=True)
    if cluster is None:
        cluster = Path(scenes_data["doc_path"]).stem
    doc_h1 = scenes_data.get("h1", "")
    written = []
    for order, scene in enumerate(scenes_data["scenes"]):
        entry = build_yaml_entry(scene, order, cluster, doc_h1=doc_h1)
        slug = slugify(scene["heading"])
        filename = f"{order:03d}-{slug}.yaml"
        path = slides_dir / filename
        path.write_text(yaml_dump(entry), encoding="utf-8")
        written.append(path)
    return written


def main():
    args = sys.argv[1:]
    if "--out" not in args:
        print(
            "Usage: emit_yaml.py --out <dir> [--scenes <path>] [--cluster <name>]",
            file=sys.stderr,
        )
        sys.exit(2)
    out_dir = Path(args[args.index("--out") + 1])
    cluster = args[args.index("--cluster") + 1] if "--cluster" in args else None
    if "--scenes" in args:
        scenes_data = json.loads(Path(args[args.index("--scenes") + 1]).read_text())
    else:
        scenes_data = json.loads(sys.stdin.read())
    written = emit_slides(scenes_data, out_dir, cluster=cluster)
    for p in written:
        print(p)


if __name__ == "__main__":
    main()
