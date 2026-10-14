# 9router-text-2-image — Notes

Durable notes for the `9router-text-2-image` skill: which models support which
resolutions, provider quirks, and learned failures. The skill reads this file
before generating and appends to it when it learns something new.

Keep entries short. Do **not** log transient transport errors (401, 503,
timeouts) here — those are not capability facts.

## Resolution support

Verdicts: `yes` = confirmed working, `no` = rejected (with the error), `?` = untested.

| Model | 1024x1024 | wide | Wide size sent | Notes |
|---|---|---|---|---|
| `cx/gpt-image-2.5` | yes* | yes* | `1792x1024` | Accepts `size`, but output dimensions are **approximate**, not exact (see Learned failures). |
| `openrouter/openai/dall-e-3` | yes | yes | `1792x1024` | `quality`/`style` also accepted. |
| `gemini/gemini-3-pro-image-preview` | ? | ? | — | Prompt-only; ignores `size`. |
| `cf/@cf/black-forest-labs/flux-2-dev` | ? | ? | — | FLUX-style; check `width`/`height`. |

> `wide` means a landscape image. The **Wide size sent** column is what the skill
> substitutes when the user passes `res:wide` for that model. Leave it blank when
> the model ignores `size`.

## Provider quirks

| Provider / model | Behavior | Notes |
|---|---|---|
| `gemini` (nano-banana) | Ignores `size`/`n` | Only `prompt` is honored. |
| `codex` / `cx` | SSE stream, extra fields | `image`, `images[]`, `image_detail`, `output_format`, `background`. May require ChatGPT Plus/Pro. |
| `black-forest-labs` (FLUX) | `size` → exact `width`/`height` | Async. |
| `stability-ai` | `size` → `aspect_ratio` | `style` preset, `output_format`. |
| `fal-ai` | `size` → ratio | `n` → `num_images`; async. |
| `runwayml` | `size` → ratio | Async. |
| `sdwebui`, `comfyui` | Localhost noAuth | `:7860` / `:8188`. |

## Learned failures

Append rows here when a model rejects a request for a capability reason.

| Date | Model | Request | Error | Resolution |
|---|---|---|---|---|
| — | `cx/gpt-image-2.5` | `size:1024x1024` | none (HTTP 200) but output was `1254x1254`, not exact | `size` is treated as approximate; warn the user the result may not be pixel-exact. |
| — | `cx/gpt-image-2.5` | `size:1792x1024` | none (HTTP 200) but output was `1270x1239` | Landscape request honored loosely; do not expect exact `wide` dimensions. |
| — | `gemini/gemini-2.5-flash-image` | any | `429 quota exceeded (free tier limit: 0)` | Provider-side quota; use a fallback model instead. |
