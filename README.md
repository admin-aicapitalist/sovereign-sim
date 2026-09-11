# ⚜ Sovereign — A Fantasy Kingdom Sim

A browser-playable, single-level **indirect-control kingdom sim** in the spirit of the
classic 2000-era fantasy kingdom management games: you are the monarch, not the general.
You raise buildings, recruit heroes and post gold bounties — but the heroes decide for
themselves whether your coin is worth the danger.

All artwork is original. All twelve building types, eleven character types, and the
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

* **Map:** 88 × 88 tiles (four times the original area). Each launch generates a
  **River Marches, Great Lake, or Coastal Realm** with a different shoreline,
  kingdom location, lair placement, forest density and road network. Settlements
  occupy dry ground, and roads connect them with bridges wherever water must be
  crossed. Four clearings provide room to expand beyond the starting town.
  [Compare three seeded regions](assets/art/environment/map-variants.png).
* **Win:** destroy all 8 monster lairs. The four distant frontier lairs begin
  spawning additional enemies once discovered or attacked.
* **Lose:** your Palace falls.

### How to play

1. **Build** (bottom bar): start with a Warriors' Guild; add a Marketplace early,
   then select it and choose **Potions & research** to unlock supplies heroes can buy.
2. **Recruit**: select a guild → Recruit. Warriors brawl, Rangers explore and shoot,
   Wizards rain fireballs but bruise easily; Thieves strike enemies distracted by allies.
3. **Bounty Flags**: heroes ignore orders but love gold. Click the flag tool, then a
   monster or lair. Select the flag to raise the reward — braver prices buy braver heroes.
   Exploration Flags pay the first hero (usually a ranger) to scout a spot.
