---
name: dynamic-sticker-pack
description: Create a consistent animated reaction-sticker or GIF pack from a character reference, including expression planning, source-image generation, MiniMax H3 image-to-video animation, seamless GIF conversion, and media/visual QA. Use for reusable emoji or sticker characters; do not invoke for unrelated general video editing.
metadata:
  short-description: Build consistent animated sticker packs
---

# Dynamic Sticker Pack

Create a sticker set whose character identity, captions, framing, background, motion, and loop behavior remain consistent across every asset.

## Before changing anything

- Inspect the reference files and workspace read-only.
- State the planned expressions, output folders, generation stages, and expected deliverables.
- Obtain any authorization required by the host instructions before writing files, starting or stopping ComfyUI, or changing configuration.
- Preserve existing artifacts. Put revisions in a new folder or filename unless the user explicitly authorizes replacement.
- Keep the user's chosen image or video model. This skill does not grant permission to install tools, spend API credits, or operate unrelated services.

## Workflow

1. Build a compact expression plan. For each sticker define the exact caption, animation-friendly starting pose, 2–4 motion beats, static elements, and intended loop ending.
2. Write a reusable character lock: immutable facial and body traits, signature markings or accessories, rendering style, background, framing, and text treatment.
3. Generate and validate one canonical source image per expression. Read [references/source-images.md](references/source-images.md) before image generation.
4. Animate approved source images. When MiniMax H3 or a local ComfyUI H3 workflow is used, read [references/minimax-h3.md](references/minimax-h3.md).
5. Convert the videos to infinite-loop GIFs and run final QA. Read [references/gif-and-qa.md](references/gif-and-qa.md). Prefer [scripts/convert-sticker-gifs.ps1](scripts/convert-sticker-gifs.ps1) for repeatable conversion.
6. If transparent GIFs are requested, preserve the opaque masters and read [references/transparent-background.md](references/transparent-background.md) before trying background removal.

## Invariants

- Reuse the same strongest character references for every source image.
- Separate immutable identity traits from expression-specific changes. Never let emotion prompts replace signature traits.
- Use one subject, a square canvas, generous safe margins, and a simple background unless the user requests otherwise.
- Treat captions, logos, props, background, and signature accessories as static during video generation unless their motion is explicitly part of the design.
- Keep camera motion off for ordinary stickers. Use small readable actions that fit within about 3–5 seconds.
- Generate GPU-heavy videos sequentially. Verify the active process belongs to the scoped project before stopping it.
- Metrics supplement visual review; they do not replace it.
- Never apply a global white color key to a white character. Test one complete animation first and inspect it over a saturated color.

## Recommended output layout

```text
sticker-pack/
|-- source-images/
|-- video/
|   `-- QA/
`-- GIF/
    |-- final/
    `-- QA/
```

Use stable, ordered names such as `01-happy.png`, `01-happy.mp4`, and `01-happy.gif`.

## Completion

Report:

- source images, videos, final GIFs, and QA artifacts;
- resolution, frame rate, duration, frame count, loop mode, and file size;
- visual findings about identity, text, background, motion, and loop seams;
- any remaining upload-size or platform-specific risk;
- whether services were stopped and whether any install, commit, or push remains.
