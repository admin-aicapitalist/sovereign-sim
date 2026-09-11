# Sovereign building collection

Ten original buildings rendered with the Royal Palace's shared materials,
terracotta tiles, grey stone, crimson heraldry, surface wear, 30-degree isometric
camera, and warm afternoon lighting. Every building has a 1920×1920 master.
Transparent margins are cropped from the runtime textures without resampling.
Their pixel density and physical proportions remain consistent in the game.

| Building | Distinguishing features |
|---|---|
| Warriors’ Guild | Stone hall, crenellated armory, heraldic shields, weapons rack |
| Rangers’ Lodge | Timber frame, veranda, archery targets, hunting sign |
| Wizards’ Guild | Octagonal tower, brass armillary, alchemist's annex, arcane stones |
| Marketplace | Striped awning, produce counters, trade sign, provision crates |
| Temple of Light | Buttressed nave, rose window, open belfry, votive garden |
| Guard Tower | Timber hoarding, watch roof, mounted crossbow |
| Peasant Cottage | Plastered timber frame, sheltered doorstep, chimney, bench |
| Old Sewer | Rusted grille, drainage channel, broken coping, rubble |
| Haunted Graveyard | Damaged chapel roof, bell gable, gravestones, iron fence |
| Goblin Camp | Rough log stronghold, hide roof, stakes, trophy poles, campfire |

`buildings-preview.png` shows the complete set. The `<type>.png` files are the
transparent game textures. `source/` contains editable Blender scenes, full
master renders, and projection metadata for each building. `buildings.json`
records cropping, source dimensions, logical dimensions, and anchors.
`buildings-in-game.png` shows the collection in the pre-built demo town.

From the repository root:

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/art/render_buildings.py -- --resolution 1920 --samples 96
.venv/bin/python tools/art/finish_buildings.py
```

Use `--only house marketplace` with the Blender command to render selected
buildings. The shared material definitions live in `render_palace.py`; the
palette is in `../palace/color-theme.json`.

The generated `buildings-sprites.js` manifest supplies each texture's logical
size, ground anchor, silhouette bounds, selection outline, and chimney/fire
positions. The game uses these for drawing, construction previews, portraits,
selection, health bars, and animated effects. Image and script URLs are versioned
when exporting, so a page reload picks up changed assets. Direct `file://` play
continues to work. Each missing image falls back to its procedural sprite.

Only the ten runtime textures and manifest are included in the hosting package.
Source scenes, master renders, preview sheets, and metadata stay in the workspace.

Verification covers all eleven building textures, source pixel density, selection
at three zoom levels, transparent corners, matching construction and completed
placement, inspector portraits, desktop/mobile gameplay, and independent fallbacks.
