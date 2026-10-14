---
name: 9router-text-2-image
description: "Generate images (text-to-image / txt2img) via 9Router /v1/images/generations using OpenAI / Gemini / DALL-E / FLUX / GPT-Image / MiniMax / SDWebUI / ComfyUI and combo models. Use whenever the user runs /9router-text-2-image, or asks to \"generate an image\", \"create a picture\", \"draw\", \"render an image\", \"buat gambar\", \"bikin gambar\", or any text-to-image request against the 9Router gateway. Supports a per-run model/resolution directive block and a SET mode that persists a primary model plus ordered fallback models into preferences.md. Remembers per-model resolution support and provider quirks in notes.md, and always asks the user before switching to a fallback model."
---

# 9Router Text → Image

Generate images through the 9Router OpenAI-compatible gateway. The skill adds three things on top of the raw endpoint:

1. **A directive block** so the user can override the model and resolution per run.
2. **`preferences.md`** — a persistent store of the user's primary model and ordered fallback models, written by `SET`.
3. **`notes.md`** — a persistent log of which models support which resolutions, plus provider quirks and learned failures.

All instruction and message text in this skill is English. Never switch models silently: a fallback is only used **after the user says yes**.

## Setup

Requires `NINEROUTER_URL` (and `NINEROUTER_KEY` if auth is enabled):

```bash
export NINEROUTER_URL="http://localhost:20128"
export NINEROUTER_KEY="sk-..."          # only if the gateway requires it
```

Verify: `curl $NINEROUTER_URL/api/health` → `{"ok":true}`.

Every request is `${NINEROUTER_URL}/v1/...` with header `Authorization: Bearer ${NINEROUTER_KEY}` (omit the header when auth is disabled).

## Invocation

```
/9router-text-2-image <prompt>
/9router-text-2-image >model:<id>; res:<size>< <prompt>
/9router-text-2-image SET >MODEL:<id>; MODEL1:<id>; MODEL2:<id><
```

| Form | Meaning |
|---|---|
| `<prompt>` only | Generate using the primary model from `preferences.md` and the default resolution. |
| `> ... <` + prompt | The block between the first `>` and the last `<` overrides `model` and/or `res` for this run only. The text outside the block is the prompt. |
| `SET > ... <` | Persist model preferences to `preferences.md`. No image is generated. |

Examples:

```
/9router-text-2-image a watercolor mountain range at sunrise
/9router-text-2-image >model:cx/gpt-image-2.5; res:1024x1024< a neon city at night
/9router-text-2-image >res:wide< a cinematic desert highway
/9router-text-2-image SET >MODEL:cx/gpt-image-2.5; MODEL1:gemini/gemini-3-pro-image-preview; MODEL2:openrouter/openai/dall-e-3<
```

## Parsing the arguments

Parse deterministically before doing anything else.

1. **Trim** the raw arguments. If empty → ask the user for a prompt and stop.
2. **SET detection**: if the first whitespace-delimited token equals `SET` (case-insensitive), enter **SET mode** (below). The rest of the input is the SET payload.
3. **Directive block**: if the trimmed input starts with `>`, the block is the substring from that `>` up to the **last** `<` in the input. Strip the leading `>` and trailing `<`. Everything before the opening `>` and after the closing `<` (joined with a space) is the **prompt**. If there is no `<` after the `>`, treat the whole input as the prompt (a lone `>` is not a directive).
4. **Keys**: split the block on `;`, then split each part on the **first** `:` into `key` and `value`. Keys are case-insensitive and trimmed. Recognize:
   - `model` → per-run model override.
   - `res` → resolution. Also tolerate the angle-bracket alias form `res<1024x1024>`: if a part looks like `res<value>`, take the text inside the first `<` … `>` pair as the value and ignore stray brackets after it.
   - `MODEL`, `MODEL1`, `MODEL2`, … → only meaningful in SET mode (see below).
   - Unknown keys → ignore, but mention them back to the user.
5. If the block exists but yields no recognized keys, fall back to treating the whole input as the prompt and tell the user the block was not understood.

