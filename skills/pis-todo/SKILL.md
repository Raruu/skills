---
name: pis-todo
description: "Turn git commit history into human-readable work-log todos in Profile Plus (MCP profile-plus). Use whenever the user runs /pis-todo, or asks to \"catat todo\", \"rekap commit jadi todo\", \"catat progress/progress kerja\", \"log pekerjaan\", \"backfill timesheet\", \"isi timesheet dari commit\", or wants their commits converted into activity entries for reporting. Produces entries in the form `<Module> -> <human activity> : <duration>` and creates them via profile-plus_create_todo after user confirmation. Optionally marks every created todo as DONE (complete) in one go when the mark-complete keyword is given."
---

# PIS Todo — Git Commits → Human-Readable Todos

Convert a range of git commits into the way the user actually reports work: one human-readable activity per workstream, with a realistic time estimate, logged into Profile Plus.

The user's reporting style is fixed — every entry looks like:

```
<Module> -> <human activity> : <duration>
```

The commits are only raw material. Never paste commit subjects verbatim (`feat(manajemen-laporan): add report detail APIs` is not a todo). Translate them into how a person would describe the work to their manager, in Indonesian, and estimate the time from the diff size and layers touched.

## Invocation

```
/pis-todo <Module>, <git range>, <date>, <mark-complete>
```

All comma-separated segments are parsed positionally:

| Segment | Required | Meaning |
|---|---|---|
| 1 | yes | Module/project name, e.g. `My Project`. May contain spaces and `/`. |
| 2 | no | Git range: `A -> B` (start & end inclusive), `A` (start only → HEAD), `A..B`, or `A...B`. |
| 3 | no | Date for the todos, `yyyy-MM-dd`. Default: today. |
| 4 | no | Mark-complete keyword: `done`, `complete`, `selesai`, or `mark-complete` — creates every todo and immediately marks it DONE. Case-insensitive, may appear in any position, with or without a leading `--`. |

If segments are missing or the input has no commas, be forgiving: detect a date with `\d{4}-\d{2}-\d{2}`, a range with `->` / `..`, and the mark-complete keyword with `^(--)?(done|complete|selesai|mark-complete)$` (case-insensitive). Strip the keyword **before** assigning positions, then treat the rest as the module name. Guard: if nothing remains after stripping the keyword (e.g. `/pis-todo done`), treat the keyword as the module name instead. When the module name is genuinely ambiguous, ask.

Examples:

```
/pis-todo My Project, 371fe53 -> 2f69e9c
/pis-todo My Project, 371fe53, 2026-09-15
/pis-todo My Project, 371fe53 -> 2f69e9c, done
/pis-todo My Project, 371fe53 -> 2f69e9c, 2026-09-15, selesai
/pis-todo My Project, done              # range inferred, todos marked DONE right away
/pis-todo Event Management Dev, 2026-09-16
```

## Step 1 — Locate the repository

Run git commands in the current working directory. If it is not a git repository, ask the user for the repo path before continuing. Never assume a path.

## Step 2 — Resolve the commit range

| Input | Behavior |
|---|---|
| `A -> B` | Start **and** end inclusive (`git log A^..B`). |
| `A` only | `A^..HEAD` — everything since that commit. |
| No range | **Infer**: call `profile-plus_get_todo_history` and search for the module name. Use the date of the most recent matching todo as the lower bound. Mark commits on that date (or later) as possible duplicates in the draft. Fallback when there is no history: the last 10 commits of the current author. |

The author filter defaults to `git config user.email` — this repo may be shared, and the user only wants to log their own work. Pass `--all-authors` only if the user explicitly asks for everyone's commits.

The bundled script `scripts/collect-commits.mjs` (relative to this skill) does all of this deterministically. Prefer it over ad-hoc git commands. It is a Node.js script, so it works identically on Linux, macOS, and Windows — no Bash, WSL, or Git Bash required:

```bash
node scripts/collect-commits.mjs --repo <path> --range "A -> B"
node scripts/collect-commits.mjs --repo <path> --from <ref> [--to <ref>]
node scripts/collect-commits.mjs --repo <path> --since <yyyy-MM-dd> [--until <yyyy-MM-dd>] --mark-from <yyyy-MM-dd>
```

