# Skills

[![skills.sh](https://skills.sh/b/Raruu/skills)](https://skills.sh/Raruu/skills)

Agent skills by [Raruu](https://github.com/Raruu).

## Skills

| Skill | What it does |
|---|---|
| [`pis-todo`](./skills/pis-todo) | Turns a range of git commits into human-readable work-log entries (`<Module> -> <activity> : <duration>`) and creates them as todos via the `profile-plus` MCP — optionally marking them complete in the same run. |

## Install

### Option 1 — skills CLI

Installs the skill file only (no slash command):

```bash
npx skills add Raruu/skills --skill pis-todo -g
```

Target a specific agent explicitly if you don't want to be prompted:

```bash
npx skills add Raruu/skills --skill pis-todo -g -a opencode
```

> **Note:** for OpenCode, the `skills` CLI installs to `~/.config/opencode/skills/`. OpenCode also reads `~/.agents/skills/`. Installing to both locations is fine but produces a `duplicate skill name` warning in the logs — pick one. The install script below uses `~/.agents/skills/`, which is shared with more agents.

### Option 2 — install script (skill + slash command)

Also drops the `/pis-todo` slash command into your OpenCode config.

**Linux, macOS, WSL, Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/Raruu/skills/main/install.ps1 | iex
```

Both scripts back up anything they overwrite and warn if a duplicate skill copy is found.

## Requirements

- **`git`** on `PATH` — the collector reads commit history through it.
- **Node.js 18+** — runs `collect-commits.mjs`, which works on Linux, macOS, and Windows without Bash or WSL.
  If Node is unavailable, the bundled `collect-commits.sh` produces identical output but needs a POSIX shell.
- **`profile-plus` MCP server** — only for creating the todos. The skill still drafts everything if the MCP is absent; it just cannot save.

## Using `pis-todo`

```
/pis-todo <Module>, <git range>, <date>, <mark-complete>
```

Every segment after the module name is optional:

| Segment | Example | Notes |
|---|---|---|
| Module | `SIPP Adipura` | Required. Used verbatim as the prefix of each entry. |
| Git range | `371fe53 -> 2f69e9c` | Start and end inclusive. Also accepts `A`, `A..B`, `A...B`. Omit to infer from your last recorded todo. |
| Date | `2026-09-15` | Defaults to today. |
| Mark complete | `done` | Also `complete`, `selesai`, `mark-complete`. Any position, case-insensitive. Creates every todo and immediately marks it DONE. |

```bash
/pis-todo My Project, 371fe53 -> 2f69e9c
/pis-todo My Project, 371fe53, 2026-09-15
/pis-todo My Project, done
```

The skill always shows a draft table first so you can correct wording, durations, or dates before anything is written.

### Example

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

## Repo layout

```
.
├── install.sh / install.ps1        # optional installers (skill + OpenCode slash command)
├── skills.sh.json                  # groups shown on the skills.sh repo page
├── opencode/command/pis-todo.md    # source of the slash command
└── skills/
    └── pis-todo/
        ├── SKILL.md
        └── scripts/
            ├── collect-commits.mjs # cross-platform collector (Node)
            └── collect-commits.sh  # identical output, POSIX shell fallback
```

## License

[MIT](./LICENSE) © Raruu Kagami
