#!/usr/bin/env python3
"""Write per-scene TTS-ready transcripts to <out_dir>/transcripts/scene_NN.txt.

Reads scenes.json from stdin (or --scenes <path>). Each scene's `text` is
already normalized (the doc-to-yaml skill handled anaphora/article rules
upstream). This script's only job is to add SSML break tags between
paragraphs and write the file.

Slide-only scenes (table/code-dominated, narration_only=true) are written as
single-line marker files so downstream TTS skills can skip them.

Output filename: scene_NN_<heading-slug>.txt

Break tags are SSML <break time="1300ms" /> — recognized by ElevenLabs and
Azure Speech Service. For consumers that don't speak SSML, pass --no-breaks.
"""
import json
import re
import sys
from pathlib import Path


PARA_BREAK_MS = 1300


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")[:40]


def add_paragraph_breaks(text: str, break_ms: int = PARA_BREAK_MS) -> str:
    """Replace blank-line paragraph breaks with explicit SSML break tags.

    Within a paragraph, soft-wrap newlines are joined with '. ' if the line
    doesn't already end with sentence punctuation.
    """
    text = re.sub(r"\r\n", "\n", text)
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    fixed = []
    for p in paragraphs:
        lines = [l.strip() for l in p.split("\n") if l.strip()]
        joined = []
        for line in lines:
            if joined and not joined[-1].rstrip().endswith((".", "!", "?", ":", ";", ",")):
                joined[-1] = joined[-1].rstrip() + "."
            joined.append(line)
        fixed.append(" ".join(joined))
    return f' <break time="{break_ms}ms" /> '.join(fixed)


def write_transcripts(scenes_data: dict, out_dir: Path, with_breaks: bool = True) -> list[Path]:
    """Write one transcript file per scene. Returns list of paths written."""
    transcripts_dir = out_dir / "transcripts"
    transcripts_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for scene in scenes_data["scenes"]:
        scene_id = scene["id"]
        heading_slug = slugify(scene["heading"])
        filename = f"scene_{scene_id:02d}_{heading_slug}.txt"
        path = transcripts_dir / filename
        if scene.get("narration_only", False):
            path.write_text(
                f"# slide-only — no narration\n"
                f"# heading: {scene['heading']}\n"
                f"# layout: {scene['layout']}\n",
                encoding="utf-8",
            )
        else:
            text = scene.get("text", "").strip()
            if not text:
                path.write_text(
                    f"# slide-only — no narration available\n"
                    f"# heading: {scene['heading']}\n",
                    encoding="utf-8",
                )
            else:
                if with_breaks:
                    text = add_paragraph_breaks(text)
                path.write_text(text + "\n", encoding="utf-8")
        written.append(path)
    return written


def main():
    args = sys.argv[1:]
    if "--out" not in args:
        print("Usage: transcript.py --out <dir> [--scenes <path>] [--no-breaks]", file=sys.stderr)
        sys.exit(2)
    out_dir = Path(args[args.index("--out") + 1])
    if "--scenes" in args:
        scenes_path = Path(args[args.index("--scenes") + 1])
        scenes_data = json.loads(scenes_path.read_text())
    else:
        scenes_data = json.loads(sys.stdin.read())
    with_breaks = "--no-breaks" not in args
    written = write_transcripts(scenes_data, out_dir, with_breaks=with_breaks)
    for p in written:
        print(p)


if __name__ == "__main__":
    main()

