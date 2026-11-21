#!/usr/bin/env python3
"""Build both FinOps profiles into one deployment ZIP."""

import argparse
import json
from pathlib import Path
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

import yaml
from catalog import build_tools

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT.parent
PROFILES = ROOT / 'profiles'
SHARED = PROFILES / 'shared'
MCP = 'azure-resource-manager-mcp'
TEAMS = 'finops-teams'
CAPACITY = ['vm-quota-usage', 'non-compute-quotas', 'db-service-quotas',
            'sku-availability', 'capacity-reservation-groups', 'zone-mapping',
            'benefit-recommendations']
CHARTS = ['PlotBarChart', 'PlotPieChart', 'PlotAreaChartWithCorrelation']
WRITE_TOOLS = ['deploy-budget', 'deploy-bulk-budgets', 'deploy-anomaly-alert',
               'deploy-bulk-anomaly-alerts', 'suppress-advisor-recommendations',
               f'{MCP}_create_budget', 'RunAzCliWriteCommands']


def load(path):
    return yaml.safe_load(path.read_text(encoding='utf-8'))


def skill(path):
    text = path.read_text(encoding='utf-8')
    metadata = yaml.safe_load(text.split('---', 2)[1])
    return {'metadata': {'name': metadata['name'], 'description': metadata['description'], 'spec': {'tools': []}},
            'skillContent': text}


def knowledge(name, text):
    return {'name': name, 'content': text, 'contentType': 'text/markdown'}


def subagent(name, instructions, tools=(), mcp=(), description=None):
    return {'metadata': {'name': name}, 'spec': {
        'name': name, 'instructions': instructions, 'handoffDescription': description or instructions,
        'tools': ['SearchMemory', *tools], 'mcpTools': list(mcp),
        'handoffs': [], 'enableVanillaMode': True,
    }}


