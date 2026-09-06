# ⚜ Sovereign — A Fantasy Kingdom Sim

A browser-playable, single-level **indirect-control kingdom sim** in the spirit of the
classic 2000-era fantasy kingdom management games: you are the monarch, not the general.
You raise buildings, recruit heroes and post gold bounties — but the heroes decide for
themselves whether your coin is worth the danger.

Everything is original and generated in code: **all sprites are drawn procedurally at
load time** (no image assets), all sounds are synthesized with WebAudio (no audio files),
and there are **zero dependencies and no build step**.

The art targets late-90s isometric-RTS production values: full-resolution painted
sprites with warm/cool directional lighting, gradient-shaded walls and roofs, soft
shadows and dirt aprons under buildings, blended terrain transitions with animated
shore foam, 4-frame walk cycles, two-phase attack animations, waving banners,
flickering fires, swaying trees, and a particle system for combat impacts, deaths,
explosions and level-ups.

## Run it

**[Play the hosted game](https://sovereign-432652279722.us-central1.run.app/)** — no sign-in required.

Open `index.html` in any modern browser. That's it.

(Optionally serve it — `python3 -m http.server` — but `file://` works fine since
everything is plain classic scripts.)

Hosting configuration and redeployment instructions are in [`deploy/README.md`](deploy/README.md).

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
| `js/sprites.js` | procedural painted-style sprite generator (rendered at 2× canvas resolution) |
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
* `test/spritesheet.html` — renders every generated sprite on one page
  (`?only=units|bld|misc`).
* `node test/browser.mjs` — optional real-browser interaction checks using Node 22+
  and a Chrome instance started with `--remote-debugging-port=9227` and a separate
  `--user-data-dir`. No test dependencies are needed. Exercises construction,
  recruitment, bounties, spells, keyboard controls, desktop/mobile rendering, and
  direct `file://` loading; screenshots go to the system temporary directory.
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

The original art uses warm stone, slate roofs, forest greens, gold accents, and a
painted miniature style. The map includes feathered fog, animated water, smoke,
trees, flags, and combat particles. The interface adapts to narrow screens; drag
the map with a finger and use the minimap's zoom controls. Sound starts with
**Begin your reign** and can be toggled using the music-note button. The ambient
score, birds, construction, combat, and spell sounds are all synthesized locally.
