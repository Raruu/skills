# Skills

[![skills.sh](https://skills.sh/b/Raruu/skills)](https://skills.sh/Raruu/skills)

Agent skills by [Raruu](https://github.com/Raruu).

## Skills

| Skill | What it does | Docs |
|---|---|---|
| [`pis-todo`](./skills/pis-todo) | Turns a range of git commits into human-readable work-log entries (`<Module> -> <activity> : <duration>`) and creates them as todos via the `profile-plus` MCP — optionally marking them complete in the same run. | [docs](./skills/pis-todo/README.md) |

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

Both scripts back up anything they overwrite to `~/.agents/skill-backups/` (kept outside `skills/` so the agent's skill scanner does not try to load the old copy) and warn if a duplicate skill copy is found.

## Requirements

- **`git`** on `PATH` — the collectors read commit history through it.
- **Node.js 18+** — runs the cross-platform collector; a POSIX shell fallback ships alongside it.
- **`profile-plus` MCP server** — required by `pis-todo` to save the todos it drafts.

Per-skill requirements are listed in each skill's README.

## Repo layout

```
.
├── install.sh / install.ps1        # optional installers (skill + OpenCode slash command)
├── skills.sh.json                  # groups shown on the skills.sh repo page
├── opencode/command/pis-todo.md    # source of the slash command
└── skills/
    └── pis-todo/
        ├── SKILL.md                # what the agent loads
        ├── README.md               # usage guide
        └── scripts/
            ├── collect-commits.mjs # cross-platform collector (Node)
            └── collect-commits.sh  # identical output, POSIX shell fallback
```

## License

[MIT](./LICENSE) © Raruu Kagami
