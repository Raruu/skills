# 9router-text-2-image

Generate images (text-to-image) through the [9Router](https://github.com/decolua/9router) OpenAI-compatible gateway, with a persistent model preference store and a learned resolution/quirk log.

On top of a plain text-to-image call, the skill adds:

- A **directive block** to override the model and resolution per run.
- **`preferences.md`** — your primary model plus ordered fallback models, written by `SET`.
- **`notes.md`** — which models support which resolutions, plus provider quirks and learned failures.

It never switches models silently: fallbacks are only used after you confirm.

## Requirements

- **9Router reachable** — set `NINEROUTER_URL` (and `NINEROUTER_KEY` if the gateway requires auth).
  ```bash
  export NINEROUTER_URL="http://localhost:20128"
  export NINEROUTER_KEY="sk-..."
  ```
- **`curl`** — used to call the gateway and download results.

## Install

### Option 1 — skills CLI

Installs the skill file only (no slash command):

```bash
npx skills add Raruu/skills --skill 9router-text-2-image -g
```

Target a specific agent explicitly if you don't want to be prompted:

```bash
npx skills add Raruu/skills --skill 9router-text-2-image -g -a opencode
```

### Option 2 — install script (skill + slash command)

Also drops the `/9router-text-2-image` slash command into your OpenCode config.

**Linux, macOS, WSL, Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/Raruu/skills/main/skills/9router-text-2-image/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/Raruu/skills/main/skills/9router-text-2-image/install.ps1 | iex
```

Reinstalling replaces the installed copy outright and warns if a duplicate skill copy is found.

> The installers copy the whole skill folder, so your `preferences.md` and `notes.md` travel with it. Back them up if you keep a lot of learned notes before reinstalling.

## Usage

```
/9router-text-2-image <prompt>
/9router-text-2-image >model:<id>; res:<size>< <prompt>
/9router-text-2-image SET >MODEL:<id>; MODEL1:<id>; MODEL2:<id><
```

| Form | Example | Notes |
|---|---|---|
| Prompt only | `/9router-text-2-image a watercolor mountain range` | Uses the primary model and default resolution. |
| Model override | `/9router-text-2-image >model:cx/gpt-image-2.5< a neon city` | Per-run only; does not change `preferences.md`. |
| Resolution | `/9router-text-2-image >res:wide< a cinematic desert highway` | `res:wide` maps to a landscape size per model (see `notes.md`). |
| Both | `/9router-text-2-image >model:gemini/gemini-3-pro-image-preview; res:1024x1024< a fox` | Keys are separated by `;`. |
| Save preferences | `/9router-text-2-image SET >MODEL:cx/gpt-image-2.5; MODEL1:openrouter/openai/dall-e-3<` | Writes `preferences.md`; generates nothing. |

The directive block is everything between the first `>` and the last `<`. Anything outside it is the prompt.

### Resolution

| Value | Meaning |
|---|---|
| `1024x1024` | Exact square size, passed through as `size`. |
| `wide` | Landscape. The skill substitutes the model's landscape size from `notes.md` (e.g. `1792x1024` for DALL-E 3, `1536x1024` for gpt-image-1 style models). |
| *(omitted)* | Defaults to `1024x1024`. |

### SET — model preferences

```
/9router-text-2-image SET >MODEL:<primary>; MODEL1:<fallback>; MODEL2:<fallback><
```

- `MODEL` is the primary; `MODEL1`, `MODEL2`, … are fallbacks, tried in order.
- Saved to `preferences.md`. Model ids are validated against `/v1/models/image` when possible.

### Fallback behavior

When generation fails, the skill always asks before doing anything else:

- With fallbacks configured: **"Model `<primary>` failed. Try fallback `<next>`?"**
- With no fallbacks: **"Model `<primary>` failed. Try again?"**

Each switch needs its own confirmation — fallbacks are never chained automatically. Capability failures (unsupported resolution, provider quirks) are recorded in `notes.md`; transport errors (401, 503, timeouts) are not.

## Files in this skill

| File | Purpose |
|---|---|
| `SKILL.md` | What the agent loads. |
| `preferences.md` | Your primary and fallback models. |
| `notes.md` | Resolution support, provider quirks, learned failures. |
| `opencode/command/` | Source of the `/9router-text-2-image` slash command. |
| `install.sh` / `install.ps1` | Installers for the skill + slash command. |
