#!/usr/bin/env python3
"""Lint per-slide YAML files for schema, voice, and rendering hazards.

Checks every YAML file in a directory (or one file) against the yaml-to-deck
schema, the Microsoft Voice rules, and known rendering hazards. Used before
build to catch issues that would otherwise show up only in the rendered .pptx.

Three severity levels:
  ERROR    - blocks the build (schema breaks, missing required fields)
  WARNING  - likely a problem (voice violations, rendering hazards)
  INFO     - style nit (long titles, edge cases)

Exit codes:
  0  clean (or only INFO)
  1  one or more ERRORs
  2  no ERRORs but at least one WARNING

Usage:
  lint.py path/to/slides/
  lint.py path/to/slides/004-P1.1.A-ask.yaml
  lint.py path/to/slides/ --strict        # warnings → errors
  lint.py path/to/slides/ --voice-only    # just voice checks
  lint.py path/to/slides/ --schema-only   # just schema checks
  lint.py path/to/slides/ --json          # machine-readable output
"""
import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: install PyYAML (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)


# Required schema
REQUIRED_KEYS = {"id", "order", "cluster", "asks_verbatim", "title", "content", "notes", "layout", "screens"}
LAYOUT_KEYS = {"kind", "addresses", "verdict"}

GENERAL_KINDS = {"TITLE", "BULLETS", "TABLE", "CODE", "CALLOUT", "OUTRO"}
V8_SRE_KINDS = {"INDEX", "ASK_A", "ASK_B", "ASK_C"}
ALL_KINDS = GENERAL_KINDS | V8_SRE_KINDS

VALID_VERDICTS = {"green", "yellow", "red", None}

# Title char limits per kind (rough — auto-shrink helps but isn't enough at the upper end)
TITLE_LIMITS = {
    "TITLE": 60,
    "INDEX": 60,
    "OUTRO": 50,
    "BULLETS": 80,
    "TABLE": 80,
    "CODE": 80,
    "CALLOUT": 80,
    "ASK_A": 80,
    "ASK_B": 80,
    "ASK_C": 80,
}

# Voice rule patterns (case-insensitive)
BANNED_PHRASES = [
    # Research / metadata jargon (V8 SRE deck rule, but applies broadly)
    (r"\bcorpus\b", "research jargon — say 'examples' or 'cases'"),
    (r"\bevidence pack\b", "research jargon — describe the actual artifact"),
    (r"MCAPS ask #?\d+", "research jargon — say 'what customers ask for'"),
    (r"ICM-\d{2}-\d{4,}", "case ID belongs in attribution, not narration"),
    (r"\bfield research\b", "internal terminology — say 'what reps tell us'"),
    (r"\bFastTrack engagement\b", "internal program — say 'a customer engagement'"),
    # Prescriptive language (V8 deck rule: inform, don't prescribe)
    (r"\bMonday move\b", "prescriptive — describe what happens, don't direct action"),
    (r"\byou should\b", "prescriptive — Microsoft Voice prefers describing capabilities"),
    (r"\byou must\b", "prescriptive — Microsoft Voice avoids commanding the reader"),
    # Microsoft Voice violations
    (r"\bthere is\b", "passive opener — Microsoft Voice leads with verbs"),
    (r"\bthere are\b", "passive opener — Microsoft Voice leads with verbs"),
    # Marketing fluff
    (r"\bthis solves\b", "humility — say 'this gives you' or 'this surfaces'"),
    (r"\bthe entire answer\b", "overclaim — humility rule"),
    (r"\bbest-in-class\b", "marketing fluff"),
    (r"\bworld-class\b", "marketing fluff"),
    (r"\bgame-?changer\b", "marketing fluff"),
    (r"\brevolutionary\b", "marketing fluff"),
    # Source citations in narration (must be stripped)
    (r"\(\[source YAML\]\([^)]+\)\)", "source citation parenthetical — strip from narration"),
    (r"see https?://", "URL in narration — narration is spoken, URLs don't read well aloud"),
]

# Bullet character checks
BULLET_PREFIX = "• "  # U+2022 + space


@dataclass
class Issue:
    severity: str  # ERROR, WARNING, INFO
    file: str
    rule: str
    message: str
    line: int | None = None

    def format(self, color: bool = True) -> str:
        if color and sys.stdout.isatty():
            colors = {"ERROR": "\033[31m", "WARNING": "\033[33m", "INFO": "\033[36m"}
            reset = "\033[0m"
            sev = f"{colors.get(self.severity, '')}{self.severity}{reset}"
        else:
            sev = self.severity
        loc = f"{self.file}" + (f":{self.line}" if self.line else "")
        return f"  {sev:<10} [{self.rule}] {loc}\n             {self.message}"


