# 9router-text-2-image — Model Preferences

Persistent model preference store for the `9router-text-2-image` skill.
Written by the skill's `SET` mode:

```
/9router-text-2-image SET >MODEL:<primary id>; MODEL1:<fallback id>; MODEL2:<fallback id><
```

- **Primary** is used for every normal run unless a per-run `>model:<id><` override is given.
- **Fallbacks** are tried only when the primary fails, and only after the user confirms.
- Order matters: fallbacks are attempted top to bottom.

Edit this file by hand if you prefer, but keep the structure below so the skill can parse it.

## Primary

| Field | Value |
|---|---|
| model | `cx/gpt-image-2.5` |

## Fallbacks

| # | model | Provider | Notes |
|---|---|---|---|
| 1 | `gemini/gemini-3-pro-image-preview` | gemini | Ignores `size`; prompt-only. |
| 2 | `openrouter/openai/dall-e-3` | openrouter | Supports `1792x1024` for wide. |

> Replace the rows above by running `SET`, or edit them directly. An empty fallback table means the skill will only offer to retry the primary on failure.

## Change log

| Date | Change |
|---|---|
| — | Initial template. |
