// T-19: RTM FR-1.1
// T-19: RTM FR-2.1
// T-19: RTM FR-3.1
// T-19: RTM FR-3.2
// T-19: RTM FR-4.1
// T-19: RTM FR-4.2
// T-19: RTM FR-4.3
// T-19: RTM NFR-4

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

function repoPath(...segments) {
  return path.join(repoRoot, ...segments);
}

function readRepoFile(...segments) {
  return fs.readFileSync(repoPath(...segments), 'utf8');
}

function assertFileExists(...segments) {
  const filePath = repoPath(...segments);
  assert.ok(fs.existsSync(filePath), `Expected file to exist: ${path.relative(repoRoot, filePath)}`);
  return filePath;
}

function assertMatches(text, pattern, message) {
  assert.match(text, pattern, message);
}

function stripJsoncComments(text) {
  return text
    .split(/\r?\n/u)
    .filter((line) => !line.trimStart().startsWith('//'))
    .join('\n');
}

function readJsoncFile(...segments) {
  return JSON.parse(stripJsoncComments(readRepoFile(...segments)));
}

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const agentFiles = [
  'azure-capacity-manager.yaml',
  'chief-financial-officer.yaml',
  'finops-practitioner.yaml',
  'ftk-database-query.yaml',
  'ftk-hubs-agent.yaml',
];

const skillFiles = [
  ['azure-capacity-management', 'FR-2.1'],
  ['azure-cost-management', 'FR-2.1'],
  ['finops-toolkit', 'FR-2.1'],
];

test('TC-1.1–TC-1.5: agent YAML files use azuresre.ai/v2 and required fields', () => {
  for (const fileName of agentFiles) {
    assertFileExists('sre-config', 'agents', fileName);
    const text = readRepoFile('sre-config', 'agents', fileName);
    const expectedName = fileName.replace(/\.ya?ml$/u, '');

    assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, `${fileName} must use azuresre.ai/v2`);
    assertMatches(text, /^kind:\s*ExtendedAgent\s*$/mu, `${fileName} must declare ExtendedAgent kind`);
    assertMatches(text, new RegExp(`^\\s+name:\\s*${escapeRegex(expectedName)}\\s*$`, 'mu'), `${fileName} must set metadata.name`);
    assertMatches(text, /^\s{2}instructions:\s*/mu, `${fileName} must include spec.instructions`);
    assertMatches(text, /^\s{2}handoffDescription:\s*/mu, `${fileName} must include spec.handoffDescription`);
    assertMatches(text, /^\s{2}tools:\s*/mu, `${fileName} must include spec.tools`);
  }
});

test('TC-2.1–TC-2.3: skill packages include frontmatter with name and description', () => {
  for (const [skillName] of skillFiles) {
    assertFileExists('sre-config', 'skills', skillName, 'SKILL.md');
    const text = readRepoFile('sre-config', 'skills', skillName, 'SKILL.md');
    const frontmatterMatch = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/mu);

    assert.ok(frontmatterMatch, `${skillName}/SKILL.md must start with YAML frontmatter`);
    const frontmatter = frontmatterMatch[1];

    assertMatches(frontmatter, new RegExp(`^name:\\s*${escapeRegex(skillName)}\\s*$`, 'mu'), `${skillName}/SKILL.md must set frontmatter name`);
    assertMatches(frontmatter, /^description:\s*/mu, `${skillName}/SKILL.md must set frontmatter description`);
    assert.ok(text.slice(frontmatterMatch[0].length).trim().length > 0, `${skillName}/SKILL.md must include body content after frontmatter`);
  }
});