@dataclass
class LintResult:
    issues: list[Issue] = field(default_factory=list)

    def add(self, severity: str, file: str, rule: str, message: str, line: int | None = None):
        self.issues.append(Issue(severity, file, rule, message, line))

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "ERROR"]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "WARNING"]

    @property
    def infos(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "INFO"]


def check_schema(file: Path, doc: dict, result: LintResult) -> None:
    """Schema checks — required keys, types, valid enums."""
    fname = file.name

    # Required top-level keys
    if not isinstance(doc, dict):
        result.add("ERROR", fname, "schema/root", f"YAML root must be a dict, got {type(doc).__name__}")
        return

    missing = REQUIRED_KEYS - set(doc.keys())
    if missing:
        result.add("ERROR", fname, "schema/required-keys", f"missing keys: {sorted(missing)}")

    # Type checks
    if "id" in doc and not isinstance(doc["id"], str):
        result.add(
            "ERROR", fname, "schema/id-type",
            f"`id` must be a string (quote it: id: '{doc['id']}'). Got {type(doc['id']).__name__}.",
        )
    if "order" in doc and not isinstance(doc["order"], int):
        result.add("ERROR", fname, "schema/order-type", f"`order` must be an int, got {type(doc['order']).__name__}")
    if "cluster" in doc and not isinstance(doc["cluster"], str):
        result.add("ERROR", fname, "schema/cluster-type", "`cluster` must be a string")
    if "asks_verbatim" in doc and not isinstance(doc["asks_verbatim"], list):
        result.add("ERROR", fname, "schema/asks-verbatim-type", "`asks_verbatim` must be a list (use `[]` for empty)")
    if "title" in doc and not isinstance(doc["title"], str):
        result.add("ERROR", fname, "schema/title-type", "`title` must be a string")
    if "content" in doc and not isinstance(doc["content"], str):
        result.add("ERROR", fname, "schema/content-type", "`content` must be a string (use `''` for empty)")
    if "notes" in doc and not isinstance(doc["notes"], str):
        result.add("ERROR", fname, "schema/notes-type", "`notes` must be a string (use `''` for empty)")

    # Layout block
    layout = doc.get("layout")
    if layout is None:
        return
    if not isinstance(layout, dict):
        result.add("ERROR", fname, "schema/layout-type", "`layout` must be a dict")
        return
    layout_missing = LAYOUT_KEYS - set(layout.keys())
    if layout_missing:
        result.add("ERROR", fname, "schema/layout-keys", f"layout missing: {sorted(layout_missing)}")
    kind = layout.get("kind")
    if kind is not None and kind not in ALL_KINDS:
        result.add(
            "ERROR", fname, "schema/layout-kind",
            f"unknown layout.kind '{kind}'. Valid: {sorted(ALL_KINDS)}",
        )
    addresses = layout.get("addresses")
    if addresses is not None and not isinstance(addresses, list):
        result.add("ERROR", fname, "schema/layout-addresses-type", "layout.addresses must be a list")
    elif isinstance(addresses, list):
        for i, a in enumerate(addresses):
            if not isinstance(a, int):
                result.add(
                    "ERROR", fname, "schema/layout-addresses-item",
                    f"layout.addresses[{i}] must be int, got {type(a).__name__}",
                )
    verdict = layout.get("verdict")
    if verdict not in VALID_VERDICTS:
        result.add(
            "ERROR", fname, "schema/layout-verdict",
            f"layout.verdict must be one of {VALID_VERDICTS}, got {verdict!r}",
        )


def check_filename(file: Path, doc: dict, result: LintResult) -> None:
    """Filename pattern: NNN-<id>-<slug>.yaml — order prefix and id segment."""
    fname = file.name
    # Skip filename check for templates/ directory — those are scaffolding files,
    # not real slides.
    if "templates" in file.parent.name:
        return
    if not fname.endswith(".yaml"):
        result.add("ERROR", fname, "filename/extension", f"must end with .yaml, got {fname}")
        return
    m = re.match(r"^(\d{3,4})-(.+?)\.yaml$", fname)
    if not m:
        result.add(
            "WARNING", fname, "filename/pattern",
            "expected NNN-<id>-<slug>.yaml (zero-padded order prefix + id + slug)",
        )
        return
    order_prefix = int(m.group(1))
    if isinstance(doc.get("order"), int) and doc["order"] != order_prefix:
        result.add(
            "WARNING", fname, "filename/order-mismatch",
            f"filename prefix {order_prefix:03d} != order: {doc['order']}",
        )
    rest = m.group(2)
    doc_id = doc.get("id")
    if isinstance(doc_id, str) and not rest.startswith(doc_id.replace(".", ".")):
        # The id segment should be at the start of `rest`.
        # Allow non-strict: the slug after id is free-form.
        if doc_id not in rest:
            result.add(
                "INFO", fname, "filename/id",
                f"filename should contain id '{doc_id}' after the order prefix",
            )


