# Sovereign — Royal Palace

Original castle artwork with a central royal keep, four watchtowers, and a
crenellated gatehouse. The current colours borrow from the user's city reference:
cool grey masonry, aged terracotta roofs, crimson-and-ivory heraldry, and olive
greens. All geometry and surface textures are generated in this project; the
reference contributes colour samples, not copied artwork.

Weathering includes chipped battlements, fractured stone around tower impacts,
cracks in the gatehouse and keep, soot above the torches, water runs beneath
projecting stonework, moss and ivy, worn roof tiles, and frayed banner edges.
Named weathering meshes remain editable separately in the Blender scene.

## Files

| File | Purpose |
|---|---|
| `palace-hires.png` | 1920×1920 transparent game texture, full colour with smooth edges and contact shadow |
| `palace-hires-preview.png` | Full-resolution castle against a dark backdrop |
| `palace.png` | Optional 240×240 pixel-art export, including contact shadow |
| `palace@2x.png` | 480×480 exact nearest-neighbor enlargement |
| `palace-no-shadow.png` | Palace layer without the ground shadow |
| `palace-shadow.png` | Separate translucent ground-shadow layer |
| `palace-preview.png` | Enlarged pixel-art presentation on a dark backdrop |
| `palace-on-grass.png` | Enlarged preview against a light terrain colour |
| `palace-in-game.png` | Browser screenshot of the integrated Palace and inspector |
| `palace-hires-in-game.png` | Maximum-zoom browser screenshot at 2× display density |
| `palace-render.png` | 1920×1920 Blender render before export |
| `sovereign-palace.blend` | Editable geometry, materials, lighting, and camera |
| `sovereign-palace.pxo` | Pixelorama project with separate palace and shadow layers |
| `palace-palette.gpl` | 88-colour castle palette, importable into sprite editors |
| `reference-palette.gpl` | Colours sampled from the user's reference image |
| `color-theme.json` | Reference samples and editable material colour assignments |
| `palace.json` | Sprite dimensions, file names, and ground anchor |
| `palace-sprite.js` | Generated runtime manifest loaded by the game and sprite gallery |
| `variants/blue-slate/` | Preserved original blue-roof render, sprites, and source files |

## Re-render

Run from the repository root:

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/art/render_palace.py -- --resolution 1920 --samples 128
.venv/bin/python tools/art/finish_palace.py
```

The Blender script batches geometry into named architectural components with
separate materials. It uses deterministic surface wear, procedural stone/clay
grain, a 30-degree orthographic camera, directional light, and CPU Cycles
rendering. Edit `color-theme.json` to change the material palette. The finishing
script preserves the full render resolution, colour range, and antialiased edges
for the game texture, adding a soft contact shadow. It also generates separate
88-colour pixel sprites and the layered Pixelorama project for optional editing.

## Placement and verification

The sprite's projected world-origin anchor is **(120, 179)**. The game and sprite
gallery load `palace-sprite.js`, then `G.loadSpriteAssets()` imports `palace-hires.png`
before the game starts. Rendering, selection, health bars, and the inspector
portrait use the exported anchor and bounds in logical 240×240 coordinates. The
texture canvas retains all 1920×1920 source pixels, with smooth scaling at game
zoom levels and on Retina displays. A failed image load retains the procedural
Palace. Classic scripts and image loading also work when opening `index.html`
directly with `file://`.

The finishing script regenerates both `palace.json` and `palace-sprite.js`, and
refreshes content-versioned image and script URLs so browser reloads pick up changes.
Only `palace-hires.png` and `palace-sprite.js` are included in the hosting image.

Verified transparent borders and dimensions, exact 2× scaling, and a two-layer
Pixelorama import/export round-trip with identical RGBA pixels.
Browser checks cover direct-file and HTTP loading, selection at three zoom levels,
the inspector, desktop/mobile play, the gallery, and a blocked-image fallback.
The high-resolution texture is also checked at maximum zoom on a 2× display;
its canvas retains all source pixels while the logical building size stays 240×240.
