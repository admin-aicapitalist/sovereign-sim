# Royal art direction

Original Sovereign artwork, drawing on the restrained materials, heraldry and
readable isometric silhouettes of classic medieval strategy games.

The four civic buildings use new Blender renders: blue-grey slate, warm dressed
stone, pale trim and crimson standards. Timber guilds retain terracotta roofs.
The Ember Warlord is a new armored variant of the original troll model, with
spiked pauldrons, a cuirass, molten eyes, a jagged crown and eight animation poses.
`ember-warlord.blend` contains an editable pose timeline (frames 1–8).

Rebuild from the repository root:

```sh
blender --background --python godot/tools/render_royal.py
.venv/bin/python godot/tools/style_art.py
```

The renderer reads the original Palace and building scenes without modifying
them. The finishing tool preserves their crop coordinates and foot anchors,
adds contact shadows and packs the boss into the same animation layout as the
troll. The raw PNG renders here are reproducible inputs; finished runtime
textures are in `godot/assets/`. The remaining actors and scenery are graded
from their original full-resolution masters.

The same finishing tool generates native nine-slice wood/parchment materials
and original SVG command symbols in `godot/assets/ui/`. No image API or external
asset service is required. Cinzel, Alegreya and Alegreya Italic remain bundled
with their existing OFL licenses.
