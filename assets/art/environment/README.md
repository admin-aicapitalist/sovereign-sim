# The living land

Original woodland, terrain and scenery use the buildings' muted olive foliage,
weathered stone and oak, warm afternoon light, and 30° isometric camera.

The collection contains 35 runtime images:

- Six pines and six oaks, including gold and russet autumn foliage.
- Four rock clusters, three shrubs, two wildflower patches, two grass clumps,
  two reed beds, a stump, a fallen log, and an oak bridge railing.
- Grass, leaf-litter soil, dirt roads, isometric paving, water, flowing highlights,
  and a timber bridge deck.

[Asset sheet](environment-preview.png) · [Town](environment-town.png) ·
[River crossing](environment-river.png) · [Woodland pond](environment-pond.png)

## Re-render

Run from the project root with Blender and the project's Pillow environment:

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/art/render_environment.py -- --resolution 1280 --samples 48
.venv/bin/python tools/art/finish_environment.py
```

Use `--only pine0 oak0` for selected models. A quick draft can use
`--resolution 640 --samples 20 --output /tmp/sovereign-environment-draft`.
The exporter reads the complete collection of master renders.

`source/<key>.blend` contains editable geometry, materials, camera and lighting;
`source/<key>-render.png` is the transparent 1280×1280 master render. Pine needles,
oak leaves, branches, roots, reeds, bark, fractured rocks, and bridge joinery are
modeled geometry. The exporter adds contact shadows and crops transparent space
without downsampling. It rejects clipped silhouettes.

Ground textures are generated reproducibly in `finish_environment.py`, using
wrapped noise and fine surface detail. The six repeating materials are 1536×768,
displayed as 256×128 logical pixels. The bridge deck is a 384×192 isometric tile,
displayed at the game's 64×32 tile size. Exported script and image URLs have
content hashes so a reload loads the latest artwork.

## In the game

`js/environment.js` traces the existing map's roads and water boundaries, rounds
their corners, and composes grass, soil, paving, banks, shallow water and bridges.
Flowing highlights are clipped to the river and pond. Tree sway pivots at the roots.
Bridge rails and scenery share depth sorting with buildings and characters.

Decoration has its own deterministic seed. Tile types, blocked cells, map layout,
building placement and pathfinding are unchanged. Rebuilding terrain also rebuilds
decorations and releases the old terrain cache.

Terrain is cached in 256-pixel sections at one, two or four times logical
resolution, selected for zoom and display density. Overlapping margins avoid
section seams. The terrain cache is limited to 96 MiB and reduces resolution if
needed to fit a large viewport. Sprite textures retain their native resolution.

Individual missing materials use solid-color or procedural fallbacks. If the
base grass texture is unavailable, the original terrain renderer remains usable;
missing tree images retain their procedural tree sprites.

`node test/environment.mjs` checks imported resolutions, unchanged navigation,
bridge decoration, opaque section boundaries, water animation, cache bounds,
mobile layout, image fallbacks and the scenery gallery. It uses the same Chrome
debugging port as `test/browser.mjs`; run these browser tests sequentially.

Only runtime PNGs and `environment-sprites.js` are included in hosting builds.
Source scenes, master renders, metadata, previews and authoring tools stay local.