4. **Spells** (sovereign magic): Healing Light (needs Temple), Lightning Bolt (needs
   Wizards' Guild), Far Sight (always). They cost gold and have cooldowns.
5. **The staff runs itself**: peasants build and repair, tax collectors walk the streets
   hauling gold back to the Palace (guard them!), palace guards hold the gate,
   guard towers shoot on sight.
6. **Recover treasure:** heroes collect gold pouches and potion drops when nearby
   ground is safe. Select a monster or lair to see its possible drops; select a
   pouch or chest to inspect its contents. Gold belongs to the collecting hero.
7. **Watch overcrowding:** six completed cottages are safe. Cottages 7–10 can
   sustain one rat sewer, 11–14 two, and so on. The campaign panel shows the
   warning and countdown. Clear sewers and protect your homes before expanding.
   Select a cottage → **Demolish · no refund** to reduce housing; construction costs
   and stored taxes are lost.

**Replay a map:** the title screen and Help (?) show the current seed. In Help or
the end-of-game screen, **Replay this map** opens a link with `?seed=12345`. You can
also use a name, such as `?seed=Alderwick`. The same seed reproduces the same map
and initial population. Normal reloads and new kingdoms choose a fresh seed; an
explicit seed in the URL keeps that map for reloads and restarts. Remove `seed`
from the URL to return to random maps.

Controls: click select/build · right-drag pan · wheel zoom · WASD/arrows/edge scroll ·
Space pause · 1/2/3 speed · F centre on Palace · Esc cancel · Shift-click places multiple.

## Architecture

Plain JS, one global namespace `G`, classic script load order (see `index.html`):

| file | role |
|---|---|
| `js/util.js` | iso math, seeded RNG, binary-heap A* pathfinding |
| `js/data.js` | every balance table: buildings, units, spells, flags, campaign lairs |
| `js/sprites.js` | procedural sprites, imported asset loading, and building placement anchors |
| `assets/art/palace/palace-sprite.js` | generated Palace image manifest: dimensions, bounds, and ground anchor |
| `assets/art/buildings/buildings-sprites.js` | generated manifests for the other eleven buildings, with selection outlines and effect positions |
| `assets/art/units/units-sprites.js` | eleven character atlases: idle, walk and action poses, floor anchors, selection bounds |
| `assets/art/environment/environment-sprites.js` | 35 tree, scenery and terrain texture manifests |
| `js/environment.js` | textured terrain, road and river boundaries, water animation, bridge rails, scenery, bounded terrain cache |
| `js/mapgen.js` | seeded landforms, dry settlement placement, connected roads and bridges |
| `js/world.js` | forests and scenery, construction sites, walkability, fog of war |
| `js/entities.js` | units/buildings, movement, combat, projectiles, XP, flags |
| `js/alchemy.js` | potion research, personal shopping, inventory and combat buffs |
| `js/loot.js` | seeded treasure drops, physical pickup, safe recovery and inventory overflow |
| `js/sanitation.js` | overcrowding pressure, safe sewer placement and recurring rat outbreaks |
| `js/ai.js` | the brains: hero utility AI (bounty scoring, shopping, resting, fleeing), worker/guard/monster AI |
| `js/game.js` | sim loop, economy, lair spawning, player actions, win/lose, hints |
| `js/render.js` | camera, pre-rendered terrain, depth-sorted scene, fx, minimap |
| `js/input.js` | mouse/keyboard, placement modes, selection |
| `js/ui.js` | DOM chrome: menus, info panel, messages, overlays |
| `js/sound.js` | WebAudio synth sfx |
| `js/main.js` | boot + main loop + debug params |

### Testing / QA

* `node test/seeds.js` — random seed selection and deterministic replay, plus 100
  generated maps checked for structural variety, dry foundations, reachable
  lairs/settlements/units, bridge crossings and starting construction space.
* `node test/world.js` — deterministic large-map generation, reachable lairs and
  settlements, bridge crossings, distant worker travel, frontier activation and
  long-detour pathfinding.
* `node test/alchemy.js` — research prerequisites, payments, pause/resume, hero shopping,
  potion use and expiry, taxes, thief recruitment and damage, and monster combat.
* `node test/loot.js` — drop ranges, separate RNG, no duplicate payouts, hero pickup,
  inventory overflow, guards/spells, safe pathfinding, fog, and reset behavior.
* `node test/sanitation.js` — housing thresholds, grace periods, recurrence, safe
  sewer placement across seeded regions, rat caps, reward suppression, and campaign counts.
* `node test/loot-browser.mjs` — real loot selection, desktop/mobile contents,
  autonomous recovery, end-game totals, overcrowding warnings and rat sewers.
* `node test/alchemy-browser.mjs` — desktop/mobile research and thief controls, inventory,
  and research progress using Chrome on port 9227. Run browser suites sequentially.
* `node test/smoke.js` — headless simulation: sprites generate, an unattended kingdom
  survives the early game, a scripted playthrough **must win**, the lose path triggers,
  no NaNs. Run it after any balance change. Pass a numeric or named seed to check
  another map, e.g. `node test/smoke.js Alderwick` (default fixture: `41972`).
* `test/spritesheet.html` — renders imported and generated sprites on one page
  (`?only=units|bld|misc`).
* `node test/map.mjs` — launch/reload randomization, replay links, pinned maps,
  restart terrain refresh, and desktop/mobile minimap navigation to every map corner,
  camera limits, extended zoom, campaign counts and terrain-cache checks. Captures
  three distinct regions using seeds `0` (lake), `1` (coast) and `4` (river).
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
  `?seed=41972` (reproducible map; omit for a fresh seed) ·
  `?demo=1` (one of every unit near the palace) · `?demo=2` (pre-built town) ·
  `?auto=1` (skip start screen) · `?t=240` (fast-forward sim seconds) · `?zoom=1.5`.

### Design notes

* Heroes pick goals by utility: `reward / (30·threat) · classAffinity · bravery ·
  proximity`, with bravery scaling by level and current health. Wounded heroes chug
  potions, flee faster than they fight, and bill you nothing for the drama.
* The economy is a loop: monster gold → hero purses → shops → tax pools → collectors →
  treasury → your next guild.
* Monsters now leave recoverable gold: rats 12–24, goblins 22–38, skeletons 26–46,
  and trolls 180–300. Goblins have a 15% Healing drop chance; skeletons 12% Stoneskin.
  Trolls always drop two Healing potions and have a 50% Strength chance.
* Lair chests contain 45–75 gold for sewers, 70–110 for goblin camps, and 95–145
  for graveyards, with a guaranteed Healing potion. Camps have a 40% Strength
  chance and graveyards a 60% Stoneskin chance. The existing 180/220/260 gold
  crown rewards remain separate from heroes' treasure.
* Found potions work before research, without unlocking shop recipes. Heroes
  leave supplies beyond their carrying capacity for others. Guards, towers and
  spells leave drops too. Loot remains until collected; repeated monster drops
  on the same tile merge. Unclaimed loot prevents building over that tile.
* Overcrowding allows one sewer per four cottages beyond six, rounded up. Each
  missing sewer appears after 60 game seconds, opens with two rats, and breeds
  another every 18 seconds, up to six living rats per sewer. Clearing it grants
  another 60 seconds before recurrence if housing remains above the safe limit.
  Sewer placement preserves buildings, roads and water; rats can emerge directly
  if no safe sewer plot exists. Existing sewers still need clearing after cottages
  are lost. Urban infestations grant no gold, potions, crown rewards or experience,
  and do not count toward the eight campaign lairs.
* Lairs spawn waves on a timer, hurry reinforcements when attacked, and rally their
  brood to defend — assaulting a camp is a commitment.
* Thieves (110 gold) train at the Thieves’ Guild (325 gold, four beds). They travel
  quickly and deal 14 bonus damage to a monster fighting another living ally.
* Monsters have more health and damage; goblins, skeletons and trolls also have
  stronger armor. Lairs are sturdier. A 1,300-health Hill Troll arrives at ten minutes
  and regenerates 3 health/second after six seconds without taking damage.
* Select a completed Marketplace → **Potions & research**. Healing costs 150 gold
  and takes 25 seconds; Strength costs 250/40s and Stoneskin costs 300/45s. Both
  advanced recipes require Healing. One project runs at a time; recipes unlock
  kingdom-wide, and research pauses while no completed Marketplace survives.
* Heroes buy supplies with personal gold. Recruitment includes 24 gold for supplies.
  Healing sells for 18 gold (carry two, restore 110 health below 45% health); Strength
  sells for 30 (carry one, +35% attack for 25s); Stoneskin sells for 28 (carry one,
  +4 armor for 25s). Combat potions activate near an enemy. Select a hero to see
  their purse, inventory, armor and active effects. Shopping revenue requires collection.

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
