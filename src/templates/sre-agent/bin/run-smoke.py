#!/usr/bin/env python3
"""Run a bounded read-only Azure SRE Agent smoke test and record tool evidence."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import time

EA_TOOL = 'azure-resource-manager-mcp_list_benefit_utilization'
COST_TOOL = 'azure-resource-manager-mcp_query_costs'


def az(*args):
    result = subprocess.run(['az', *args, '--only-show-errors', '-o', 'json'], check=True,
                            capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def summary(messages, thread, subscription, enrollment):
    executions, searches, results = [], [], []
    marker = re.compile(r'\b(?:PASS|FAIL|BLOCKED|FINOPS_HUB_QUERY_OK|FINOPS_HUB_COSTS_READ_OK|FINOPS_HUB_COSTS_NO_DATA|HTTP [45]\d{2})\b')
    for msg in messages:
        if call := msg.get('mcpToolExecution'):
            payload = json.dumps(call.get('result'))
            executions.append({**{key: call.get(key) for key in ('id', 'fullToolName', 'status', 'completedAt')},
                               'hasError': call.get('error') is not None or bool(re.search(
                                   r'AuthorizationFailed|Unauthorized|Forbidden|isError[\\\s"]*:\s*true', payload, re.I)),
                               'hasResult': call.get('result') is not None,
                               'billingScopeMatched': args_match(call, f'/providers/Microsoft.Billing/billingAccounts/{enrollment}'),
                               'subscriptionScopeMatched': args_match(call, f'/subscriptions/{subscription}')})
        if search := msg.get('toolSearchToolResult'):
            searches.append(search.get('activatedTools', []))
        if msg.get('isComplete') and (text := msg.get('text') or '').startswith('UAT_SMOKE_RESULT'):
            results.append({'id': msg.get('id'), 'markers': marker.findall(text)})
    return {'threadId': thread, 'mcpExecutions': executions, 'activatedTools': searches, 'reportedResults': results}


def args_match(call, scope_prefix):
    return scope_prefix.lower() in json.dumps(call.get('parameters')).lower()


def verdict(record, mode):
    markers = {value for result in record['reportedResults'] for value in result['markers']}
    if not record['reportedResults']:
        return 'TIMEOUT'
    if 'FAIL' in markers or 'BLOCKED' in markers:
        return 'FAILED'
    calls = {call['fullToolName']: call for call in record['mcpExecutions']
             if call['status'] == 'Completed' and call['hasResult'] and not call['hasError']}
    if mode == 'native':
        if calls.get(EA_TOOL, {}).get('billingScopeMatched') and calls.get(COST_TOOL, {}).get('subscriptionScopeMatched'):
            return 'PASSED'
    activated = {tool for search in record.get('activatedTools', []) for tool in search}
    if mode == 'hubs' and 'FINOPS_HUB_COSTS_READ_OK' in markers and {'monthly-cost-trend', 'hub-cost-query-proof'} <= activated:
        if calls.get(EA_TOOL, {}).get('billingScopeMatched'):
            return 'PASSED'
    if mode == 'hub-probe' and 'FINOPS_HUB_QUERY_OK' in markers and 'hub-query-probe' in activated:
        return 'PASSED'
    return 'UNVERIFIED'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--agent-id', required=True)
    parser.add_argument('--mode', choices=('native', 'hubs', 'hub-probe'), required=True)
    parser.add_argument('--enrollment', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    subscription = args.agent_id.split('/')[2]
    if not re.fullmatch(r'[0-9a-f-]{36}', subscription, re.I) or not re.fullmatch(r'\d+', args.enrollment):
        parser.error('Invalid subscription or EA enrollment.')
    endpoint = az('resource', 'show', '--ids', args.agent_id, '--api-version', '2026-01-01',
                  '--query', 'properties.agentEndpoint').rstrip('/')
    shell_args = ['rest', '--resource', 'https://azuresre.dev']
    instruction = ('Read-only acceptance test. Activate the exact registered tools using ToolSearch. '
                   'If needed, use Task with the configured specialist. No writes, memory, or message delivery. '
                   'Never substitute a tool. After executing, start your final response with UAT_SMOKE_RESULT '
                   'and report only PASS, FAIL, or BLOCKED per tool, any HTTP error code, and any literal probe result. '
                   'Do not include quantities, prices, or financial rows. ')
    ea = ('Run azure-resource-manager-mcp_list_benefit_utilization at '
          f'/providers/Microsoft.Billing/billingAccounts/{args.enrollment}. ')
    probes = {
        'native': (f'Run azure-resource-manager-mcp_query_costs against /subscriptions/{subscription} '
                   'for a period of two complete days within the last week with PreTaxCost. ' + ea),
        'hubs': ('Run monthly-cost-trend against the configured Hub with Kusto datetime expressions '
                 'for both arguments, using the prior complete month for the interval. Also run hub-cost-query-proof '
                 'and copy its literal nonfinancial output to show that Costs() returned data. ' + ea),
        'hub-probe': 'Run the exact hub-query-probe Kusto tool and return its literal nonfinancial output.',
    }
    response = az(*shell_args, '--method', 'post', '--url', endpoint + '/api/v1/threads', '--body',
                  json.dumps({'startMessage': {'text': instruction + probes[args.mode]}}), '--query', '{id:id || threadId}')
    thread = response['id']
    print(f'{args.mode} smoke thread: {thread}', flush=True)
    args.output.parent.mkdir(exist_ok=True, parents=True)
    deadline = time.monotonic() + 300
    while True:
        payload = az(*shell_args, '--method', 'get', '--url', endpoint + f'/api/v1/threads/{thread}/messages')
        record = summary(payload if isinstance(payload, list) else payload.get('value', []), thread, subscription, args.enrollment)
        args.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        if record['reportedResults'] or time.monotonic() >= deadline:
            record['verdict'] = verdict(record, args.mode)
            args.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
            print(f"{args.output}: {record['verdict']}")
            return 0 if record['verdict'] == 'PASSED' else 2
        time.sleep(15)


if __name__ == '__main__':
    raise SystemExit(main())
