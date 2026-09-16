# Character art release

[Play the deployed game](https://sovereign-432652279722.us-central1.run.app/).
Revision `sovereign-00011-8gs` serves 100% of traffic; the previous Royal art
revision `sovereign-00010-rr2` remains available for rollback.

Twelve character appearances were rebuilt as original medieval miniatures with
layered armor, heraldic shields, cloth folds, visible tools and differentiated
monster anatomy. Every appearance has eight viewing directions, four idle
poses, eight walk poses and six combat poses: **1,728 frames**, plus twelve
dedicated portraits. The figures are larger and easier to distinguish at normal
camera scale than the previous eight-pose, mirrored sprites.

## Visual review

- [Complete lineup](characters-lineup.png)
- [Animated march](characters-marching.webp) and [eight-direction turntable](characters-directions.webp)
- [Units in Godot](characters-in-game.png), [rear views](characters-rear-views.png)
- [Attack wind-up](characters-windup.png) and [impact](characters-impact.png)
- [Character inspector](characters-inspector.png), [phone viewport](characters-mobile.png)

The lineup uses a constant world scale. The in-game gallery is a paused test
fixture with a clearing, shown through the normal world renderer. It includes
enemies and the boss so their art can be reviewed without playing through the
campaign. Normal play retains the generated forest and autonomous behavior.

## Validation

- [Native atlas and animation checks](characters-native.json): 3,497 checks,
  including all atlas bounds, logical scale, direction sectors, wind-up/release,
  worker animation and loading a pre-existing save.
- [Source render checks](characters-assets.json): 1,728 nonempty frames, no
  geometry clipped by a render edge, all textures under 4096 pixels per axis.
- [Browser art checks](characters-browser.json): all twelve types/directions,
  movement and combat states, picking, portraits, save/load and a 390px DPR2
  phone viewport.
- [Native campaign regression](characters-simulation.json): 108 checks and an
  autonomous campaign victory with no failures.
- [Campaign systems regression](characters-milestone.json): 402 checks covering
  the boss, relic equipment, training and save continuation, with no failures.
- [Full browser regression](characters-regression.json): construction, staffing,
  recruitment, bounties, research, spells, saves, endings, touch controls, replay
  and player startup passed without browser or engine errors.
- [Deployed file verification](characters-deployed-hosting.json) matched all
  downloaded HTML, JS, WASM and PCK bytes to the local export after decompression;
  MIME types, health and 404 responses passed. The [live character checks](characters-deployed-browser.json)
  repeated direction, animation, selection, save and phone-layout checks without
  errors. [Live screenshot](characters-deployed.png).
- [Crowd performance](characters-performance.json): 60 FPS at 100 and 300 actors;
  44.6 FPS at 1,000 actors with 954 visible, a 22.7 ms 95th-percentile frame and no
  dropped simulation time. Each measurement lasted 15 seconds after a 3-second
  warm-up in Chrome on this Apple M4 Pro. Phone layout checks used viewport/DPR
  emulation, not a physical handset. [Crowd screenshot](characters-play-crowd-1000.png).

The exported game uses approximately **35.46 MB** with gzip, including the engine,
world art, audio and new characters. The unit atlas masters occupy about 131 MB
as uncompressed RGBA before mipmaps. Lossy texture import reduces transfer size
while preserving the lossless source PNGs; it does not reduce GPU memory.

[Source models and reproduction](../../assets/art/units/directional/README.md).

Deployed PCK SHA-256:
`79e26a633587317e788e4c91539475ba0979e0bc9f3c4a3f1df4ddb41f022666`.
The upload contains only the browser export and Nginx container configuration.
