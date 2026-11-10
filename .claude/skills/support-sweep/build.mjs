// Step 3: bucket and sort triaged threads, lint drafts, and build the review page.
// Usage: node build.mjs [--sweep <dir>] [--offline]
// Reads threads.json, triage/*.md, context.json (optional), posted.json. Refetches thread state unless --offline (read-only).
// Writes rows.json, drafts/<i|d><n>.md, and support-sweep.html in the sweep folder.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ARTIFACT_URL_FILE, args, sweepDir, readJson, writeJson, readTriage, fetchMany, daysSince, ref } from './lib.mjs';

const { flags } = args();
const dir = sweepDir(flags.sweep);
const here = path.dirname(fileURLToPath(import.meta.url));
const OLD_DAYS = 60;
const { threads, snapshotAt } = readJson(path.join(dir, 'threads.json'), {});
if (!threads) throw new Error(`No threads.json in ${dir}`);
const triage = readTriage(dir);
const ctx = Object.fromEntries(readJson(path.join(dir, 'context.json'), []).map(c => [c.n, c]));
const posted = Object.fromEntries(readJson(path.join(dir, 'posted.json'), []).map(p => [p.n, p]));
const byN = Object.fromEntries(threads.map(t => [t.n, t]));

const missing = threads.filter(t => t.candidate && !triage[t.n]).map(ref);
const unknown = Object.keys(triage).filter(n => !byN[n]).map(n => `#${n}`);
const list = Object.values(triage).filter(b => byN[b.n]).map(b => ({ b, t: byN[b.n] }));

// Live state since the snapshot (closed, answered, new comments).
let live = {};
if (!flags.offline) { process.stderr.write(`Refreshing ${list.length} threads...\n`); live = fetchMany(list.map(x => x.t)); }

