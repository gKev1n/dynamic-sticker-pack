# GIF conversion and QA

Read this reference when animated sticker videos must become final looping GIFs.

## Recommended conversion

Use [`../scripts/convert-sticker-gifs.ps1`](../scripts/convert-sticker-gifs.ps1) when PowerShell 7, FFmpeg, and FFprobe are available.

```powershell
pwsh -File scripts/convert-sticker-gifs.ps1 `
  -InputPath "path/to/video" `
  -OutputDirectory "path/to/GIF/final" `
  -LoopMode Auto `
  -Json
```

Defaults:

- `448×448` canvas with aspect-ratio preservation and white padding;
- `15 FPS`;
- `160` palette colors;
- infinite loop;
- automatic direct/crossfade selection using first-to-last SSIM;
- `0.3 s` fade when a seam needs repair.

The script refuses to overwrite by default. Use `-Overwrite` only after the user explicitly authorizes replacement.

## Loop strategy

- Direct loop: use when the source already ends close to its first pose.
- Crossfade: keep the complete opening, then fade the last segment back to a cloned static first frame.
- Do not repair a seam by trimming away the opening unless the opening is intentionally disposable. In testing, trimming the first 0.3 seconds caused a sad sticker to begin with closed eyes and lose its identity-defining starting expression.

An input first/last SSIM around `0.97` is a useful automatic boundary. This is a routing heuristic, not a quality verdict.

## Final QA

Verify:

- GIF codec, dimensions, FPS, frame count, duration, and file size;
- Netscape loop extension exists and loop count is `0` (infinite);
- first/last SSIM is ideally at least `0.98` after loop repair;
- all first and last corners retain the intended background;
- captions, signature traits, and props remain legible in a contact sheet;
- no crossfade ghosting is visible around text or the character face.

Always view the animation or a whole-shot contact sheet. A high SSIM can coexist with a bad mid-shot deformation.

Keep a high-quality master. If a platform imposes a current upload limit, verify that limit from an authoritative source and create a separately named compressed copy by reducing FPS, canvas size, colors, or duration. Do not overwrite the master.
