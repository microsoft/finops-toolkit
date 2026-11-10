// Step 4: post ONE maintainer-approved reply, after checking that nothing changed since the sweep.
// Usage: node post.mjs <n> <issue|discussion> <bodyfile> [--dry-run] [--sweep <dir>] [--reply-to <commentId>]
//                      [--reviewed-through <ISO time>]
// Aborts (exit 2) if the thread is closed, answered, or locked, or if anyone (team or customer) commented or edited
// after the sweep's snapshot of that thread. Prints what changed so the agent can re-review.
// --reviewed-through: only after re-reading the changes and getting fresh approval; pass the latest change time printed.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { REPO, args, sweepDir, readJson, writeJson, fetchThread, gh } from './lib.mjs';

const { flags, pos } = args();
const [nArg, kind, bodyFile] = pos;
const die = (msg, code = 1) => { console.error(msg); process.exit(code); };
if (!/^\d+$/.test(nArg || '') || !['issue', 'discussion'].includes(kind) || !bodyFile) die('Usage: node post.mjs <n> <issue|discussion> <bodyfile> [--dry-run] [--sweep <dir>] [--reply-to <commentId>]');
const n = +nArg, dry = !!flags['dry-run'];
const dir = sweepDir(flags.sweep);

// Body checks
const body = fs.existsSync(bodyFile) ? fs.readFileSync(bodyFile, 'utf8').trim() : die(`Body file not found: ${bodyFile}`);
if (!body) die('Body file is empty.');
if (!/^🤖 \[AI\]/u.test(body)) die('Body must start with "🤖 [AI]".');

// Snapshot from the sweep
const snap = (readJson(path.join(dir, 'threads.json'), { threads: [] }).threads).find(t => t.n === n);
if (!snap) die(`#${n} isn't in ${dir}/threads.json, so there's no snapshot to check against. Run gather.mjs and triage it first.`);
const an = k => (k === 'issue' ? 'an issue' : 'a discussion');
if (snap.kind !== kind) die(`#${n} is ${an(snap.kind)} in the sweep, not ${an(kind)}.`);
const postedFile = path.join(dir, 'posted.json');
const posted = readJson(postedFile, []);
const prior = posted.find(p => p.n === n);
if (prior) die(`Already posted to #${n} at ${prior.postedAt}: ${prior.url}. Not posting again.`, 2);
let since = snap.snapshotAt;
if (flags['reviewed-through']) {
  const r = new Date(flags['reviewed-through']);
  if (isNaN(r)) die('--reviewed-through needs an ISO timestamp.');
  since = r.toISOString().replace('.000Z', 'Z');
}

// Post-time check: refetch now
const t = fetchThread(kind, n);
if (!t) die(`#${n} not found as ${an(kind)}.`, 2);
// --reviewed-through can only move the check forward to a change that actually happened, never past unseen activity.
if (since > snap.snapshotAt) {
  const seen = new Set([t.lastEditedAt, ...t.comments.flatMap(c => [c.at, c.editedAt])].filter(x => x && x > snap.snapshotAt));
  if (!seen.has(since)) die(`--reviewed-through ${since} doesn't match any change on #${n} since the snapshot. Use the exact time the abort message printed.`);
}
const problems = [];
if (t.closed) problems.push(`${kind} is closed`);
if (t.answered) problems.push(`discussion has an accepted answer (by @${t.answer.author?.login || '?'}, ${t.answer.createdAt})`);
if (t.locked) problems.push(`${kind} is locked`);
const after = t.comments.filter(c => c.at > since);
const people = after.filter(c => !c.bot);
const edits = t.comments.filter(c => !c.bot && c.at <= since && c.editedAt && c.editedAt > since);
if (t.lastEditedAt && t.lastEditedAt > since) problems.push(`the ${kind} body was edited ${t.lastEditedAt}`);
for (const c of people) problems.push(`new comment by @${c.by} (${c.us ? 'maintainer' : 'customer'}) at ${c.at}: ${c.url}\n      "${c.body.replace(/\s+/g, ' ').slice(0, 240)}${c.body.length > 240 ? '...' : ''}"`);
for (const c of edits) problems.push(`comment by @${c.by} (${c.us ? 'maintainer' : 'customer'}) edited at ${c.editedAt}: ${c.url}`);
for (const c of after.filter(c => c.bot)) console.log(`Note: bot comment by @${c.by} at ${c.at} (ignored)`);

console.log(`#${n} ${kind}: ${t.title}\n${t.url}\nSnapshot: ${snap.snapshotAt}${since !== snap.snapshotAt ? ` · reviewed through ${since}` : ''} · last before snapshot: @${snap.lastBy} (${snap.last}) ${snap.lastAt}`);
if (problems.length) {
  const latest = [...people.map(c => c.at), ...edits.map(c => c.editedAt), t.lastEditedAt > since ? t.lastEditedAt : ''].filter(Boolean).sort().at(-1);
  die(`ABORTED: #${n} changed since the sweep. Re-read the thread, update the draft, and get approval again.\n  - ${problems.join('\n  - ')}` +
    (latest ? `\nAfter re-review and approval, rerun with --reviewed-through ${latest}` : ''), 2);
}
const maintainers = t.comments.filter(c => c.us && !c.bot);
console.log(`Check passed: no new comments or edits since ${since}. Maintainer comments on the thread: ${maintainers.length ? maintainers.map(c => `@${c.by} ${c.at.slice(0, 10)}`).join(', ') : 'none'}.`);
console.log(`\n----- reply -----\n${body}\n-----------------`);

if (dry) { console.log(`\nDRY RUN: would post to #${n} via ${kind === 'issue' ? 'gh issue comment' : 'addDiscussionComment'}${flags['reply-to'] ? ` (reply to ${flags['reply-to']})` : ''}. Nothing posted; posted.json unchanged.`); process.exit(0); }

let url;
if (kind === 'issue') {
  url = gh(['issue', 'comment', String(n), '--repo', REPO, '--body-file', bodyFile]).trim().split('\n').at(-1);
} else {
  const query = 'mutation($id:ID!,$body:String!,$replyTo:ID){addDiscussionComment(input:{discussionId:$id,body:$body,replyToId:$replyTo}){comment{url}}}';
  const variables = { id: t.id, body, ...(flags['reply-to'] ? { replyTo: flags['reply-to'] } : {}) };
  const r = JSON.parse(gh(['api', 'graphql', '--input', '-'], JSON.stringify({ query, variables })));
  if (r.errors) die(`GitHub error: ${JSON.stringify(r.errors)}`);
  url = r.data.addDiscussionComment.comment.url;
}
posted.push({ n, kind, url, postedAt: new Date().toISOString(), bodyFile: path.resolve(bodyFile), sha256: crypto.createHash('sha256').update(body).digest('hex') });
writeJson(postedFile, posted);
console.log(`\nPosted: ${url}\nRecorded in ${postedFile}. Rebuild to move #${n} to Responded.`);
