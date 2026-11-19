#!/usr/bin/env python3
"""Capture a sanitized, read-only comparison of a reference and UAT agent."""

import argparse
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import quote
from zipfile import ZipFile


def az(*args):
    result = subprocess.run(['az', *args, '--only-show-errors', '-o', 'json'], check=True, stdout=subprocess.PIPE, text=True)
    return json.loads(result.stdout)


def data(endpoint, route, query=None):
    args = ['rest', '--method', 'get', '--resource', 'https://azuresre.dev', '--url', endpoint + route]
    if query:
        args.extend(['--query', query])
    return az(*args)


def read_items(endpoint, route, project):
    response = data(endpoint, route, '{items: value[].' + project + ', nextLink: nextLink}')
    items = response['items'] or []
    next_link = response.get('nextLink')
    while next_link:
        if next_link.startswith(endpoint + '/'):
            next_link = next_link.removeprefix(endpoint)
        if not next_link.startswith('/') or next_link.startswith('//'):
            raise ValueError('Unexpected next link for SRE Agent inventory')
        response = data(endpoint, next_link, '{items: value[].' + project + ', nextLink: nextLink}')
        items.extend(response['items'] or [])
        next_link = response.get('nextLink')
    return sorted(items, key=lambda x: x['name'])


def inventory(resource_id, teams, expected=None):
    agent = az('resource', 'show', '--ids', resource_id, '--api-version', '2026-01-01',
               '--query', '{id:id, endpoint:properties.agentEndpoint, state:properties.provisioningState, '
               'mode:properties.actionConfiguration.mode, access:properties.actionConfiguration.accessLevel, '
               'identity:identity.type, principal:identity.principalId, source:tags."cost-source"}')
    endpoint = agent.pop('endpoint').rstrip('/')
    extended = '/api/v2/extendedAgent/'
    agent['connectors'] = read_items(endpoint, extended + 'connectors', '{name:name, type:properties.dataConnectorType, '
                                    'identity:properties.identity, visibleTools:properties.extendedProperties.toolsVisibleToMetaAgent}')
    agent['customTools'] = read_items(endpoint, extended + 'tools', '{name:name, type:properties.type}')
    agent['skills'] = read_items(endpoint, extended + 'skills', '{name:name}')
    agent['subagents'] = read_items(endpoint, extended + 'agents', '{name:name, tools:properties.tools, '
                                   'mcpTools:properties.mcpTools, handoffs:properties.handoffs}')
    schedules = data(endpoint, '/api/v1/scheduledtasks',
                     '[].{name:name, cron:cronExpression, owner:agent, mode:agentMode, status:status, prompt:agentPrompt}')
    schedule_prompts = {task['name']: task.pop('prompt') for task in schedules}
    agent['schedules'] = sorted(schedules, key=lambda task: task['name'])
    connector = quote(teams, safe='')
    agent['teams'] = data(endpoint, f'/api/v2/connectorV2/connections/{connector}',
                          '{name:name, status:properties.overallStatus}')
    agent['teams']['operations'] = data(endpoint, f'/api/v2/connectorV2/mcpservers/{connector}',
                                        'properties.connectors[].operations[].name')
    agent['toolPermissions'] = data(endpoint, '/api/v2/agent/settings/global', 'permissions')
    runtime = data(endpoint, '/api/v2/agent/tools', 'data[].{name:name, enabled:enabled, permission:customPermission}')
    agent['runtimeTools'] = sorted(runtime, key=lambda item: item['name'])
    if expected is not None:
        instructions = data(endpoint, '/api/v2/agent/customInstructions', 'instructions')
        agent['packageChecks'] = audit_package(expected, agent, schedule_prompts, instructions)
    return agent


def compare(reference, uat, key):
    a = {x['name']: x for x in reference[key]}
    b = {x['name']: x for x in uat[key]}
    return {'referenceCount': len(a), 'uatCount': len(b), 'referenceOnly': sorted(a.keys() - b.keys()),
            'uatOnly': sorted(b.keys() - a.keys()),
            'changed': sorted(name for name in a.keys() & b.keys() if a[name] != b[name])}


def roster(expected, observed):
    """Report missing, unexpected, duplicate and present entries without collapsing duplicates."""
    actual = set(observed)
    return {'expected': len(expected), 'present': len(expected & actual), 'missing': sorted(expected - actual),
            'unexpected': sorted(actual - expected),
            'duplicates': sorted(name for name in actual if observed.count(name) != 1)}


