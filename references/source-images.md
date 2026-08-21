# Source-image generation

Read this reference when a character reference must become a set of still sticker sources.

## Character lock

Write the lock before generating variants:

| Field | Capture |
|---|---|
| Identity | species, age impression, proportions, coat/skin color |
| Face | eye shape and color, nose, muzzle, mouth |
| Silhouette | ear shape, hair, tail, body proportions |
| Signature traits | markings, scars, bandages, jewelry, clothing |
| Rendering | 2D/3D style, material, lighting, outline |
| Layout | square crop, subject scale, safe margins |
| Background | solid color or transparent target |
| Caption | exact text, font mood, color, outline, placement |

Mark identity and signature traits as immutable. Expressions may change brows, eyelids, mouth, paw or hand pose, and small props without changing the lock.

## Build an expression matrix

Each source pose should make the later animation easy:

| Example | Starting pose | Useful motion |
|---|---|---|
| Happy | balanced stance, paws slightly raised | blink, small jump, tail wag |
| Angry | one paw ready to stomp | cheek puff, two stomps, anger icon pulse |
| Sad | seated, paws together | slow blink, tears, small sob |
| Waiting for work to end | paws near keyboard | type, glance at clock, sigh, rest head |

Adapt the examples to the requested character and culture. Do not turn them into a mandatory fixed pack.

## Prompt shape

Include:

1. the task and square sticker style;
2. the character lock in concrete visual terms;
3. the requested emotion and animation-friendly pose;
4. exact caption text and typography;
5. background and safe-margin requirements;
6. negative constraints: one subject, no extra text, no logo, no watermark.

For a white-background pack, say: “solid opaque white `#FFFFFF` from edge to edge; no checkerboard, transparency pattern, gradient, vignette, border, or scenery.” A subtle contact shadow directly under the character is acceptable.

## Reference strategy

- Inspect every local reference before editing it.
- Use the original character image plus the strongest approved style anchor for each variant.
- Do not use a failed checkerboard or drifted derivative as a new identity anchor.
- Generate each distinct asset with its own image-generation call when the active tool requires one call per asset.
- Copy generated outputs into the project and leave provider originals in place unless deletion is explicitly requested.

## QA before animation

Check every source image for:

- exact caption and punctuation;
- one subject and correct limb count;
- immutable facial, silhouette, and signature traits;
- drooping/upright ears or other silhouette details;
- accessory count, shape, layering, and location;
- opaque white or intended alpha at the edges;
- safe margins for motion and platform cropping.

For white backgrounds, sample all four corners and a border grid. Near-white RGB values are acceptable after encoding; a checkerboard pattern is not. If a critical invariant fails, make one targeted correction before video generation instead of hoping the video model will repair it.
