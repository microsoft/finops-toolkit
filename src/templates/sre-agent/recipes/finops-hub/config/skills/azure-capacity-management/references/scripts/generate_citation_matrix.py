from __future__ import annotations

import re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs"

# Match inline Markdown links: [label](url)
LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)]+)\)")


def extract_links(md_path: Path):
    """Extract all inline Markdown links from a file."""
    links = []  # list of (label, url)
    content = md_path.read_text(encoding="utf-8", errors="ignore")
    for match in LINK_RE.finditer(content):
        label, url = match.groups()
        links.append((label, url))
    return links


def main():
    md_files = sorted(
        [
            p
            for p in DOCS_DIR.rglob("*.md")
            if "_site" not in p.parts and "AGENTS.md" not in p.name
        ]
    )

    url_map = defaultdict(list)  # url -> list of (file_rel, label)

    for md in md_files:
        rel = md.relative_to(ROOT).as_posix()
        for label, url in extract_links(md):
            url_map[url].append((rel, label))

    matrix_path = DOCS_DIR / "operations" / "support-and-reference" / "citation-matrix.md"
    matrix_path.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("---")
    lines.append("title: Citation traceability matrix")
    lines.append("parent: Support & Reference")
    lines.append("nav_order: 4")
    lines.append("---")
    lines.append("")
    lines.append("# Citation traceability matrix")
    lines.append("")
    lines.append(
        "This matrix lists external links used across the documentation, along with the files that reference them."
    )
    lines.append("")
    lines.append(f"**Total unique URLs:** {len(url_map)}")
    lines.append("")
    lines.append("| URL | Label | Used in |")
    lines.append("| --- | --- | --- |")

    for url in sorted(url_map.keys()):
        uses = url_map[url]
        # Pick first label as the display label
        label = uses[0][1]
        # Deduplicate files
        files = sorted(set(rel for rel, _ in uses))
        files_desc = ", ".join(files)
        # Escape pipes in label
        label_escaped = label.replace("|", "\\|")
        lines.append(f"| <{url}> | {label_escaped} | {files_desc} |")

    lines.append("")

    matrix_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {matrix_path} with {len(url_map)} unique URLs")


if __name__ == "__main__":
    main()