def audit_package(expected, actual, schedule_prompts, instructions):
    names = lambda items: {item['metadata']['name'] for item in items}
    knowledge = {re.sub(r'-+', '-', re.sub(r'[^a-z0-9-]+', '-', item['name'].lower())).strip('-')
                 for item in expected['knowledgeItems']}
    profile_connectors = {item['name'] for item in expected['connectors']}
    expected_rosters = {'connectors': profile_connectors | knowledge,
                        **{key: names(expected[spec]) for key, spec in
                           [('customTools', 'tools'), ('subagents', 'subagents'), ('skills', 'skills'), ('schedules', 'scheduledTasks')]}}
    rosters = {key: roster(values, [item['name'] for item in actual[key]]) for key, values in expected_rosters.items()}
    live_connectors = {item['name']: item for item in actual['connectors']}
    connector_checks = []
    for item in expected['connectors']:
        props = item['properties']
        live = live_connectors.get(item['name'], {})
        if live.get('type') != props['dataConnectorType'] or live.get('identity') != props['identity']:
            connector_checks.append(item['name'])
        elif set(live.get('visibleTools') or []) != set(props.get('extendedProperties', {}).get('toolsVisibleToMetaAgent', [])):
            connector_checks.append(item['name'])
    types = {item['name']: item['type'] for item in actual['customTools']}
    live_agents = {item['name']: item for item in actual['subagents']}
    live_schedules = {item['name']: item for item in actual['schedules']}
    expected_runtime = {item['name']: item['enabled'] for item in expected['builtInTools']['overrides']}
    expected_runtime.update({name: True for name in expected_rosters['customTools']})
    for connector in expected['connectors']:
        tools = connector['properties'].get('extendedProperties', {}).get('toolsVisibleToMetaAgent', [])
        expected_runtime.update({name: True for name in tools})
    runtime = {item['name']: item for item in actual['runtimeTools']}
    checks = {
        'connectorsWithWrongConfig': connector_checks,
        'knowledgeWithWrongType': sorted(name for name in knowledge if live_connectors.get(name, {}).get('type') != 'KnowledgeFile'),
        'toolsWithWrongType': sorted(item['metadata']['name'] for item in expected['tools']
                                     if types.get(item['metadata']['name']) != item['spec']['type']),
        'runtimeCatalogMismatches': sorted(name for name, enabled in expected_runtime.items()
                                           if runtime.get(name, {}).get('enabled') != enabled),
        'enabledWithoutExpectedDeny': sorted(name for name in expected['toolPermissions']['deny']
                                             if runtime.get(name, {}).get('enabled') is True and
                                             (runtime[name].get('permission') or '').lower() != 'deny'),
        'subagentBindingMismatches': sorted(
            item['metadata']['name'] for item in expected['subagents']
            if any(set(item['spec'].get(key, [])) != set(live_agents.get(item['metadata']['name'], {}).get(key) or [])
                   for key in ('tools', 'mcpTools', 'handoffs'))),
        'scheduleMismatches': sorted(item['metadata']['name'] for item in expected['scheduledTasks']
                                     if not schedule_matches(item, live_schedules, schedule_prompts)),
    }
    bindings = {op['name'] for op in expected['connectorV2'][0]['spec']['operations']}
    flags = {'agentMode': actual['mode'].lower() == 'review' and actual['access'] == 'Low',
             'profileAndState': actual['source'] == expected['mode'] and actual['state'] == 'Succeeded',
             'teamsBindingOnly': actual['teams']['name'] == expected['connectorV2'][0]['spec']['connectionName'] and
             set(actual['teams']['operations']) == bindings,
             'instructions': instructions == expected['customInstructions'],
             'permissions': all(set(expected['toolPermissions'].get(key, [])) == set(actual['toolPermissions'].get(key) or [])
                                for key in ('allow', 'ask', 'deny'))}
    clean_rosters = all(not (record['missing'] or record['unexpected'] or record['duplicates']) for record in rosters.values())
    return {'status': 'PASSED' if clean_rosters and not any(checks.values()) and all(flags.values()) else 'FAILED',
            'rosters': rosters, 'mismatches': checks, 'verified': flags, 'runtimeChecked': len(expected_runtime)}


def schedule_matches(item, schedules, prompts):
    name = item['metadata']['name']
    spec = item['spec']
    live = schedules.get(name, {})
    return (live.get('cron') == spec['schedule'] and live.get('owner') == spec['agent'] and
            (live.get('mode') or '').lower() == spec['mode'].lower() and prompts.get(name) == spec['prompt'] and
            (live.get('status') or '').lower() in {'active', 'enabled'})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ('reference', 'reference-teams', 'uat', 'deployment', 'subscription'):
        parser.add_argument('--' + arg, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--package', type=Path, help='Exact release ZIP deployed to UAT')
    parser.add_argument('--profile', choices=('native', 'hubs'))
    args = parser.parse_args()
    if bool(args.package) != bool(args.profile):
        parser.error('--package and --profile must be supplied together.')
    expected = None
    if args.package:
        with ZipFile(args.package) as package:
            expected = json.loads(package.read(f'{args.profile}/extras.json'))
    reference = inventory(args.reference, args.reference_teams)
    uat = inventory(args.uat, 'finops-teams', expected)
    deployment = az('deployment', 'sub', 'show', '--subscription', args.subscription, '--name', args.deployment,
                    '--query', '{id:id, name:name, state:properties.provisioningState, timestamp:properties.timestamp, '
                    'correlationId:properties.correlationId}')
    result = {'capturedAt': datetime.now(timezone.utc).isoformat(), 'deployment': deployment,
              'reference': reference, 'uat': uat,
              'comparison': {key: compare(reference, uat, key) for key in ('connectors', 'customTools', 'skills', 'subagents', 'schedules')}}
    result['matchingReferenceScheduleNamesAndCron'] = (
        [(item['name'], item['cron']) for item in reference['schedules']] ==
        [(item['name'], item['cron']) for item in uat['schedules']])
    if args.package:
        result['package'] = {'sha256': sha256(args.package.read_bytes()).hexdigest(), 'profile': args.profile}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(args.output)
    return 0 if expected is None or uat['packageChecks']['status'] == 'PASSED' else 2


if __name__ == '__main__':
    raise SystemExit(main())
