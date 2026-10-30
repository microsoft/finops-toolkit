// Step 1: list every open issue and discussion with metadata and split triage candidates into batches.
// Usage: node gather.mjs [--date YYYY-MM-DD] [--batch 15] [--fresh]
// Writes ~/.claude/ftk-sweeps/<date>/: threads.json, batches.json, threads/<i|d><n>.md (full text for triage),
// and triage/00-carried.md (unchanged blocks from the previous sweep, unless --fresh). Read-only on GitHub.
import fs from 'node:fs';
import path from 'node:path';
import { OWNER, NAME, REPO, ROOT, SKIP_CATEGORIES, args, gql, isUs, isBot, people, ref, iso, daysSince, writeJson, readJson, readTriage } from './lib.mjs';

const { flags } = args();
const date = flags.date || new Date().toLocaleDateString('en-CA'); // local YYYY-MM-DD
const size = +(flags.batch || 15);
const NUDGE_DAYS = 14; // open bugs where we spoke last become nudge or close candidates after this many quiet days
const strip = s => (s || '').replace(/<!--[\s\S]*?-->/g, '').trim();
const dir = path.join(ROOT, date);
fs.mkdirSync(path.join(dir, 'threads'), { recursive: true });
fs.mkdirSync(path.join(dir, 'triage'), { recursive: true });

const who = `author{login} authorAssociation`;
const page = (conn, fields, after, n) => `{repository(owner:"${OWNER}",name:"${NAME}"){${conn}(states:OPEN,first:${n}${after ? `,after:"${after}"` : ''}){pageInfo{hasNextPage endCursor}nodes{${fields}}}}}`;
const all = (conn, fields, n) => {
  const out = [];
  for (let after = null; ;) {
    const r = gql(page(conn, fields, after, n)).repository[conn];
    out.push(...r.nodes); process.stderr.write(`${conn}: ${out.length}\r`);
    if (!r.pageInfo.hasNextPage) break; after = r.pageInfo.endCursor;
  }
  process.stderr.write('\n');
  return out;
};

const snapshotAt = new Date().toISOString();
const issues = all('issues', `number title url body createdAt updatedAt ${who} labels(first:20){nodes{name}} milestone{title} assignees(first:5){nodes{login}} comments(last:100){totalCount nodes{${who} createdAt body}}`, 40);
const discussions = all('discussions', `id number title url body createdAt updatedAt ${who} category{name} answer{id} comments(last:100){totalCount nodes{id ${who} createdAt body replies(last:50){nodes{id ${who} createdAt body}}}}`, 20);

const threads = [];
const text = {};
for (const [kind, list] of [['issue', issues], ['discussion', discussions]]) {
  for (const t of list) {
    const d = kind === 'discussion';
    const c = people(t.comments.nodes, d);
    const author = t.author?.login || 'ghost';
    const authorUs = isUs(author, t.authorAssociation);
    const labels = (t.labels?.nodes || []).map(l => l.name);
    const last = c.at(-1);
    const lastUs = last ? isUs(last.author.login, last.authorAssociation) : authorUs;
    const community = [...new Set(c.filter(x => !isUs(x.author.login, x.authorAssociation) && x.author.login !== author).map(x => x.author.login))];
    const sev = (labels.find(l => /^Severity: S[0-3]/.test(l)) || '').replace(/^Severity: (S[0-3]).*/, '$1');
    const type = (labels.find(l => l.startsWith('Type: ')) || '').replace(/^Type: (\w+).*/, '$1');
    const outside = c.some(x => !isUs(x.author.login, x.authorAssociation));
    const answered = !!t.answer;
    let skip = '';
    if (isBot(author)) skip = 'bot';
    else if (d && authorUs && SKIP_CATEGORIES.has(t.category?.name)) skip = `maintainer ${t.category.name.toLowerCase()}`;
    const row0 = { lastAt: last?.createdAt || t.createdAt };
    const waitingOnUs = !skip && !lastUs && !answered && !(kind === 'issue' && authorUs && !outside);
    let reason = '';
    if (!skip) {
      if (waitingOnUs) reason = 'waiting on us';
      else if (kind === 'issue' && ['S0', 'S1'].includes(sev)) reason = `${sev} open`;
      else if (kind === 'issue' && type === 'Bug' && daysSince(row0.lastAt) >= NUDGE_DAYS) reason = `bug, quiet ${NUDGE_DAYS}+ days`;
    }
    const row = {
      kind, n: t.number, title: t.title, url: t.url, created: t.createdAt, updated: t.updatedAt, author, authorUs,
      labels, sev, type, milestone: t.milestone?.title || '', assignees: (t.assignees?.nodes || []).map(a => a.login),
      category: t.category?.name || '', answered, comments: c.length, community,
      last: lastUs ? 'us' : 'them', lastBy: last?.author.login || author, lastAt: last?.createdAt || t.createdAt,
      lastActivityAt: last?.createdAt || t.createdAt, totalComments: t.comments.totalCount,
      waitingOnUs, waitDays: waitingOnUs ? daysSince(last?.createdAt || t.createdAt) : 0, ageDays: daysSince(t.createdAt),
      skip, candidate: !!reason, reason, snapshotAt,
    };
    threads.push(row);
    if (row.candidate) {
      const tag = (l, a) => `@${l}${isUs(l, a) ? ' (maintainer)' : ''}`;
      text[ref(row)] = [
        `# ${kind} #${t.number}: ${t.title}`, '',
        `${t.url} · opened ${iso(t.createdAt)} by ${tag(author, t.authorAssociation)}` + (labels.length ? ` · labels: ${labels.join(', ')}` : '') + (row.milestone ? ` · milestone: ${row.milestone}` : '') + (row.category ? ` · category: ${row.category}` : '') + (answered ? ' · ANSWERED' : ''), '',
        strip(t.body) || "_(no body)_", "",
        ...c.map(x => `---\n\n**${tag(x.author.login, x.authorAssociation)} · ${x.createdAt.slice(0, 16).replace('T', ' ')}Z**\n\n${strip(x.body)}\n`),
        t.comments.totalCount > 100 ? `\n_(older comments not shown; ${t.comments.totalCount} total)_` : '',
      ].join('\n');
    }
  }
}

