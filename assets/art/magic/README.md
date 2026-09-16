# Sovereign: the art of spellcasting

All artwork, animation, shaders and sound design in this release are original.
The reference is the legibility and material richness of medieval strategy games;
no Age of Empires artwork or audio is used.

The live effects combine grounded inscriptions, opaque mineral/smoke textures,
additive light, ballistic fragments, and a turbulent CanvasItem fire shader.
Spell recipients, impact times and projectile origins come from the simulation.

## Authoring

Use Blender 5.2 and the project's Pillow environment:

```sh
blender --background --python-exit-code 1 --python godot/tools/render_arcane.py
.venv/bin/python godot/tools/finish_arcane.py
blender --background --python-exit-code 1 --python godot/tools/render_characters.py -- --casting --resolution 384 --samples 32 --output /tmp/sovereign-casting-renders
.venv/bin/python godot/tools/finish_casting.py
python3 godot/tools/bake_arcane_audio.py
```

`glacial-quartz.blend` and `obsidian-meteor.blend` contain editable geometry,
lighting and material nodes. The 384px PNGs here are lossless render masters;
the runtime images are trimmed without moving their projected anchors.
`projection.json` records those anchors. The finishing tool also authors four
deterministic turbulent smoke textures.

The additional wizard performance is 16 poses × 8 directions, packed separately
from the previous 144-frame base character. Its authoring script records projected
staff and palm sockets after articulation and rotation. The editable casting pose
and atlas are in `../units/directional/wizard-casting.blend` and `wizard_cast.png`.
Animation is authored procedurally in Python; the saved Blender file is a pose,
not a rig with timeline keyframes.

The audio baker synthesizes 18 original stereo cues at 32 kHz: seven spells,
meteor impact, fire launch/impact, bow, ward impact, and three variants each of
metal/body hits. Modal resonances, filtered air and stereo reflections are mixed
offline. No samples, external services, or added runtime libraries are needed.
