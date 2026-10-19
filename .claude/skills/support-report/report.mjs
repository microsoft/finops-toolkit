// Gathers FinOps toolkit support metrics from GitHub and prints a Markdown status report.
// Usage: node report.mjs [--since YYYY-MM-DD] [--out <dir>]
// Requires: gh CLI signed in with read access to microsoft/finops-toolkit.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const REPO = 'microsoft/finops-toolkit';
const [OWNER, NAME] = REPO.split('/');
const MAINTAINER_ASSOC = new Set(['OWNER', 'MEMBER', 'COLLABORATOR']);
const TEAM = new Set(['flanakin', 'MSBrett', 'RolandKrummenacher', 'helderpinto', 'arthurclares']);
const BOTS = /\[bot\]$|^microsoft-github-policy-service$|^allcontributors$|^github-actions$/;

const args = process.argv.slice(2);
const arg = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const outDir = arg('--out', path.join(os.homedir(), '.claude', 'ftk-reports'));
fs.mkdirSync(outDir, { recursive: true });
const today = new Date();
const iso = d => d.toISOString().slice(0, 10);
const prior = fs.readdirSync(outDir).filter(f => /^support-\d{4}-\d{2}-\d{2}\.md$/.test(f)).sort().pop();
const since = arg('--since', prior ? prior.slice(8, 18) : iso(new Date(today - 7 * 864e5)));
const days = d => Math.round((today - new Date(d)) / 864e5);

const gql = (query) => JSON.parse(execFileSync('gh', ['api', 'graphql', '-f', `query=${query}`], { encoding: 'utf8', maxBuffer: 1e8 })).data.repository;
const isUs = (login, assoc) => TEAM.has(login) || MAINTAINER_ASSOC.has(assoc);
const people = nodes => nodes.filter(n => n.author && !BOTS.test(n.author.login));

// Open issues (paged)
const issues = [];
for (let after = null; ;) {
  const r = gql(`{repository(owner:"${OWNER}",name:"${NAME}"){issues(states:OPEN,first:100${after ? `,after:"${after}"` : ''}){pageInfo{hasNextPage endCursor}nodes{number title createdAt author{login} authorAssociation labels(first:20){nodes{name}} milestone{title} comments(last:20){nodes{author{login} authorAssociation createdAt}}}}}}`).issues;
  issues.push(...r.nodes); if (!r.pageInfo.hasNextPage) break; after = r.pageInfo.endCursor;
}
// Open discussions (paged)
const discussions = [];
for (let after = null; ;) {
  const r = gql(`{repository(owner:"${OWNER}",name:"${NAME}"){discussions(first:100,states:OPEN${after ? `,after:"${after}"` : ''}){pageInfo{hasNextPage endCursor}nodes{number title createdAt author{login} authorAssociation category{name} answer{id} comments(last:20){nodes{author{login} authorAssociation createdAt replies(last:20){nodes{author{login} authorAssociation createdAt}}}}}}}}`).discussions;
  discussions.push(...r.nodes); if (!r.pageInfo.hasNextPage) break; after = r.pageInfo.endCursor;
}