A Bash implementation (`scripts/collect-commits.sh`) ships alongside it with byte-identical output. Use it only when Node is unavailable:

```bash
bash scripts/collect-commits.sh --repo <path> --range "A -> B"
```

Either script emits per commit: hash, date, subject, file count, +/− lines, and up to 12 file paths (chronological order), plus a `TOTAL` footer. `WARN: possible duplicate` appears when a commit's date is on/after `--mark-from`. If it prints `NO_COMMITS`, tell the user the range was empty and suggest a different one — do not invent todos.

## Step 3 — Group commits into activities

Grouping is where the human quality comes from. Rules:

- Different workstreams → separate entries, even in the same commit range.
- Iterations of the same workstream → merge into one entry. Example from real history: `feat: implement budget CRUD` + `ui update budget` + `fix : edit budget failed` is **one** activity, not three.
- A large `feat` that spans backend + frontend may be split into two entries (one per layer) when that matches how the user reports.
- Tiny chores (typo, copy tweak, hide a column) may be merged into a neighboring activity or kept as a `10 - 15 menit` entry if they stand alone.
- Never produce one entry per commit mechanically — and never fewer entries than distinct workstreams.

## Step 4 — Translate and estimate

For each activity, derive the human description from three signals:

1. **Commit scope** (`feat(manajemen-laporan)` → the feature name, `fix(upload)` → the module being fixed).
2. **Commit type**: `feat` → "Pengembangan/Pembuatan/Implementasi/Menambahkan", `fix` → "Perbaikan/Bug fix", `refactor` → "Refactor/Rombak", `docs` → "Pembaruan panduan", `test` → "Pengujian", `chore`/`build` → "Konfigurasi/Setup".
3. **Files touched** → layer, which becomes the parenthetical detail:
   - `prisma/`, `seeds/`, `migrations/` → "skema & seeder", "DB"
   - `server/repositories|services|validators`, `app/api` → "backend API (Repositories, Services, Validators, & Endpoint API)"
   - `components|hooks|app/dashboard`, `services/*-service.ts`, `styles/` → "antarmuka (frontend) ... dan integrasi data"
   - `.kiro/`, `*.md` → "pembaruan panduan ..."

Estimate duration from the diff — calibrated against the user's real logs:

| Scale | Signal | Estimate |
|---|---|---|
| Trivial | 1 file, < 20 lines | `10 - 15 menit` |
| Small | fix, 1–3 files, < 100 lines | `30 - 45 menit` |
| Medium | fix/refactor within one layer | `45 menit - 1 jam` |
| Feature, one layer | backend **or** frontend feature | `2 - 3 jam` |
| Multi-layer | backend + frontend | `3 - 4 jam` |
| With DB work | schema/migration/seeder + code | `4 - 6 jam` |

Ground truth from the user's history: `src/lib/upload.ts` + docs (~100 lines) → `1 jam`; 13 backend files (~865 lines) → `2 jam`; 22 frontend files (~2175 lines) → `2 jam`. Use a range (`2 - 3 jam`) when uncertain; single values are fine when confident. Duration formats in use: `10 menit`, `30 menit`, `45 menit`, `1 jam`, `1.5 jam`, `2 jam`, `2 - 3 jam`.

## Step 5 — Output format

**ALWAYS** use this exact template for each entry:

```
{Module} -> {human activity} : {duration}
```

The `{Module}` is exactly what the user passed as segment 1. Do not add prefixes like `feat:` or `[backend]`. Keep technical terms that carry meaning in parentheses.

