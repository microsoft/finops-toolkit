#!/usr/bin/env python3
"""Deploy a FinOps Toolkit SRE Agent from the release package."""

import argparse
import json
import os
from pathlib import Path
import re
from shutil import which
import subprocess
import sys
from tempfile import TemporaryDirectory
from uuid import NAMESPACE_URL, uuid5
from zipfile import ZipFile

ENROLLMENT_READER = '24f8edb6-1668-4659-b5e2-40bb5f3a7d7e'
BILLING_API = '2019-10-01-preview'
CLUSTER_ID = re.compile(r'/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft\.Kusto/clusters/([a-z0-9-]+)', re.I)
CLUSTER_URI = re.compile(r'https://([a-z0-9-]+)(?:\.[a-z0-9-]+)*\.kusto\.windows\.net/Hub')


def az(*args):
    result = subprocess.run(['az', *args, '--only-show-errors', '-o', 'json'], check=True, stdout=subprocess.PIPE, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, default=Path(__file__).with_name('sre-agent-recipe.zip'))
    parser.add_argument('--mode', choices=['native', 'hubs'], required=True)
    parser.add_argument('--subscription', required=True)
    parser.add_argument('--resource-group', required=True)
    parser.add_argument('--name', required=True, help='Agent base name; the mode is appended')
    parser.add_argument('--location', required=True)
    parser.add_argument('--cluster-uri')
    parser.add_argument('--cluster-resource-id')
    parser.add_argument('--ea-enrollment', help='Grant EnrollmentReader to the runtime principal')
    parser.add_argument('--subscription-reader', action='store_true')
    parser.add_argument('--subscription-cost-reader', action='store_true')
    parser.add_argument('--dry-run', action='store_true', help='Validate package and print deployment parameters without Azure calls')
    parser.add_argument('--validate', action='store_true', help='Validate using Azure without creating resources')
    parser.add_argument('--resume', metavar='DEPLOYMENT', help='Wait for an existing ARM deployment and apply its profile')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{1,54}[a-z0-9]', args.name):
        parser.error('Agent base name must be 3–56 lowercase letters, digits, or hyphens, beginning and ending with a letter or digit.')
    if not re.fullmatch(r'[a-zA-Z0-9._()-]{1,90}', args.resource_group):
        parser.error('Enter a valid resource group name.')
    if args.ea_enrollment and not re.fullmatch(r'\d+', args.ea_enrollment):
        parser.error('EA enrollment must contain only digits.')
    if args.mode == 'native' and (args.cluster_uri or args.cluster_resource_id):
        parser.error('Native mode does not accept a hub cluster URI or resource ID.')
    if args.mode == 'hubs':
        uri = CLUSTER_URI.fullmatch(args.cluster_uri or '')
        resource_id = CLUSTER_ID.fullmatch(args.cluster_resource_id or '')
        if not uri or not resource_id or uri[1].lower() != resource_id[1].lower():
            parser.error('Hubs mode requires a /Hub URI and a matching ADX cluster resource ID.')
    if args.dry_run and args.validate:
        parser.error('Choose either --dry-run or --validate.')
    if args.resume and (args.dry_run or args.validate):
        parser.error('--resume must be used with a live deployment.')
    required = [] if args.dry_run else ['az'] if args.validate else ['az', 'pwsh']
    for executable in required:
        if not which(executable):
            parser.error(f'{executable} is required in PATH.')
    return args


def billing_assignments(scope):
    url = f'https://management.azure.com{scope}/billingRoleAssignments?api-version={BILLING_API}'
    while url:
        if not url.startswith('https://management.azure.com/'):
            raise ValueError('Unexpected billing pagination host.')
        page = az('rest', '--method', 'get', '--url', url)
        yield from page.get('value', [])
        url = page.get('nextLink')


def grant_billing(scope, principal, tenant, directory):
    role = f'{scope}/billingRoleDefinitions/{ENROLLMENT_READER}'

    def matching_assignments():
        return [entry['properties'] for entry in billing_assignments(scope)
                if entry.get('properties', {}).get('principalId', '').lower() == principal.lower()]

    def is_reader(entry):
        return entry.get('roleDefinitionId', '').lower().endswith('/' + ENROLLMENT_READER)

    current = matching_assignments()
    if not any(map(is_reader, current)):
        if current:
            raise ValueError(f'Billing principal {principal} already has another role at {scope}; no change made.')
        assignment = uuid5(NAMESPACE_URL, f'{scope.lower()}/{principal.lower()}/{ENROLLMENT_READER}')
        body = directory / 'billing-assignment.json'
        body.write_text(json.dumps({'properties': {'principalId': principal, 'principalTenantId': tenant,
                                                    'roleDefinitionId': role}}), encoding='utf-8')
        az('rest', '--method', 'put', '--url', f'https://management.azure.com{scope}/billingRoleAssignments/{assignment}?api-version={BILLING_API}',
           '--body', f'@{body}')
    if not any(map(is_reader, matching_assignments())):
        raise ValueError(f'EnrollmentReader not visible for {principal} at {scope}.')
    print(f'EnrollmentReader assignment verified at {scope}; runtime query still required.', flush=True)