## SET mode — persist model preferences

`SET` writes to `preferences.md` (same folder as this file). It never generates an image.

Parse the payload after `SET` using the same `> ... <` block grammar:

| Key | Meaning |
|---|---|
| `MODEL` | The **primary** model. |
| `MODEL1`, `MODEL2`, … | Ordered **fallback** models. Tried only when the primary fails, and only after the user confirms. Order is `MODEL1`, then `MODEL2`, etc. |

Rules:

- `MODEL` is required. If it is missing, ask for it and stop.
- Preserve the order of `MODEL1`, `MODEL2`, … exactly as given. Renumber them to a clean `1..n` list.
- Overwrite `preferences.md` with the new primary and fallback list, keeping the file's Markdown structure (see that file for the exact shape). Do not touch `notes.md`.
- Validate each id against `$NINEROUTER_URL/v1/models/image` (see Discover). If an id is not listed, warn the user but still save it (the gateway may expose it later) — ask them to confirm.
- After writing, echo back the saved primary and fallback list so the user can verify.

## Discover models (optional, for validation)

```bash
curl "$NINEROUTER_URL/v1/models/image" -H "Authorization: Bearer $NINEROUTER_KEY" | jq -r '.data[].id'
# Per-model params/options (supported size enum, quality enum, capabilities):
curl "$NINEROUTER_URL/v1/models/info?id=cx/gpt-image-2.5" -H "Authorization: Bearer $NINEROUTER_KEY"
```

Use `data[].id` as the `model` field. `info.params` lists the fields a model accepts (e.g. `size`, `quality`, `style`).

## Resolve model and resolution

1. **Model**: per-run `model:` override → else the primary in `preferences.md` → else, if `preferences.md` has no primary, ask the user (or suggest running `SET`).
2. **Resolution**:
   - `res:1024x1024` → use as-is.
   - `res:wide` → look up the model's landscape size in the **Resolution support** table in `notes.md`. If the model is not listed, use the default `1024x1024` (or the model's documented wide size if `info` exposes one) and add a row to `notes.md` once the result is known.
   - No `res` → default `1024x1024`.
3. Before sending, check `notes.md`: if the model is recorded as **not supporting** the requested resolution, warn the user up front and offer an alternative from `notes.md` / `preferences.md`.

## Generate

```bash
curl -X POST "$NINEROUTER_URL/v1/images/generations?response_format=binary" \
  -H "Authorization: Bearer $NINEROUTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"cx/gpt-image-2.5","prompt":"watercolor mountains at sunrise","size":"1024x1024"}' \
  --output out.png
```

- Save the image in the current working directory with a descriptive, filesystem-safe name (e.g. `watercolor-mountains-at-sunrise.png`). If a file of that name exists, add a numeric suffix.
- If the gateway returns JSON instead of binary (some providers ignore `?response_format=binary`), parse `data[0].url` or `data[0].b64_json` and save accordingly:
  - `url` → download it to the same target path.
  - `b64_json` → base64-decode into the target file.
- After a successful generation with an explicit `res`, check the actual output dimensions (e.g. `file`/`identify`). If they differ from the requested size, mention it to the user and record the mismatch in `notes.md` (some models treat `size` as approximate).
- After a successful generation with an explicit `res`, if that model+resolution combination is not already recorded in `notes.md`, add or update its row.
- Report the saved path, the model used, and the resolution.

## Response shapes (for reference)

JSON default (`response_format=url`):

```json
{ "created": 1735000000, "data": [{ "url": "https://..." }] }
```

`response_format=b64_json`:

```json
{ "created": 1735000000, "data": [{ "b64_json": "iVBORw0KGgo..." }] }
```

Query `?response_format=binary` returns raw image bytes (`Content-Type: image/png` or `image/jpeg`).

## Fallback flow — always ask first

When generation fails, **never** silently retry with another model. Follow this exactly:

