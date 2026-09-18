# Skills

## Skills

| Skill | What it does | Docs |
|---|---|---|
| [`pis-todo`](./skills/pis-todo) | Turns a range of git commits into human-readable work-log entries (`<Module> -> <activity> : <duration>`) and creates them as todos via the `profile-plus` MCP — optionally marking them complete in the same run. | [docs](./skills/pis-todo/README.md) |
| [`pis-todo-to-tch`](./skills/pis-todo-to-tch) | Turns Profile Plus todos and attendance into a formatted internship log book (DOCX + PDF) using the Polinema template — month, week, or date-range periods. | [docs](./skills/pis-todo-to-tch/README.md) |

## Requirements

Per-skill requirements are listed in each skill's README.

## Repo layout

```
.
├── skills.sh.json                    # groups shown on the skills.sh repo page
└── skills/
    ├── pis-todo/
    │   ├── SKILL.md                  # what the agent loads
    │   ├── README.md                 # usage guide
    │   ├── install.sh                # installer (skill + OpenCode slash command)
    │   ├── install.ps1               # Windows installer
    │   ├── opencode/command/         # source of the slash command
    │   └── scripts/
    │       ├── collect-commits.mjs   # cross-platform collector (Node)
    │       └── collect-commits.sh    # identical output, POSIX shell fallback
    └── pis-todo-to-tch/
        ├── SKILL.md                  # what the agent loads
        ├── README.md                 # usage guide
        ├── config.example.json       # personal data template (copied to your workdir on first run)
        ├── install.sh                # installer (skill + OpenCode slash command)
        ├── install.ps1               # Windows installer
        ├── opencode/command/         # source of the slash command
        ├── assets/
        │   ├── template.docx         # placeholder log book template
        │   ├── contoh-log-book.docx  # filled example
        │   └── logo.jpeg             # letterhead logo for PDF rendering
        └── scripts/
            └── build-logbook.py      # period resolution, DOCX fill, PDF render
```

## License

[MIT](./LICENSE) © Raruu Kagami
