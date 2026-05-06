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

function listFilesRecursive(directoryPath, predicate) {
  return fs.readdirSync(directoryPath, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directoryPath, entry.name);
    if (entry.isDirectory()) {
      return listFilesRecursive(entryPath, predicate);
    }

    return predicate(entryPath) ? [entryPath] : [];
  });
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

test('TC-1.6: Kusto query agents avoid az rest and expose freshness tool', () => {
  const databaseQuery = readRepoFile('sre-config', 'agents', 'ftk-database-query.yaml');
  const hubsAgent = readRepoFile('sre-config', 'agents', 'ftk-hubs-agent.yaml');

  assertMatches(
    databaseQuery,
    /Never use RunAzCliReadCommands[\s\S]*`az rest`[\s\S]*Azure Data Explorer[\s\S]*data-freshness-check[\s\S]*ManagedIdentityCredential/mu,
    'ftk-database-query must steer Kusto execution away from az rest and toward managed identity REST or repository tools',
  );
  assertMatches(
    hubsAgent,
    /data-freshness-check[\s\S]*Do not use Azure CLI or `az rest` against Azure Data Explorer/mu,
    'ftk-hubs-agent must use data-freshness-check instead of az rest for Hub freshness checks',
  );

  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const freshnessTaskFiles = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file)).filter(file =>
    fs.readFileSync(file, 'utf8').includes('data-freshness-check'),
  );
  const agentsRequiringFreshness = new Set();

  for (const file of freshnessTaskFiles) {
    const text = fs.readFileSync(file, 'utf8');
    const agentMatch = text.match(/^\s{2}agent:\s*([A-Za-z0-9_-]+)\s*$/mu);
    if (agentMatch) {
      agentsRequiringFreshness.add(`${agentMatch[1]}.yaml`);
    }
  }

  assert.ok(agentsRequiringFreshness.size > 0, 'Expected scheduled tasks to require data-freshness-check');

  for (const fileName of agentsRequiringFreshness) {
    const text = readRepoFile('sre-config', 'agents', fileName);
    assertMatches(text, /^\s*-\s*data-freshness-check\s*$/mu, `${fileName} must expose data-freshness-check`);
  }
});