const sev = labels => (labels.find(l => /^Severity: S[0-3]/.test(l)) || '').replace('Severity: ', '');
const items = [
  ...issues.map(i => {
    const c = people(i.comments.nodes); const last = c[c.length - 1];
    const labels = i.labels.nodes.map(l => l.name);
    const authorUs = isUs(i.author?.login, i.authorAssociation);
    return { kind: 'issue', n: i.number, title: i.title, created: i.createdAt, labels, sev: sev(labels), milestone: i.milestone?.title,
      authorUs, triage: labels.includes('Needs: Triage 🔍'),
      lastUs: last ? isUs(last.author.login, last.authorAssociation) : authorUs, lastAt: last?.createdAt || i.createdAt,
      newThem: c.filter(x => x.createdAt >= since && !isUs(x.author.login, x.authorAssociation)).length,
      newUs: c.filter(x => x.createdAt >= since && isUs(x.author.login, x.authorAssociation)).length };
  }),
  ...discussions.filter(d => !['Announcements', 'Polls', 'Releases'].includes(d.category.name)).map(d => {
    const c = people(d.comments.nodes.flatMap(x => [x, ...x.replies.nodes])).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
    const last = c[c.length - 1];
    return { kind: 'discussion', n: d.number, title: d.title, created: d.createdAt, labels: [], sev: '', authorUs: isUs(d.author?.login, d.authorAssociation),
      answered: !!d.answer, lastUs: last ? isUs(last.author.login, last.authorAssociation) : false, lastAt: last?.createdAt || d.createdAt,
      newThem: c.filter(x => x.createdAt >= since && !isUs(x.author.login, x.authorAssociation)).length,
      newUs: c.filter(x => x.createdAt >= since && isUs(x.author.login, x.authorAssociation)).length };
  }),
];

// "Waiting on us" = a non-maintainer spoke last (or opened it with no reply) and it isn't an answered discussion.
const waiting = items.filter(x => !x.lastUs && !x.answered && !(x.kind === 'issue' && x.authorUs && !x.newThem));
const byAge = (a, b) => days(b.lastAt) - days(a.lastAt);
const triage = items.filter(x => x.triage);
const s01 = items.filter(x => x.kind === 'issue' && ['S0', 'S1'].includes(x.sev));
const newOpened = items.filter(x => x.created >= since && !x.authorUs);
const ref = x => `#${x.n}`;
const list = (arr, max = 5) => arr.slice(0, max).map(ref).join(', ') + (arr.length > max ? ` +${arr.length - max}` : '') || 'none';

const waitingIssues = waiting.filter(x => x.kind === 'issue'), waitingDisc = waiting.filter(x => x.kind === 'discussion');
const isFeature = x => x.labels.some(l => l.startsWith('Type: Feature'));
const waitingBugs = waitingIssues.filter(x => !isFeature(x)), waitingFeatures = waitingIssues.filter(isFeature);
const over7 = waiting.filter(x => days(x.lastAt) > 7 && !isFeature(x)).sort(byAge);
const md = [
  `# FTK support status · ${iso(today)}`,
  '',
  `**TLDR:** ${waitingBugs.length + waitingDisc.length} customers waiting on us (${waitingBugs.length} issues, ${waitingDisc.length} discussions; ${waitingFeatures.length} feature requests not counted) · ${over7.length} over 7 days · oldest ${over7[0] ? days(over7[0].lastAt) + 'd' : 'n/a'} · triage queue ${triage.length}${s01.length ? ` · S0/S1 open ${s01.length}` : ''}`,
  '',
  `**Since ${since}:** ${items.reduce((s, x) => s + x.newUs, 0)} team replies · ${items.reduce((s, x) => s + x.newThem, 0)} customer replies · ${newOpened.length} new threads (${list(newOpened)})`,
  `- Customers replied: ${list(items.filter(x => x.newThem > 0 && !x.lastUs).sort(byAge))}`,
  `- Oldest waiting: ${over7.slice(0, 5).map(x => `${ref(x)} (${days(x.lastAt)}d)`).join(', ') || 'none'}`,
  `- Triage queue: ${list(triage)}`,
  '',
].join('\n');

const file = path.join(outDir, `support-${iso(today)}.md`);
fs.writeFileSync(file, md);
fs.writeFileSync(path.join(outDir, `support-${iso(today)}.json`), JSON.stringify({ since, waiting: waiting.map(ref), triage: triage.map(ref), s01: s01.map(ref), over7: over7.map(x => ({ n: x.n, kind: x.kind, days: days(x.lastAt), title: x.title })) }, null, 1));
process.stdout.write(md + `\n<!-- saved: ${file} -->\n`);
