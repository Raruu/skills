# pis-todo

Turn a range of git commits into human-readable work-log entries and save them as todos via the `profile-plus` MCP.

Instead of pasting commit subjects into your timesheet, the skill reads your history, groups related commits into workstreams, translates them into plain language, estimates the duration from the diff, and creates the entries for you — optionally marking them complete in the same run.

## Requirements

- **`git`** on `PATH` — the collector reads commit history through it.
- **Node.js 18+** — runs `collect-commits.mjs`, which works on Linux, macOS, and Windows without Bash or WSL.
  If Node is unavailable, the bundled `collect-commits.sh` produces identical output but needs a POSIX shell.
- **`profile-plus` MCP server** — only for creating the todos. The skill still drafts everything if the MCP is absent; it just cannot save.

## Usage

```
/pis-todo <Module>, <git range>, <date>, <mark-complete>
```

Every segment after the module name is optional:

| Segment | Example | Notes |
|---|---|---|
| Module | `My Project` | Required. Used verbatim as the prefix of each entry. |
| Git range | `371fe53 -> 2f69e9c` | Start and end inclusive. Also accepts `A`, `A..B`, `A...B`. Omit to infer from your last recorded todo. |
| Date | `2026-09-15` | Defaults to today. |
| Mark complete | `done` | Also `complete`, `selesai`, `mark-complete`. Any position, case-insensitive. Creates every todo and immediately marks it DONE. |

```bash
/pis-todo My Project, 371fe53 -> 2f69e9c
/pis-todo My Project, 371fe53, 2026-09-15
/pis-todo My Project, done
```

The skill always shows a draft table first so you can correct wording, durations, or dates before anything is written.

## Example

Commits like these:

```
371fe53 feat(upload): add local file storage support
cb9f2ad feat(reporting): add report detail APIs
2f69e9c feat(reporting): add detail report page
```

become:

```
My Project -> Implementasi dukungan penyimpanan file lokal (Local File Storage) & pembaruan panduan arsitektur/keamanan : 1 jam
My Project -> Pengembangan backend API untuk detail laporan (Repositories, Services, Validators, & Endpoint API) : 2 jam
My Project -> Pembuatan antarmuka (frontend) halaman detail laporan, komponen UI, dan integrasi data : 2 jam
```

## Scripts

`scripts/collect-commits.mjs` gathers the commit data the skill works from. `scripts/collect-commits.sh` is a POSIX shell port with byte-identical output.

```bash
node scripts/collect-commits.mjs --repo <path> --range "A -> B"          # start & end inclusive
node scripts/collect-commits.mjs --repo <path> --from <ref> [--to <ref>]
node scripts/collect-commits.mjs --repo <path> --since <yyyy-MM-dd> [--until <yyyy-MM-dd>]
```

| Flag | Meaning |
|---|---|
| `--repo <path>` | Repository path (default: current directory) |
| `--range "<A -> B>"` | Commit range; accepts `A -> B`, `A..B`, `A...B`, or `A` |
| `--from` / `--to` | Explicit start (inclusive) and end refs |
| `--since` / `--until` | Date window, used when no range is given |
| `--author <email>` | Filter by author (default: `git config user.email`) |
| `--all-authors` | Include everyone's commits |
| `--max-files <n>` | Max file paths listed per commit (default: 12) |
| `--mark-from <date>` | Flag commits on/after this date as possible duplicates |

Each commit is reported as hash, date, subject, file count, +/− lines, and up to 12 file paths, followed by a `TOTAL` footer. `WARN: possible duplicate` appears when a commit's date is on/after `--mark-from`. `NO_COMMITS` means the range was empty.

## Install

See the [root README](../../README.md#install) for both install paths (skills CLI and the install script).