test('TC-1.6a: costs-enriched-base rejects broad raw detail windows', () => {
  const text = readRepoFile('tools', 'costs-enriched-base.yaml');

  assertMatches(text, /description:[\s\S]*row-level cost and usage sample/imu, 'costs-enriched-base must be documented as row-level detail');
  assertMatches(text, /description:[\s\S]*Do not use it for full-month[\s\S]*aggregation tools/imu, 'costs-enriched-base must direct reporting workflows to aggregate tools');
  assertMatches(text, /let\s+_startDate\s*=\s*todatetime\(##startDate##\);/mu, 'costs-enriched-base must parse startDate once');
  assertMatches(text, /let\s+_endDate\s*=\s*todatetime\(##endDate##\);/mu, 'costs-enriched-base must parse endDate once');
  assertMatches(text, /let\s+_maxRawWindow\s*=\s*1d;/mu, 'costs-enriched-base must cap raw detail windows at one day');
  assertMatches(text, /assert\(_endDate\s*>\s*_startDate/mu, 'costs-enriched-base must reject inverted windows');
  assertMatches(
    text,
    /assert\(_endDate\s*-\s*_startDate\s*<=\s*_maxRawWindow[\s\S]*Use aggregated cost tools for full-month or scheduled reports/imu,
    'costs-enriched-base must reject broad windows with aggregate-tool guidance',
  );
  assertMatches(
    text,
    /ChargePeriodStart\s*>=\s*_startDate\s+and\s+ChargePeriodStart\s*<\s*_endDate/mu,
    'costs-enriched-base must filter with the guarded date variables',
  );
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
  assertMatches(sh, /^set -[eu]*o pipefail\s*$/mu, 'post-provision.sh must use pipefail');
  assertMatches(sh, /srectl init --resource-url/mu, 'post-provision.sh must run srectl init');
  assertMatches(sh, /srectl skill apply/mu, 'post-provision.sh must apply skills');
  assertMatches(sh, /srectl (apply-yaml|tool apply|agent apply)/mu, 'post-provision.sh must apply artifacts via srectl');
  assertMatches(sh, /srectl doc upload --file/mu, 'post-provision.sh must upload knowledge documents');
  assertMatches(sh, /srectl scheduledtask apply/mu, 'post-provision.sh must apply scheduled tasks');

  assertMatches(ps1, /srectl init --resource-url/mu, 'post-provision.ps1 must run srectl init');
  assertMatches(ps1, /srectl skill apply/mu, 'post-provision.ps1 must apply skills');
  assertMatches(ps1, /srectl (apply-yaml|tool apply|agent apply)/mu, 'post-provision.ps1 must apply artifacts via srectl');
  assertMatches(ps1, /srectl doc upload --file/mu, 'post-provision.ps1 must upload knowledge documents');
  assertMatches(ps1, /scheduledtask.*apply/mu, 'post-provision.ps1 must apply scheduled tasks');
});

test('TC-4.2e: knowledge package includes a listable document index sentinel', () => {
  const knowledgeDir = repoPath('sre-config', 'knowledge');
  const knowledgeFiles = fs.readdirSync(knowledgeDir).filter(f => f.endsWith('.md')).sort();
  const indexText = readRepoFile('sre-config', 'knowledge', 'document-index.md');
  const sh = readRepoFile('scripts', 'post-provision.sh');
  const ps1 = readRepoFile('scripts', 'post-provision.ps1');

  assert.ok(knowledgeFiles.includes('document-index.md'), 'knowledge package must include document-index.md');
  assert.ok(knowledgeFiles.length >= 4, `Expected at least 4 knowledge documents, found ${knowledgeFiles.length}`);
  assertMatches(indexText, /srectl doc get/mu, 'document-index.md must document the supported document-list command');
  assertMatches(indexText, /List uploaded documents|listing uploaded knowledge documents/imu, 'document-index.md must explain that doc get lists uploaded documents');
  assertMatches(indexText, /srectl doc search[\s\S]*not a reliable replacement/imu, 'document-index.md must prevent using search as a list substitute');
  assertMatches(indexText, /If `srectl doc get` returns no output[\s\S]*empty knowledge base/imu, 'document-index.md must classify empty doc get output as no visible uploaded documents');
  assertMatches(sh, /srectl doc get/mu, 'post-provision.sh must verify knowledge documents are listable after upload');
  assertMatches(sh, /max_attempts=3[\s\S]*sleep 5/mu, 'post-provision.sh must use a bounded retry for document listing visibility');
  assertMatches(sh, /document-index\.md/mu, 'post-provision.sh must verify the knowledge document index was uploaded');
  assertMatches(ps1, /srectl doc get/mu, 'post-provision.ps1 must verify knowledge documents are listable after upload');
  assertMatches(ps1, /\$attempt = 1; \$attempt -le 3[\s\S]*Start-Sleep -Seconds 5/mu, 'post-provision.ps1 must use a bounded retry for document listing visibility');
  assertMatches(ps1, /document-index\.md/mu, 'post-provision.ps1 must verify the knowledge document index was uploaded');

  for (const fileName of knowledgeFiles) {
    assertMatches(
      indexText,
      new RegExp(`\`${escapeRegex(fileName)}\``, 'mu'),
      `document-index.md must include ${fileName}`,
    );
  }
});

test('TC-4.2a: all scheduled task prompts include Teams delivery instruction', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file));
  assert.ok(files.length >= 9, `Expected at least 9 scheduled task files, found ${files.length}`);

  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    const displayName = path.relative(repoRoot, file);
    assertMatches(
      text,
      /Post the final .+ to our Teams channel/iu,
      `${displayName} must instruct the agent to post final results to the Teams channel`,
    );
    assertMatches(
      text,
      /Do not post intermediate results/iu,
      `${displayName} must explicitly exclude intermediate results from Teams posts`,
    );
    assertMatches(
      text,
      /read all documents in the knowledge base/iu,
      `${displayName} must instruct the agent to read knowledge base before starting`,
    );
    assertMatches(
      text,
      /Never save financial figures|Do not commit task reports, financial figures/iu,
      `${displayName} must enforce the knowledge vs Teams data split`,
    );
    assertMatches(
      text,
      /Teams delivery guard:[\s\S]*exactly once per run[\s\S]*PostTeamsMessage/iu,
      `${displayName} must check Teams delivery availability once per run`,
    );
    assertMatches(
      text,
      /Do not call `PostTeamsMessage`[\s\S]*just to test availability/iu,
      `${displayName} must not probe Teams by calling delivery tools`,
    );
    assertMatches(
      text,
      /If no Teams connector\/channel is configured[\s\S]*do not retry or probe alternate delivery paths/iu,
      `${displayName} must limit local-output degradation to runs without a configured Teams connector/channel`,
    );
    assertMatches(
      text,
      /When a Teams connector\/channel is configured[\s\S]*Teams delivery is mandatory[\s\S]*if configured Teams delivery fails[\s\S]*mark the task\/run failed/iu,
      `${displayName} must fail when configured Teams delivery fails`,
    );
  }
});

test('TC-4.2c: scheduled task agents keep Teams connector tools enabled', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file));
  const agentNames = new Set();

  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    const match = text.match(/^\s{2}agent:\s*([a-z0-9-]+)\s*$/mu);
    if (match) {
      agentNames.add(match[1]);
    }
  }

  assert.ok(agentNames.size > 0, 'Scheduled tasks must specify agents');

  for (const expectedAgentName of ['finops-practitioner', 'azure-capacity-manager', 'ftk-hubs-agent', 'chief-financial-officer']) {
    assert.ok(agentNames.has(expectedAgentName), `Scheduled tasks must include ${expectedAgentName}`);
  }

  for (const agentName of agentNames) {
    const text = readRepoFile('sre-config', 'agents', `${agentName}.yaml`);
    for (const toolName of ['PostTeamsMessage', 'ReplyToTeamsMessage', 'GetTeamsMessages']) {
      assertMatches(
        text,
        new RegExp(`^\\s+-\\s+${escapeRegex(toolName)}\\s*$`, 'mu'),
        `${agentName}.yaml must include ${toolName} so production Teams delivery works when the connector is available`,
      );
    }
  }
});

test('TC-4.2d: Teams notification guidance documents once-per-run degradation', () => {
  const docs = [
    ['teams-notification-guide.md', readRepoFile('sre-config', 'knowledge', 'teams-notification-guide.md')],
    ['known-issues-and-workarounds.md', readRepoFile('sre-config', 'knowledge', 'known-issues-and-workarounds.md')],
  ];

  for (const [name, text] of docs) {
    assertMatches(text, /Teams delivery guard|Teams tool discovery and availability/iu, `${name} must describe Teams availability handling`);
    assertMatches(text, /exactly once per run/iu, `${name} must require a single Teams availability check per run`);
    assertMatches(text, /PostTeamsMessage/iu, `${name} must preserve the production PostTeamsMessage path`);
    assertMatches(text, /do not retry/iu, `${name} must prevent repeated Teams probing`);
    assertMatches(text, /no Teams connector\/channel is configured/iu, `${name} must limit local-output degradation to missing Teams configuration`);
    assertMatches(text, /configured Teams delivery fails|configured delivery failed/iu, `${name} must define configured Teams delivery failure`);
    assertMatches(text, /task\/run fail/iu, `${name} must fail runs when configured Teams delivery fails`);
  }
});