Few-shot examples (real entries from this user's Profile Plus history):

**Input commits:**
```
371fe53 feat(upload): add local file storage support
  .kiro/steering/backend-architecture.md, .kiro/steering/security.md, src/lib/s3.ts, src/lib/upload.ts  (+103 -81)
```
**Output:** `My Project -> Implementasi dukungan penyimpanan file lokal (Local File Storage) & pembaruan panduan arsitektur/keamanan : 1 jam`

**Input commits:**
```
cb9f2ad feat(manajemen-laporan): add report detail APIs
  src/app/api/**, src/server/repositories/**, services/**, validators/**  (13 files, +865)
```
**Output:** `My Project -> Pengembangan backend API untuk detail laporan (Repositories, Services, Validators, & Endpoint API) : 2 jam`

**Input commits:**
```
2f69e9c feat(manajemen-laporan): add detail laporan page
  src/app/dashboard/**, components/dashboard/**, hooks/**, services/**, types/report.ts  (22 files, +2175)
```
**Output:** `My Project -> Pembuatan antarmuka (frontend) halaman detail laporan, komponen UI, dan integrasi data : 2 jam`

**Input commits (db + seeder):**
```
0236fe1 feat(db): period snapshot + component assessments
  prisma/schema.prisma, prisma/seeds/**  (+237)
```
**Output:** `My Project -> update db, tambah skema & seeder untuk snapshot titik pantau : 2 jam`

## Step 6 — Draft, confirm, then create

Show the draft **before** calling any MCP tool. Present a compact table:

```
Berikut draft todo yang akan dibuat (tanggal: 2026-09-15):

| #   | Kegiatan                                                                           | Estimasi | Sumber  |
| --- | ---------------------------------------------------------------------------------- | -------- | ------- |
| 1   | My Project -> Implementasi dukungan penyimpanan file lokal (Local File Storage)... | 1 jam    | 371fe53 |
| 2   | My Project -> Pengembangan backend API untuk detail laporan (...)                  | 2 jam    | cb9f2ad |
| 3   | My Project -> Pembuatan antarmuka (frontend) halaman detail laporan (...)          | 2 jam    | 2f69e9c |
```

Include a ⚠️ marker on rows derived from commits flagged as possible duplicates. If the mark-complete keyword was given, add a line above the table saying all todos will be marked DONE right after creation. Then ask the user to confirm or edit (text, duration, date, merge/split/remove items).

Only after explicit approval, call `profile-plus_create_todo` once per activity with:

- `task`: the full formatted string (`{Module} -> {activity} : {duration}`)
- `date`: the resolved date in `yyyy-MM-dd`

If the mark-complete keyword was given, immediately follow each successful `create_todo` with `profile-plus_update_todo`:

- `id`: the ID returned by `create_todo`
- `status`: `DONE` — always pass this explicitly. Calling `update_todo` with only an `id` toggles the current status instead of setting DONE, which silently flips an already-DONE todo back to PENDING.

Finally, report the outcome per item. Always show the date and status so the user can see what was actually persisted:

```
| # | Kegiatan                                      | Tanggal    | Status   | ID       |
|---|-----------------------------------------------|------------|----------|----------|
| 1 | My Project -> Implementasi ... : 1 jam        | 2026-09-15 | DONE ✅  | b8e7b6c3 |
| 2 | My Project -> Pengembangan backend ... : 2 jam | 2026-09-15 | PENDING  | 0d1ea635 |
```

## Edge cases

- **Not a git repo / no repo path** → ask, do not guess.
- **Empty range** → report `NO_COMMITS`, propose an alternative range (e.g. widen or use `--since`), never fabricate entries — and never create or mark anything, even when the mark-complete keyword was given.
- **`user.email` unset** → ask which email to filter by, or whether to include all authors.
- **Start ref is not an ancestor of end ref** → the script warns and uses an exclusive range; surface this to the user.
- **Root commit as start ref** → the script handles it (inclusive of the root); no action needed.
- **Windows** → run `node scripts/collect-commits.mjs`; no Git Bash or WSL needed. `git` must be on `PATH` (Git for Windows provides it). If Node is missing, `collect-commits.sh` needs Git Bash or WSL.
- **More than 15 activities** → suggest splitting into multiple runs.
- **Uncommitted changes exist** → optionally mention them and offer to include them as a separate entry; do not silently include.
- **MCP call fails** → report the error and stop; do not retry blindly or silently drop entries.
- **`create_todo` succeeds but `update_todo` fails** → report which items are still `PENDING` with their IDs so the user can fix them manually, then stop; do not blindly retry.
- **Before creating**, when history inference was used, double-check for duplicates against `profile-plus_get_todo_history` and skip or flag entries that already exist.
