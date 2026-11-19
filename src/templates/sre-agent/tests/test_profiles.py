"""Local packaging and dry-run checks. These tests never contact Azure."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
HUB_ID = '/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/hub/providers/Microsoft.Kusto/clusters/test-hub'
HUB_ARGS = ['--cluster-uri', 'https://test-hub.eastus2.kusto.windows.net/Hub', '--cluster-resource-id', HUB_ID]


class ProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build = TemporaryDirectory()
        cls.addClassCleanup(build.cleanup)
        cls.directory = Path(build.name)
        subprocess.run([sys.executable, ROOT / 'bin/build-package.py', '--output', cls.directory], check=True)
        cls.package = cls.directory / 'sre-agent-recipe.zip'
        with ZipFile(cls.package) as bundle:
            cls.extras = {mode: json.loads(bundle.read(f'{mode}/extras.json')) for mode in ('native', 'hubs')}
            for name in ['deploy.py', 'azuredeploy.json']:
                (cls.directory / name).write_bytes(bundle.read(name))

    def dry_run(self, mode, *args):
        # Exercise the released CLI outside the source tree.
        return subprocess.run([sys.executable, self.directory / 'deploy.py', '--dry-run', '--mode', mode,
                               '--subscription', '00000000-0000-0000-0000-000000000001',
                               '--resource-group', 'uat', '--name', 'finops-uat', '--location', 'eastus2', *args],
                              capture_output=True, text=True, cwd=self.directory)

    def test_native_has_no_hub_configuration(self):
        profile = self.extras['native']
        self.assertEqual({'Mcp'}, {item['properties']['dataConnectorType'] for item in profile['connectors']})
        self.assertFalse(any(tool['spec']['type'] == 'KustoTool' for tool in profile['tools']))
        self.assertEqual(17, len(profile['scheduledTasks']))
        result = self.dry_run('native')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual({'mode': 'native'}, json.loads(result.stdout)['parameters']['costSource']['value'])

    def test_hubs_has_catalog_and_hub_schedules(self):
        profile = self.extras['hubs']
        actual = {item['metadata']['name'] for item in profile['tools'] if item['spec']['type'] == 'KustoTool'}
        catalog = ROOT.parents[1] / 'queries/catalog'
        self.assertEqual({path.stem for path in catalog.glob('*.kql')} | {'hub-query-probe', 'hub-cost-query-proof'}, actual)
        self.assertIn('monthly-cost-trend', actual)
        self.assertEqual(19, len(profile['scheduledTasks']))
        result = self.dry_run('hubs', *HUB_ARGS)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(HUB_ID, json.loads(result.stdout)['parameters']['costSource']['value']['clusterResourceId'])

    def test_incompatible_inputs_fail(self):
        self.assertNotEqual(0, self.dry_run('native', *HUB_ARGS).returncode)
        self.assertNotEqual(0, self.dry_run('hubs').returncode)
        self.assertNotEqual(0, self.dry_run('hubs', *[HUB_ARGS[0], HUB_ARGS[1].replace('test-hub', 'other'), *HUB_ARGS[2:]]).returncode)

    def test_deny_writes_and_validate_agent_routes(self):
        for profile in self.extras.values():
            deny = set(profile['toolPermissions']['deny'])
            self.assertIn('azure-resource-manager-mcp_create_budget', deny)
            tool_names = {item['metadata']['name'] for item in profile['tools']}
            self.assertFalse(deny.intersection(tool_names))
            self.assertFalse(deny.intersection(profile['toolPermissions']['allow']))
            mcp = next(connector for connector in profile['connectors'] if connector['name'] == 'azure-resource-manager-mcp')
            names = mcp['properties']['extendedProperties']['toolsVisibleToMetaAgent']
            self.assertIn('azure-resource-manager-mcp_query_costs', names)
            self.assertNotIn('azure-resource-manager-mcp_create_budget', names)
            agents = {item['metadata']['name']: item['spec'] for item in profile['subagents']}
            for agent in agents.values():
                self.assertFalse(deny.intersection(agent['tools'] + agent['mcpTools']))
                self.assertEqual([], agent['handoffs'])
                self.assertLessEqual(len(agent['handoffDescription']), 500)
                self.assertTrue({name for name in agent['tools'] if '-' in name} <= tool_names)
            for task in profile['scheduledTasks']:
                self.assertEqual('Review', task['spec']['mode'])
                self.assertIn(task['spec']['agent'], agents)

    def test_portal_and_cli_use_same_template_contract(self):
        template = json.loads((self.directory / 'azuredeploy.json').read_text())
        portal = json.loads((self.directory / 'createUiDefinition.json').read_text())
        self.assertTrue(portal['parameters']['outputs'].keys() <= template['parameters'].keys())
        self.assertIn('costSource', portal['parameters']['outputs'])
        self.assertFalse(template['parameters']['enableSubscriptionReaderRole']['defaultValue'])

    def test_external_grant_names_follow_recreated_identity(self):
        template = json.loads((self.directory / 'azuredeploy.json').read_text())

        def resources(node):
            if isinstance(node, dict):
                if 'type' in node and 'name' in node:
                    yield node
                for value in node.values():
                    yield from resources(value)
            elif isinstance(node, list):
                for value in node:
                    yield from resources(value)

        grants = list(resources(template))
        subscription_roles = [item['name'] for item in grants if item['type'] == 'Microsoft.Authorization/roleAssignments'
                              and 'guid(subscription().id,' in item['name']]
        adx_roles = [item['name'] for item in grants if item['type'] == 'Microsoft.Kusto/clusters/databases/principalAssignments']
        self.assertEqual(1, len(subscription_roles))
        self.assertIn("parameters('principalId')", subscription_roles[0])
        self.assertEqual(2, len(adx_roles))
        self.assertTrue(all("parameters('principalApplicationId')" in name for name in adx_roles))


class DeploymentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('deploy', ROOT / 'bin/deploy.py')
        cls.cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.cli)

    def test_normalizes_arm_output_casing(self):
        outputs = {'properties': {'outputs': {'systeM_MANAGED_IDENTITY_PRINCIPAL_ID': {'value': 'example-agent'}}}}
        self.assertEqual({'SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID': 'example-agent'}, self.cli.deployment_outputs(outputs))

    def test_existing_billing_role_is_not_overwritten(self):
        role = {'properties': {'principalId': 'example-agent', 'roleDefinitionId': '/billingRoleDefinitions/different'}}
        with patch.object(self.cli, 'billing_assignments', return_value=iter([role])), patch.object(self.cli, 'az') as azure:
            with self.assertRaisesRegex(ValueError, 'already has another role'):
                self.cli.grant_billing('/example-scope', 'example-agent', 'example-tenant', ROOT)
            azure.assert_not_called()

    def test_existing_enrollment_reader_assignment_is_reused(self):
        role = {'properties': {'principalId': 'example-agent',
                               'roleDefinitionId': '/billingRoleDefinitions/' + self.cli.ENROLLMENT_READER}}
        with patch.object(self.cli, 'billing_assignments', side_effect=[[role], [role]]), patch.object(self.cli, 'az') as azure:
            self.cli.grant_billing('/example-scope', 'example-agent', 'example-tenant', ROOT)
            azure.assert_not_called()


class InventoryEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('capture_evidence', ROOT / 'bin/capture-evidence.py')
        cls.capture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.capture)

    def test_inventory_detects_missing_duplicates_and_unexpected(self):
        audit = self.capture.roster({'required', 'missing'}, ['required', 'required', 'unmanaged'])
        self.assertEqual({'expected': 2, 'present': 1, 'missing': ['missing'],
                          'unexpected': ['unmanaged'], 'duplicates': ['required']}, audit)

    def test_schedule_audit_checks_prompt_and_active_state(self):
        task = {'metadata': {'name': 'Monthly'}, 'spec': {'agent': 'practitioner', 'mode': 'Review',
                'schedule': '0 9 1 * *', 'prompt': 'Run a read-only report'}}
        live = {'Monthly': {'cron': '0 9 1 * *', 'owner': 'practitioner', 'mode': 'Review', 'status': 'Active'}}
        self.assertTrue(self.capture.schedule_matches(task, live, {'Monthly': 'Run a read-only report'}))
        self.assertFalse(self.capture.schedule_matches(task, live, {'Monthly': 'Different prompt'}))
        live['Monthly']['status'] = 'Paused'
        self.assertFalse(self.capture.schedule_matches(task, live, {'Monthly': 'Run a read-only report'}))


class RuntimeEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('run_smoke', ROOT / 'bin/run-smoke.py')
        cls.smoke = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.smoke)

    def test_agent_summary_without_tool_trace_does_not_pass(self):
        record = {'reportedResults': [{'markers': ['PASS']}], 'mcpExecutions': []}
        self.assertEqual('UNVERIFIED', self.smoke.verdict(record, 'native'))

    def test_hub_probe_without_cost_proof_does_not_pass_hubs(self):
        record = {'reportedResults': [{'markers': ['PASS', 'FINOPS_HUB_QUERY_OK']}], 'mcpExecutions': [],
                  'activatedTools': [['hub-query-probe']]}
        self.assertEqual('UNVERIFIED', self.smoke.verdict(record, 'hubs'))
        self.assertEqual('PASSED', self.smoke.verdict(record, 'hub-probe'))

    def test_native_pass_requires_both_scoped_tool_results(self):
        execution = {'status': 'Completed', 'hasResult': True, 'hasError': False}
        record = {'reportedResults': [{'markers': ['PASS', 'PASS']}], 'mcpExecutions': [
            {**execution, 'fullToolName': self.smoke.EA_TOOL, 'billingScopeMatched': True},
            {**execution, 'fullToolName': self.smoke.COST_TOOL, 'subscriptionScopeMatched': True},
        ]}
        self.assertEqual('PASSED', self.smoke.verdict(record, 'native'))
        record['mcpExecutions'][0]['billingScopeMatched'] = False
        self.assertEqual('UNVERIFIED', self.smoke.verdict(record, 'native'))

if __name__ == '__main__':
    unittest.main()
