#!/usr/bin/env python3
"""Top-level orchestrator: convert one or many docs to narrated-deck assets.

Single doc:
    convert.py <doc.md> --output <out_dir>

Multiple docs (the per-doc fan-out path):
    convert.py <doc1.md> <doc2.md> <doc3.md> --output <out_dir>

This orchestrator does the deterministic work itself (no subagents needed) when
running locally as a single Python script. The per-doc fan-out as separate
subagents is the responsibility of the calling agent: it should spawn one
subagent per source doc, with each subagent invoking this script once with one
doc path. That gives parallel execution while keeping each subagent's context
small.

Per-doc pipeline (runs inline within this script):
    1. extract_scenes — parse the .md into scenes.json
    2. transcript     — write per-scene .txt files
    3. build_outline  — write deck-outline.md
    4. build_pptx     — write slides.pptx

Output layout per doc:
    <out_dir>/<doc-slug>/
        scenes.json
        deck-outline.md
        slides.pptx
        transcripts/scene_NN_*.txt
"""
import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def convert_doc(doc_path: Path, out_dir: Path, next_title: str = "") -> dict:
    """Run the full pipeline for a single doc. Returns paths produced."""
    doc_slug = slugify(doc_path.stem)
    doc_out = out_dir / doc_slug
    doc_out.mkdir(parents=True, exist_ok=True)

    # Step 1: extract scenes
    scenes_path = doc_out / "scenes.json"
    result = subprocess.run(
        ["python3", str(SCRIPT_DIR / "extract_scenes.py"), str(doc_path)],
        capture_output=True, text=True, check=True,
    )
    scenes_path.write_text(result.stdout, encoding="utf-8")

    # Step 2: write transcripts
    subprocess.run(
        [
            "python3", str(SCRIPT_DIR / "transcript.py"),
            "--out", str(doc_out),
            "--scenes", str(scenes_path),
        ],
        capture_output=True, text=True, check=True,
    )

    # Step 3: write deck-outline.md
    outline_path = doc_out / "deck-outline.md"
    subprocess.run(
        [
            "python3", str(SCRIPT_DIR / "build_outline.py"),
            "--out", str(outline_path),
            "--slug", doc_slug,
            "--scenes", str(scenes_path),
        ],
        capture_output=True, text=True, check=True,
    )

    # Step 4: build pptx
    pptx_path = doc_out / "slides.pptx"
    pptx_args = [
        "python3", str(SCRIPT_DIR / "build_pptx.py"),
        "--out", str(pptx_path),
        "--scenes", str(scenes_path),
    ]
    if next_title:
        pptx_args.extend(["--next", next_title])
    subprocess.run(pptx_args, capture_output=True, text=True, check=True)

    return {
        "doc_slug": doc_slug,
        "doc_path": str(doc_path),
        "out_dir": str(doc_out),
        "scenes_json": str(scenes_path),
        "deck_outline": str(outline_path),
        "slides_pptx": str(pptx_path),
        "transcripts_dir": str(doc_out / "transcripts"),
    }


def main():
    args = sys.argv[1:]
    if "--output" not in args:
        print(
            "Usage: convert.py <doc1.md> [<doc2.md> ...] --output <dir> [--next <title>]",
            file=sys.stderr,
        )
        sys.exit(2)
    out_idx = args.index("--output")
    out_dir = Path(args[out_idx + 1])
    next_title = ""
    if "--next" in args:
        next_idx = args.index("--next")
        next_title = args[next_idx + 1]
        # Drop --next NAME from doc list
        doc_args = [a for i, a in enumerate(args[:out_idx]) if i != next_idx and i != next_idx + 1]
    else:
        doc_args = args[:out_idx]
    docs = [Path(d) for d in doc_args]
    for d in docs:
        if not d.exists():
            print(f"File not found: {d}", file=sys.stderr)
            sys.exit(2)
    results = []
    for doc in docs:
        try:
            r = convert_doc(doc, out_dir, next_title=next_title)
            results.append(r)
            print(f"OK  {doc.name} -> {r['out_dir']}", file=sys.stderr)
        except subprocess.CalledProcessError as e:
            print(f"FAIL {doc.name}: {e.stderr.strip()}", file=sys.stderr)
    print(json.dumps({"results": results}, indent=2))


if __name__ == "__main__":
    main()
