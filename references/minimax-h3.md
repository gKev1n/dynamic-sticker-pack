# MiniMax H3 image-to-video

Read this reference when still sticker sources will be animated with MiniMax H3, especially through local ComfyUI.

## Plan motion for a short shot

Use 2–4 visually distinct beats:

1. begin from the source pose;
2. perform one main readable action;
3. add one small secondary action or effect;
4. return close to the initial pose or hold a deliberate end pose.

State fixed elements after the motion description: identity traits, signature accessories, caption, background, camera, props, and limb count. Keep the camera fixed. Large rotations, fast travel, or several competing actions increase identity and text drift.

Prompt order:

1. preserve the same character, scene, composition, and rendering;
2. describe motion beats in time order;
3. describe the ending and loop intent;
4. lock accessories, silhouette, text, props, and background;
5. forbid camera movement, extra limbs, new objects, subtitles, logos, and watermarks;
6. optionally request short nonverbal sound. GIF output will discard audio.

## Tested sticker defaults

- Square input and output: `448×448`
- Video length: `107` frames
- Frame rate: `24 FPS`
- Approximate duration: `4.458 s`
- H3 Turbo sampling: `8` steps
- Queue videos sequentially to avoid overlapping VRAM peaks

Treat these as a proven starting point, not a universal requirement. Confirm that the active model accepts the chosen dimensions; common H3 workflows require multiples of 32.

## Known local workflow mapping

For the workflow named `07_I2V_Turbo_8步推荐版.api.json`, verify the node classes before editing and then use:

| Node | Purpose | Inputs to set |
|---|---|---|
| `7` | MiniMax H3 image-to-video | `prompt`, `width`, `height`, `length` |
| `8` | Random noise | `noise_seed` |
| `16` | Save video | `filename_prefix` |
| `20` | Load image | `image` |

Do not assume these IDs for another workflow.

## Service lifecycle

- Starting or stopping ComfyUI requires the authorization required by the host environment.
- Check the intended port before launch. If another process owns it, identify the process and stop rather than killing it.
- Wait for a health endpoint before submitting work.
- Submit one video, poll its history until success or a bounded timeout, copy the reported MP4 to the stable deliverable folder, then submit the next.
- Before shutdown, confirm the queue is empty. Resolve the listener PID and executable path, and stop it only when both match the scoped project.
- Preserve concise logs for failures; do not paste large model-load logs into the handoff.

## Video QA

Probe each MP4 and verify codec, square dimensions, FPS, frame count, duration, and audio stream. Build a contact sheet that samples the whole shot. Inspect:

- caption stability and spelling;
- silhouette and signature accessory drift;
- background color or checkerboard artifacts;
- camera movement and crop;
- limb count and face deformation;
- whether the requested motion actually occurs;
- first-to-last similarity and likely loop seam.

If H3 drifts, first reduce action amplitude and competing effects. Regenerate only the failed expression; keep successful outputs.
