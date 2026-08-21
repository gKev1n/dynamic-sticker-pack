# Transparent-background GIFs

Read this reference only when the user requests transparent GIF output.

## Limits

GIF has binary, one-bit transparency. Soft fur, motion blur, shadows, and antialiased text cannot retain the same edge quality as RGBA PNG, APNG, or animated WebP.

A global white color key is unsafe when the subject is white. It can punch holes through fur, eyeshine, clothing, speech bubbles, and props. Preserve the opaque master and write transparent attempts to a separate folder.

## Preferred order

1. If an approved semantic background-removal model is already available, prefer it and inspect temporal consistency.
2. For a uniform near-white background, try [`../scripts/remove-connected-white-background.py`](../scripts/remove-connected-white-background.py). It removes only low-texture near-white pixels connected to the image border and protects textured white foreground regions.
3. If either method damages the subject or leaves large background islands, stop. Installing or downloading a segmentation model needs separate authorization.

The classical script requires Python 3, Pillow, NumPy, and SciPy.

```powershell
python scripts/remove-connected-white-background.py `
  "path/to/GIF/final" `
  --output-dir "path/to/GIF/transparent" `
  --json
```

Tested defaults are near-white threshold `245`, neutral-channel range `14`, gradient limit `4.0`, and one-pixel edge growth. These are starting points, not universal values.

## Required trial

Process one complete GIF before batching. Composite nine evenly spaced frames over a saturated blue or magenta background and inspect:

- holes or shimmering in white fur and accessories;
- opaque white blocks exposed during large motion;
- text and speech-bubble edges;
- props or tables that touch the canvas edge;
- contact shadows and halos;
- first/last loop continuity.

Static first-frame approval is insufficient. Video compression artifacts can appear only during motion.

## Final checks

- input and output frame counts match;
- loop count remains zero (infinite);
- every sampled frame contains transparent pixels;
- foreground is intact across the whole contact sheet;
- no large opaque background islands remain;
- the opaque master is still available.

If a platform accepts APNG or animated WebP, offer that format as a higher-quality transparent alternative instead of claiming GIF can preserve soft alpha.