const lint = (r) => {
  const w = [], d = r.draft;
  if (r.needsYou && !r.ask) w.push('Needs a "Your call" line');
  if (!d) return w;
  if (!d.startsWith('🤖 [AI]')) w.push('Draft must start with "🤖 [AI]"');
  if (r.waiting > OLD_DAYS && !/sorry|apolog/i.test(d)) w.push('Long wait: apologize for the delay');
  if (r.age > OLD_DAYS && /\b(we('ll| will) close|close (this|it) (in|after)|if we don't hear back)/i.test(d)) w.push('Drop the close deadline on an old thread');
  if (/\b(confirmed|confirm that) (this|it|the) ?(is )?(a )?bug|\bthis is a bug\b/i.test(d)) w.push('Confirms a bug: only if tested or confirmed by a contributor');
  if (/\b(unreleased|not (been )?released|internal (bug|issue|tracking))\b/i.test(d)) w.push('Cites internal or unreleased work: give the fix or workaround instead');
  if (/\b(soon|next release|upcoming release|coming weeks|shortly)\b/i.test(d)) w.push('Give timelines by milestone (for example, "planned for v16")');
  return w;
};

const rows = list.map(({ b, t }) => {
  const l = live[t.n];
  const people = l ? l.comments.filter(c => !c.bot) : [];
  const fresh = people.filter(c => c.at > (t.snapshotAt || snapshotAt));
  const lastC = people.at(-1);
  const last = l ? (lastC ? (lastC.us ? 'us' : 'them') : t.last) : t.last;
  const lastBy = lastC?.by || t.lastBy, lastAt = lastC?.at || t.lastAt;
  const p = posted[t.n];
  const c = ctx[t.n] || {};
  const r = {
    kind: t.kind, n: t.n, ref: ref(t), url: t.url, title: t.title, created: t.created.slice(0, 10), age: daysSince(t.created),
    comments: l ? people.length : t.comments, community: t.community, category: t.category,
    last, lastBy, lastAt: lastAt.slice(0, 10), waiting: last === 'them' ? daysSince(lastAt) : 0,
    sev: b.sev || (t.kind === 'discussion' ? 'Q' : ''), action: b.action, conf: b.conf, ask: b.ask,
    problem: b.problem || c.problem || '', sofar: b.sofar || c.sofar || '', open: b.open || c.open || '',
    draft: b.draft, evidence: b.evidence,
    posted: p ? { at: p.postedAt.slice(0, 10), url: p.url } : null,
    changed: fresh.filter(x => !p || x.at > p.postedAt).map(x => ({ by: x.by, at: x.at.slice(0, 10), us: x.us, url: x.url })),
  };
  const closed = l ? l.closed : false, answered = l ? l.answered : t.answered;
  r.needsYou = !!b.ask || r.conf === 'LOW' || /needs? (a )?maintainer|maintainer (decision|call)/i.test(r.action);
  const usAfter = r.changed.some(x => x.us);
  const themAfterPost = p && people.some(x => !x.us && x.at > p.postedAt);
  if (closed || answered) r.bucket = 'done', r.doneWhy = closed ? 'Closed' : 'Answered';
  else if (p && !themAfterPost) r.bucket = 'responded';
  else if (usAfter && last === 'us') r.bucket = 'responded', r.note = 'A maintainer replied after the sweep. Drop or re-triage this draft.';
  else if (!r.draft) r.bucket = 'internal';
  else if (last === 'them' && r.needsYou) r.bucket = 'you';
  else if (last === 'them') r.bucket = ['S0', 'S1'].includes(r.sev) || r.waiting <= OLD_DAYS ? 'now' : 'old';
  else if (/\bclose\b/i.test(r.action)) r.bucket = 'close';
  else r.bucket = 'nudge';
  if (themAfterPost) r.note = 'The customer replied after our post. Re-triage.';
  else if (r.changed.length && !r.note && r.bucket !== 'done') r.note = 'New activity since the sweep. Re-read the thread and update the draft before posting.';
  r.warnings = r.bucket === 'done' || r.bucket === 'responded' ? [] : lint(r);
  return r;
});

const sevRank = { S0: 0, S1: 1, S2: 2, Q: 2, S3: 3, '': 4 };
const bRank = { now: 0, you: 1, old: 2, close: 3, nudge: 4, internal: 5, responded: 6, done: 7 };
rows.sort((x, y) => bRank[x.bucket] - bRank[y.bucket] || sevRank[x.sev] - sevRank[y.sev] || y.waiting - x.waiting || y.age - x.age);

fs.mkdirSync(path.join(dir, 'drafts'), { recursive: true });
for (const r of rows) if (r.draft) fs.writeFileSync(path.join(dir, 'drafts', `${r.ref}.md`), r.draft + '\n');
writeJson(path.join(dir, 'rows.json'), rows);

const count = k => rows.filter(r => r.bucket === k).length;
const meta = {
  date: path.basename(dir), snapshotAt, builtAt: new Date().toISOString(), refreshed: !flags.offline,
  total: rows.length, issues: rows.filter(r => r.kind === 'issue').length, discussions: rows.filter(r => r.kind === 'discussion').length,
  waiting: rows.filter(r => r.last === 'them' && !['done', 'responded'].includes(r.bucket)).length, missing,
};
const json = v => JSON.stringify(v).replace(/</g, '\\u003c');
const html = fs.readFileSync(path.join(here, 'page.tpl.html'), 'utf8')
  .replace('/*ROWS*/', () => json(rows)).replace('/*META*/', () => json(meta));
const out = path.join(dir, 'support-sweep.html');
fs.writeFileSync(out, html);

const counts = Object.keys(bRank).map(k => `${k} ${count(k)}`).join(' · ');
console.log(`Built ${rows.length} rows (${meta.issues} issues, ${meta.discussions} discussions) · ${counts}`);
const warned = rows.filter(r => r.warnings.length);
if (warned.length) console.log(`Draft warnings (${warned.length}):\n` + warned.map(r => `  #${r.n}: ${r.warnings.join('; ')}`).join('\n'));
const changed = rows.filter(r => r.note);
if (changed.length) console.log(`Changed since the sweep (${changed.length}): ${changed.map(r => `#${r.n}`).join(' ')}`);
if (missing.length) console.log(`Not triaged yet (${missing.length}): ${missing.join(' ')}`);
if (unknown.length) console.log(`Triage blocks with no matching open thread (ignored): ${unknown.join(' ')}`);
console.log(`Page: ${out}`);
console.log(fs.existsSync(ARTIFACT_URL_FILE) ? `Artifact URL: ${fs.readFileSync(ARTIFACT_URL_FILE, 'utf8').trim()}` : `No saved artifact URL (${ARTIFACT_URL_FILE}); the first publish creates one.`);
