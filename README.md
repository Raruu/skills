# Skills

## Skills

| Skill | What it does | Docs |
|---|---|---|
| [`pis-todo`](./skills/pis-todo) | Turns a range of git commits into human-readable work-log entries (`<Module> -> <activity> : <duration>`) and creates them as todos via the `profile-plus` MCP — optionally marking them complete in the same run. | [docs](./skills/pis-todo/README.md) |
## Requirements

Per-skill requirements are listed in each skill's README.

## Repo layout

```
.
├── skills.sh.json                  # groups shown on the skills.sh repo page
└── skills/
    └── pis-todo/
        ├── SKILL.md                # what the agent loads
        ├── README.md               # usage guide
        ├── install.sh              # installer (skill + OpenCode slash command)
        ├── install.ps1             # Windows installer
        ├── opencode/command/       # source of the slash command
        └── scripts/
            ├── collect-commits.mjs # cross-platform collector (Node)
            └── collect-commits.sh  # identical output, POSIX shell fallback
```

## License

[MIT](./LICENSE) © Raruu Kagami
