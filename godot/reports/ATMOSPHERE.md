# Chimney smoke and wind

Completed cottages, Warriors’ Guilds, Rangers’ Lodges and Thieves’ Guilds release
soft smoke that expands, curls downwind and dissipates. Palace, guild, tower and
bounty flags ripple in the same breeze, with anchored seams, shaded folds,
gold hems and preserved royal heraldry.

Three new Blender building plates remove exactly 65 baked cloth faces while
retaining their five poles and the original architecture/cameras. Runtime smoke
reuses the arcane cloud textures; each chimney has ten stateless wisps. Animation
uses simulation time and adds no particle nodes, gameplay randomness or save data.

Validation: Godot 4.7.2 import/startup and web export passed. The browser suite
checks pixel changes for all four chimney types and five rooftop flags, exact
pixel stability during pause, a player-posted bounty flag, save/load, and phone
DPR2 rendering. Nine checks pass with no browser or Godot errors; see
[results](atmosphere-browser.json).

Deployed as `sovereign-00013-84n` at 100% traffic. Live hosting checks verify
gzip, MIME types, health/404 responses and byte-for-byte export integrity. All
nine animation checks also pass on the live service; see [deployment](atmosphere-deployment.json)
and [live browser results](atmosphere-deployed-browser.json).

Screenshots: [town](atmosphere-palace.png), [smoke](atmosphere-house.png),
[guild](atmosphere-warriors.png), [bounty](atmosphere-bounty.png),
[phone](atmosphere-mobile.png).

Reproduction is documented in [the art sources](../../assets/art/atmosphere/README.md).
