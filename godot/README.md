# Sovereign: Godot browser trial

A playable migration experiment on branch `migration/godot-slice`: keep the existing illustrated isometric world, move a small complete game loop into Godot, and measure the actual browser export.

Open `project.godot` in **Godot 4.7.2 Standard** and press F6/F5. The main scene is `main.tscn`. The checked-in fixture and artwork are sufficient to run it; Node and Pillow are only needed to regenerate those assets. All migration files live in this directory.

The exported trial is served locally at **http://127.0.0.1:8131/** when the server below is running. [Measured results and remaining risks](reports/RESULTS.md), [starting kingdom screenshot](reports/kingdom.png).

## Play

1. Place a Warriors’ Guild on clear land near the Palace. Workers build it automatically; use 3× speed to shorten the wait.
2. Select the completed guild and recruit up to four warriors.
3. Click **Find the lair**, then post an attack bounty. Heroes travel and fight autonomously.
4. Destroy the lair while protecting the Palace. Save/Load preserves the kingdom in this browser and origin.

Left-click selects or places; right-drag or WASD/arrows pans; wheel zooms; Space pauses; F returns to the Palace; Esc cancels construction; Shift keeps the build tool active. Keys 1 and 3 select speed. The trial currently targets desktop browsers with keyboard and mouse.

## Browser export

Install the matching Godot 4.7.2 export templates through **Editor → Manage Export Templates**. From the repository root:

```sh
python3 godot/tools/export_web.py --godot /path/to/Godot
python3 -m http.server 8131 --bind 127.0.0.1 --directory godot/build/web
```

Alternatively, supply a directory containing `web_nothreads_debug.zip` and `web_nothreads_release.zip` from the matching official template archive:

```sh
python3 godot/tools/export_web.py --godot /path/to/Godot --templates /path/to/templates
```

For this workspace, the downloaded engine is `/tmp/sovereign-godot-engine/Godot.app/Contents/MacOS/Godot` and the template directory is `/tmp/sovereign-godot-templates`. These temporary downloads are not repository dependencies. The helper temporarily configures custom template paths and restores the portable preset even on failure; do not run concurrent exports.

The preset uses **GDScript, Compatibility/WebGL 2, no threads, no extensions**. Godot 4 C# does not currently export to the web; the single-threaded option avoids the cross-origin isolation requirement. See the [official web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

Serve the generated HTML, JS, WASM, PCK and PNG files together over HTTP locally or HTTPS when hosted. Production hosting should compress JS/WASM/PCK and serve WASM as `application/wasm`. The Python server is an uncompressed local test server. `build/` and the import cache are ignored by Git. This experiment has not been deployed to the existing site.

## What was migrated

| Existing source | Trial implementation |
| --- | --- |
| `js/mapgen.js`, `world.js` | An exported 88×88 seed-41972 fixture; all starting friendly buildings and the nearest hostile lair |
| Blender PNGs and sprite manifests | Copied/downsampled textures, animated unit atlas frames, trees and buildings sorted by isometric depth |
| `js/data.js` | Imported building/unit balance tables; a deliberately smaller subset of behavior |
| `game.js`, `ai.js` | Workers, construction, recruitment/capacity, collector taxes, personal gold, loot, bounty escrow, combat, retreat/healing, one-lair victory and Palace defeat |
| Canvas renderer | Godot `Node2D` drawing, view culling, static baked ground, fixed camera angle and zoom/pan |
| DOM interface and persistence | Godot Controls and browser localStorage via JavaScriptBridge; native file save for editor play |

`scripts/simulation.gd` owns the game state and native `AStarGrid2D` navigation. It advances at 20 fixed ticks per second, staggers decisions, uses spatial buckets for opponent lookup, and caps path requests at 24 per tick. Failed paths wait before retrying. `world_view.gd` only draws; `main.gd` owns input, interface, the clock and persistence.

This is a **vertical slice**, not full parity. Research, alchemy/shops, wizard spells, procedural audio, fog/exploration, sanitation/overcrowding, corpse systems, minimap, dynamic map generation, connectivity-preserving placement and the full campaign are not ported. Ranged damage is immediate; projectile travel and collision are not implemented. Ground is baked and camera rotation is absent. Actors share a navigation grid without physical crowd separation. Marketplace behavior is limited to construction and taxes. The imported map is identical, but Godot's RNG/AI scheduling differs from the JavaScript simulation. Browser-game saves are not compatible with this trial.

## Rebuild imported data and art

Regeneration reads the browser code in the current working tree, including local changes. Keep the commands in this order; the art step rewrites atlas coordinates in the exported manifest.

```sh
node godot/tools/import_browser.mjs 41972
python3 godot/tools/prepare_art.py
python3 godot/tools/bake_ground.py
```

The Python art tools require Pillow (`python3 -m pip install Pillow` in your environment). Copies are limited to 3× logical resolution. The fixed ground texture is 5632×2848; larger/dynamic maps should use chunks or tiles instead. Regenerated fixtures can differ when the source game's balance or generator changes.

## Verify

```sh
/path/to/Godot --headless --path godot --script tests/simulation_test.gd
```

The suite checks invalid placement/payment, path walkability, pause, autonomous construction, guild capacity, bounty refund/payout, taxes, save continuity including RNG and paths, malformed-save rejection, victory/defeat and 100/300/1000-actor simulation loads. Results are written to `reports/native.json`.

For the browser suite, start the exported site, then launch a separate Chrome with remote debugging on port 9231. For example on macOS:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --no-first-run --no-default-browser-check --user-data-dir=/tmp/sovereign-godot-chrome --remote-debugging-port=9231 about:blank
node godot/tests/browser.mjs
```

Node 22+ is needed for built-in WebSocket. `GODOT_TEST_URL`, `GODOT_CDP_URL` and `GODOT_BENCH_SECONDS` override the defaults. Keep GPU acceleration enabled for comparable rendering measurements. The test opens/closes its own tab, drives real mouse placement/recruitment/bounty controls, uses an explicit test bridge to advance simulation time, reloads saved state, checks the normal player URL, and measures live rendering. It writes JSON and screenshots under `reports/`. The automation bridge exists only with `?test=1`; omit that parameter when playing.

Godot is distributed under the [MIT license](https://godotengine.org/license/). Original project art is reused here; the bundled fonts retain their [Alegreya](assets/Alegreya-OFL.txt) and [Cinzel](assets/Cinzel-OFL.txt) licenses.
