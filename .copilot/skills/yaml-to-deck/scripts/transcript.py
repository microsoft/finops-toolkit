#!/usr/bin/env python3
"""Write per-slide TTS transcripts from slide YAML.

Reads slides/*.yaml in filename order. Outputs one or both of:

  --output-dir <dir>   →  <dir>/transcripts/scene_NNN_<slug>.txt   (per-scene .txt)
  --manifest  <path>   →  <path>                                    (single manifest.json)

The manifest.json format matches the V8 deck's renders/audio/manifest.json
shape exactly (id, text, chars), suitable for batch TTS pipelines.

Paragraph breaks (<br/><br/>) become SSML <break> tags by default. Customize
the break duration with --break-time (default "0.9s" matches the V8 baseline).

Slides whose notes contain "(slide-only" or are empty get a marker file in
text mode and chars=0 with text="" in manifest mode.

Usage examples:

    # plain text per scene, no breaks
    transcript.py --slides-dir <dir> --output-dir <out> --no-breaks

    # text + manifest, default breaks (0.9s — matches V8 baseline)
    transcript.py --slides-dir <dir> --output-dir <out> --manifest <out>/manifest.json

    # manifest only, with custom break duration
    transcript.py --slides-dir <dir> --manifest <out>/manifest.json --break-time 1300ms

All paths required when their corresponding output is requested. No defaults.
"""
import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: install PyYAML (pip install pyyaml)")


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", (text or "").lower()).strip("_")[:40] or "untitled"


def notes_to_text(notes: str, break_time: str | None) -> str:
    """Convert YAML `notes:` HTML fragment into TTS-ready prose.

    Args:
        notes: the raw notes string (may contain <br/> and <br/><br/>)
        break_time: SSML break duration like "0.9s" or "1300ms". None to omit
                    breaks entirely (paragraphs joined with blank line).

    Behavior:
        - <br/><br/> → SSML <break> (or blank line if break_time is None)
        - single <br/> → soft wrap, joined with '. ' if no terminal punctuation
        - leading/trailing whitespace stripped
    """
    if not notes:
        return ""
    text = notes.replace("\r\n", "\n")
    paragraphs = re.split(r"<br\s*/>\s*<br\s*/>", text)
    fixed = []
    for p in paragraphs:
        p = p.strip()
        if not p:
            continue
        lines = re.split(r"<br\s*/>", p)
        joined = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if joined and not joined[-1].rstrip().endswith((".", "!", "?", ":", ";", ",")):
                joined[-1] = joined[-1].rstrip() + "."
            joined.append(line)
        fixed.append(" ".join(joined))
    if break_time is None:
        return "\n\n".join(fixed)
    # Match V8 baseline format exactly: ` <break time="0.9s"/> ` (space-tag-space, no space inside)
    return f' <break time="{break_time}"/> '.join(fixed)


def main() -> int:
    parser = argparse.ArgumentParser(description="Write per-slide TTS transcripts from slide YAML.")
    parser.add_argument("--slides-dir", required=True, help="Directory containing per-slide *.yaml files")
    parser.add_argument("--output-dir", help="Optional: directory for per-scene .txt files (writes <dir>/transcripts/)")
    parser.add_argument("--manifest", help="Optional: path to write single manifest.json (V8 shape: id, text, chars)")
    parser.add_argument("--no-breaks", action="store_true", help="Omit SSML <break> tags (paragraphs joined with blank line)")
    parser.add_argument("--break-time", default="0.9s",
                        help="SSML <break time=\"...\"/> duration (default: 0.9s — matches V8 baseline manifest)")
    args = parser.parse_args()

    if not args.output_dir and not args.manifest:
        sys.exit("ERROR: must pass --output-dir and/or --manifest")

    slides_dir = Path(args.slides_dir).expanduser().resolve()
    if not slides_dir.is_dir():
        sys.exit(f"ERROR: --slides-dir not a directory: {slides_dir}")

    yaml_files = sorted(slides_dir.glob("*.yaml"))
    if not yaml_files:
        sys.exit(f"ERROR: no .yaml files in {slides_dir}")

    break_time = None if args.no_breaks else args.break_time

    txt_dir = None
    if args.output_dir:
        txt_dir = Path(args.output_dir).expanduser().resolve() / "transcripts"
        txt_dir.mkdir(parents=True, exist_ok=True)

    manifest: list[dict] = []
    written = 0
    skipped = 0
    for i, f in enumerate(yaml_files, 1):
        s = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        sid = str(s.get("id", ""))
        title = str(s.get("title", "") or "")
        notes = str(s.get("notes", "") or "")
        is_marker = (not notes.strip()) or "(slide-only" in notes.lower()
        text = "" if is_marker else notes_to_text(notes, break_time)

        if txt_dir is not None:
            slug = slugify(title)
            out_path = txt_dir / f"scene_{i:03d}_{slug}.txt"
            if is_marker:
                out_path.write_text(
                    f"# slide-only — no narration\n"
                    f"# id: {sid}\n"
                    f"# title: {title}\n"
                    f"# layout: {(s.get('layout') or {}).get('kind')}\n",
                    encoding="utf-8",
                )
                skipped += 1
            else:
                out_path.write_text(text + "\n", encoding="utf-8")
                written += 1

        if args.manifest is not None:
            manifest.append({"id": sid, "text": text, "chars": len(text)})

    if txt_dir is not None:
        print(f"Wrote {written} transcript(s) + {skipped} slide-only marker(s) → {txt_dir}")

    if args.manifest is not None:
        manifest_path = Path(args.manifest).expanduser().resolve()
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote manifest with {len(manifest)} entries → {manifest_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