def check_layout_fit(file: Path, doc: dict, result: LintResult) -> None:
    """Layout-specific sizing rules."""
    fname = file.name
    layout = doc.get("layout") or {}
    if not isinstance(layout, dict):
        return
    kind = layout.get("kind")
    title = doc.get("title") or ""
    content = doc.get("content") or ""
    if not isinstance(title, str) or not isinstance(content, str):
        return

    # Title length
    limit = TITLE_LIMITS.get(kind, 80)
    if len(title) > limit:
        result.add(
            "WARNING", fname, "layout/title-length",
            f"{kind} title is {len(title)} chars; limit ~{limit}. Will wrap or auto-shrink.",
        )

    # Bullet count
    bullets = [b for b in content.split("<br/>") if b.strip()]
    bullet_count = len(bullets)
    if kind == "TITLE" and bullet_count > 3:
        result.add(
            "WARNING", fname, "layout/title-bullets",
            f"TITLE layout has {bullet_count} bullets; max 3 (or use BULLETS layout)",
        )
    elif kind == "BULLETS" and bullet_count > 7:
        result.add(
            "WARNING", fname, "layout/bullets-overflow",
            f"BULLETS has {bullet_count} bullets; >7 is hard to read. Consider splitting.",
        )
    elif kind in ("CALLOUT",) and bullet_count > 1:
        result.add(
            "INFO", fname, "layout/callout-multiline",
            "CALLOUT works best with one strong line. Multiple bullets render awkwardly.",
        )

    # Bullet character — only flag mixed style (some bullets, some prose).
    # Consistent absence of '• ' = intentional prose style (full sentences) and
    # renders fine. Inconsistency means a typo.
    if kind in ("TITLE", "BULLETS", "OUTRO") and bullet_count >= 2:
        with_prefix = sum(1 for b in bullets if b.strip().startswith(BULLET_PREFIX))
        without_prefix = bullet_count - with_prefix
        if with_prefix and without_prefix:
            result.add(
                "WARNING", fname, "content/bullet-char-mixed",
                f"mixed bullet style: {with_prefix} use '• ', {without_prefix} don't. Pick one.",
            )


def check_voice(file: Path, doc: dict, result: LintResult) -> None:
    """Voice rule violations in `notes:`."""
    fname = file.name
    notes = doc.get("notes") or ""
    if not isinstance(notes, str):
        return
    if not notes.strip() or "(slide-only" in notes.lower():
        return  # nothing to check

    for pattern, why in BANNED_PHRASES:
        m = re.search(pattern, notes, re.IGNORECASE)
        if m:
            result.add(
                "WARNING", fname, "voice/banned-phrase",
                f"'{m.group()}' — {why}",
            )

    # Paragraph break sanity: if notes has multiple "sentences" but no <br/><br/>,
    # speakers will run out of breath
    if len(notes) > 300 and "<br/><br/>" not in notes:
        result.add(
            "INFO", fname, "voice/no-paragraph-break",
            "long narration with no paragraph break — consider splitting with <br/><br/>",
        )

    # Single <br/> (not double) is treated as soft wrap — flag if it looks intentional
    single_br = re.findall(r"(?<!<br/>)<br/>(?!<br/>)", notes)
    # Allow: any <br/> that's part of a <br/><br/> double is OK


def check_citations(file: Path, doc: dict, result: LintResult) -> None:
    """V8 SRE deck citation requirement: clusters P1/P2/H need asks_verbatim."""
    fname = file.name
    cluster = doc.get("cluster") or ""
    asks = doc.get("asks_verbatim") or []
    layout = doc.get("layout") or {}
    if not isinstance(cluster, str) or not isinstance(asks, list) or not isinstance(layout, dict):
        return
    addresses = layout.get("addresses") or []
    notes = doc.get("notes") or ""
    if not isinstance(addresses, list) or not isinstance(notes, str):
        return

    # Detect V8 SRE cluster slides
    is_v8_cluster = bool(re.match(r"^(P1|P2|H)", cluster))
    if not is_v8_cluster:
        return

    # ASK slides must have addresses populated
    if layout.get("kind") in ("ASK_A", "ASK_B", "ASK_C") and not addresses:
        result.add(
            "WARNING", fname, "citations/missing-addresses",
            f"{layout['kind']} slide should have layout.addresses populated with MCAPS ask numbers",
        )

    # Cluster slides with prose narration but no asks_verbatim
    if not asks and notes.strip() and "(slide-only" not in notes.lower():
        result.add(
            "WARNING", fname, "citations/missing-asks-verbatim",
            f"cluster '{cluster}' slide has narration but no asks_verbatim entries — claims may be ungrounded",
        )

    # asks_verbatim should be a superset of layout.addresses
    if asks and addresses:
        ask_nums = {a.get("num") for a in asks if isinstance(a, dict)}
        addr_nums = set(addresses)
        missing_in_asks = addr_nums - ask_nums
        if missing_in_asks:
            result.add(
                "WARNING", fname, "citations/addresses-not-in-asks",
                f"layout.addresses {sorted(missing_in_asks)} not in asks_verbatim",
            )


