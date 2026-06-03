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


def read_kql_body(path: pathlib.Path) -> str:
    text = read_text(path)
    lines = text.splitlines()
    start = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "" or stripped.startswith("//"):
            continue
        start = index
        break
    return "\n".join(lines[start:]).rstrip()


def collect_kql_comment_block(path: pathlib.Path) -> list[str]:
    comments: list[str] = []
    for line in read_text(path).splitlines():
        stripped = line.strip()
        if stripped == "":
            continue
        if not stripped.startswith("//"):
            break
        comments.append(stripped[2:].strip())
    return comments


def kql_description(path: pathlib.Path) -> str:
    comments = collect_kql_comment_block(path)
    query_name = path.stem.replace("-", " ")
    description_lines: list[str] = []
    in_description = False
    for comment in comments:
        if comment == "Description:":
            in_description = True
            continue
        if comment == "Parameters:" or comment.startswith("Query:"):
            if in_description:
                break
            if comment.startswith("Query:"):
                query_name = comment.split(":", 1)[1].strip() or query_name
            continue
        if in_description:
            description_lines.append(comment)
    description = " ".join(part for part in description_lines if part)
    if not description:
        description = f"Runs the {query_name} FinOps Hub catalog query."
    return description


def kql_parameters(path: pathlib.Path) -> list[JsonObject]:
    comments = collect_kql_comment_block(path)
    query = read_kql_body(path)
    parameters: list[JsonObject] = []
    in_parameters = False
    for comment in comments:
        if comment == "Parameters:":
            in_parameters = True
            continue
        if not in_parameters:
            continue
        if comment.startswith("Each row") or comment.startswith("Use this query"):
            break
        if comment.lower().startswith("none"):
            break
        if ":" not in comment:
            continue
        name, raw_description = comment.split(":", 1)
        name = name.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            continue
        if not re.search(rf"^let\s+{re.escape(name)}\s*=", query, flags=re.MULTILINE):
            continue
        if any(parameter["name"] == name for parameter in parameters):
            continue
        parameters.append(
            {
                "name": name,
                "type": "string",
                "description": raw_description.strip(),
                "required": True,
            }
        )
    return parameters


def replace_kql_parameter_defaults(query: str, parameters: list[JsonObject]) -> str:
    for parameter in parameters:
        name = re.escape(str(parameter["name"]))
        query = re.sub(
            rf"^let\s+{name}\s*=\s*[^;\n]+;",
            f"let {parameter['name']} = ##{parameter['name']}##;",
            query,
            count=1,
            flags=re.MULTILINE,
        )
    return query


def collect_catalog_kusto_tools(recipe_dir: pathlib.Path) -> list[JsonObject]:
    catalog_dir = (recipe_dir / "../../../../queries/catalog").resolve()
    if not catalog_dir.is_dir():
        raise SystemExit(f"FinOps Hub query catalog not found: {catalog_dir}")

    generated: list[JsonObject] = []
    for path in sorted(catalog_dir.glob("*.kql")):
        name = path.stem
        parameters = kql_parameters(path)
        query = replace_kql_parameter_defaults(read_kql_body(path), parameters)
        spec: JsonObject = {
            "type": "KustoTool",
            "connector": "finops-hub-kusto",
            "toolMode": "Auto",
            "description": kql_description(path),
            "database": "Hub",
            "query": query,
        }
        if parameters:
            spec["parameters"] = parameters
        generated.append(
            {
                "api_version": "azuresre.ai/v2",
                "kind": "ExtendedAgentTool",
                "metadata": {"name": name},
                "spec": spec,
            }
        )
    return generated


def validate_explicit_tools(tools: list[JsonObject]) -> None:
    explicit_kusto_names: list[str] = []
    for tool in tools:
        name = metadata_name(tool)
        spec = tool.get("spec") or {}
        if spec.get("type") == "KustoTool":
            explicit_kusto_names.append(name)
    if explicit_kusto_names:
        raise SystemExit(
            "Kusto tools must be generated from src/queries/catalog/*.kql; "
            "remove explicit Kusto YAML file(s): "
            + ", ".join(sorted(explicit_kusto_names))
        )


def catalog_kpi_tool_names(recipe_dir: pathlib.Path) -> set[str]:
    kpi_path = (recipe_dir / "../../../../queries/KPI.md").resolve()
    if not kpi_path.is_file():
        raise SystemExit(f"FinOps KPI catalog not found: {kpi_path}")
    text = read_text(kpi_path)
    return set(re.findall(r"\[([a-z0-9-]+)\]\(catalog/\1\.kql\)", text))


def validate_tool_and_task_coverage(recipe_dir: pathlib.Path, extras: JsonObject) -> None:
    catalog_dir = (recipe_dir / "../../../../queries/catalog").resolve()
    catalog_names = {path.stem for path in catalog_dir.glob("*.kql")}
    tools = extras.get("tools") or []
    tool_names = [metadata_name(tool) for tool in tools]
    duplicate_names = sorted({name for name in tool_names if tool_names.count(name) > 1})
    if duplicate_names:
        raise SystemExit("Duplicate tool definitions found: " + ", ".join(duplicate_names))

    kusto_names = {
        metadata_name(tool)
        for tool in tools
        if (tool.get("spec") or {}).get("type") == "KustoTool"
    }
    missing_kusto = sorted(catalog_names - kusto_names)
    if missing_kusto:
        raise SystemExit(
            "Catalog query file(s) missing generated Kusto tools: "
            + ", ".join(missing_kusto)
        )

    kpi_names = catalog_kpi_tool_names(recipe_dir)
    missing_kpi_tools = sorted(kpi_names - kusto_names)
    if missing_kpi_tools:
        raise SystemExit(
            "KPI catalog query file(s) missing generated Kusto tools: "
            + ", ".join(missing_kpi_tools)
        )

    scheduled_text = "\n".join(json.dumps(task, sort_keys=True) for task in extras.get("scheduledTasks") or [])
    missing_scheduled_kpis = [
        name
        for name in sorted(kpi_names)
        if not re.search(rf"(?<![A-Za-z0-9_-]){re.escape(name)}(?![A-Za-z0-9_-])", scheduled_text)
    ]
    if missing_scheduled_kpis:
        raise SystemExit(
            "KPI catalog query tool(s) are not requested by any scheduled task: "
            + ", ".join(missing_scheduled_kpis)
        )


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

    explicit_tools = collect_yaml(recipe_dir / "config/tools")
    validate_explicit_tools(explicit_tools)
    generated_tools = collect_catalog_kusto_tools(recipe_dir)

    extras = {
        "connectors": collect_connectors(recipe_dir, args.kusto_connector_uri),
        "builtInTools": load_json(recipe_dir / "config/built-in-tools.json", {"overrides": []}),
        "knowledgeItems": collect_knowledge_items(recipe_dir),
        "skills": collect_skill_directories(recipe_dir / "config/skills"),
        "subagents": ordered_subagents(recipe_dir / "config/subagents"),
        "tools": [*explicit_tools, *generated_tools],
        "scheduledTasks": collect_yaml(recipe_dir / "automations/scheduled-tasks"),
    }
    validate_tool_and_task_coverage(recipe_dir, extras)

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
