# ⚜ Sovereign — A Fantasy Kingdom Sim

A browser-playable, single-level **indirect-control kingdom sim** in the spirit of the
classic 2000-era fantasy kingdom management games: you are the monarch, not the general.
You raise buildings, recruit heroes and post gold bounties — but the heroes decide for
themselves whether your coin is worth the danger.

All artwork is original. All eleven building types, ten character types, and the
woodland and scenery use high-resolution artwork made with Blender and Pillow.
Textured grass, soil, roads, rivers and paving are composed from the map at load time. Sounds are
synthesized with WebAudio (no audio files), and there are **zero runtime dependencies
and no build step**.

The menus use parchment, dark wood, brass trim and crimson selections. Cinzel titles
and Alegreya body text are bundled locally; font attribution and OFL licenses are in
[`assets/fonts/`](assets/fonts/README.md). No external font service is required.
[Interface preview](assets/art/ui/interface-preview.png) · [Title screen](assets/art/ui/welcome-preview.png).

The art targets late-90s isometric-RTS production values: full-resolution painted
sprites with warm/cool directional lighting, gradient-shaded walls and roofs, soft
shadows and dirt aprons under buildings, blended terrain transitions with animated
shore foam, 4-frame walk cycles, three-frame attack and worker animations, waving banners,
flickering fires, swaying trees, and a particle system for combat impacts, deaths,
explosions and level-ups.

## Run it

