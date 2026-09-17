#!/usr/bin/env node
//
// collect-commits.mjs — deterministic git history collector for the `pis-todo` skill.
//
// Cross-platform (Linux, macOS, Windows) Node.js port of collect-commits.sh.
// Emits the same stable, line-oriented report so an agent can translate commits
// into human-readable todos without guessing at stats or paths.
//
// Usage:
//   node collect-commits.mjs --repo <path> --range "A -> B"          # start & end inclusive
//   node collect-commits.mjs --repo <path> --from <ref> [--to <ref>]
//   node collect-commits.mjs --repo <path> --since <yyyy-MM-dd> [--until <yyyy-MM-dd>]
//
// Options:
//   --repo <path>        Repository path (default: current directory)
//   --range "<A -> B>"   Commit range; accepts "A -> B", "A..B", "A...B", or "A"
//   --from <ref>         Start ref (inclusive)
//   --to <ref>           End ref (default: HEAD)
//   --since <date>       Only commits after this date (when no range/from given)
//   --until <date>       Only commits up to this date
//   --author <email>     Filter by author email (default: git config user.email)
//   --all-authors        Do not filter by author
//   --max-files <n>      Max file paths listed per commit (default: 12)
//   --mark-from <date>   Mark commits with date >= <date> as possible duplicates
//   -h, --help           Show this help
//
// Exit codes: 0 ok | 2 bad usage | 3 author unknown | 4 bad repo/ref
//

import { execFileSync } from 'node:child_process';

const USAGE = `collect-commits.mjs — deterministic git history collector for the \`pis-todo\` skill.

Emits a stable, line-oriented report of commits in a range so an agent can
translate them into human-readable todos without guessing at stats or paths.

Usage:
  collect-commits.mjs --repo <path> --range "A -> B"          # start & end inclusive
  collect-commits.mjs --repo <path> --from <ref> [--to <ref>]
  collect-commits.mjs --repo <path> --since <yyyy-MM-dd> [--until <yyyy-MM-dd>]

Options:
  --repo <path>        Repository path (default: current directory)
  --range "<A -> B>"   Commit range; accepts "A -> B", "A..B", "A...B", or "A"
  --from <ref>         Start ref (inclusive)
  --to <ref>           End ref (default: HEAD)
  --since <date>       Only commits after this date (when no range/from given)
  --until <date>       Only commits up to this date
  --author <email>     Filter by author email (default: git config user.email)
  --all-authors        Do not filter by author
  --max-files <n>      Max file paths listed per commit (default: 12)
  --mark-from <date>   Mark commits with date >= <date> as possible duplicates
  -h, --help           Show this help

Exit codes: 0 ok | 2 bad usage | 3 author unknown | 4 bad repo/ref`;

function die(code, message) {
  process.stderr.write(`ERROR: ${message}\n`);
  process.exit(code);
}

// --- argument parsing --------------------------------------------------------
let repo = '.';
let range = '';
let from = '';
let to = '';
let since = '';
let until = '';
let author = '';
let allAuthors = false;
let maxFilesRaw = '12';
let markFrom = '';

const VALUE_FLAGS = {
  '--repo': (v) => { repo = v; },
  '--range': (v) => { range = v; },
  '--from': (v) => { from = v; },
  '--to': (v) => { to = v; },
  '--since': (v) => { since = v; },
  '--until': (v) => { until = v; },
  '--author': (v) => { author = v; },
  '--mark-from': (v) => { markFrom = v; },
  '--max-files': (v) => { maxFilesRaw = v; },
};

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if (arg === '-h' || arg === '--help') {
    process.stdout.write(`${USAGE}\n`);
    process.exit(0);
  }
  if (arg === '--all-authors') {
    allAuthors = true;
    continue;
  }
  const setter = VALUE_FLAGS[arg];
  if (setter) {
    if (i + 1 >= argv.length) die(2, `${arg} requires a value`);
    setter(argv[++i]);
    continue;
  }
  die(2, `unknown option: ${arg} (see --help)`);
}

