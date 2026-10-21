// Posts the latest support report Teams draft to the contributor sync chat through a Teams Workflows webhook.
// Usage: node post-teams.mjs [--file <path to .teams.txt>] [--dry-run]
// The webhook URL is a secret: it's read from ~/.claude/ftk-reports/teams-webhook.url (never commit it).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const dir = path.join(os.homedir(), '.claude', 'ftk-reports');
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const fileArg = args.includes('--file') ? args[args.indexOf('--file') + 1] : null;

const file = fileArg || fs.readdirSync(dir).filter(f => /^support-\d{4}-\d{2}-\d{2}\.teams\.txt$/.test(f)).sort().map(f => path.join(dir, f)).pop();
if (!file || !fs.existsSync(file)) { console.error('No Teams draft found. Run the report first.'); process.exit(1); }
const lines = fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean);
if (!lines.length || !lines[0].startsWith('🤖 [AI]')) { console.error(`Draft must start with "🤖 [AI]": ${file}`); process.exit(1); }

const marker = file.replace(/\.teams\.txt$/, '.teams.posted');
if (fs.existsSync(marker) && !dryRun) { console.error(`Already posted: ${fs.readFileSync(marker, 'utf8').trim()}`); process.exit(1); }

const card = {
  type: 'message',
  attachments: [{
    contentType: 'application/vnd.microsoft.card.adaptive',
    content: {
      $schema: 'http://adaptivecards.io/schemas/adaptive-card.json',
      type: 'AdaptiveCard',
      version: '1.4',
      body: [
        { type: 'TextBlock', text: lines[0], weight: 'Bolder', wrap: true },
        ...lines.slice(1).map(text => ({ type: 'TextBlock', text, wrap: true, spacing: 'Small' })),
      ],
    },
  }],
};

if (dryRun) { console.log(JSON.stringify(card, null, 2)); process.exit(0); }

const urlFile = path.join(dir, 'teams-webhook.url');
if (!fs.existsSync(urlFile)) { console.error(`Missing ${urlFile}. Paste the Workflows webhook URL there.`); process.exit(1); }
const url = fs.readFileSync(urlFile, 'utf8').trim();
if (!/^https:\/\/\S+$/.test(url)) { console.error('Webhook URL looks invalid.'); process.exit(1); }

const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card) });
if (!res.ok) { console.error(`Post failed: ${res.status} ${await res.text()}`); process.exit(1); }
fs.writeFileSync(marker, new Date().toISOString());
console.log(`Posted ${path.basename(file)} (${res.status})`);
