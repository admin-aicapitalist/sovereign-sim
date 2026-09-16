# Directional medieval characters

These are original Sovereign models and textures. The historical RTS reference
informs proportions, heraldry, readable equipment and the isometric camera; no
Age of Empires artwork or models are included.

All twelve appearances have **144 frames**: four idle poses, eight walking poses
and six attack poses, each rendered from eight directions. Heroes, guards,
carpenters, collectors, rats, goblins, skeletons, trolls and the Warlord have
distinct clothing, armor, weapons and silhouettes. The carpenter's attack motion
also animates construction and repairs.

`*.blend` contains each editable idle model, named material/component meshes,
camera and lighting. The motion source is
[`render_characters.py`](../../../../godot/tools/render_characters.py): articulated
legs and arms, a weighted upper-body turn/lean, cloth folds and follow-through.
The script generates poses directly; these files do not contain an armature or
an animation timeline. The Blender batches share primitive geometry helpers with
the original art, but the characters and costumes are newly authored.

`*.png` are lossless, trimmed master atlases. `manifest.json` stores every frame's
source rectangle, logical size and foot anchor. Crops can differ without moving
the world origin. Eight views retain the correct shield and weapon hands; the
game does not mirror the character textures. `lineup.png` shows relative sizes.

## Reproduce

From the repository root, with Blender 5.2.1 and Pillow 12.3:

```sh
blender --background --python-exit-code 1 --python godot/tools/render_characters.py -- --resolution 384 --samples 32
blender --background --python-exit-code 1 --python godot/tools/render_characters.py -- --portraits --resolution 512 --samples 48
.venv/bin/python godot/tools/finish_characters.py
.venv/bin/python godot/tools/finish_characters.py --portraits-only
```

Renders use `/tmp/sovereign-unit-renders` by default; both tools accept an explicit
render directory (`--output` and `--source`, respectively). Use `--preview` for
one idle view or `--only warrior ranger` for selected types. A full atlas finish
expects complete renders with matching resolution; a preview is not a full set.

The finisher rejects clipped/empty source images, adds contact shadows, preserves
ground anchors and packs each type into one texture below 4096 pixels per axis.
The Godot copies use 90% lossy import compression with alpha and mipmaps, while
the master PNGs remain lossless. This reduces the download, not GPU memory; see
[Godot image import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#compress-mode).

`prepare_art.py`, `style_art.py` and the legacy metadata importer preserve this
directional manifest. Portraits are separate 256px framed busts used by the unit
inspector and recruitment cards.

## Runtime and checks

[`character_animation.gd`](../../../../godot/scripts/character_animation.gd)
samples the atlas from simulation time. Gait advances by distance traveled;
attack wind-up and release follow the pending hit/projectile state. Pausing or
changing game speed affects the animation with the simulation. Heading is visual
state inferred from movement, combat and restored paths, so old save formats do
not require a new schema.

The world renderer draws atlas regions directly to keep large crowds inexpensive.
See [verification and previews](../../../../godot/reports/CHARACTERS.md).