// --- git helpers -------------------------------------------------------------
function git(args, { input, allowFailure = false } = {}) {
  try {
    return execFileSync('git', ['-C', repo, ...args], {
      input,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (err) {
    if (allowFailure) return null;
    const stderr = err.stderr ? String(err.stderr) : '';
    const stdout = err.stdout ? String(err.stdout) : '';
    if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);
    process.exit(4);
  }
}

if (git(['rev-parse', '--git-dir'], { allowFailure: true }) === null) {
  die(4, `not a git repository: ${repo}`);
}
if (git(['rev-parse', '--verify', '--quiet', 'HEAD'], { allowFailure: true }) === null) {
  die(4, `repository has no commits yet: ${repo}`);
}

// --- author filter -----------------------------------------------------------
if (!allAuthors) {
  if (!author) {
    const configured = git(['config', 'user.email'], { allowFailure: true });
    author = configured ? configured.trim() : '';
  }
  if (!author) die(3, 'author email unknown; pass --author <email> or --all-authors');
}

// --- normalize --range -------------------------------------------------------
if (range) {
  const trimmed = range.trim();
  if (trimmed.includes('...')) {
    [from, to] = trimmed.split('...', 2);
  } else if (trimmed.includes('..')) {
    [from, to] = trimmed.split('..', 2);
  } else if (trimmed.includes('->')) {
    [from, to] = trimmed.split('->', 2);
  } else {
    from = trimmed;
  }
  from = (from ?? '').replace(/\s+$/, '');
  to = (to ?? '').replace(/^\s+|\s+$/g, '');
}

// --- resolve commit list -----------------------------------------------------
let hashes = [];
let rangeDesc = '';
let mode = '';

function revParse(ref) {
  const out = git(['rev-parse', '--verify', '--quiet', ref], { allowFailure: true });
  return out ? out.trim() : null;
}

if (from) {
  mode = 'range';
  const fromFull = revParse(`${from}^{commit}`);
  if (!fromFull) die(4, `start ref not found: ${from}`);
  const toRef = to || 'HEAD';
  const toFull = revParse(`${toRef}^{commit}`);
  if (!toFull) die(4, `end ref not found: ${toRef}`);

  const isAncestor = git(['merge-base', '--is-ancestor', fromFull, toFull], { allowFailure: true });
  if (isAncestor !== null) {
    const parent = revParse(`${fromFull}^`);
    if (parent) {
      rangeDesc = `${from}^..${toRef} (start inclusive)`;
      hashes = git(['rev-list', `${parent}..${toFull}`]).split('\n').filter(Boolean);
    } else {
      // root commit: A^ does not exist, walk from the end and stop at A (inclusive)
      rangeDesc = `${from}..${toRef} + root commit ${from} (start inclusive)`;
      const all = git(['rev-list', toFull]).split('\n').filter(Boolean);
      hashes = [];
      for (const hash of all) {
        hashes.push(hash);
        if (hash === fromFull) break;
      }
    }
  } else {
    process.stderr.write(
      `WARN: start ref is not an ancestor of end ref; using exclusive range ${from}..${toRef}\n`,
    );
    rangeDesc = `${from}..${toRef} (exclusive, non-ancestor)`;
    hashes = git(['rev-list', `${fromFull}..${toFull}`]).split('\n').filter(Boolean);
  }

  if (hashes.length === 0) {
    process.stdout.write(`NO_COMMITS: no commits found in range (${rangeDesc})\n`);
    process.exit(0);
  }
} else {
  mode = 'date';
  if (/^\d{4}-\d{2}-\d{2}$/.test(until)) {
    until = `${until} 23:59:59`; // include the whole end day
  }
  rangeDesc = `since=${since || 'beginning'} until=${until || 'HEAD'}`;
}

// --- emit raw commit stream --------------------------------------------------
const gitArgs = ['log', '--no-merges', '--numstat', '--format=@@@%h\t%ad\t%an\t%s', '--date=format:%Y-%m-%d'];
if (!allAuthors) gitArgs.push(`--author=${author}`);

let raw;
if (mode === 'range') {
  // rev-list is newest-first; reverse so the report reads chronologically
  const ordered = [...hashes].reverse().join('\n');
  raw = git([...gitArgs, '--no-walk=unsorted', '--stdin'], { input: `${ordered}\n` });
} else {
  const dateArgs = [];
  if (since) dateArgs.push(`--since=${since}`);
  if (until) dateArgs.push(`--until=${until}`);
  raw = git([...gitArgs, '--reverse', ...dateArgs]);
}

// awk compares `nfiles <= max_files` using strnum semantics: numeric when the
// value looks numeric, lexicographic string comparison otherwise. Emulate it so
// odd inputs like `--max-files abc` behave exactly like the bash version.
function looksNumeric(value) {
  return /^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\s*$/.test(value);
}

function withinMaxFiles(nfiles, raw) {
  if (looksNumeric(raw)) return nfiles <= Number(raw);
  return String(nfiles) <= raw;
}

// --- render report -----------------------------------------------------------
const out = [];
let nCommits = 0;
let totFiles = 0;
let totIns = 0;
let totDel = 0;

let current = null;

function flush() {
  if (!current) return;
  out.push(`=== COMMIT ${current.hash}`);
  out.push(`DATE: ${current.date}`);
  out.push(`SUBJECT: ${current.subject}`);
  out.push(`STAT: ${current.nfiles} files, +${current.ins} -${current.del}`);
  if (current.warn) out.push('WARN: possible duplicate — date overlaps last recorded todo');
  out.push('FILES:');
  if (current.files.length > 0) out.push(current.files.join('\n'));
  if (current.more > 0) out.push(`  ... (+${current.more} more files)`);
  out.push('END');
  out.push('');
  nCommits++;
  totFiles += current.nfiles;
  totIns += current.ins;
  totDel += current.del;
}

for (const line of raw.split('\n')) {
  if (line.startsWith('@@@')) {
    flush();
    const fields = line.split('\t');
    current = {
      hash: (fields[0] ?? '').slice(3),
      date: fields[1] ?? '',
      subject: fields.slice(3).join('\t'),
      nfiles: 0,
      ins: 0,
      del: 0,
      files: [],
      more: 0,
      warn: markFrom !== '' && (fields[1] ?? '') >= markFrom,
    };
    continue;
  }
  if (!current) continue;
  const parts = line.split('\t');
  if (parts.length >= 3 && parts[2] !== '') {
    current.nfiles++;
    if (/^\d+$/.test(parts[0])) current.ins += Number(parts[0]);
    if (/^\d+$/.test(parts[1])) current.del += Number(parts[1]);
    if (withinMaxFiles(current.nfiles, maxFilesRaw)) current.files.push(`  ${parts[2]}`);
    else current.more++;
  }
}
flush();

if (nCommits === 0) out.push('NO_COMMITS: no commits matched the filters in this range');
out.push(`TOTAL: ${nCommits} commits | ${totFiles} file-changes | +${totIns} -${totDel}`);
out.push(`RANGE: ${rangeDesc}`);
out.push(`AUTHOR: ${author || '(all authors)'}`);

process.stdout.write(`${out.join('\n')}\n`);