def check_rendering_hazards(file: Path, doc: dict, result: LintResult) -> None:
    """Things that would render badly in PowerPoint."""
    fname = file.name
    content = doc.get("content") or ""
    notes = doc.get("notes") or ""
    if not isinstance(content, str) or not isinstance(notes, str):
        return
    layout = doc.get("layout") or {}
    if not isinstance(layout, dict):
        return

    # Very long lines in code blocks (CODE layout)
    if layout.get("kind") == "CODE":
        lines = content.split("<br/>")
        for i, line in enumerate(lines):
            if len(line) > 80:
                result.add(
                    "INFO", fname, "render/code-line-long",
                    f"CODE line {i+1} is {len(line)} chars; >80 may wrap on slide",
                )

    # Markdown that won't render (asterisks, brackets in narration)
    if "**" in notes or "__" in notes:
        result.add(
            "WARNING", fname, "render/markdown-in-notes",
            "notes contain markdown emphasis (** or __) — these don't render in TTS",
        )
    if re.search(r"\[[^\]]+\]\([^)]+\)", notes):
        result.add(
            "WARNING", fname, "render/markdown-link-in-notes",
            "notes contain markdown link [text](url) — strip for TTS",
        )

    # Single <br/> in notes is treated as soft wrap (joined with '. ')
    # No flag here — it's intentional behavior


def lint_file(file: Path, modes: set[str]) -> LintResult:
    result = LintResult()
    try:
        text = file.read_text(encoding="utf-8")
        doc = yaml.safe_load(text)
    except Exception as e:
        result.add("ERROR", file.name, "yaml/parse", f"failed to parse: {e}")
        return result
    if doc is None:
        result.add("ERROR", file.name, "yaml/empty", "file is empty or contains only comments")
        return result

    if "schema" in modes:
        check_schema(file, doc, result)
        check_filename(file, doc, result)
    if "layout" in modes:
        check_layout_fit(file, doc, result)
    if "voice" in modes:
        check_voice(file, doc, result)
    if "citations" in modes:
        check_citations(file, doc, result)
    if "render" in modes:
        check_rendering_hazards(file, doc, result)
    return result


def lint_path(path: Path, modes: set[str]) -> LintResult:
    """Lint a single file or every .yaml in a directory."""
    combined = LintResult()
    files = [path] if path.is_file() else sorted(path.glob("*.yaml"))
    if not files:
        combined.add("ERROR", str(path), "input", "no .yaml files found")
        return combined
    for f in files:
        r = lint_file(f, modes)
        combined.issues.extend(r.issues)
    return combined


def report(result: LintResult, json_out: bool, total_files: int) -> int:
    if json_out:
        out = {
            "errors": [i.__dict__ for i in result.errors],
            "warnings": [i.__dict__ for i in result.warnings],
            "infos": [i.__dict__ for i in result.infos],
            "summary": {
                "files": total_files,
                "errors": len(result.errors),
                "warnings": len(result.warnings),
                "infos": len(result.infos),
            },
        }
        print(json.dumps(out, indent=2))
    else:
        for issue in result.errors + result.warnings + result.infos:
            print(issue.format())
        n_e, n_w, n_i = len(result.errors), len(result.warnings), len(result.infos)
        if n_e == 0 and n_w == 0 and n_i == 0:
            print(f"\n  ✓ {total_files} files, clean")
        else:
            print(f"\n  Summary: {n_e} error(s), {n_w} warning(s), {n_i} info, across {total_files} files")
    return 0 if not result.errors and not result.warnings else (1 if result.errors else 2)


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint per-slide YAML for yaml-to-deck.")
    parser.add_argument("path", type=Path, help="YAML file or directory")
    parser.add_argument("--strict", action="store_true", help="warnings → errors")
    parser.add_argument("--voice-only", action="store_true", help="only run voice checks")
    parser.add_argument("--schema-only", action="store_true", help="only run schema checks")
    parser.add_argument("--json", action="store_true", help="machine-readable JSON output")
    args = parser.parse_args()

    if args.voice_only:
        modes = {"voice"}
    elif args.schema_only:
        modes = {"schema"}
    else:
        modes = {"schema", "layout", "voice", "citations", "render"}

    result = lint_path(args.path, modes)

    if args.strict:
        # Promote warnings to errors
        for w in result.warnings:
            w.severity = "ERROR"

    total_files = 1 if args.path.is_file() else len(list(args.path.glob("*.yaml")))
    return report(result, args.json, total_files)


if __name__ == "__main__":
    sys.exit(main())
