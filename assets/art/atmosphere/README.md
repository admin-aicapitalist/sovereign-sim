# Living building sources

`godot/tools/render_atmosphere.py` reads the original palace, Warriors’ Guild and
guard tower Blender scenes, removes only the exact 65 flag-cloth faces, and renders
three clean plates. The original `.blend` files stay intact. Face matching retains
flagpoles, finials, facade banners and architectural cloth accents. The existing
cameras project the five moving flags into `projection.json`.

`godot/tools/finish_atmosphere.py` applies the existing royal shadows, crop,
resolution and color finishing, writing `godot/assets/atmosphere/` and
`godot/data/atmosphere.json`. Menu thumbnails retain the original full flags.

`godot/scripts/atmosphere.gd` draws anchored, shaded cloth strips with gold hems
and crimson heraldry. Cottages, Warriors’ Guilds, Rangers’ Lodges and Thieves’
Guilds emit overlapping wisps using the original arcane smoke textures. Only
completed, surviving buildings smoke. Building depth and fog provide occlusion.
The shared breeze follows simulation time, consumes no gameplay randomness,
and needs no additional save data or particle nodes.
