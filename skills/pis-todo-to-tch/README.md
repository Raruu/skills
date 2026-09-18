# pis-todo-to-tch

Turn your Profile Plus todos and attendance records into a formatted internship log book — the official `LOG BOOK KEGIATAN` document, as DOCX and PDF.

Instead of retyping your activity log into the campus template, the skill reads your todos and check-in/check-out data through the `profile-plus` MCP, fills the document, and drops it in a `Laporan <Bulan>` folder in your working directory.

## Requirements

- **`profile-plus` MCP server** — source of todos and attendance.
- **Python 3** with **`python-docx`** (DOCX generation) and **`fpdf2`** (PDF rendering):
  ```bash
  pip install python-docx fpdf2
  ```
- A **serif font** for the PDF (Times New Roman if installed; Liberation Serif or DejaVu Serif work as fallbacks).

## Install

### Option 1 — skills CLI

Installs the skill file only (no slash command):

```bash
npx skills add Raruu/skills --skill pis-todo-to-tch -g
```

Target a specific agent explicitly if you don't want to be prompted:

```bash
npx skills add Raruu/skills --skill pis-todo-to-tch -g -a opencode
```

### Option 2 — install script (skill + slash command)

Also drops the `/pis-todo-to-tch` slash command into your OpenCode config.

**Linux, macOS, WSL, Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo-to-tch/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/Raruu/skills/main/skills/pis-todo-to-tch/install.ps1 | iex
```

Reinstalling replaces the installed copy outright and warns if a duplicate skill copy is found.

## Usage

```
/pis-todo-to-tch <periode>, <word|pdf>
/pis-todo-to-tch SETUP
```

Both segments are optional. Without a period, the current month (1st → today) is used. Without a format, both DOCX and PDF are generated.

| Period input | Meaning |
|---|---|
| *(empty)* | Current month, 1st → today |
| `September` / `September 2026` | That month (past: full month; current: 1st → today) |
| `September/minggu 2` | Calendar week 2 (Mon–Sun), clipped to the month |
| `September/minggu 2->3` | Calendar weeks 2 through 3 |
| `Tanggal 2026-09-01 -> 2026-09-15` | Explicit date range (only this date format) |

### SETUP

`/pis-todo-to-tch SETUP` prepares an empty working folder without generating anything:

- shows an environment report (config status, Python/libs, fonts, git),
- asks for your personal data (or offers selective updates if the config already exists),
- optionally adds `.pis-todo-to-tch.json` to `.gitignore`,
- smoke-tests the `profile-plus` MCP connection.

After SETUP, run `/pis-todo-to-tch` to generate the current month.

## Example

```
/pis-todo-to-tch September
```

Produces, in the current directory:

```
Laporan September 2026/
├── Log Book September 2026.docx
└── Log Book September 2026.pdf
```

The document contains the Polinema letterhead, your student info (from config), one row per working day with check-in/check-out times, one bullet per todo in the Kegiatan column, and the signature block.

Weekend rows appear only when that day has data. Days without attendance show `-` in the time columns.

## Config

Personal data is read from `.pis-todo-to-tch.json` in the working directory (the folder where you run the skill):

```json
{
  "nama": "Kamina Botan",
  "nim": "1234567890",
  "program_studi": "D-IV Teknik Informatika",
  "mitra_industri": "PT Hoshino Teknologi Nusantara",
  "dosen_pembimbing": "Kagamihara Nadeshiko",
  "pembimbing_lapangan": "Gotoh Hitori"
}
```

On first run the skill copies `config.example.json` to that path and asks you to confirm or edit the values before generating anything. Pass `--config <path>` to use a config elsewhere.

If the working folder is a git repository, add `.pis-todo-to-tch.json` to `.gitignore` — it contains personal data.

## Scripts

`scripts/build-logbook.py` does all the deterministic work: period resolution (`--resolve-only` for a dry run), filling the DOCX template, and rendering the PDF.

```bash
python3 scripts/build-logbook.py --input "September/minggu 2->3" --resolve-only
python3 scripts/build-logbook.py --input "September" --data data.json --outdir . --format both
```

`assets/template.docx` is the placeholder template; `assets/contoh-log-book.docx` shows a filled example.