**[Play the hosted game](https://sovereign-432652279722.us-central1.run.app/)** — no sign-in required.

Open `index.html` in any modern browser. That's it.

(Optionally serve it — `python3 -m http.server` — but `file://` works fine since
everything is plain classic scripts.)

Hosting configuration and redeployment instructions are in [`deploy/README.md`](deploy/README.md).

Optional pixel-art editors, export commands, and the Python sprite environment
are documented in [`tools/art/README.md`](tools/art/README.md).

## Level 1 — The Young Kingdom

* **Win:** destroy all 4 monster lairs (Sewer, Haunted Graveyard, 2 Goblin Camps).
* **Lose:** your Palace falls.

### How to play

1. **Build** (bottom bar): start with a Warriors' Guild; add a Marketplace early so
   heroes can spend their loot — their spending becomes your taxes.
2. **Recruit**: select a guild → Recruit. Warriors brawl, Rangers explore and shoot,
   Wizards rain fireballs but bruise easily.
3. **Bounty Flags**: heroes ignore orders but love gold. Click the flag tool, then a
   monster or lair. Select the flag to raise the reward — braver prices buy braver heroes.
   Exploration Flags pay the first hero (usually a ranger) to scout a spot.
4. **Spells** (sovereign magic): Healing Light (needs Temple), Lightning Bolt (needs
   Wizards' Guild), Far Sight (always). They cost gold and have cooldowns.
5. **The staff runs itself**: peasants build and repair, tax collectors walk the streets
   hauling gold back to the Palace (guard them!), palace guards hold the gate,
   guard towers shoot on sight.

Controls: click select/build · right-drag pan · wheel zoom · WASD/arrows/edge scroll ·
Space pause · 1/2/3 speed · F centre on Palace · Esc cancel · Shift-click places multiple.

## Architecture

Plain JS, one global namespace `G`, classic script load order (see `index.html`):

| file | role |
|---|---|
| `js/util.js` | iso math, seeded RNG, binary-heap A* pathfinding |
| `js/data.js` | every balance table: buildings, units, spells, flags, level layout |
| `js/sprites.js` | procedural sprites, imported asset loading, and building placement anchors |
| `assets/art/palace/palace-sprite.js` | generated Palace image manifest: dimensions, bounds, and ground anchor |
| `assets/art/buildings/buildings-sprites.js` | generated manifests for the other ten buildings, with selection outlines and effect positions |
| `assets/art/units/units-sprites.js` | ten character atlases: idle, walk and action poses, floor anchors, selection bounds |
| `assets/art/environment/environment-sprites.js` | 35 tree, scenery and terrain texture manifests |
| `js/environment.js` | textured terrain, road and river boundaries, water animation, bridge rails, scenery, bounded terrain cache |
| `js/world.js` | seeded map gen, walkability, fog of war |
| `js/entities.js` | units/buildings, movement, combat, projectiles, XP, flags |
| `js/ai.js` | the brains: hero utility AI (bounty scoring, shopping, resting, fleeing), worker/guard/monster AI |
| `js/game.js` | sim loop, economy, lair spawning, player actions, win/lose, hints |
| `js/render.js` | camera, pre-rendered terrain, depth-sorted scene, fx, minimap |
| `js/input.js` | mouse/keyboard, placement modes, selection |
| `js/ui.js` | DOM chrome: menus, info panel, messages, overlays |
| `js/sound.js` | WebAudio synth sfx |
| `js/main.js` | boot + main loop + debug params |

### Testing / QA

* `node test/smoke.js` — headless simulation: sprites generate, an unattended kingdom
  survives the early game, a scripted playthrough **must win**, the lose path triggers,
  no NaNs. Run it after any balance change.
* `test/spritesheet.html` — renders imported and generated sprites on one page
  (`?only=units|bld|misc`).
* `node test/environment.mjs` — browser checks for terrain detail, river animation,
  bridge navigation, cache limits and image fallbacks, with Retina screenshots of
  town, river and pond. Run sequentially with the other browser tests.
* `node test/browser.mjs` — optional real-browser interaction checks using Node 22+
  and a Chrome instance started with `--remote-debugging-port=9227` and a separate
  `--user-data-dir`. No test dependencies are needed. Exercises construction,
  recruitment, bounties, spells, keyboard controls, desktop/mobile rendering, and
  direct `file://` loading, selection and placement previews for all buildings,
  character animation frames, mirrored atlas drawing, portraits, selection,
  and independent missing-image fallbacks;
  screenshots go to the system temporary directory.
* Debug URL params on `index.html`:
  `?demo=1` (one of every unit near the palace) · `?demo=2` (pre-built town) ·
  `?auto=1` (skip start screen) · `?t=240` (fast-forward sim seconds) · `?zoom=1.5`.

### Design notes

* Heroes pick goals by utility: `reward / (30·threat) · classAffinity · bravery ·
  proximity`, with bravery scaling by level and current health. Wounded heroes chug
  potions, flee faster than they fight, and bill you nothing for the drama.
* The economy is a loop: monster gold → hero purses → shops → tax pools → collectors →
  treasury → your next guild.
* Lairs spawn waves on a timer, hurry reinforcements when attacked, and rally their
  brood to defend — assaulting a camp is a commitment.
* A Hill Troll pays the kingdom a visit at the 10-minute mark. Build a tower or two.

### Presentation and audio

The buildings share cool grey masonry, terracotta roofs, crimson banners, and
weathering, with distinct architecture for each guild, cottage, and monster lair.
Editable sources and export instructions are in the
[Palace guide](assets/art/palace/README.md) and
[building collection guide](assets/art/buildings/README.md). Heroes, workers and
monsters share the same lighting and materials, with editable models and
animated previews in the [character guide](assets/art/units/README.md).
The [environment guide](assets/art/environment/README.md) covers detailed pine and
oak forests, autumn foliage, textured ground, worn paving, riverbanks, reeds,
wildflowers, rocks, fallen wood and timber bridges.
The game retains the textures' full resolution and scales them smoothly while
preserving their ground positions. It loads artwork before starting and
retains individual procedural fallbacks if images are unavailable. The map includes feathered fog, animated water, smoke,
trees, flags, and combat particles. The interface adapts to narrow screens; drag
the map with a finger and use the minimap's zoom controls. Sound starts with
**Begin your reign** and can be toggled using the music-note button. The ambient
score, birds, construction, combat, and spell sounds are all synthesized locally.
