// Shared helpers for the support sweep scripts.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export const REPO = 'microsoft/finops-toolkit';
export const [OWNER, NAME] = REPO.split('/');
export const TEAM = new Set(['flanakin', 'MSBrett', 'RolandKrummenacher', 'helderpinto']);
export const TEAM_ASSOC = new Set(['OWNER', 'MEMBER', 'COLLABORATOR']);
export const BOTS = /\[bot\]$|^microsoft-github-policy-service$|^allcontributors$|^github-actions$/;
export const SKIP_CATEGORIES = new Set(['Announcements', 'Polls', 'Releases']);
export const ROOT = process.env.FTK_SWEEPS_ROOT || path.join(os.homedir(), '.claude', 'ftk-sweeps'); // env override is for testing
export const ARTIFACT_URL_FILE = path.join(ROOT, 'artifact-url.txt');

export const isUs = (login, assoc) => TEAM.has(login) || TEAM_ASSOC.has(assoc);
export const isBot = login => !login || BOTS.test(login);
export const iso = d => new Date(d).toISOString().slice(0, 10);
export const daysSince = (d, now = new Date()) => Math.max(0, Math.round((now - new Date(d)) / 864e5));
export const ref = t => `${t.kind === 'issue' ? 'i' : 'd'}${t.n}`;

export function args(argv = process.argv.slice(2)) {
  const flags = {}, pos = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { pos.push(a); continue; }
    const k = a.slice(2);
    if (argv[i + 1] !== undefined && !argv[i + 1].startsWith('--')) flags[k] = argv[++i]; else flags[k] = true;
  }
  return { flags, pos };
}

export function gh(argv, input) {
  return execFileSync('gh', argv, { encoding: 'utf8', maxBuffer: 2e8, input, stdio: [input ? 'pipe' : 'ignore', 'pipe', 'pipe'] });
}

export function gql(query, vars = {}) {
  const a = ['api', 'graphql', '-f', `query=${query}`];
  for (const [k, v] of Object.entries(vars)) a.push(typeof v === 'number' ? '-F' : '-f', `${k}=${v}`);
  const r = JSON.parse(gh(a));
  if (r.errors) throw new Error(JSON.stringify(r.errors));
  return r.data;
}

// Latest sweep folder, or the one passed with --sweep.
export function sweepDir(flag) {
  if (flag && flag !== true) return path.resolve(flag);
  const dirs = fs.existsSync(ROOT) ? fs.readdirSync(ROOT).filter(d => /^\d{4}-\d{2}-\d{2}$/.test(d)).sort() : [];
  if (!dirs.length) throw new Error(`No sweep found in ${ROOT}. Run gather.mjs first.`);
  return path.join(ROOT, dirs.at(-1));
}

export const readJson = (f, d) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return d; } };
export const writeJson = (f, v) => { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, JSON.stringify(v, null, 1)); };

// Flatten issue comments or discussion comments + replies into one sorted list of people (no bots).
export function people(nodes, discussion) {
  const all = discussion ? nodes.flatMap(c => [c, ...(c.replies?.nodes || [])]) : nodes;
  return all.filter(c => !isBot(c.author?.login)).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}

