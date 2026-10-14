---
description: Generate images via 9Router text-to-image, with per-run model/resolution overrides and persistent model preferences
---
Load the `9router-text-2-image` skill using the skill tool, then follow its workflow exactly.

Arguments: $ARGUMENTS

Parsing reminder: if the first token is `SET` (case-insensitive), enter SET mode and write `preferences.md` — `MODEL` is the primary, `MODEL1`/`MODEL2`/… are ordered fallbacks. Otherwise, if the input starts with `>`, the directive block is everything from the first `>` to the last `<` (`;`-separated `key:value` pairs, keys case-insensitive: `model`, `res`); the remaining text outside the block is the prompt. If there is no block, the whole input is the prompt. Never switch to a fallback model without asking the user first.