test('TC-3.1: connector YAML specifies Kusto with managed identity', () => {
  assertFileExists('sre-config', 'connectors', 'finops-hub-kusto.yaml');
  const text = readRepoFile('sre-config', 'connectors', 'finops-hub-kusto.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v1\s*$/mu, 'Connector must declare azuresre.ai/v1');
  assertMatches(text, /^kind:\s*DataConnector\s*$/mu, 'Connector must declare DataConnector kind');
  assertMatches(text, /^\s{2}name:\s*finops-hub-kusto\s*$/mu, 'Connector must declare the expected name');
  assertMatches(text, /^\s{2}dataConnectorType:\s*Kusto\s*$/mu, 'Connector must use Kusto type');
  assertMatches(text, /^\s{2}dataSource:\s*"?(##finopsHubClusterUri##|https?:\/\/\S+)"?\s*$/mu, 'Connector must point to a cluster URI or template placeholder');
  assertMatches(text, /^\s{2}identity:\s*system\s*$/mu, 'Connector must use system managed identity');
});

test('TC-3.2: Bicep module assigns AllDatabasesViewer at ADX cluster scope', () => {
  assertFileExists('infra', 'bicep', 'modules', 'adx-role.bicep');
  const text = readRepoFile('infra', 'bicep', 'modules', 'adx-role.bicep');

  assertMatches(text, /Microsoft\.Kusto\/clusters\/principalAssignments/mu, 'Bicep module must target ADX cluster principal assignments');
  assertMatches(text, /role:\s*'AllDatabasesViewer'/mu, 'Bicep module must assign AllDatabasesViewer');
  assertMatches(text, /resource\s+cluster\s+'Microsoft\.Kusto\/clusters/mu, 'Bicep module must reference existing ADX cluster');
});

test('TC-4.1: azure.yaml defines Bicep infra and postprovision hook', () => {
  assertFileExists('azure.yaml');
  const text = readRepoFile('azure.yaml');

  assertMatches(text, /^infra:\s*$/mu, 'azure.yaml must define infra configuration');
  assertMatches(text, /^\s{2}provider:\s*bicep\s*$/mu, 'azure.yaml must use the Bicep infra provider');
  assert.ok(!/^\s*module:/mu.test(text), 'azure.yaml must not include a module directive (azd uses main.bicep by default)');
  assertMatches(text, /^\s+postprovision:\s*$/mu, 'azure.yaml must declare a postprovision hook');
  assertMatches(text, /^\s+run:\s*bash \.\/scripts\/post-provision\.sh\s*$/mu, 'azure.yaml must run the post-provision script');
});

test('TC-4.1a: packaged deploy scripts wrap the azd environment workflow', () => {
  assertFileExists('scripts', 'deploy.sh');
  assertFileExists('scripts', 'deploy.ps1');
  const sh = readRepoFile('scripts', 'deploy.sh');
  const ps1 = readRepoFile('scripts', 'deploy.ps1');

  assertMatches(sh, /^#!\/usr\/bin\/env bash\s*$/mu, 'deploy.sh must use a bash shebang');
  assertMatches(sh, /azd env new/mu, 'deploy.sh must create azd environments');
  assertMatches(sh, /azd env set/mu, 'deploy.sh must set azd environment values');
  assertMatches(sh, /azd up/mu, 'deploy.sh must deploy through azd up');
  assertMatches(sh, /azd down/mu, 'deploy.sh must support replacement teardown');
  assertMatches(sh, /azd env remove/mu, 'deploy.sh must remove replaced azd environments');
  assertMatches(sh, /--destroy/mu, 'deploy.sh must support standalone destroy mode');

  assertMatches(ps1, /azd env new/mu, 'deploy.ps1 must create azd environments');
  assertMatches(ps1, /azd up/mu, 'deploy.ps1 must deploy through azd up');
  assertMatches(ps1, /azd down/mu, 'deploy.ps1 must support replacement teardown');
  assertMatches(ps1, /azd env remove/mu, 'deploy.ps1 must remove replaced azd environments');
  assertMatches(ps1, /Destroy/mu, 'deploy.ps1 must support standalone destroy mode');
});

test('TC-4.2: post-provision scripts initialize srectl and apply repo configuration', () => {
  assertFileExists('scripts', 'post-provision.sh');
  assertFileExists('scripts', 'post-provision.ps1');
  assertFileExists('sre-config', 'knowledge', 'onboarding-recommendations.md');
  const sh = readRepoFile('scripts', 'post-provision.sh');
  const ps1 = readRepoFile('scripts', 'post-provision.ps1');

  assertMatches(sh, /^#!\/usr\/bin\/env bash\s*$/mu, 'post-provision.sh must use a bash shebang');
  assertMatches(sh, /^set -euo pipefail\s*$/mu, 'post-provision.sh must fail fast');
  assertMatches(sh, /srectl init --resource-url/mu, 'post-provision.sh must run srectl init');
  assertMatches(sh, /srectl skill apply/mu, 'post-provision.sh must apply skills');
  assertMatches(sh, /srectl apply-yaml --file/mu, 'post-provision.sh must apply YAML artifacts');
  assertMatches(sh, /srectl doc upload --file/mu, 'post-provision.sh must upload knowledge documents');
  assertMatches(sh, /srectl scheduledtask apply/mu, 'post-provision.sh must apply scheduled tasks');
  assertMatches(sh, /srectl repo add/mu, 'post-provision.sh must add repo connector');

  assertMatches(ps1, /srectl init --resource-url/mu, 'post-provision.ps1 must run srectl init');
  assertMatches(ps1, /srectl skill apply/mu, 'post-provision.ps1 must apply skills');
  assertMatches(ps1, /srectl apply-yaml --file/mu, 'post-provision.ps1 must apply YAML artifacts');
  assertMatches(ps1, /srectl doc upload --file/mu, 'post-provision.ps1 must upload knowledge documents');
  assertMatches(ps1, /scheduledtask.*apply/mu, 'post-provision.ps1 must apply scheduled tasks');
  assertMatches(ps1, /srectl repo add/mu, 'post-provision.ps1 must add repo connector');
});

test('TC-4.2a: all scheduled task prompts include Teams delivery instruction', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = fs.readdirSync(tasksDir).filter(f => f.endsWith('.yaml') || f.endsWith('.yml'));
  assert.ok(files.length >= 9, `Expected at least 9 scheduled task files, found ${files.length}`);

  for (const file of files) {
    const text = fs.readFileSync(path.join(tasksDir, file), 'utf8');
    assertMatches(
      text,
      /Post the final .+ to our Teams channel/iu,
      `${file} must instruct the agent to post final results to the Teams channel`,
    );
    assertMatches(
      text,
      /Do not post intermediate results/iu,
      `${file} must explicitly exclude intermediate results from Teams posts`,
    );
    assertMatches(
      text,
      /read all documents in the knowledge base/iu,
      `${file} must instruct the agent to read knowledge base before starting`,
    );
    assertMatches(
      text,
      /Never save financial figures/iu,
      `${file} must enforce the knowledge vs Teams data split`,
    );
  }
});

test('TC-4.3: README includes a Deploy to Azure button', () => {
  assertFileExists('README.md');
  const text = readRepoFile('README.md');

  assertMatches(
    text,
    /\[!\[Deploy to Azure\]\(https:\/\/aka\.ms\/deploytoazurebutton\)\]\(https:\/\/portal\.azure\.com\/#create\/Microsoft\.Template\)/mu,
    'README must include the Deploy to Azure button',
  );
  assertMatches(text, /bash \.\/scripts\/deploy\.sh/mu, 'README must document the packaged Bash deploy script');
  assertMatches(text, /pwsh \.\/scripts\/deploy\.ps1/mu, 'README must document the packaged PowerShell deploy script');
});

test('TC-4.4: dev container includes Azure CLI, PowerShell, .NET 9, and srectl bootstrap', (t) => {
  if (!fs.existsSync(repoPath('.devcontainer', 'devcontainer.json'))) {
    t.skip('.devcontainer/devcontainer.json is not present in this template');
    return;
  }

  assertFileExists('.devcontainer', 'devcontainer.json');
  assertFileExists('.devcontainer', 'post-create.sh');
  assertFileExists('.devcontainer', 'post-start.sh');

  const devcontainer = readJsoncFile('.devcontainer', 'devcontainer.json');
  const postCreate = readRepoFile('.devcontainer', 'post-create.sh');
  const postStart = readRepoFile('.devcontainer', 'post-start.sh');

  assert.equal(devcontainer.features['ghcr.io/devcontainers/features/azure-cli:1'].installBicep, true, 'Dev container must install Azure CLI with Bicep');
  assert.ok(devcontainer.features['ghcr.io/devcontainers/features/powershell:1'], 'Dev container must include PowerShell feature');
  assert.equal(devcontainer.features['ghcr.io/devcontainers/features/dotnet:2'].version, '9.0', 'Dev container must include .NET 9');
  assert.equal(devcontainer.postCreateCommand, 'bash .devcontainer/post-create.sh', 'Dev container must run post-create bootstrap');
  assert.equal(devcontainer.postStartCommand, 'bash .devcontainer/post-start.sh', 'Dev container must run post-start bootstrap');

  assertMatches(postCreate, /dotnet tool (install|update) --global sreagent\.cli/mu, 'post-create.sh must install or update srectl');
  assertMatches(postCreate, /verify_command "az"/mu, 'post-create.sh must verify Azure CLI');
  assertMatches(postCreate, /verify_command "pwsh"/mu, 'post-create.sh must verify PowerShell');
  assertMatches(postCreate, /verify_command "dotnet"/mu, 'post-create.sh must verify .NET');
  assertMatches(postCreate, /verify_command "srectl"/mu, 'post-create.sh must verify srectl');
  assertMatches(postStart, /for tool_name in az azd pwsh dotnet srectl;/mu, 'post-start.sh must report tool readiness');
});

test('TC-5.1: Sprint 2 Bicep modules exist', () => {
  assertFileExists('infra', 'bicep', 'main.bicep');
  assertFileExists('infra', 'bicep', 'resources.bicep');
  assertFileExists('infra', 'bicep', 'modules', 'identity.bicep');
  assertFileExists('infra', 'bicep', 'modules', 'monitoring.bicep');
  assertFileExists('infra', 'bicep', 'modules', 'sre-agent.bicep');
  assertFileExists('infra', 'bicep', 'modules', 'subscription-rbac.bicep');
  assertFileExists('infra', 'bicep', 'modules', 'adx-role.bicep');
});

test('TC-5.2: SRE Agent uses stable API with Autonomous mode and single UAMI', () => {
  const text = readRepoFile('infra', 'bicep', 'modules', 'sre-agent.bicep');

  assertMatches(text, /Microsoft\.App\/agents@2025-05-01-preview/mu, 'sre-agent.bicep must use the 2025-05-01-preview API');
  assertMatches(text, /mode:\s*'Autonomous'/mu, 'sre-agent.bicep must use Autonomous action mode');
  assertMatches(text, /#disable-next-line BCP081/mu, 'sre-agent.bicep must suppress BCP081 for preview resource type');

  // Single UAMI: identityId used for both knowledgeGraph and action
  const knowledgeIdentity = text.match(/knowledgeGraphConfiguration[\s\S]*?identity:\s*(\w+)/mu);
  const actionIdentity = text.match(/actionConfiguration[\s\S]*?identity:\s*(\w+)/mu);
  assert.ok(knowledgeIdentity && actionIdentity, 'sre-agent.bicep must configure both knowledgeGraph and action identity');
  assert.equal(knowledgeIdentity[1], actionIdentity[1], 'sre-agent.bicep must use the same identity for knowledgeGraph and action');
  assertMatches(text, /experimentalSettings:\s*\{[\s\S]*EnableV2AgentLoop:\s*true/mu, 'sre-agent.bicep must enable the V2 agent loop');
  assertMatches(text, /experimentalSettings:\s*\{[\s\S]*EnableWorkspaceTools:\s*true/mu, 'sre-agent.bicep must enable workspace tools for code interpreter workflows');
});

test('TC-5.2a: analytical subagents enable execute_python by default', () => {
  for (const fileName of [
    'azure-capacity-manager.yaml',
    'chief-financial-officer.yaml',
    'finops-practitioner.yaml',
    'ftk-database-query.yaml',
  ]) {
    const text = readRepoFile('sre-config', 'agents', fileName);
    assertMatches(text, /^\s+-\s+execute_python\s*$/mu, `${fileName} must include execute_python`);
  }
});

test('TC-5.3: subscription-rbac assigns exactly Reader and Monitoring Contributor', () => {
  const text = readRepoFile('infra', 'bicep', 'modules', 'subscription-rbac.bicep');

  assertMatches(text, /acdd72a7-3385-48ef-bd42-f606fba81ae7/mu, 'subscription-rbac.bicep must include Reader role ID');
  assertMatches(text, /749f88d5-cbae-40b8-bcfc-e573ddc772fa/mu, 'subscription-rbac.bicep must include Monitoring Contributor role ID');

  // Must not include other common role IDs from the reference lab
  assert.ok(!/43d0d8ad-25c7-4714-9337-8ba259a9fe05/mu.test(text), 'subscription-rbac.bicep must not include Monitoring Reader (redundant)');
  assert.ok(!/73c42c96-874c-492b-b04d-ab87d138a893/mu.test(text), 'subscription-rbac.bicep must not include Log Analytics Reader');
  assert.ok(!/358470bc-b998-42bd-ab17-a7e34c199c0f/mu.test(text), 'subscription-rbac.bicep must not include Container Apps Contributor');
});

test('TC-5.4: monitoring does not output sensitive keys', () => {
  const text = readRepoFile('infra', 'bicep', 'modules', 'monitoring.bicep');

  assert.ok(!/logAnalyticsWorkspaceKey/mu.test(text), 'monitoring.bicep must not output logAnalyticsWorkspaceKey');
  assert.ok(!/listKeys\(/mu.test(text), 'monitoring.bicep must not call listKeys()');
});

test('TC-5.5: main.bicep confines deployer() and enforces region allowlist', () => {
  const mainText = readRepoFile('infra', 'bicep', 'main.bicep');

  assertMatches(mainText, /targetScope\s*=\s*'subscription'/mu, 'main.bicep must be subscription-scoped');
  assertMatches(mainText, /@allowed\(\[\s*'swedencentral'\s*'eastus2'\s*'australiaeast'\s*\]\)/mu, 'main.bicep must enforce the three allowed regions');
  assertMatches(mainText, /deployer\(\)\.objectId/mu, 'main.bicep must call deployer().objectId');
  assertMatches(mainText, /deployerPrincipalType/mu, 'main.bicep must pass deployerPrincipalType');

  // deployer() must NOT appear in any other Bicep file
  const resourcesText = readRepoFile('infra', 'bicep', 'resources.bicep');
  const agentText = readRepoFile('infra', 'bicep', 'modules', 'sre-agent.bicep');
  assert.ok(!/deployer\(\)/mu.test(resourcesText), 'resources.bicep must not call deployer() directly');
  assert.ok(!/deployer\(\)/mu.test(agentText), 'sre-agent.bicep must not call deployer() directly');
});

test('TC-5.6: main.parameters.json maps required azd variables', () => {
  assertFileExists('infra', 'bicep', 'main.parameters.json');
  const text = readRepoFile('infra', 'bicep', 'main.parameters.json');
  const params = JSON.parse(text);

  assert.ok(params.parameters.adxClusterName, 'main.parameters.json must map adxClusterName');
  assert.equal(params.parameters.adxClusterName.value, '${FINOPS_HUB_CLUSTER_NAME}', 'adxClusterName must map from FINOPS_HUB_CLUSTER_NAME');
  assert.ok(params.parameters.adxClusterResourceGroupName, 'main.parameters.json must map adxClusterResourceGroupName');
  assert.equal(params.parameters.adxClusterResourceGroupName.value, '${FINOPS_HUB_CLUSTER_RESOURCE_GROUP}', 'adxClusterResourceGroupName must map from FINOPS_HUB_CLUSTER_RESOURCE_GROUP');
  assert.ok(params.parameters.deployerPrincipalType, 'main.parameters.json must map deployerPrincipalType');
  assert.equal(params.parameters.deployerPrincipalType.value, '${AZURE_PRINCIPAL_TYPE}', 'deployerPrincipalType must map from AZURE_PRINCIPAL_TYPE');
});

test('TC-5.7: ADX role module is resource-group scoped with no nested deployment', () => {
  const text = readRepoFile('infra', 'bicep', 'modules', 'adx-role.bicep');

  assert.ok(!/targetScope/mu.test(text), 'adx-role.bicep must not set targetScope (defaults to resource group)');
  assert.ok(!/Microsoft\.Resources\/deployments/mu.test(text), 'adx-role.bicep must not use nested ARM deployments');
  assertMatches(text, /resource\s+cluster\s+'Microsoft\.Kusto\/clusters/mu, 'adx-role.bicep must reference existing ADX cluster');
  assertMatches(text, /AllDatabasesViewer/mu, 'adx-role.bicep must assign AllDatabasesViewer role');
});