test('TC-4.2e-teams: repository guidance requires configured Teams delivery', () => {
  const text = readRepoFile('AGENTS.md');

  assertMatches(text, /PostTeamsMessage[\s\S]*ReplyToTeamsMessage[\s\S]*GetTeamsMessages/iu, 'AGENTS.md must require the Teams connector tools');
  assertMatches(text, /When a Teams connector\/channel is configured[\s\S]*results must be delivered through that configured Teams channel/iu, 'AGENTS.md must require configured Teams delivery');
  assertMatches(text, /Failure to deliver through a configured Teams channel means the task\/run fails/iu, 'AGENTS.md must fail configured delivery failures');
  assertMatches(text, /degraded local-output behavior is allowed only when no Teams connector\/channel is configured/iu, 'AGENTS.md must limit degradation to missing Teams configuration');
  assertMatches(text, /Check Teams capability exactly once per scheduled-task run/iu, 'AGENTS.md must require one Teams capability check per run');
  assertMatches(text, /Do not use repeated probing, retry loops/iu, 'AGENTS.md must prohibit repeated Teams probing');
});

test('TC-4.2f: chart-producing scheduled tasks require non-visual artifact verification', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file));
  const unavailableVisualTool = 'View' + 'Image';
  const chartFiles = files.filter(file => {
    const text = fs.readFileSync(file, 'utf8');
    return /Visualizations|generate charts|chart images|trend chart|comparison chart/iu.test(text);
  });
  const knowledgeText = readRepoFile('sre-config', 'knowledge', 'chart-artifact-verification.md');

  assert.ok(chartFiles.length >= 18, `Expected at least 18 chart-producing scheduled task files, found ${chartFiles.length}`);

  for (const file of chartFiles) {
    const text = fs.readFileSync(file, 'utf8');
    const displayName = path.relative(repoRoot, file);

    assert.ok(!text.includes(unavailableVisualTool), `${displayName} must not rely on unavailable visual chart verification`);
    assertMatches(text, /Verify each generated chart non-visually/iu, `${displayName} must require non-visual chart checks`);
    assertMatches(text, /file exists/iu, `${displayName} must check chart file existence`);
    assertMatches(text, /non-zero size/iu, `${displayName} must check chart file size`);
    assertMatches(text, /opens as an image/iu, `${displayName} must check image readability`);
    assertMatches(text, /dimensions/iu, `${displayName} must check chart dimensions`);
    assertMatches(text, /metadata/iu, `${displayName} must check chart metadata`);
    assertMatches(
      text,
      /Do not use visual inspection as the verification gate/iu,
      `${displayName} must not use visual inspection as the chart verification gate`,
    );
  }

  assert.ok(!knowledgeText.includes(unavailableVisualTool), 'chart artifact knowledge must not rely on unavailable visual chart verification');
  assertMatches(knowledgeText, /non-visual checks/iu, 'chart artifact knowledge must require non-visual checks');
  assertMatches(knowledgeText, /file exists[\s\S]*non-zero size[\s\S]*metadata[\s\S]*dimensions/iu, 'chart artifact knowledge must cover file, size, metadata, and dimensions');
  assertMatches(knowledgeText, /Do not use visual inspection as the verification gate/iu, 'chart artifact knowledge must prohibit visual inspection as the verification gate');
});

test('TC-4.2b: scheduled task reports use complete-month date windows', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file));
  const unsafeEarlyMonthStart = /startofmonth\(ago\(1d\)\)/iu;
  const safeReportWindowGuidance = /Do not run `costs-enriched-base` for freshness checks or (?:month-level|fiscal-period) reports; use aggregated Kusto tools for complete-month reporting windows/iu;
  const reportFiles = [
    'sre-config/scheduled-tasks/mom-report.yaml',
    'sre-config/scheduled-tasks/ytd-report.yaml',
    'sre-config/scheduled-tasks/scheduledtasks/MOM/MOM.yaml',
    'sre-config/scheduled-tasks/scheduledtasks/YTD/YTD.yaml',
  ];

  assert.ok(files.length >= 18, `Expected at least 18 scheduled task files, found ${files.length}`);

  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    assert.doesNotMatch(
      text,
      unsafeEarlyMonthStart,
      `${path.relative(repoRoot, file)} must not use a one-day-ago month-start window because it can create a zero-length month window`,
    );
  }

  for (const file of reportFiles) {
    const text = readRepoFile(...file.split('/'));
    assertMatches(
      text,
      safeReportWindowGuidance,
      `${file} must route report windows away from row-level freshness checks`,
    );
  }
});