def profile(mode):
    hub = mode == 'hubs'
    source = PROFILES / mode
    native_mcp = load(PROFILES / 'native/connector.json')
    selected = native_mcp['properties']['extendedProperties']
    for key in ('toolsVisibleToMetaAgent', 'selectedTools'):
        selected[key].remove('create_budget')
    selected['headers'] = {'x-mcp-toolset': selected['x-mcp-toolset']}
    mcp = [f'{MCP}_{name}' for name in selected['selectedTools']]
    # Workspace tool search uses qualified tool identifiers, as in the live Hubs reference.
    selected['toolsVisibleToMetaAgent'] = mcp.copy()
    connectors = [native_mcp]
    tools = [load(source / 'tools' / f'{name}.yaml') for name in [*CAPACITY, 'resource-graph-query']]
    if hub:
        connectors.insert(0, load(source / 'connector.json'))
        tools.append(load(source / 'tools/data-freshness-check.yaml'))
        tools.append({'metadata': {'name': 'hub-query-probe'}, 'spec': {
            'type': 'KustoTool', 'connector': 'finops-hub-kusto', 'database': 'Hub', 'toolMode': 'Auto',
            'description': 'Verify the configured Hub database can execute a read-only Kusto query without exposing data.',
            'query': 'print HubQueryProbe = "FINOPS_HUB_QUERY_OK"',
        }})
        tools.append({'metadata': {'name': 'hub-cost-query-proof'}, 'spec': {
            'type': 'KustoTool', 'connector': 'finops-hub-kusto', 'database': 'Hub', 'toolMode': 'Auto',
            'description': 'Read one recent row through the Costs function and return only a nonfinancial verification marker.',
            'query': ('Costs()\n| where ChargePeriodStart >= startofmonth(ago(32d))\n| take 1\n'
                      '| summarize Observed = count()\n'
                      '| project Proof = iff(Observed > 0, "FINOPS_HUB_COSTS_READ_OK", "FINOPS_HUB_COSTS_NO_DATA")'),
        }})
        tools.extend(build_tools(TEMPLATES.parent / 'queries/catalog'))
    names = {tool['metadata']['name'] for tool in tools}

    teams = load(SHARED / 'microsoft-teams.yaml')
    teams['spec']['connectionName'] = TEAMS
    teams_tools = [op['name'] for op in teams['spec']['operations']]
    agents = [
        subagent('azure-capacity-manager', 'Collect read-only quota, SKU, zone, reservation group, and capacity evidence. '
                 'Report scope, freshness, headroom, and missing evidence. Never request quota or change resources.', CAPACITY),
        subagent('chief-financial-officer', 'Frame executive decisions from supplied evidence. '
                 'State confidence, business trade-offs, and data gaps. Do not collect operational data.'),
    ]
    routing = ('Use assigned Azure Cost Management MCP tools for cost and forecast evidence. '
               'Use Task to invoke azure-capacity-manager for capacity evidence and chief-financial-officer for finance framing.')
    if hub:
        analytics = sorted(tool['metadata']['name'] for tool in tools if tool['spec']['type'] == 'KustoTool')
        agents.extend([
            subagent('ftk-database-query', 'Read cost, allocation, savings, and fiscal data from the configured Hub database. '
                     'Use the catalog tools. Do not claim that empty transactions prove no transactions or that an unvalidated MACC result proves a contractual obligation.', analytics),
            subagent('ftk-hubs-agent', 'Check the Hub database freshness and scope using the attached read tools. '
                     'Report ingestion, reachability, and data coverage gaps without changing the hub.', ['data-freshness-check', 'resource-graph-query']),
        ])
        routing = ('Use Task to invoke ftk-database-query for Hub financial history and ftk-hubs-agent for Hub freshness and scope. '
                   'Use assigned Azure Cost Management tools for live budgets, alerts, prices, and billing evidence, never as a silent replacement for Hub history. '
                   'Use Task to invoke azure-capacity-manager for quota and capacity evidence and chief-financial-officer for finance framing.')
    agents.append(subagent('finops-practitioner', routing + ' Use the reporting guide in the knowledge base. '
                           'Never change resources. Recommend owner and dependency validation for deletion candidates. '
                           'Post a final report only to a configured Teams channel; otherwise return it in the run output.',
                           ['resource-graph-query', *CHARTS, *teams_tools], mcp,
                           description='Coordinate read-only FinOps evidence, analysis, and reporting.'))

    tasks = []
    for original in load(source / 'schedules.json'):
        original_spec = original['spec']
        filename = original['file']
        focus = {
            'monthly-report': ('Compare supported monthly periods and break down cost drivers, allocation, and forecast.',
                               'Compare monthly billed and effective costs; show allocation, savings, anomalies, and forecast where supported.'),
            'yoy-report': ('Use supported native lookback windows. Without verified prior-year data, label the trend recent-period only.',
                           'Compare matched fiscal periods against the prior year only when both periods have sufficient coverage.'),
            'hubs-health-check': ('', 'Hand off data-freshness-check to ftk-hubs-agent. Distinguish stale costs from empty transactions.'),
            'monitoring-scope-validation': ('', 'Compare Hub observed coverage with subscription inventory. Report uncovered or inaccessible scopes.'),
            'cost-optimization': ('Identify savings candidates. Validate ownership and dependencies before proposing deletion.',) * 2,
            'budget-coverage-audit': ('List existing budgets and report missing or ambiguous coverage. Do not create budgets.',) * 2,
            'alert-coverage-audit': ('Inspect available alert evidence and report gaps. Do not create alerts.',) * 2,
            'advisor-suppression-review': ('Review existing Advisor suppressions and recommend follow-up. Do not add, remove, or renew suppressions.',) * 2,
            'ai-workload-cost-analysis': ('Report available Azure OpenAI and AI workload costs. Do not infer token counts from spend.',
                                          'Use the Hub AI model, application, daily trend, and token breakdown tools. Note uncovered meters and missing tags.'),
            'benefit-recommendation-review': ('Compare reservation and savings plan recommendations by term, lookback, and scope. '
                                              'Distinguish recommendation estimates from realized savings and MACC.',) * 2,
            'compute-utilization-trend': ('Compare VM quota headroom by family and region. '
                                          'Distinguish quota consumption from VM utilization and compare only against documented history.',) * 2,
            'capacity-daily-monitor': ('Check VM quota, capacity reservation utilization, and zone access. Flag missing scopes and high headroom risk.',) * 2,
            'capacity-weekly-supply-review': ('Compare quota headroom, regional SKU availability, reservation utilization, and benefit recommendations.',) * 2,
            'capacity-monthly-planning': ('Identify capacity runway by workload and region. Separate measured demand from forecasts and document owners.',) * 2,
            'capacity-quarterly-strategy': ('Evaluate capacity and resilience risks, recovery options, and commitments. Quantify trade-offs where supported.',) * 2,
            'db-quota-audit': ('Use the database quota tool to compare regional access and quota pressure. Separate missing access from zero usage.',) * 2,
            'non-compute-quota-audit': ('Review storage, network, and service quotas. Distinguish inferred limits from provider-reported limits.',) * 2,
            'sku-availability-audit': ('Check compute SKU region, zone, and subscription restrictions.',
                                       'Check compute restrictions and use the Kusto provider for ADX SKU eligibility; do not infer it from compute.'),
            'storage-paas-growth-forecast': ('Use inventory and quota evidence. Forecast only if you have enough history.',
                                            'Combine inventory and quotas with available storage unit economics; do not turn cost change into usage growth without evidence.'),
        }.get(filename, ('', ''))[int(hub)]
        task = {'metadata': original['metadata'], 'spec': {
            'name': original_spec['name'], 'description': original_spec['description'],
            'schedule': original_spec['schedule'], 'mode': 'Review', 'agent': 'finops-practitioner',
            'prompt': f"{original_spec['description']}. {focus} {routing} "
                      'Collect read-only evidence. State sources, scope, reporting periods, uncertainty, and follow-up. '
                      'Use the reporting guide in the knowledge base. Send only the final report to the configured Teams channel, '
                      'or return it in the run output if Teams is not configured.',
        }}
        tasks.append(task)

    style = TEMPLATES / 'agent-plugin/output-styles/ftk-output-style.md'
    skill_dir = SHARED / 'skills'
    skills = [skill(skill_dir / name / 'SKILL.md') for name in ['azure-capacity-management', 'azure-cost-management']]
    if hub:
        skills.append(skill(skill_dir / 'finops-toolkit/SKILL.md'))
    builtins = load(SHARED / 'tool-overrides.json')
    if hub:
        builtins['overrides'].append({'name': 'KustoClient', 'enabled': True})
    instructions = ('This is a read-only FinOps agent. Use ToolSearch to activate the exact configured '
                    'azure-resource-manager-mcp_* tool for Azure Cost Management, including query_costs and '
                    'list_benefit_utilization. If it is unavailable in the parent, use Task to invoke '
                    'finops-practitioner. Never substitute a different tool without stating the substitution. '
                    'Distinguish no tool execution from a tool error. Never report a test as passed without its result.')
    if hub:
        instructions += (' For Hub analytics, use ToolSearch to activate the catalog query or use Task to invoke '
                         'ftk-database-query. Run hub-query-probe to isolate connectivity without querying financial data. '
                         'Use KustoClient only for read-only diagnostics against the configured Hub. '
                         'Do not infer missing permissions or ingestion failures from an absent tool result.')
    extras = {'mode': mode, 'connectors': connectors, 'connectorV2': [teams], 'tools': tools,
              'subagents': agents, 'scheduledTasks': tasks, 'skills': skills,
              'customInstructions': instructions,
              'builtInTools': builtins,
              'toolPermissions': {'allow': [x['name'] for x in builtins['overrides']],
                                  'ask': [], 'deny': WRITE_TOOLS},
              'knowledgeItems': [knowledge(style.name, style.read_text(encoding='utf-8'))]}
    if len(names) != len(tools) or names.intersection(WRITE_TOOLS):
        raise ValueError(f'{mode}: unexpected or duplicate custom tools')
    if not hub and any(tool['spec']['type'] == 'KustoTool' for tool in tools):
        raise ValueError('Native mode must not contain Kusto tools')
    return extras


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    template = subprocess.check_output(['bicep', 'build', str(ROOT / 'main.bicep'), '--stdout'])
    archive = args.output / 'sre-agent-recipe.zip'
    with ZipFile(archive, 'w') as bundle:
        assets = {
            'azuredeploy.json': template,
            'deploy.py': (ROOT / 'bin/deploy.py').read_bytes(),
            'Apply-SreAgentExtras.ps1': (ROOT / 'infra/scripts/Apply-SreAgentExtras.ps1').read_bytes(),
            **{f'{mode}/extras.json': json.dumps(profile(mode), indent=2).encode() for mode in ('native', 'hubs')},
        }
        for name, payload in assets.items():
            bundle.writestr(ZipInfo(name), payload, compress_type=ZIP_DEFLATED)
    (args.output / 'azuredeploy.json').write_bytes(template)
    (args.output / 'createUiDefinition.json').write_bytes((ROOT / 'createUiDefinition.json').read_bytes())
    print(archive)


if __name__ == '__main__':
    main()
