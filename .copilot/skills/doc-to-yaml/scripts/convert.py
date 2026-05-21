#!/usr/bin/env python3
"""Top-level orchestrator: convert one or many docs to per-slide YAML.

Single doc:
    convert.py <doc.md> --output <out_dir>

Multiple docs:
    convert.py <doc1.md> <doc2.md> --output <out_dir>

Per-doc pipeline (runs inline):
    1. extract_scenes — parse the .md into in-memory scene plan
    2. emit_yaml      — write per-slide YAML files

Output:
    <out_dir>/<doc-slug>/slides/NNN-<slug>.yaml ...
"""
import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def convert_doc(doc_path: Path, out_dir: Path) -> dict:
    """Run extract_scenes + emit_yaml for a single doc."""
    doc_slug = slugify(doc_path.stem)
    doc_out = out_dir / doc_slug
    doc_out.mkdir(parents=True, exist_ok=True)

    extract_proc = subprocess.run(
        ["python3", str(SCRIPT_DIR / "extract_scenes.py"), str(doc_path)],
        capture_output=True,
        text=True,
        check=True,
    )
    scenes_path = doc_out / "scenes.json"
    scenes_path.write_text(extract_proc.stdout, encoding="utf-8")

    emit_proc = subprocess.run(
        [
            "python3", str(SCRIPT_DIR / "emit_yaml.py"),
            "--out", str(doc_out),
            "--scenes", str(scenes_path),
            "--cluster", doc_slug,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    yaml_files = [Path(line) for line in emit_proc.stdout.strip().split("\n") if line]

    return {
        "doc_slug": doc_slug,
        "doc_path": str(doc_path),
        "out_dir": str(doc_out),
        "scenes_json": str(scenes_path),
        "slides_dir": str(doc_out / "slides"),
        "yaml_files": [str(p) for p in yaml_files],
        "scene_count": len(yaml_files),
    }


def main():
    args = sys.argv[1:]
    if "--output" not in args:
        print(
            "Usage: convert.py <doc1.md> [<doc2.md> ...] --output <dir>",
            file=sys.stderr,
        )
        sys.exit(2)
    out_idx = args.index("--output")
    out_dir = Path(args[out_idx + 1])
    docs = [Path(d) for d in args[:out_idx]]
    for d in docs:
        if not d.exists():
            print(f"File not found: {d}", file=sys.stderr)
            sys.exit(2)
    results = []
    for doc in docs:
        try:
            r = convert_doc(doc, out_dir)
            results.append(r)
            print(f"OK  {doc.name} -> {r['out_dir']} ({r['scene_count']} scenes)", file=sys.stderr)
        except subprocess.CalledProcessError as e:
            print(f"FAIL {doc.name}: {e.stderr.strip()}", file=sys.stderr)
    print(json.dumps({"results": results}, indent=2))


if __name__ == "__main__":
    main()