// Parse triage markdown blocks: "## #N Title · Sev · Action · Confidence" followed by "- **Field:**" bullets.
// Returns { [n]: block }.
export function parseTriage(md) {
  const out = {};
  for (const part of md.replace(/<!--[\s\S]*?-->/g, '').split(/\n(?=## #\d)/)) {
    const m = part.match(/^## #(\d+)\s+(.*)$/m);
    if (!m || !part.startsWith('## #')) continue;
    const n = +m[1];
    const lines = part.split('\n');
    const body = lines.slice(1).join('\n').split(/\n#{1,2} (?!#\d)/)[0].replace(/\n---\s*$/, '').trim();
    const segs = m[2].split(' · ').map(s => s.trim());
    const si = segs.findIndex((s, i) => i > 0 && /^(S[0-3]|Q)\b/.test(s));
    const field = k => (body.match(new RegExp(`^- \\*\\*${k}:\\*\\*\\s*(.+)$`, 'im')) || [])[1]?.trim() || '';
    let sev = field('Severity') || (si > 0 ? segs[si].match(/^(S[0-3]|Q)/)[1] : '');
    sev = (sev.match(/^(S[0-3]|Q)/) || [])[1] || '';
    let action = field('Action') || (si > 0 ? segs.slice(si + 1, -1).join(' · ') : '');
    let conf = field('Confidence') || (si > 0 && segs.length > si + 1 ? segs.at(-1) : '');
    conf = (conf.replace(/confidence\s*/i, '').match(/^(HIGH|MED|LOW)/i) || [''])[0].toUpperCase();
    const dm = body.match(/^-? ?\*\*Draft reply:\*\*\s*\n+((?:>.*(?:\n|$))+)/m);
    let draft = dm ? dm[1].split('\n').map(l => l.replace(/^> ?/, '')).join('\n').trim() : '';
    if (/^\(?\s*none\b/i.test(draft)) draft = ''; // "none (internal)" means no reply
    const evidence = body
      .replace(/^-? ?\*\*Draft reply:\*\*[\s\S]*$/m, '')
      .split('\n').filter(l => !/^- \*\*(Severity|Action|Confidence|Your call|Problem|So far|Open|Kind):\*\*/i.test(l))
      .join('\n').trim();
    out[n] = {
      n, title: (si > 0 ? segs.slice(0, si) : [segs[0]]).join(' · '), sev, action, conf,
      ask: field('Your call'), problem: field('Problem'), sofar: field('So far'), open: field('Open'),
      draft, evidence, raw: part.trim(),
    };
  }
  return out;
}

export function readTriage(dir) {
  const t = path.join(dir, 'triage');
  const out = {};
  if (!fs.existsSync(t)) return out;
  for (const f of fs.readdirSync(t).filter(f => f.endsWith('.md')).sort()) Object.assign(out, parseTriage(fs.readFileSync(path.join(t, f), 'utf8')));
  return out;
}

// Current state of one thread, for the post-time safety check.
const WHO = 'author{login} authorAssociation';
const ISSUE_Q = `id number title url state locked lastEditedAt ${WHO} comments(last:100){nodes{id url createdAt lastEditedAt ${WHO} body}}`;
const DISC_Q = `id number title url closed locked lastEditedAt answer{id createdAt ${WHO}} ${WHO} comments(last:100){nodes{id url createdAt lastEditedAt ${WHO} body replies(last:100){nodes{id url createdAt lastEditedAt ${WHO} body}}}}`;
export function normalize(kind, t) {
  if (!t) return null;
  const d = kind === 'discussion';
  return {
    kind, n: t.number, id: t.id, title: t.title, url: t.url, locked: t.locked, lastEditedAt: t.lastEditedAt,
    closed: d ? t.closed : t.state !== 'OPEN', answered: d ? !!t.answer : false, answer: t.answer || null,
    comments: (d ? t.comments.nodes.flatMap(c => [c, ...(c.replies?.nodes || [])]) : t.comments.nodes)
      .map(c => ({ id: c.id, url: c.url, at: c.createdAt, editedAt: c.lastEditedAt, by: c.author?.login || 'ghost', us: isUs(c.author?.login, c.authorAssociation), bot: isBot(c.author?.login), body: c.body }))
      .sort((a, b) => a.at.localeCompare(b.at)),
  };
}
export function fetchThread(kind, n) {
  const q = `query($n:Int!){repository(owner:"${OWNER}",name:"${NAME}"){${kind === 'issue' ? `issue(number:$n){${ISSUE_Q}}` : `discussion(number:$n){${DISC_Q}}`}}}`;
  return normalize(kind, gql(q, { n: +n }).repository[kind]);
}
// Many threads at once (aliased), for the build refresh.
export function fetchMany(list, chunk = 20) {
  const out = {};
  for (let i = 0; i < list.length; i += chunk) {
    const part = list.slice(i, i + chunk);
    const body = part.map(t => `${ref(t)}:${t.kind}(number:${t.n}){${t.kind === 'issue' ? ISSUE_Q : DISC_Q}}`).join(' ');
    const r = gql(`{repository(owner:"${OWNER}",name:"${NAME}"){${body}}}`).repository;
    for (const t of part) out[t.n] = normalize(t.kind, r[ref(t)]);
  }
  return out;
}
