#!/usr/bin/env bash
set -euo pipefail
usage() { echo "Usage: $0 <recipe-directory> [--secrets <file>] [--output <prefix>]" >&2; exit "${1:-1}"; }
DIR=""; SECRETS=""; OUT_PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --secrets) SECRETS="$2"; shift 2 ;;
    --output) OUT_PREFIX="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    -*) echo "Unknown option: $1" >&2; usage 1 ;;
    *) DIR="$1"; shift ;;
  esac
done
[ -n "$DIR" ] || usage 1
[ -d "$DIR" ] || { echo "Recipe directory not found: $DIR" >&2; exit 1; }
[ -f "$DIR/agent.json" ] || { echo "Missing $DIR/agent.json" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
[ -n "$OUT_PREFIX" ] || OUT_PREFIX="$DIR"
[ -n "$SECRETS" ] || SECRETS="$DIR/connectors.secrets.env"
[ ! -f "$SECRETS" ] || { set -a; . "$SECRETS"; set +a; }
PARAMS_FILE="${OUT_PREFIX}.parameters.json"
EXTRAS_FILE="${OUT_PREFIX}.extras.json"
python3 - "$DIR" "$PARAMS_FILE" "$EXTRAS_FILE" <<'PYCODE'
import os, sys, json, mimetypes
from pathlib import Path
import yaml
recipe=Path(sys.argv[1]); params_file=Path(sys.argv[2]); extras_file=Path(sys.argv[3])
def load_yaml(path):
    with open(path, encoding='utf-8') as f: return yaml.safe_load(f) or {}
def read(path): return Path(path).read_text(encoding='utf-8')
def collect_yaml(rel):
    out=[]
    for base in [recipe/'config'/rel, recipe/'automations'/rel]:
        if base.is_dir():
            for p in sorted(list(base.glob('*.yaml'))+list(base.glob('*.yml'))): out.append(load_yaml(p))
    return out
def parse_frontmatter(text):
    if text.startswith('---'):
        parts=text.split('---',2)
        if len(parts)>=3: return yaml.safe_load(parts[1]) or {}, parts[2].lstrip('\n')
    return {}, text
def collect_skills():
    base=recipe/'config/skills'; out=[]
    if not base.is_dir(): return out
    for d in sorted([p for p in base.iterdir() if p.is_dir()]):
        skill_md=d/'SKILL.md'
        if not skill_md.exists(): skill_md=d/'README.md'
        if skill_md.exists(): meta, content=parse_frontmatter(read(skill_md))
        else: meta, content={}, ''
        name=meta.get('name') or d.name
        desc=meta.get('description') or (content.strip().split('\n')[0].lstrip('# ').strip() if content.strip() else name)
        tools=meta.get('tools') or []
        files=[]
        for p in sorted(d.rglob('*')):
            if p.is_file() and p != skill_md:
                try: files.append({'path': str(p.relative_to(d)), 'content': read(p)})
                except UnicodeDecodeError: pass
        out.append({'metadata': {'name': name, 'description': desc, 'spec': {'tools': tools}}, 'skillContent': content, 'additionalFiles': files})
    return out
def resolve_env(obj):
    if isinstance(obj,str):
        for k,v in os.environ.items(): obj=obj.replace('${'+k+'}', v)
        return obj
    if isinstance(obj,list): return [resolve_env(x) for x in obj]
    if isinstance(obj,dict): return {k:resolve_env(v) for k,v in obj.items()}
    return obj
agent=json.loads(read(recipe/'agent.json'))
conn_raw={'toggles':{},'connectors':[]}
if (recipe/'connectors.json').exists(): conn_raw=resolve_env(json.loads(read(recipe/'connectors.json')))
connectors=conn_raw if isinstance(conn_raw,list) else conn_raw.get('connectors',[])
connectors=[c for c in connectors if c.get('properties',{}).get('dataSource','') and '${' not in c.get('properties',{}).get('dataSource','')]
ctog={} if isinstance(conn_raw,list) else conn_raw.get('toggles',{})
knowledge=[]
if (recipe/'knowledge').is_dir():
    for p in sorted((recipe/'knowledge').glob('*')):
        if p.is_file(): knowledge.append({'filename': p.name, 'mimeType': mimetypes.guess_type(p.name)[0] or 'text/plain', 'triggerIndexing': True, 'localPath': str(p.resolve())})
params={'$schema':'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#','contentVersion':'1.0.0.0','parameters':{
  'agentName': {'value': agent['identity']['agentName']},
  'agentResourceGroupName': {'value': agent['identity']['resourceGroup']},
  'location': {'value': agent['identity'].get('location','eastus2')},
  'targetResourceGroups': {'value': agent['identity'].get('targetResourceGroups',[])},
  'accessLevel': {'value': agent.get('access',{}).get('accessLevel','Low')},
  'actionMode': {'value': agent.get('access',{}).get('actionMode','Review')},
  'upgradeChannel': {'value': agent.get('upgradeChannel','Preview')},
  'defaultModelProvider': {'value': agent.get('defaultModelProvider','Anthropic')},
  'defaultModelName': {'value': agent.get('defaultModelName','Automatic')},
  'monthlyAgentUnitLimit': {'value': int(agent.get('monthlyAgentUnitLimit',10000))},
  'tags': {'value': agent.get('tags',{})},
  'existingManagedIdentityId': {'value': agent.get('existingUamiId','')},
  'existingAgentAppInsightsId': {'value': agent.get('existingAgentAppInsightsId','')},
  'enableAppInsightsConnector': {'value': bool(ctog.get('enableAppInsightsConnector',False))},
  'appInsightsResourceId': {'value': ctog.get('appInsightsResourceId','')},
  'appInsightsAppId': {'value': ctog.get('appInsightsAppId','')},
  'enableLogAnalyticsConnector': {'value': bool(ctog.get('enableLogAnalyticsConnector',False))},
  'lawResourceId': {'value': ctog.get('lawResourceId','')},
  'enableAzureMonitorConnector': {'value': bool(ctog.get('enableAzureMonitorConnector',False))},
  'azureMonitorLookbackDays': {'value': int(ctog.get('azureMonitorLookbackDays',7))},
  'enableDailyHealthCheckTask': {'value': bool(agent.get('toggles',{}).get('enableDailyHealthCheckTask',False))},
  'enableDenyProdDeletesHook': {'value': bool(agent.get('toggles',{}).get('enableDenyProdDeletesHook',False))},
  'enableSafetyRulesPrompt': {'value': bool(agent.get('toggles',{}).get('enableSafetyRulesPrompt',False))},
  'enableWebhookBridge': {'value': bool(agent.get('toggles',{}).get('enableWebhookBridge',False))},
  'webhookBridgeTriggerUrl': {'value': agent.get('toggles',{}).get('webhookBridgeTriggerUrl','')},
  'connectors': {'value': [c for c in connectors if c.get('properties',{}).get('dataConnectorType') not in ('Mcp','KnowledgeFile')]},
  'tools': {'value': collect_yaml('tools')},
  'skills': {'value': collect_skills()},
  'subagents': {'value': collect_yaml('subagents')},
  'scheduledTasks': {'value': []}, 'incidentFilters': {'value': []}, 'commonPrompts': {'value': []}, 'pluginConfigs': {'value': []}
}}
extras={'repos': [], 'incidentPlatforms': collect_yaml('incident-platforms'), 'incidentFilters': collect_yaml('incident-filters'), 'scheduledTasks': collect_yaml('scheduled-tasks'), 'hooks': collect_yaml('hooks'), 'commonPrompts': [], 'httpTriggers': [], 'knowledge': knowledge, 'knowledgeItems': [], 'synthesizedKnowledge': [], 'synthesizedKnowledgeDir': '', 'repoInstructions': [], 'plugins': {'marketplaces': [], 'installations': []}, 'connectors': [c for c in connectors if c.get('properties',{}).get('dataConnectorType') in ('Mcp','KnowledgeFile')]}
params_file.parent.mkdir(parents=True, exist_ok=True)
extras_file.parent.mkdir(parents=True, exist_ok=True)
params_file.write_text(json.dumps(params, indent=2)+'\n', encoding='utf-8')
extras_file.write_text(json.dumps(extras, indent=2)+'\n', encoding='utf-8')
print(f"Wrote {params_file}")
print(f"Wrote {extras_file}")
print(f"subagents={len(params['parameters']['subagents']['value'])} skills={len(params['parameters']['skills']['value'])} tools={len(params['parameters']['tools']['value'])} scheduledTasks={len(extras['scheduledTasks'])} connectors={len(connectors)}")
PYCODE
