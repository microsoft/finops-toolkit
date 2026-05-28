#!/usr/bin/env python3
"""Build SRE Agent extras from a FinOps Toolkit recipe.

The output follows the microsoft/sre-agent apply-extras contract: infrastructure
stays in Bicep/ARM, while data-plane and connector extras are assembled into one
JSON document for the local apply step.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - exercised by shell prereq checks
    raise SystemExit("PyYAML is required. Install with: pip install pyyaml") from exc


JsonObject = dict[str, Any]


def load_json(path: pathlib.Path, default: Any) -> Any:
    if not path.is_file():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_yaml(path: pathlib.Path) -> JsonObject:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise SystemExit(f"YAML manifest must be an object: {path}")
    return data


def yaml_files(root: pathlib.Path) -> list[pathlib.Path]:
    if not root.is_dir():
        return []
    paths: list[pathlib.Path] = []
    for dirpath, _, filenames in os.walk(root, followlinks=True):
        for filename in filenames:
            path = pathlib.Path(dirpath) / filename
            if path.suffix.lower() in {".yaml", ".yml"}:
                paths.append(path)
    return sorted(paths)


def collect_yaml(root: pathlib.Path) -> list[JsonObject]:
    return [load_yaml(path) for path in yaml_files(root)]


def metadata_name(item: JsonObject) -> str:
    metadata = item.get("metadata") or {}
    spec = item.get("spec") or {}
    name = metadata.get("name") or spec.get("name") or item.get("name")
    if not name:
        raise SystemExit(f"Manifest missing metadata.name: {item}")
    return str(name)


def ordered_subagents(root: pathlib.Path) -> list[JsonObject]:
    items = collect_yaml(root)
    by_name = {metadata_name(item): item for item in items}
    dependencies: dict[str, list[str]] = {}
    for name, item in by_name.items():
        spec = item.get("spec") or {}
        handoffs = spec.get("handoffs") or []
        dependencies[name] = [str(handoff) for handoff in handoffs if str(handoff) in by_name]

    ordered: list[JsonObject] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        if name in visiting:
            cycle = " -> ".join([*visiting, name])
            raise SystemExit(f"Subagent handoff cycle detected: {cycle}")
        visiting.add(name)
        for dependency in dependencies[name]:
            visit(dependency)
        visiting.remove(name)
        visited.add(name)
        ordered.append(by_name[name])

    for name in sorted(by_name):
        visit(name)
    return ordered


def parse_frontmatter(text: str) -> JsonObject:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            raw = "\n".join(lines[1:index])
            data = yaml.safe_load(raw) or {}
            if not isinstance(data, dict):
                return {}
            return data
    return {}


def as_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, str):
        return [part for part in re.split(r"[\s,]+", value.strip()) if part]
    return [str(value)]


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def collect_skill_directories(root: pathlib.Path) -> list[JsonObject]:
    if not root.is_dir():
        return []

    skills: list[JsonObject] = []
    for skill_dir in sorted(path for path in root.iterdir() if path.is_dir()):
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.is_file():
            continue

        skill_content = read_text(skill_file)
        frontmatter = parse_frontmatter(skill_content)
        name = str(frontmatter.get("name") or skill_dir.name)
        description = str(frontmatter.get("description") or "")
        tools = as_list(frontmatter.get("tools"))

        additional_files: list[JsonObject] = []
        for dirpath, _, filenames in os.walk(skill_dir, followlinks=True):
            for filename in filenames:
                path = pathlib.Path(dirpath) / filename
                relative_path = path.relative_to(skill_dir).as_posix()
                if relative_path == "SKILL.md":
                    continue
                additional_files.append(
                    {
                        "name": relative_path,
                        "path": relative_path,
                        "content": read_text(path),
                    }
                )

        skills.append(
            {
                "metadata": {
                    "name": name,
                    "description": description,
                    "spec": {"tools": tools},
                },
                "skillContent": skill_content,
                "additionalFiles": sorted(additional_files, key=lambda item: item["name"]),
            }
        )

    return skills


def replace_env_refs(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, str):
        pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")

        def repl(match: re.Match[str]) -> str:
            key = match.group(1)
            return replacements.get(key) or os.environ.get(key) or match.group(0)

        return pattern.sub(repl, value)
    if isinstance(value, list):
        return [replace_env_refs(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: replace_env_refs(item, replacements) for key, item in value.items()}
    return value


def collect_connectors(recipe_dir: pathlib.Path, kusto_connector_uri: str) -> list[JsonObject]:
    config = load_json(recipe_dir / "connectors.json", {"connectors": []})
    raw_connectors = config if isinstance(config, list) else config.get("connectors", [])
    replacements = {}
    if kusto_connector_uri:
        replacements["FINOPS_HUB_CLUSTER_URI"] = kusto_connector_uri

    connectors: list[JsonObject] = []
    for raw in raw_connectors:
        connector = replace_env_refs(raw, replacements)
        properties = connector.get("properties") or {}
        connector_type = str(properties.get("dataConnectorType") or properties.get("type") or "")
        if connector_type.lower() == "kusto" and not kusto_connector_uri:
            continue
        if connector_type.lower() == "kusto":
            properties["dataSource"] = kusto_connector_uri
            connector["properties"] = properties
        connectors.append(connector)
    return connectors


def knowledge_content_type(path: pathlib.Path) -> str:
    suffix = path.suffix.lower()
    return {
        ".md": "text/markdown",
        ".txt": "text/plain",
        ".json": "application/json",
        ".csv": "text/csv",
        ".yaml": "application/yaml",
        ".yml": "application/yaml",
    }.get(suffix, "application/octet-stream")


def collect_knowledge_items(recipe_dir: pathlib.Path) -> list[JsonObject]:
    knowledge_paths: list[pathlib.Path] = []
    knowledge_dir = recipe_dir / "knowledge"
    if knowledge_dir.is_dir():
        knowledge_paths.extend(sorted(path for path in knowledge_dir.iterdir() if path.is_file()))

    output_style = (recipe_dir / "../../../claude-plugin/output-styles/ftk-output-style.md").resolve()
    if not output_style.is_file():
        raise SystemExit(f"Output style knowledge document not found: {output_style}")
    knowledge_paths.append(output_style)

    items: list[JsonObject] = []
    for path in knowledge_paths:
        items.append(
            {
                "name": path.name,
                "content": read_text(path),
                "contentType": knowledge_content_type(path),
                "sourcePath": str(path),
            }
        )
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description="Build FinOps Toolkit SRE Agent extras JSON.")
    parser.add_argument("--recipe", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--kusto-connector-uri", default="")
    args = parser.parse_args()

    recipe_dir = args.recipe.resolve()
    if not recipe_dir.is_dir():
        raise SystemExit(f"Recipe directory not found: {recipe_dir}")

    extras = {
        "connectors": collect_connectors(recipe_dir, args.kusto_connector_uri),
        "builtInTools": load_json(recipe_dir / "config/built-in-tools.json", {"overrides": []}),
        "knowledgeItems": collect_knowledge_items(recipe_dir),
        "skills": collect_skill_directories(recipe_dir / "config/skills"),
        "subagents": ordered_subagents(recipe_dir / "config/subagents"),
        "tools": collect_yaml(recipe_dir / "config/tools"),
        "scheduledTasks": collect_yaml(recipe_dir / "automations/scheduled-tasks"),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        json.dump(extras, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    summary = {key: len(value) for key, value in extras.items() if isinstance(value, list)}
    summary["builtInToolOverrides"] = len((extras["builtInTools"] or {}).get("overrides", []))
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
