#!/usr/bin/env python3
"""Validate the Microsoft Writing Style Guide skill without network access."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
import sys
import tempfile
import unicodedata
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PINNED_COMMIT = "c78a330b932812a342be2ebca0ec8bc3d01fbac2"
TERM_COUNT = 870
TERM_SHA256 = "aad58a61c045534da05987d34f12a011c17bdc9f19552e538ea768f9a374c212"
PATH_SHA256 = "e18b479add127d835865d787c2d86ee1ab5f2ca59fa7810d3f8e2cb5b90b76c2"
CANONICAL_REFERENCES = {
    "a-z-term-list-a-c.md",
    "a-z-term-list-d-g.md",
    "a-z-term-list-h-m.md",
    "a-z-term-list-n-r.md",
    "a-z-term-list-s-u.md",
    "a-z-term-list-v-z.md",
    "accessibility-and-bias-free-communication.md",
    "checklists.md",
    "content-planning-and-process.md",
    "developer-and-bot-content.md",
    "global-communications.md",
    "grammar-and-parts-of-speech.md",
    "keys-and-keyboard-shortcuts.md",
    "numbers-acronyms-capitalization.md",
    "punctuation.md",
    "scannable-content-and-procedures.md",
    "term-collections-numbers-symbols.md",
    "text-formatting.md",
    "word-choice.md",
}


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).lower()
    value = re.sub(r"<[^>]*>", "", value)
    value = re.sub(r"\\([#*_-])", r"\1", value)
    value = (
        value.replace("’", "'")
        .replace("‘", "'")
        .replace("“", '"')
        .replace("”", '"')
    )
    value = re.sub(r"[*_`]", "", value)
    return re.sub(r"\s+", " ", value).strip()


def digest(values: list[str]) -> str:
    payload = "\n".join(sorted(values)) + "\n"
    return hashlib.sha256(payload.encode()).hexdigest()


def validate_skill(root: Path) -> list[str]:
    errors: list[str] = []
    skill_path = root / "SKILL.md"
    references = root / "references"
    index_path = references / "term-index.tsv"
    manifest_path = references / "source-manifest.md"
    eval_path = root / "evals" / "evals.json"
    required_distribution_files = {
        "LICENSE": "MIT License",
        "LICENSE-CONTENT": "Attribution 4.0 International",
        "NOTICE.md": "MicrosoftDocs/microsoft-style-guide-pr",
    }

    if not skill_path.is_file():
        return ["SKILL_MISSING: SKILL.md is missing"]

    skill = skill_path.read_text(encoding="utf-8")
    frontmatter = re.match(r"\A---\n(.*?)\n---\n", skill, re.S)
    if not frontmatter:
        errors.append("SKILL_FRONTMATTER: valid YAML frontmatter is missing")
    else:
        metadata = frontmatter.group(1)
        if not re.search(r"^name: microsoft-writing-style-guide$", metadata, re.M):
            errors.append("SKILL_NAME: frontmatter name is incorrect")
        if not re.search(r"^description: .+", metadata, re.M):
            errors.append("SKILL_DESCRIPTION: frontmatter description is missing")

    if len(skill.splitlines()) > 250:
        errors.append("SKILL_LENGTH: SKILL.md exceeds 250 lines")

    for filename, expected in required_distribution_files.items():
        path = root / filename
        if not path.is_file():
            errors.append(f"DISTRIBUTION_FILE_MISSING: {filename}")
        elif expected not in path.read_text(encoding="utf-8"):
            errors.append(f"DISTRIBUTION_FILE_CONTENT: {filename}")

    required_skill_text = (
        "## Choose a mode",
        "## Source precedence",
        "## Load only what you need",
        "### Write",
        "### Rewrite",
        "### Review",
        "## Guardrails",
    )
    for expected in required_skill_text:
        if expected not in skill:
            errors.append(f"SKILL_WORKFLOW: missing {expected!r}")

    markdown_references = {
        path.name
        for path in references.glob("*.md")
        if path.name != "source-manifest.md"
    }
    if markdown_references != CANONICAL_REFERENCES:
        missing = sorted(CANONICAL_REFERENCES - markdown_references)
        unexpected = sorted(markdown_references - CANONICAL_REFERENCES)
        errors.append(
            f"REFERENCE_INVENTORY: missing={missing}, unexpected={unexpected}"
        )

    for path in [skill_path, *sorted(references.glob("*.md"))]:
        text = path.read_text(encoding="utf-8")
        if re.search(r"!INCLUDE\s*\[", text):
            errors.append(f"UNRESOLVED_INCLUDE: {path.relative_to(root)}")
        if re.search(r"!(?!\[)(?:image|screenshot)\b", text, re.I):
            errors.append(f"UNRESOLVED_IMAGE: {path.relative_to(root)}")
        if "ms.topic: include" in text:
            errors.append(f"INCLUDE_FRONTMATTER: {path.relative_to(root)}")

    if not manifest_path.is_file():
        errors.append("MANIFEST_MISSING: references/source-manifest.md is missing")
    else:
        manifest = manifest_path.read_text(encoding="utf-8")
        for expected in (
            PINNED_COMMIT,
            "2026-08-22",
            "| A-Z term pages | 870 |",
            "| Shared include files | 45 |",
        ):
            if expected not in manifest:
                errors.append(f"MANIFEST_CONTENT: missing {expected!r}")

    rows: list[dict[str, str]] = []
    if not index_path.is_file():
        errors.append("TERM_INDEX_MISSING: references/term-index.tsv is missing")
    else:
        with index_path.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            if reader.fieldnames != ["term", "file", "source_path"]:
                errors.append(
                    f"TERM_INDEX_HEADER: found {reader.fieldnames!r}"
                )
            else:
                rows = list(reader)

    if rows:
        terms = [normalize(row["term"]) for row in rows]
        source_paths = [row["source_path"] for row in rows]
        if len(rows) != TERM_COUNT:
            errors.append(f"TERM_COUNT: expected {TERM_COUNT}, found {len(rows)}")
        if len(set(terms)) != len(terms):
            errors.append("TERM_DUPLICATE: normalized term identities aren't unique")
        if len(set(source_paths)) != len(source_paths):
            errors.append("TERM_SOURCE_DUPLICATE: source paths aren't unique")
        if digest(terms) != TERM_SHA256:
            errors.append("TERM_IDENTITY_HASH: authoritative term identities differ")
        if digest(source_paths) != PATH_SHA256:
            errors.append("TERM_PATH_HASH: authoritative source paths differ")

        heading_cache: dict[str, set[str]] = {}
        for row in rows:
            filename = row["file"]
            target = references / filename
            if not target.is_file():
                errors.append(f"TERM_TARGET_FILE: {filename!r} doesn't exist")
                continue
            if filename not in heading_cache:
                heading_cache[filename] = {
                    normalize(heading)
                    for heading in re.findall(
                        r"^### (.+)$", target.read_text(encoding="utf-8"), re.M
                    )
                }
            if normalize(row["term"]) not in heading_cache[filename]:
                errors.append(
                    f"TERM_TARGET_HEADING: {row['term']!r} isn't in {filename}"
                )

    sentinels = {
        references / "a-z-term-list-n-r.md": (
            "### plugin",
            "In generative AI experiences",
            "use one word (no hyphen)",
        ),
        references / "a-z-term-list-v-z.md": (
            "### visit",
            "More of a suggestion than a required action",
            "staying for a while and browsing around",
        ),
        skill_path: (
            "Omit periods and colons from most titles, headings, and short UI text",
        ),
    }
    for path, expected_values in sentinels.items():
        text = path.read_text(encoding="utf-8")
        for expected in expected_values:
            if expected not in text:
                errors.append(
                    f"FRESHNESS_SENTINEL: {path.relative_to(root)} lacks {expected!r}"
                )

    if not eval_path.is_file():
        errors.append("EVAL_MISSING: evals/evals.json is missing")
    else:
        try:
            data = json.loads(eval_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"EVAL_JSON: {exc}")
        else:
            if data.get("skill_name") != "microsoft-writing-style-guide":
                errors.append("EVAL_SKILL_NAME: skill_name is incorrect")
            evaluations = data.get("evals")
            if not isinstance(evaluations, list) or len(evaluations) < 12:
                errors.append("EVAL_COUNT: at least 12 evaluations are required")
            else:
                ids = []
                for position, evaluation in enumerate(evaluations, start=1):
                    if not isinstance(evaluation, dict):
                        errors.append(f"EVAL_SHAPE: evaluation {position} isn't an object")
                        continue
                    ids.append(evaluation.get("id"))
                    for key in ("prompt", "expected_output"):
                        if not isinstance(evaluation.get(key), str) or not evaluation[key]:
                            errors.append(
                                f"EVAL_SHAPE: evaluation {position} has invalid {key}"
                            )
                    if not isinstance(evaluation.get("files"), list):
                        errors.append(
                            f"EVAL_SHAPE: evaluation {position} has invalid files"
                        )
                if ids != list(range(1, len(evaluations) + 1)):
                    errors.append("EVAL_IDS: IDs must be unique and sequential")

    return errors


def run_self_check(root: Path) -> list[str]:
    failures: list[str] = []
    include_fixtures = {
        "canonical": "[!INCLUDE [self-check](../includes/self-check.md)]",
        "blockquoted": "> [!INCLUDE [self-check](../includes/self-check.md)]",
    }
    for name, fixture in include_fixtures.items():
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "skill"
            shutil.copytree(root, candidate)
            checklist = candidate / "references" / "checklists.md"
            checklist.write_text(
                checklist.read_text(encoding="utf-8") + f"\n{fixture}\n",
                encoding="utf-8",
            )
            if not any(
                error.startswith("UNRESOLVED_INCLUDE")
                for error in validate_skill(candidate)
            ):
                failures.append(
                    f"SELF_CHECK_INCLUDE: {name} include wasn't detected"
                )

    with tempfile.TemporaryDirectory() as directory:
        candidate = Path(directory) / "skill"
        shutil.copytree(root, candidate)
        checklist = candidate / "references" / "checklists.md"
        checklist.write_text(
            checklist.read_text(encoding="utf-8")
            + "\n!Screenshot unresolved image placeholder\n",
            encoding="utf-8",
        )
        if not any(
            error.startswith("UNRESOLVED_IMAGE")
            for error in validate_skill(candidate)
        ):
            failures.append(
                "SELF_CHECK_IMAGE: unresolved image placeholder wasn't detected"
            )

    with tempfile.TemporaryDirectory() as directory:
        candidate = Path(directory) / "skill"
        shutil.copytree(root, candidate)
        (candidate / "LICENSE").unlink()
        if not any(
            error.startswith("DISTRIBUTION_FILE_MISSING")
            for error in validate_skill(candidate)
        ):
            failures.append(
                "SELF_CHECK_LICENSE: missing distribution license wasn't detected"
            )

    with tempfile.TemporaryDirectory() as directory:
        candidate = Path(directory) / "skill"
        shutil.copytree(root, candidate)
        index = candidate / "references" / "term-index.tsv"
        lines = index.read_text(encoding="utf-8").splitlines()
        index.write_text(
            "\n".join([lines[0], *lines[2:]]) + "\n",
            encoding="utf-8",
        )
        errors = validate_skill(candidate)
        if not any(error.startswith("TERM_COUNT") for error in errors):
            failures.append("SELF_CHECK_COUNT: missing index row wasn't detected")
        if not any(error.startswith("TERM_PATH_HASH") for error in errors):
            failures.append("SELF_CHECK_HASH: changed authoritative set wasn't detected")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-check",
        action="store_true",
        help="Verify that critical failure detectors trigger",
    )
    args = parser.parse_args()

    errors = validate_skill(ROOT)
    if not errors and args.self_check:
        errors = run_self_check(ROOT)

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1

    if args.self_check:
        print("PASS validator self-check")
    else:
        print(
            "PASS skill validation: "
            "45 includes resolved, 870 authoritative terms indexed"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
