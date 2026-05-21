#!/usr/bin/env python3
"""Consume per-slide YAML files and produce the narrated-deck artifact set.

Reads a directory of YAML files (output of doc-to-yaml) and writes:
    <out_dir>/slides.pptx
    <out_dir>/transcripts/scene_NN_<slug>.txt
    <out_dir>/scenes.json   (combined scene index, useful for downstream skills)

YAML files are read in filename order. Each YAML is a dict with this shape
(matching release-deck/slides/*.yaml exactly):

    id: '1'
    order: 0
    cluster: overview
    asks_verbatim: []
    title: 'Heading text'
    content: '• Bullet 1<br/>• Bullet 2'
    notes: 'Spoken narration.<br/><br/>Second paragraph.'
    layout:
        kind: BULLETS         # TITLE | BULLETS | TABLE | CODE | CALLOUT | OUTRO
        addresses: []
        verdict: null
    screens: null

Usage:
    consume.py <slides_dir> --output <out_dir> [--next "Next module title"]

Where <slides_dir> is a directory containing the .yaml files.
"""
import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: install PyYAML (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

# Import the renderer + transcript writer from sibling modules
import build_pptx  # type: ignore
import transcript  # type: ignore


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:40]


def yaml_to_scene(y: dict) -> dict:
    """Translate a per-slide YAML dict into the scene dict shape that
    build_pptx.render_*_slide and transcript.write_transcripts expect.

    The build_pptx renderers expect:
        - heading
        - text (the narration prose, without break tags)
        - layout (TITLE/BULLETS/TABLE/CODE/CALLOUT/OUTRO)
        - raw_markdown (used by TABLE and CODE renderers; we synthesize from content)
        - narration_only (True for slide-only scenes with no spoken narration)
    """
    notes_html = y.get("notes") or ""
    # Detect slide-only marker
    narration_only = "(slide-only" in notes_html.lower()
    # Convert <br/><br/> back to \n\n for the renderers and transcript writer
    notes_text = re.sub(r"<br\s*/>\s*<br\s*/>", "\n\n", notes_html)
    notes_text = re.sub(r"<br\s*/>", " ", notes_text).strip()
    if narration_only:
        notes_text = ""
    # For TABLE and CODE layouts, build_pptx looks at raw_markdown for the table
    # rows or code block. The doc-to-yaml emitter doesn't carry raw markdown
    # forward, so we synthesize a minimal raw_markdown from the content bullets.
    # This is good enough for the BULLETS layout (the most common). For TABLE
    # and CODE, the slide will use a fallback heading-only layout.
    content_html = y.get("content") or ""
    bullets = [
        re.sub(r"^[\u2022•]\s*", "", b).strip()
        for b in re.split(r"<br\s*/>", content_html)
        if b.strip()
    ]
    raw_markdown = (
        f"## {y.get('title', '')}\n\n"
        + "\n".join(f"- {b}" for b in bullets)
    )
    return {
        "id": int(re.match(r"^\d+", str(y.get("id", "0"))).group()) if re.match(r"^\d+", str(y.get("id", "0"))) else 0,
        "heading": y.get("title", ""),
        "text": notes_text,
        "raw_markdown": raw_markdown,
        "layout": y.get("layout", {}).get("kind", "BULLETS"),
        "has_table": y.get("layout", {}).get("kind") == "TABLE",
        "has_code": y.get("layout", {}).get("kind") == "CODE",
        "narration_only": narration_only,
    }


def consume(slides_dir: Path, out_dir: Path, next_title: str = "") -> dict:
    """Read all YAMLs in slides_dir, produce pptx + transcripts in out_dir."""
    out_dir.mkdir(parents=True, exist_ok=True)
    yaml_files = sorted(slides_dir.glob("*.yaml"))
    if not yaml_files:
        raise FileNotFoundError(f"No .yaml files in {slides_dir}")
    raw_yaml = [yaml.safe_load(p.read_text(encoding="utf-8")) for p in yaml_files]
    scenes = [yaml_to_scene(y) for y in raw_yaml]
    # Re-number scenes 1..N for filename and ordering
    for i, scene in enumerate(scenes, 1):
        scene["id"] = i

    # Derive H1 (the deck title) from the first scene if it's a TITLE,
    # else from the cluster of the first slide
    first = raw_yaml[0]
    # H1 = title of first TITLE slide; falls back to cluster name
    h1 = first.get("title") or first.get("cluster") or "Narrated deck"

    scenes_data = {
        "h1": h1,
        "doc_path": str(slides_dir),
        "scenes": scenes,
    }

    # Persist combined scene index
    scenes_json = out_dir / "scenes.json"
    scenes_json.write_text(json.dumps(scenes_data, indent=2), encoding="utf-8")

    # Write transcripts (transcript.py reads scenes.json shape)
    transcripts_dir = out_dir / "transcripts"
    transcript.write_transcripts(scenes_data, out_dir, with_breaks=True)

    # Build PPTX
    pptx_path = out_dir / "slides.pptx"
    build_pptx.build(scenes_data, pptx_path, next_title=next_title)

    return {
        "h1": h1,
        "scenes_json": str(scenes_json),
        "transcripts_dir": str(transcripts_dir),
        "slides_pptx": str(pptx_path),
        "scene_count": len(scenes),
    }


def main():
    parser = argparse.ArgumentParser(description="Consume per-slide YAML and emit PPTX + transcripts.")
    parser.add_argument("slides_dir", type=Path, help="Directory containing per-slide YAML files")
    parser.add_argument("--output", required=True, type=Path, help="Output directory for slides.pptx and transcripts/")
    parser.add_argument("--next", default="", help="Title of the next module (for the OUTRO slide)")
    args = parser.parse_args()
    if not args.slides_dir.is_dir():
        print(f"Not a directory: {args.slides_dir}", file=sys.stderr)
        sys.exit(2)
    result = consume(args.slides_dir, args.output, next_title=args.next)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