test('TC-4.2h: scheduled cost reports avoid raw full-window cost detail exports', () => {
  const tasksDir = repoPath('sre-config', 'scheduled-tasks');
  const files = listFilesRecursive(tasksDir, file => /\.ya?ml$/iu.test(file));
  const reportFiles = [
    'sre-config/scheduled-tasks/mom-report.yaml',
    'sre-config/scheduled-tasks/ytd-report.yaml',
    'sre-config/scheduled-tasks/scheduledtasks/MOM/MOM.yaml',
    'sre-config/scheduled-tasks/scheduledtasks/YTD/YTD.yaml',
  ];

  assert.ok(files.length >= 18, `Expected at least 18 scheduled task files, found ${files.length}`);

  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    const displayName = path.relative(repoRoot, file);

    for (const line of text.split(/\r?\n/u).filter(line => /costs-enriched-base/iu.test(line))) {
      assertMatches(
        line,
        /Do not run|one-day drill-downs only/iu,
        `${displayName} must mention costs-enriched-base only as a guardrail, not as scheduled report evidence`,
      );
    }
  }

  for (const file of reportFiles) {
    const text = readRepoFile(...file.split('/'));
    assertMatches(text, /data-freshness-check/iu, `${file} must use data-freshness-check for freshness`);
    assertMatches(text, /aggregated? Kusto tools?|cost-by-financial-hierarchy/iu, `${file} must prefer aggregate Kusto tools for report windows`);
    assertMatches(text, /one-day drill-downs only/iu, `${file} must limit row-level detail to one-day drill-downs`);
  }
});