1. **Classify the failure**:
   - Resolution/capability error (e.g. "unsupported size", "invalid size", 400 mentioning size/aspect ratio) → record it in `notes.md` under the model as unsupported for that resolution, with the error text.
   - Provider/capability error (model ignores `size`, needs a ratio, edit-only, etc.) → record under **Provider quirks** in `notes.md`.
   - Transport/availability error (401, 429/quota, 503 `All accounts unavailable`, timeout, connection refused) → do **not** log as a capability note.
2. **Decide what to offer**:
   - If `preferences.md` has fallback models, the next one is the first not yet tried in this run.
   - If there are no fallback models, offer only a retry of the same model.
3. **Ask the user** — this step is mandatory, even when there is exactly one fallback:
   - With a fallback: `Model <primary> failed (<short error>). Try fallback <next>?`
   - With no fallback: `Model <primary> failed (<short error>). Try again?`
   - Present the options via the question tool (Yes / No). Do not proceed without an answer.
4. **Act on the answer**:
   - Yes + fallback → regenerate with that model, same prompt, same resolution (unless `notes.md` says that model needs a different size — then use the compatible size and say so). Continue down the fallback list, asking again before each further switch.
   - Yes + no fallback → retry the same model once.
   - No → stop, report the failure, and leave the last error visible.
5. Every fallback switch requires its own confirmation. Never chain fallbacks without asking.

## Provider quirks

Common fields work everywhere. These add/override (mirror into `notes.md` as you learn):

| Provider | Extra/changed fields | Notes |
|---|---|---|
| `openai`, `minimax`, `openrouter`, `recraft` | `quality`, `style`, `response_format` | Standard OpenAI shape |
| `gemini` (nano-banana) | — | Only `prompt`; ignores `size`/`n` |
| `codex` / `cx` | `image`, `images[]`, `image_detail`, `output_format`, `background` | SSE stream for some; ChatGPT Plus/Pro may be required |
| `huggingface` | — | Only `prompt`; returns a single image |
| `nanobanana` | `image`, `images[]` (edit mode) | `size` → aspect ratio; async polling |
| `fal-ai` | `image` (img2img) | `n` → `num_images`; `size` → ratio; async |
| `stability-ai` | `style` (preset), `output_format` | `size` → `aspect_ratio` |
| `black-forest-labs` (FLUX) | `image` (ref) | `size` → exact `width`/`height`; async |
| `runwayml` | `image` (ref) | `size` → ratio; async; video models exist |
| `cf` (Cloudflare) | — | `size` passed through; check per-model support |
| `sdwebui`, `comfyui` | — | Localhost noAuth (`:7860` / `:8188`) |

## Maintaining the notes

`notes.md` is the skill's memory. Update it whenever you learn something durable:

- Add/adjust a row in **Resolution support** when a model accepts or rejects a size.
- Add/adjust a row in **Provider quirks** when a model needs a non-standard field or ignores one.
- Keep entries short: model id, resolution, verdict, and a one-line reason.

Do not log transient transport errors. Do not delete existing rows without a reason — correct them instead.

## Edge cases

- **`NINEROUTER_URL` unset** → tell the user to export it (and `NINEROUTER_KEY` if needed); stop.
- **401** → refresh `NINEROUTER_KEY`; stop.
- **429 / quota exceeded** → surface the provider message and any retry hint; treat as a transport/availability failure (do **not** log in `notes.md`) and enter the fallback flow.
- **503 `All accounts unavailable`** → surface the `retry-after` header and offer to retry; this is not a capability failure.
- **Empty prompt after parsing** → ask for the prompt; do not generate.
- **Model not in `/v1/models/image`** → warn, and only proceed after the user confirms.
- **Unknown directive key** → ignore it, but tell the user which keys were skipped.
- **Response is not an image** (JSON error body, or HTML) even with `?response_format=binary` → parse the JSON `error.message` when present, show it, and enter the fallback flow.
- **Fallback list exhausted** → report every model tried and its error, then ask whether to retry from the top.
- **`preferences.md` missing or unreadable** → recreate it from its template header and ask the user to run `SET` (or proceed with a per-run `model:` override).
- **`notes.md` missing** → recreate it from its template header before writing any note.
