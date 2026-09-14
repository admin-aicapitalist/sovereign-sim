# Sovereign — Godot

The complete existing game, ported to native GDScript on `migration/godot-full`. It keeps the illustrated isometric presentation and targets browsers first. The earlier one-lair experiment remains on `migration/godot-slice`.

Open `project.godot` in **Godot 4.7.2 Standard** and press F5. The checked-in data, art, effects and audio are sufficient to play; the original JavaScript game is not loaded at runtime.

[Play locally](http://127.0.0.1:8131/) while the server below is running. [Verification and measurements](reports/RESULTS.md), [port coverage](PORT_STATUS.md).

## Play

Build guilds and recruit warriors, rangers, wizards and thieves. Heroes choose their own tasks; attack and exploration bounties influence their decisions. Destroy all eight campaign lairs while protecting the Palace.

Marketplaces research potions, sell supplies to heroes and accumulate taxable revenue. Temples research a shared spellbook: the crown casts with gold, while wizards spend regenerating mana. Treasure belongs to the heroes who collect it. More than six completed cottages eventually create recurring rat sewers; demolishing cottages reduces that pressure.

Click or tap to select and place. Right-drag, touch-drag, WASD or arrows pan; wheel or +/− zoom; the minimap moves the camera. Space pauses, 1/2/3 selects speed, F centers the Palace, and Esc/right-click cancels placement. Shift-click keeps a placement tool active. Command cards scroll horizontally; longer panels scroll vertically. Help explains the rules in-game.

Start with a random map, enter a numeric or named seed, or use `?seed=41972`. Help and the ending screen offer replay. Save/Load stores the full kingdom in this browser and origin (`sovereign-godot-save-v2`); native play uses `user://kingdom-v2.json`. JavaScript prototype and trial saves use different formats.

## Browser build

Install matching Godot 4.7.2 export templates through **Editor → Manage Export Templates**, then run from the repository root:

```sh
python3 godot/tools/export_web.py --godot /path/to/Godot
python3 -m http.server 8131 --bind 127.0.0.1 --directory godot/build/web
```

Alternatively pass `--templates /path/to/templates`, pointing to a folder containing `web_nothreads_debug.zip` and `web_nothreads_release.zip`. In this workspace the engine is `/tmp/sovereign-godot-engine/Godot.app/Contents/MacOS/Godot` and templates are in `/tmp/sovereign-godot-templates`; these temporary downloads are not repository dependencies.

The helper restores portable template settings after export, produces the browser files and compressed copies, and records sizes in `reports/download.json`. Do not run concurrent exports. Generated builds and Godot's import cache are ignored by Git.

The preset uses GDScript, Compatibility/WebGL 2, one thread and no extensions. Serve the complete output directory over HTTP locally or HTTPS when hosted, with `application/wasm` for WASM and compression for WASM/JS/PCK. The local Python server serves uncompressed files. See [Godot's web export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

A separate container definition serves this export on port 8080:

```sh
# Export first; use godot/ as the Docker build context.
docker build -t sovereign-godot -f godot/Dockerfile godot
docker run --rm -p 8132:8080 sovereign-godot
```

This branch does not deploy to the existing production site. The root JavaScript application and its deployment files remain the reference implementation; deploy the `godot/` container to serve the port.

## Implementation

| Existing systems | Godot implementation |
| --- | --- |
| Seeded geography, roads, bridges, forests, lair sites | `seed_rng.gd`, `world_generator.gd`; generated at runtime, with exact reference-map parity |
| Buildings, construction, recruitment, taxes, combat, waves, XP, projectiles, campaign | `simulation.gd`, `actor.gd`, `brain.gd` |
| Potion research, personal shopping, inventory, buffs, physical treasure | `supplies.gd` |
| Temple research, seven royal spells, wizard decisions/mana, delayed meteors | `magic.gd` |
| Overcrowding, safe sewer placement, recurring rats, demolition | `sanitation.gd` |
| Original sprites, depth ordering, animated terrain, fog, bridge details, spell atlases | `world_view.gd`, terrain/fog shaders |
| Build/recruit/bounty/spell cards, inspection, research, objectives, minimap, start/help/end | `kingdom_ui.gd`, `minimap.gd` |
| Camera, touch/mouse/keyboard, pause/speed, complete save/load | `main.gd` |
| Original musical cues and ambience | `sound.gd`; offline-rendered WAV samples, enabled by a player gesture |

The simulation runs at 20 fixed ticks per second. It uses native `AStarGrid2D`, staggered decisions, spatial opponent buckets and at most 24 new paths per tick. Rendering consumes state/events and never advances combat or delayed spell damage. IDs preserve entity relationships in saves. Save validation completes before replacing the active kingdom. The minimap caches terrain in a small texture, avoiding thousands of polygon commands per frame.

Map geography and source balance are preserved. Native pathfinding, fixed-step scheduling, terrain shading and the Control-based interface produce some differences from the JavaScript presentation and moment-to-moment movement. Actors share walkable space without physical crowd separation, as in the prototype. This port covers the existing game; it does not add a new campaign or rotating 3D camera.

## Refresh source data and art

These optional tools use the frozen migration inputs in `tools/reference/`, including the prototype edits that were pending when the port began. Pass `--current-source` to the Node import/baking commands when intentionally importing later changes from `js/`. The game never loads this reference JavaScript, and these tools are not needed to run the checked-in project.

```sh
node godot/tools/export_data.mjs
node godot/tools/import_browser.mjs
python3 godot/tools/prepare_art.py
python3 godot/tools/bake_audio.py
node godot/tools/bake_effects.mjs
```

Run the metadata importer immediately before `prepare_art.py`: it restores original atlas coordinates before resampling to 3× logical resolution. That Python tool requires Pillow. Audio baking uses only Python's standard library. Effect baking uses Chrome's remote debugging endpoint on port 9231 and renders the original painted spell artwork into transparent animation atlases. None of these steps modifies the source artwork.

## Verify

From the repository root:

```sh
/path/to/Godot --headless --path godot --script tests/map_test.gd
/path/to/Godot --headless --path godot --script tests/full_simulation_test.gd
/path/to/Godot --headless --path godot --script tests/extended_simulation_test.gd
```

These check original RNG/map parity, 100 generated kingdoms, construction and economy, a full autonomous campaign, all spell effects and research, potion shopping and loot, save continuity/corruption, sanitation, and a controlled 30-minute run. Reports are written under `reports/`.

For browser tests, export and serve the game, then start a separate Chrome with GPU acceleration and remote debugging. For example on macOS:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --no-first-run --no-default-browser-check --user-data-dir=/tmp/sovereign-godot-chrome --remote-debugging-port=9231 about:blank
node godot/tests/browser.mjs
```

Node 22+ supplies the built-in WebSocket client. `GODOT_TEST_URL`, `GODOT_CDP_URL` and `GODOT_BENCH_SECONDS` override the defaults. `GODOT_SKIP_BENCH=1` runs interaction checks only. The suite opens its own tab, uses real mouse/touch events for controls, and uses a test bridge for scenario setup and accelerated simulation. It checks desktop and 390px/DPR2 mobile layouts, research, casting, save/reload, seed controls and the ordinary player URL, then measures 100/300/1,000 actors. The harness disables browser caching so every run exercises the current export. `?test=1` explicitly enables the automation bridge; ordinary player URLs do not expose it.

For a focused fresh-page profile, run `node godot/tests/performance.mjs 1000`. After starting the container on port 8132, `node godot/tests/hosting.mjs` checks health, 404 handling, MIME types, gzip delivery and decoded file integrity.

Godot uses the [MIT license](https://godotengine.org/license/). Original project art is reused, and the bundled fonts retain their [Alegreya](assets/Alegreya-OFL.txt) and [Cinzel](assets/Cinzel-OFL.txt) licenses.