def deployment_outputs(result):
    # ARM output property casing can differ from the Bicep identifiers.
    return {key.upper(): output['value'] for key, output in result['properties']['outputs'].items()}


def deploy(args, directory, parameters):
    if args.mode == 'hubs':
        cluster = az('resource', 'show', '--ids', args.cluster_resource_id, '--api-version', '2024-04-13')
        if cluster['properties']['uri'].rstrip('/') + '/Hub' != args.cluster_uri:
            raise ValueError('The Hub URI does not match the endpoint advertised by the ADX resource.')
        for database in ('Hub', 'Ingestion'):
            az('resource', 'show', '--ids', f'{args.cluster_resource_id}/databases/{database}', '--api-version', '2024-04-13')
    billing_scope = f'/providers/Microsoft.Billing/billingAccounts/{args.ea_enrollment}' if args.ea_enrollment else None
    if billing_scope:
        next(billing_assignments(billing_scope), None)  # Verify the caller can see the enrollment before creating resources.

    name = f'{args.name}-{args.mode}'
    if az('group', 'exists', '--subscription', args.subscription, '--name', args.resource_group):
        resources = az('resource', 'list', '--subscription', args.subscription, '--resource-group', args.resource_group,
                       '--resource-type', 'Microsoft.App/agents')
        for resource in resources:
            if resource['name'].lower() == name.lower() and (resource.get('tags') or {}).get('cost-source') != args.mode:
                raise ValueError(f'Existing agent {name} is not tagged for the requested profile. No change made.')
    if args.resume:
        target = ['--subscription', args.subscription, '--name', args.resume]
        prior = az('deployment', 'sub', 'show', *target)
        expected = json.loads(parameters.read_text(encoding='utf-8'))['parameters']
        actual = prior['properties']['parameters']
        if any(actual.get(key, {}).get('value') != item['value'] for key, item in expected.items()):
            raise ValueError('Existing deployment parameters do not match the requested mode, scope, or permissions.')
        print(f'Waiting for existing ARM deployment {args.resume}.', flush=True)
        az('deployment', 'sub', 'wait', *target, '--created', '--interval', '15', '--timeout', '1200')
        result = az('deployment', 'sub', 'show', *target)
    else:
        action = 'validate' if args.validate else 'create'
        print(f'{action.capitalize()} infrastructure for {name}.', flush=True)
        result = az('deployment', 'sub', action, '--subscription', args.subscription, '--location', args.location,
                    '--name', name, '--template-file', str(directory / 'azuredeploy.json'),
                    '--parameters', f'@{parameters}')
    if args.validate:
        print('Azure template validation passed.')
        return
    outputs = deployment_outputs(result)
    principal = outputs['SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID']
    endpoint = outputs['SRE_AGENT_ENDPOINT']
    print(f'Infrastructure deployed for {name}. Applying {args.mode} profile.', flush=True)
    status = 0
    if billing_scope:
        try:
            grant_billing(billing_scope, principal, outputs['SYSTEM_MANAGED_IDENTITY_TENANT_ID'], directory)
        except (ValueError, KeyError, subprocess.CalledProcessError) as error:
            print(f'Billing readiness blocked for {principal} at {billing_scope}: {error}', file=sys.stderr, flush=True)
            status = 1
    env = dict(os.environ, subscriptionId=args.subscription, resourceGroupName=args.resource_group,
               agentName=name, agentEndpoint=endpoint, costSourceMode=args.mode,
               kustoConnectorUri=args.cluster_uri or '', FTK_LOCAL_EXTRAS=str(directory / 'extras.json'))
    subprocess.run(['pwsh', '-NoProfile', '-File', str(directory / 'Apply-SreAgentExtras.ps1')], env=env, check=True)
    print('Complete read-only runtime smoke tests before marking UAT ready.')
    return status


def main():
    args = parse_args()
    source = {'mode': args.mode}
    if args.mode == 'hubs':
        source.update(clusterUri=args.cluster_uri, clusterResourceId=args.cluster_resource_id)
    params = {'resourceGroupName': args.resource_group, 'agentName': args.name, 'location': args.location,
              'costSource': source, 'applyPackagedExtras': False,
              'enableSubscriptionReaderRole': args.subscription_reader,
              'enableSubscriptionCostReaderRole': args.subscription_cost_reader}
    parameters = {'$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
                  'contentVersion': '1.0.0.0', 'parameters': {key: {'value': value} for key, value in params.items()}}
    with TemporaryDirectory(prefix='ftk-sre-') as tmp, ZipFile(args.package) as bundle:
        directory = Path(tmp)
        for member in ['azuredeploy.json', 'Apply-SreAgentExtras.ps1']:
            (directory / member).write_bytes(bundle.read(member))
        extras = json.loads(bundle.read(f'{args.mode}/extras.json'))
        if extras['mode'] != args.mode:
            raise ValueError('Package mode does not match request.')
        (directory / 'extras.json').write_text(json.dumps(extras), encoding='utf-8')
        if args.dry_run:
            print(json.dumps(parameters, indent=2))
            return 0
        parameters_path = directory / 'parameters.json'
        parameters_path.write_text(json.dumps(parameters), encoding='utf-8')
        return deploy(args, directory, parameters_path)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