// Carry forward unchanged triage from the previous sweep so a rerun only triages what moved.
const carried = [];
const carriedFrom = {};
const triageFile = path.join(dir, 'triage', '00-carried.md');
if (!flags.fresh && !fs.existsSync(triageFile)) {
  const prev = fs.existsSync(ROOT) ? fs.readdirSync(ROOT).filter(d => /^\d{4}-\d{2}-\d{2}$/.test(d) && d < date).sort().at(-1) : null;
  if (prev) {
    const pdir = path.join(ROOT, prev);
    const pthreads = Object.fromEntries((readJson(path.join(pdir, 'threads.json'), { threads: [] }).threads).map(t => [t.n, t]));
    const posted = new Set(readJson(path.join(pdir, 'posted.json'), []).map(p => p.n));
    const blocks = readTriage(pdir);
    for (const t of threads.filter(t => t.candidate)) {
      const p = pthreads[t.n], b = blocks[t.n];
      if (p && b && !posted.has(t.n) && p.lastActivityAt === t.lastActivityAt) { carried.push(b.raw); carriedFrom[t.n] = p; }
    }
    if (carried.length) fs.writeFileSync(triageFile, `<!-- carried from ${prev}: no new activity since that sweep -->\n\n${carried.join('\n\n---\n\n')}\n`);
  }
}

// Batches: candidates not yet covered by any triage file in this sweep, so a rerun resumes where it stopped.
// A thread's snapshotAt must be the time its triage input was captured. post.mjs aborts on any comment after it.
const done = readTriage(dir);
const before = Object.fromEntries(readJson(path.join(dir, 'threads.json'), { threads: [] }).threads.map(t => [t.n, t]));
for (const t of threads) {
  const old = before[t.n] || carriedFrom[t.n];
  if (done[t.n] && old) {
    t.snapshotAt = old.snapshotAt;
    if (old.lastActivityAt !== t.lastActivityAt) t.changedSinceTriage = true;
    delete text[ref(t)];
  }
}
const todo = threads.filter(t => t.candidate && !done[t.n])
  .sort((a, b) => (a.kind === b.kind ? 0 : a.kind === 'issue' ? -1 : 1) || b.waitingOnUs - a.waitingOnUs || a.n - b.n);
const kept = readJson(path.join(dir, 'batches.json'), []).filter(x => fs.existsSync(path.join(dir, x.out)));
let next = Math.max(0, ...kept.map(x => +x.id));
const open = [];
for (let i = 0; i < todo.length; i += size) {
  const id = String(++next).padStart(2, '0');
  open.push({ id, out: `triage/batch-${id}.md`, refs: todo.slice(i, i + size).map(ref) });
}
for (const [k, v] of Object.entries(text)) fs.writeFileSync(path.join(dir, 'threads', `${k}.md`), v);
writeJson(path.join(dir, 'threads.json'), { repo: REPO, snapshotAt, threads });
writeJson(path.join(dir, 'batches.json'), [...kept, ...open]);

const c = threads.filter(t => t.candidate);
console.log(`Sweep ${date}: ${issues.length} issues, ${discussions.length} discussions open · ${threads.filter(t => t.skip).length} skipped · ${threads.filter(t => t.waitingOnUs).length} waiting on us`);
console.log(`Candidates ${c.length} (${c.filter(t => t.kind === 'issue').length} issues, ${c.filter(t => t.kind === 'discussion').length} discussions) · carried ${carried.length} · already triaged ${threads.filter(t => t.candidate && done[t.n]).length - carried.length} · changed since triage ${threads.filter(t => t.changedSinceTriage).length} · open batches ${open.length}`);
for (const b of open) console.log(`  batch ${b.id} → ${b.out}: ${b.refs.join(' ')}`);
console.log(`Saved: ${dir}`);