test('TC-4.2g: non-compute quota reports use normalized rows and safe accessors', () => {
  for (const file of ['non-compute-quota-audit.yaml', 'storage-paas-growth-forecast.yaml']) {
    const text = readRepoFile('sre-config', 'scheduled-tasks', file);

    assertMatches(text, /normalized `quotas` array/iu, `${file} must tell reports to use normalized quota rows`);
    assertMatches(text, /safe accessors/iu, `${file} must require safe accessors for quota schema variants`);
    assertMatches(text, /default missing `location` to `subscription`/iu, `${file} must define a location fallback`);
    assertMatches(text, /\.get\(\).*safe-access/iu, `${file} must tell chart code not to index optional fields directly`);
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

test('TC-6.1: vm-quota-usage PythonTool meets contract', () => {
  assertFileExists('tools', 'vm-quota-usage.yaml');
  const text = readRepoFile('tools', 'vm-quota-usage.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'vm-quota-usage.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'vm-quota-usage.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'vm-quota-usage.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'vm-quota-usage.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*requests/mu, 'functionCode must use requests for ARM REST calls');
  assertMatches(text, /functionCode:[\s\S]*Microsoft\.Compute[\s\S]*locations\/\{region\}\/usages/mu, 'functionCode must call the Compute usages ARM endpoint');
  assertMatches(text, /functionCode:[\s\S]*\/subscriptions\/\{subscription_id\}\/locations/mu, 'functionCode must use ARM REST to discover locations');
  assert.ok(!/dependencies:[\s\S]*azure-mgmt-/mu.test(text), 'vm-quota-usage.yaml must not depend on Azure management SDK packages');
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'vm-quota-usage.yaml must require the subscription_id parameter',
  );
  assertMatches(text, /-\s*name:\s*location\b/mu, 'vm-quota-usage.yaml must declare the location parameter');
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*quota usage/imu, 'description must mention quota usage');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'vm-quota-usage.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'vm-quota-usage.yaml timeoutSeconds must be at least 120');

  assertMatches(
    text,
    /functionCode:[\s\S]*(utili[sz]ation(?:\s*%|_?percent|Percent|Pct|_pct))/mu,
    'functionCode must calculate and return utilization percentage',
  );
  assertMatches(
    text,
    /functionCode:[\s\S]*(at[-_ ]?risk|isAtRisk|is_at_risk)[\s\S]*(80|95)|(80|95)[\s\S]*(at[-_ ]?risk|isAtRisk|is_at_risk)/mu,
    'functionCode must return at-risk flags based on 80% and 95% thresholds',
  );
  assertMatches(text, /functionCode:[\s\S]*warning_count/mu, 'functionCode must return warning_count for >80% and <=95% utilization');
  assertMatches(text, /functionCode:[\s\S]*critical_count/mu, 'functionCode must return critical_count for >95% utilization');
  assertMatches(text, /functionCode:[\s\S]*suppressed_error_count/mu, 'functionCode must return suppressed_error_count for expected regional noise');
  assertMatches(text, /functionCode:[\s\S]*suppressed_from_failure_summary/mu, 'functionCode must mark expected regional errors as suppressed from failure summaries');
  assertMatches(
    text,
    /functionCode:[\s\S]*is_expected_preview_region[\s\S]*stage[\s\S]*preview[\s\S]*canary[\s\S]*euap/mu,
    'functionCode must suppress VM quota errors from stage, preview, canary, and EUAP regions',
  );
  assertMatches(
    text,
    /functionCode:[\s\S]*>\s*80[\s\S]*<=\s*95[\s\S]*warning_count/mu,
    'warning_count must count only >80% and <=95% utilization',
  );
  assertMatches(
    text,
    /functionCode:[\s\S]*>\s*95[\s\S]*critical_count/mu,
    'critical_count must count only >95% utilization',
  );
  assert.ok(!/functionCode:[\s\S]*blocking_count/mu.test(text), 'functionCode must not return obsolete blocking_count');
});

test('TC-6.4: sku-availability PythonTool meets contract', () => {
  assertFileExists('tools', 'sku-availability.yaml');
  const text = readRepoFile('tools', 'sku-availability.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'sku-availability.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'sku-availability.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'sku-availability.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'sku-availability.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*requests/mu, 'functionCode must use requests for ARM REST calls');
  assertMatches(text, /functionCode:[\s\S]*Microsoft\.Compute\/skus/mu, 'functionCode must call the Compute SKUs ARM endpoint');
  assertMatches(text, /functionCode:[\s\S]*\$filter/mu, 'functionCode must filter SKUs by location');
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'sku-availability.yaml must require the subscription_id parameter',
  );
  assertMatches(
    text,
    /-\s*name:\s*location\b[\s\S]*?required:\s*true\b/mu,
    'sku-availability.yaml must require the location parameter',
  );
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*SKU availability/imu, 'description must mention SKU availability');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'sku-availability.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'sku-availability.yaml timeoutSeconds must be at least 120');
});

test('TC-6.3: capacity-reservation-groups PythonTool meets contract', () => {
  assertFileExists('tools', 'capacity-reservation-groups.yaml');
  const text = readRepoFile('tools', 'capacity-reservation-groups.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'capacity-reservation-groups.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'capacity-reservation-groups.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'capacity-reservation-groups.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'capacity-reservation-groups.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*requests/mu, 'functionCode must use requests for ARM REST calls');
  assertMatches(text, /functionCode:[\s\S]*capacity_reservation_groups/mu, 'functionCode must query capacity_reservation_groups');
  assertMatches(text, /functionCode:[\s\S]*capacityReservationGroups/mu, 'functionCode must call the Capacity Reservation Groups ARM endpoint');
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'capacity-reservation-groups.yaml must require the subscription_id parameter',
  );
  assertMatches(
    text,
    /description:\s*(\|[-+]?\s*)?[\s\S]*capacity reservation/imu,
    'description must mention capacity reservation',
  );

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'capacity-reservation-groups.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'capacity-reservation-groups.yaml timeoutSeconds must be at least 120');

  assertMatches(
    text,
    /functionCode:[\s\S]*(return[\s\S]*utili[sz]ation|utili[sz]ation[\s\S]*return)/mu,
    'functionCode must return utilization data',
  );
});

test('TC-6.5: data-freshness-check PythonTool meets contract', () => {
  assertFileExists('tools', 'data-freshness-check.yaml');
  const text = readRepoFile('tools', 'data-freshness-check.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'data-freshness-check.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'data-freshness-check.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'data-freshness-check.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'data-freshness-check.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*ManagedIdentityCredential/mu, 'functionCode must support managed identity client ID authentication');
  assertMatches(text, /functionCode:[\s\S]*requests/mu, 'functionCode must use requests for Kusto REST calls');
  assertMatches(text, /functionCode:[\s\S]*KUSTO_SCOPE\s*=\s*"https:\/\/api\.kusto\.windows\.net\/\.default"/mu, 'functionCode must request the canonical Kusto token scope');
  assertMatches(text, /functionCode:[\s\S]*\/v2\/rest\/query/mu, 'functionCode must call the Kusto v2 REST query endpoint');
  assertMatches(text, /source_of_truth[\s\S]*direct_adx_rest_query[\s\S]*KUSTO_QUERY_PATH/mu, 'functionCode must identify direct ADX REST as the freshness source of truth');
  assertMatches(text, /source_of_truth[\s\S]*authoritative_function[\s\S]*Costs\(\)/mu, 'functionCode must make Costs() the authoritative freshness function');
  assertMatches(text, /supersedes[\s\S]*stale memory conclusions[\s\S]*raw KQL freshness rollups[\s\S]*Kusto ingestion timestamp checks/mu, 'functionCode must mark stale memory/raw KQL/ingestion timestamp checks as superseded');
  assertMatches(text, /authoritative_freshness_signal[\s\S]*Costs\(\)[\s\S]*latest_data_date[\s\S]*is_stale/mu, 'functionCode must return an authoritative Costs() freshness signal');
  assert.doesNotMatch(
    text,
    /get_token\(\s*f["']\{cluster_uri\}\/\.default["']\s*\)/mu,
    'functionCode must not request cluster-specific token scopes',
  );
  assertMatches(text, /functionCode:[\s\S]*urlparse[\s\S]*parsed_cluster_uri\.path/mu, 'functionCode must normalize cluster URIs that include a database path');
  assertMatches(text, /functionCode:[\s\S]*Costs\(\)/mu, 'functionCode must query the Costs() function for freshness checks');
  assertMatches(text, /functionCode:[\s\S]*ChargePeriodStart/mu, 'functionCode must use ChargePeriodStart for freshness checks');
  assertMatches(
    text,
    /Prices\(\)\s*\|\s*summarize\s+(?:RowCount=count\(\),\s*)?LatestData=max\(x_EffectivePeriodStart\)/mu,
    'Prices() freshness checks must use x_EffectivePeriodStart',
  );
  assert.doesNotMatch(
    text,
    /Prices\(\)\s*\|\s*summarize\s+LatestData=max\(ChargePeriodStart\)/mu,
    'Prices() freshness checks must not use ChargePeriodStart',
  );
  assertMatches(
    text,
    /Transactions\(\)\s*\|[\s\S]*RowCount=count\(\)[\s\S]*LatestData=max\(ChargePeriodStart\)/mu,
    'Transactions() freshness checks must return row count and latest ChargePeriodStart',
  );
  assertMatches(text, /functionCode:[\s\S]*TRANSACTIONS_ZERO_ROWS/mu, 'functionCode must emit a precise Transactions() zero-row diagnostic');
  assertMatches(text, /functionCode:[\s\S]*reservationtransactions/mu, 'functionCode must name the expected reservationtransactions export dataset');
  assertMatches(text, /schema_query[\s\S]*Transactions\(\) \| getschema/mu, 'functionCode must verify the Transactions() stored-function schema');
  assertMatches(text, /has_data\s*=\s*row_count is not None and row_count > 0/mu, 'functionCode must use RowCount to decide whether a function has data');
  assert.doesNotMatch(text, /has_data\s*=\s*bool\(freshness_rows\)/mu, 'functionCode must not treat summarize output rows as data presence');
  assertMatches(text, /attention_required/mu, 'functionCode must expose attention_required for non-healthy diagnostics');
  assertMatches(
    text,
    /-\s*name:\s*cluster_uri\b[\s\S]*?required:\s*true\b/mu,
    'data-freshness-check.yaml must require the cluster_uri parameter',
  );
  assertMatches(
    text,
    /-\s*name:\s*client_id\b[\s\S]*?required:\s*false\b/mu,
    'data-freshness-check.yaml must support an optional client_id parameter',
  );
  assertMatches(
    text,
    /description:\s*(\|[-+]?\s*)?[\s\S]*(data freshness|ingestion)/imu,
    'description must mention data freshness or ingestion',
  );

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'data-freshness-check.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'data-freshness-check.yaml timeoutSeconds must be at least 120');

  assertMatches(
    text,
    /functionCode:[\s\S]*(staleness|is_stale|isStale|stale)/mu,
    'functionCode must return a staleness indicator',
  );
});

test('TC-6.5a: freshness source of truth supersedes stale memory and raw KQL', () => {
  const knowledgeText = readRepoFile('sre-config', 'knowledge', 'known-issues-and-workarounds.md');
  assertMatches(knowledgeText, /Superseded data freshness conclusions/mu, 'knowledge must mark old freshness conclusions as superseded');
  assertMatches(knowledgeText, /Costs current through 2026-05-01/mu, 'knowledge must call out the reconciled current Costs() evidence');
  assertMatches(knowledgeText, /data-freshness-check[\s\S]*authoritative source/mu, 'knowledge must make data-freshness-check authoritative');
  assertMatches(knowledgeText, /stale-memory[\s\S]*raw-KQL[\s\S]*superseded and unsafe/mu, 'knowledge must mark stale memory/raw KQL claims unsafe when not revalidated');

  for (const taskPath of [
    ['sre-config', 'scheduled-tasks', 'hubs-health-check.yaml'],
    ['sre-config', 'scheduled-tasks', 'mom-report.yaml'],
    ['sre-config', 'scheduled-tasks', 'ytd-report.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'HubsHealthCheck', 'HubsHealthCheck.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'MOM', 'MOM.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'YTD', 'YTD.yaml'],
  ]) {
    const taskText = readRepoFile(...taskPath);
    assertMatches(taskText, /data-freshness-check/mu, `${taskPath.join('/')} must run data-freshness-check`);
    assertMatches(taskText, /Costs\(\)|`Costs\(\)`/mu, `${taskPath.join('/')} must treat Costs() as the freshness signal`);
    assertMatches(taskText, /3 days old or newer/mu, `${taskPath.join('/')} must use the 3-day freshness threshold`);
    assertMatches(taskText, /stale-memory[\s\S]*raw-KQL[\s\S]*(superseded|stale-data remediation)/imu, `${taskPath.join('/')} must supersede stale memory/raw KQL freshness claims`);
  }
});

test('TC-6.5b: transaction zero rows require explicit diagnostics before success', () => {
  for (const toolPath of [
    ['tools', 'top-other-transactions.yaml'],
    ['tools', 'top-commitment-transactions.yaml'],
  ]) {
    const toolText = readRepoFile(...toolPath);
    assertMatches(toolText, /ZERO_ROWS_RETURNED/mu, `${toolPath.join('/')} must document the empty-result sentinel`);
    assertMatches(toolText, /data-freshness-check[\s\S]*Transactions\(\)[\s\S]*diagnostic_code/imu, `${toolPath.join('/')} must require transaction diagnostics before success`);
    assertMatches(toolText, /TRANSACTIONS_ZERO_ROWS/mu, `${toolPath.join('/')} must surface TRANSACTIONS_ZERO_ROWS`);
    assert.doesNotMatch(toolText, /successful empty result set/imu, `${toolPath.join('/')} must not classify the sentinel as false success`);
  }

  for (const fileName of [
    'chief-financial-officer.yaml',
    'finops-practitioner.yaml',
    'ftk-database-query.yaml',
  ]) {
    const agentText = readRepoFile('sre-config', 'agents', fileName);
    assertMatches(
      agentText,
      /top-other-transactions[\s\S]*ZERO_ROWS_RETURNED[\s\S]*data-freshness-check[\s\S]*TRANSACTIONS_ZERO_ROWS/imu,
      `${fileName} must require data-freshness-check before reporting transaction zero rows as success`,
    );
  }

  for (const taskPath of [
    ['sre-config', 'scheduled-tasks', 'hubs-health-check.yaml'],
    ['sre-config', 'scheduled-tasks', 'mom-report.yaml'],
    ['sre-config', 'scheduled-tasks', 'ytd-report.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'HubsHealthCheck', 'HubsHealthCheck.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'MOM', 'MOM.yaml'],
    ['sre-config', 'scheduled-tasks', 'scheduledtasks', 'YTD', 'YTD.yaml'],
  ]) {
    const taskText = readRepoFile(...taskPath);
    assertMatches(
      taskText,
      /Transactions\(\)[\s\S]*(TRANSACTIONS_ZERO_ROWS|data-freshness-check)[\s\S]*(export|ingestion|stored-function)/imu,
      `${taskPath.join('/')} must surface Transactions() export/ingestion/stored-function diagnostics`,
    );
    assert.doesNotMatch(
      taskText,
      /ZERO_ROWS_RETURNED[\s\S]*successful empty result set/imu,
      `${taskPath.join('/')} must not treat transaction zero rows as false success`,
    );
  }

  const knowledgeText = readRepoFile('sre-config', 'knowledge', 'known-issues-and-workarounds.md');
  assertMatches(knowledgeText, /Transactions\(\) zero rows/imu, 'knowledge must document Transactions() zero rows');
  assertMatches(knowledgeText, /TRANSACTIONS_ZERO_ROWS[\s\S]*data quality action item/imu, 'knowledge must require explicit transaction diagnostics');
  assert.doesNotMatch(knowledgeText, /ZERO_ROWS_RETURNED[\s\S]*successful empty result set/imu, 'knowledge must not classify transaction sentinels as false success');
});

test('TC-6.7: benefit-recommendations PythonTool meets contract', () => {
  assertFileExists('tools', 'benefit-recommendations.yaml');
  const text = readRepoFile('tools', 'benefit-recommendations.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'benefit-recommendations.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'benefit-recommendations.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'benefit-recommendations.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'benefit-recommendations.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(
    text,
    /functionCode:[\s\S]*(benefitRecommendations|benefit_recommendations)/mu,
    'functionCode must call benefitRecommendations or benefit_recommendations',
  );
  assertMatches(
    text,
    /-\s*name:\s*billing_scope\b[\s\S]*?required:\s*true\b/mu,
    'benefit-recommendations.yaml must require the billing_scope parameter',
  );
  assertMatches(
    text,
    /description:\s*(\|[-+]?\s*)?[\s\S]*(benefit|recommendation)/imu,
    'description must mention benefit or recommendation',
  );

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'benefit-recommendations.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'benefit-recommendations.yaml timeoutSeconds must be at least 120');
});

test('TC-6.8: non-compute-quotas PythonTool meets contract', () => {
  assertFileExists('tools', 'non-compute-quotas.yaml');
  const text = readRepoFile('tools', 'non-compute-quotas.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'non-compute-quotas.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'non-compute-quotas.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'non-compute-quotas.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'non-compute-quotas.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(
    text,
    /functionCode:[\s\S]*(storage|app service|service bus|key vault|sql|service|quota)/imu,
    'functionCode must reference non-compute service quota concepts',
  );
  assertMatches(text, /"quotas":\s*\[\]/mu, 'non-compute-quotas.yaml must return a normalized quotas array for reporting');
  assertMatches(text, /def\s+safe_get\(/mu, 'non-compute-quotas.yaml must include a safe accessor for variable quota schemas');
  assertMatches(text, /def\s+normalize_quota_record\(/mu, 'non-compute-quotas.yaml must normalize quota records before reporting');
  assertMatches(
    text,
    /\["current_count",\s*"currentValue",\s*"current_value",\s*"current"/mu,
    'non-compute-quotas.yaml must normalize current usage across common key variants',
  );
  assertMatches(
    text,
    /\["location",\s*"location_name",\s*"region",\s*"regionName",\s*"region_name"\]/mu,
    'non-compute-quotas.yaml must normalize location across common key variants',
  );
  assertMatches(text, /return\s+"subscription"/mu, 'non-compute-quotas.yaml must provide a subscription-level location fallback');
  assertMatches(
    text,
    /result\["quotas"\]\.append\(normalized_item\)/mu,
    'non-compute-quotas.yaml must append normalized quota records for chart/report consumers',
  );
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'non-compute-quotas.yaml must require the subscription_id parameter',
  );
  assertMatches(
    text,
    /description:\s*(\|[-+]?\s*)?[\s\S]*(non-compute|service quota)/imu,
    'description must mention non-compute or service quota',
  );

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'non-compute-quotas.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'non-compute-quotas.yaml timeoutSeconds must be at least 120');
  assertMatches(text, /functionCode:[\s\S]*suppressed_count/mu, 'functionCode must return suppressed_count for expected quota defaults');
  assertMatches(text, /functionCode:[\s\S]*suppressed_from_risk_summary/mu, 'functionCode must mark expected defaults as suppressed from risk summaries');
  assertMatches(
    text,
    /functionCode:[\s\S]*is_expected_network_watcher_default[\s\S]*networkwatchers[\s\S]*current_count[\s\S]*==\s*1[\s\S]*limit[\s\S]*==\s*1/mu,
    'functionCode must suppress Network Watcher 1/1 Azure default entries from actionable risk',
  );
});

test('TC-6.6: resource-graph-query PythonTool meets contract', () => {
  assertFileExists('tools', 'resource-graph-query.yaml');
  const text = readRepoFile('tools', 'resource-graph-query.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'resource-graph-query.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'resource-graph-query.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'resource-graph-query.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'resource-graph-query.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*requests/mu, 'functionCode must use requests for ARM REST calls');
  assertMatches(text, /functionCode:[\s\S]*Microsoft\.ResourceGraph\/resources/mu, 'functionCode must call the Resource Graph REST endpoint');
  assertMatches(
    text,
    /-\s*name:\s*query\b[\s\S]*?required:\s*true\b/mu,
    'resource-graph-query.yaml must require the query parameter',
  );
  assertMatches(text, /-\s*name:\s*subscription_ids\b/mu, 'resource-graph-query.yaml must declare the subscription_ids parameter');
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*resource graph/imu, 'description must mention resource graph');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'resource-graph-query.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'resource-graph-query.yaml timeoutSeconds must be at least 120');
});

test('TC-6.10: deploy-budget PythonTool meets contract', () => {
  assertFileExists('tools', 'deploy-budget.yaml');
  const text = readRepoFile('tools', 'deploy-budget.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'deploy-budget.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'deploy-budget.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'deploy-budget.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'deploy-budget.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*budget/imu, 'functionCode must mention budget');
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'deploy-budget.yaml must require the subscription_id parameter',
  );
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*budget/imu, 'description must mention budget');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'deploy-budget.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'deploy-budget.yaml timeoutSeconds must be at least 120');
});

test('TC-6.11: deploy-bulk-budgets PythonTool meets contract', () => {
  assertFileExists('tools', 'deploy-bulk-budgets.yaml');
  const text = readRepoFile('tools', 'deploy-bulk-budgets.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'deploy-bulk-budgets.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'deploy-bulk-budgets.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'deploy-bulk-budgets.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'deploy-bulk-budgets.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*budget/imu, 'functionCode must mention budget');
  assertMatches(
    text,
    /-\s*name:\s*management_group\b[\s\S]*?required:\s*true\b/mu,
    'deploy-bulk-budgets.yaml must require the management_group parameter',
  );
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*budget/imu, 'description must mention budget');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'deploy-bulk-budgets.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'deploy-bulk-budgets.yaml timeoutSeconds must be at least 120');
});

test('TC-6.12: deploy-anomaly-alert PythonTool meets contract', () => {
  assertFileExists('tools', 'deploy-anomaly-alert.yaml');
  const text = readRepoFile('tools', 'deploy-anomaly-alert.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'deploy-anomaly-alert.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'deploy-anomaly-alert.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'deploy-anomaly-alert.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'deploy-anomaly-alert.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*anomal/imu, 'functionCode must mention anomaly');
  assertMatches(
    text,
    /-\s*name:\s*subscription_id\b[\s\S]*?required:\s*true\b/mu,
    'deploy-anomaly-alert.yaml must require the subscription_id parameter',
  );
  assertMatches(
    text,
    /-\s*name:\s*email_recipients\b[\s\S]*?required:\s*true\b/mu,
    'deploy-anomaly-alert.yaml must require the email_recipients parameter',
  );
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*anomal/imu, 'description must mention anomaly');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'deploy-anomaly-alert.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'deploy-anomaly-alert.yaml timeoutSeconds must be at least 120');
});

test('TC-6.13: deploy-bulk-anomaly-alerts PythonTool meets contract', () => {
  assertFileExists('tools', 'deploy-bulk-anomaly-alerts.yaml');
  const text = readRepoFile('tools', 'deploy-bulk-anomaly-alerts.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'deploy-bulk-anomaly-alerts.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'deploy-bulk-anomaly-alerts.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'deploy-bulk-anomaly-alerts.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'deploy-bulk-anomaly-alerts.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*anomal/imu, 'functionCode must mention anomaly');
  assertMatches(
    text,
    /-\s*name:\s*management_group\b[\s\S]*?required:\s*true\b/mu,
    'deploy-bulk-anomaly-alerts.yaml must require the management_group parameter',
  );
  assertMatches(
    text,
    /-\s*name:\s*email_recipients\b[\s\S]*?required:\s*true\b/mu,
    'deploy-bulk-anomaly-alerts.yaml must require the email_recipients parameter',
  );

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'deploy-bulk-anomaly-alerts.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'deploy-bulk-anomaly-alerts.yaml timeoutSeconds must be at least 120');
});

test('TC-6.14: suppress-advisor-recommendations PythonTool meets contract', () => {
  assertFileExists('tools', 'suppress-advisor-recommendations.yaml');
  const text = readRepoFile('tools', 'suppress-advisor-recommendations.yaml');

  assertMatches(text, /^api_version:\s*azuresre\.ai\/v2\s*$/mu, 'suppress-advisor-recommendations.yaml must use azuresre.ai/v2');
  assertMatches(text, /^kind:\s*ExtendedAgentTool\s*$/mu, 'suppress-advisor-recommendations.yaml must declare ExtendedAgentTool kind');
  assertMatches(text, /^\s{2}type:\s*PythonTool\s*$/mu, 'suppress-advisor-recommendations.yaml must declare PythonTool type');
  assertMatches(text, /authScopes:[\s\S]*?^\s*-\s*ARM\s*$/mu, 'suppress-advisor-recommendations.yaml must request ARM auth scope');
  assertMatches(text, /functionCode:[\s\S]*DefaultAzureCredential/mu, 'functionCode must use DefaultAzureCredential');
  assertMatches(text, /functionCode:[\s\S]*(advisor|suppress)/imu, 'functionCode must mention advisor or suppression');
  assertMatches(
    text,
    /-\s*name:\s*management_group_id\b[\s\S]*?required:\s*true\b/mu,
    'suppress-advisor-recommendations.yaml must require the management_group_id parameter',
  );
  assertMatches(text, /description:\s*(\|[-+]?\s*)?[\s\S]*advisor/imu, 'description must mention advisor');

  const timeoutMatch = text.match(/^\s{2}timeoutSeconds:\s*(\d+)\s*$/mu);
  assert.ok(timeoutMatch, 'suppress-advisor-recommendations.yaml must set timeoutSeconds');
  assert.ok(Number(timeoutMatch[1]) >= 120, 'suppress-advisor-recommendations.yaml timeoutSeconds must be at least 120');
});
