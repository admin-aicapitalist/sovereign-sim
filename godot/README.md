# Sovereign — Godot

Sovereign runs in native GDScript. **The Ashen March** adds replayable settlement runs: choose province conditions and a charter, build a kingdom, recover the monastery, defeat the Warlord, earn Renown, and found another settlement. This branch is a local build; it has not been deployed. The standalone **Ember Crown** and **Classic Kingdom** remain available for older saves.

The **Royal art pass** adds a composed title screen, a matching browser loading screen, carved wood and brass frames, parchment command cards, Cinzel headings and Alegreya body/italic text. Civic buildings have newly rendered slate roofs and warm stone. Terrain includes broad meadow variation, shoreline highlights and slow cloud shadows. Sprite mipmaps keep distant views stable while the closer view retains crisp detail. See [art sources and reproduction](../assets/art/royal/README.md) and [visual verification](reports/ROYAL_ART.md).

The **character release** rebuilds all heroes, staff, monsters and the Warlord with eight viewing directions, layered medieval equipment, cloth motion and dedicated portraits. Each appearance has 144 frames; walking follows distance traveled, while attack poses follow actual wind-up and release. See the [animated previews and checks](reports/CHARACTERS.md) and [editable Blender sources](../assets/art/units/directional/README.md).

The **magic and combat release** adds 128 wizard casting frames, effects attached to staff and palm sockets, seven distinct native spell animations, a turbulent meteor fire shader, rendered quartz and molten rock, reactive wards, weapon arcs, recoil and 18 original stereo cues. Effects follow the real targets and damage timing, freeze with pause, and survive save/load. See [visuals and verification](reports/ARCANE.md) and [editable effect sources](../assets/art/magic/README.md).

The **living buildings pass** adds drifting chimney smoke to cottages and timber guilds, and rippling cloth on palace, guild, tower and bounty flags. The five rooftop flags use newly rendered building plates with their baked cloth removed; the original poles, architecture and projection stay fixed. A shared breeze animates cloth folds and expanding smoke wisps using the simulation clock. Rebuild with `blender --background --python-exit-code 1 --python godot/tools/render_atmosphere.py` followed by `.venv/bin/python godot/tools/finish_atmosphere.py`; verify with `node godot/tests/atmosphere_browser.mjs` after exporting.

Open `project.godot` in **Godot 4.7.2 Standard** and press F5. The checked-in data, art, effects and audio are sufficient to play; the original JavaScript game is not loaded at runtime.

[Play locally](http://127.0.0.1:8131/) while the server below is running. [Ember Crown verification](reports/MILESTONE.md), [original port measurements](reports/RESULTS.md), [port coverage](PORT_STATUS.md).

[Settlement implementation and verification](reports/SETTLEMENT.md) covers the new loop, compatibility checks, campaign matrix and remaining human playtest gates.

## Play

Build guilds and recruit warriors, rangers, wizards and thieves. Heroes choose their own tasks; attack and exploration bounties influence their decisions. The default setup shows a fresh province, seed, condition and starting charter. Founding or resuming a settlement starts time immediately; press Space or Pause to stop time when needed. Four dismissible hints explain recruitment, bounties, recovery and personal shopping.

Open **Hero Journeys** to track Persona or Shadow, interrupted journeys, locations, purses and support actions for the entire roster. A crushing defeat can send even veterans into persistent Shadow. Fund a hero’s recovery from their row, then protect their time at a guild or Temple. Refusing heroes spend money at the new **Inn** and **Brothel**. Thieves steal from patrons and bank half; open **Guild banks & leisure** to confiscate guild reserves once per 120 game seconds. See [the rules and verification](reports/JOURNEYS.md).

Heroes now enter **guilds, Temples, Inns and Brothels** to shelter and rest. Occupied buildings show flickering lights and waving pennants; select one to see its residents, or track everyone’s location in Hero Journeys. The shadow venues have new dark sprites, beckoning courtesans, a drinking patron and a street brawl. See [the animations and shelter checks](reports/LEISURE.md).

In **The Ashen March**, victory requires defeating the Ember Warlord while the Palace stands. Other lairs provide optional preparation and rewards. Two lairs reveal the monastery, or heroes can discover it naturally. Clearing it starts a visible 90-second recovery window before the Warlord arrives. He guards the ruins, marks his ground slam, and calls reinforcements once at half health. Scheduled Palace raids begin after three minutes; there is no unrelated ten-minute troll arrival.

Results record accomplishments, losses, notable heroes and 0–17 Renown. **Guild Compact** costs 10 Renown and trades 15% cheaper guild construction for 10% lower periodic taxes. **Rich Ruins** trades stronger frontier defenders for better frontier treasure. Base classes and services are available immediately. The **Reign** menu offers save-and-leave or abandonment; completed results offer a fresh settlement or replay of the same conditions with a new run identity.

**Standalone chronicles / older saves** opens the previous Ember Crown and Classic Kingdom menu. Their original eight-lair victory requirements and save slot are retained; they do not award Renown.

Completed hero guilds can train to tier II, increasing capacity and providing attack/armor support to their recruits. Heroes automatically equip better weapons and armor from treasure; another hero can recover their equipment after death.

Marketplaces research potions, sell supplies to heroes and accumulate taxable revenue. Temples research a shared spellbook: the crown casts with gold, while wizards spend regenerating mana. Treasure belongs to the heroes who collect it. More than six completed cottages eventually create recurring rat sewers; demolishing cottages reduces that pressure.

Click or tap to select and place. Right-drag, touch-drag, WASD or arrows pan; wheel or +/− zoom; the minimap moves the camera. Space pauses, 1/2/3 selects speed, F centers the Palace, and Esc/right-click cancels placement. Shift-click keeps a placement tool active. Command cards scroll horizontally; longer panels scroll vertically. Help explains the rules in-game.

Start with a random map, enter a numeric or named seed, or use `?seed=41972`. The full configuration includes the selected charter and condition. Format-4 settlement saves retain resolved rules, hero records, timers, equipment, research and RNG state. Autosave runs every 60 seconds; manual Save and Reign → Save and leave are also available.

Settlement saves and profiles are separate: browser keys begin `sovereign-settlement-v1-`, and native files use `user://settlement-*.json`. Checksummed writes retain backups. A durable completion receipt prevents duplicate awards and recovers interruptions between result and profile writes. Storage failures expose a retry; a new run cannot replace unsaved completion progress. A previously completed run loads its recorded result even when an earlier active save is restored. Unlocks and seen-hint preferences survive new runs. Test URLs use a separate settlement profile namespace.

Standalone saves keep `sovereign-godot-save-v2` / `user://kingdom-v2.json`. Formats 2 and 3 remain readable. Older game builds cannot read format 4; JavaScript prototype and trial saves use different formats.

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

For GCP, deploy this `godot/` directory to the existing Cloud Run service. The source upload allowlist includes only the exported browser files and container configuration. See [deployment instructions](../deploy/README.md) for the command, live URL and rollback procedure. The root JavaScript application remains the reference implementation.

## Implementation

| Existing systems | Godot implementation |
| --- | --- |
| Seeded geography, roads, bridges, forests, lair sites | `seed_rng.gd`, `world_generator.gd`; generated at runtime, with exact reference-map parity |
| Buildings, construction, recruitment, taxes, combat, waves, XP, projectiles, campaign | `simulation.gd`, `actor.gd`, `brain.gd` |
| Indoor shelter, protected occupants, recovery and destruction exits | `shelter.gd`, `brain.gd` |
| Shadow venue scenery and occupied lights/pennants | `leisure_visuals.gd`, `leisure_cast.json` |
| Potion research, personal shopping, inventory, buffs, physical treasure | `supplies.gd` |
| Temple research, seven royal spells, wizard decisions/mana, delayed meteors | `magic.gd` |
| Overcrowding, safe sewer placement, recurring rats, demolition | `sanitation.gd` |
| Editor-authored unit/building/spell/item definitions | `content/catalog.tres`, typed scripts in `scripts/content/` |
| Monastery encounter, boss telegraph/enrage, relic equipment, guild upgrades | `mission.gd`, `equipment.gd`, `simulation.gd` |
| Settlement configuration, factual hero records, rewards, profile storage, setup and results | `settlement_rules.gd`, `settlement_store.gd`, `settlement_ui.gd`, `content/settlements.json` |
| Reusable AnimationPlayer impact, death, upgrade and relic cues | `scenes/combat_cue.tscn`, `combat_cue.gd` |
| Original sprites, depth ordering, animated terrain, fog, bridge details, spell atlases | `world_view.gd`, terrain/fog shaders |
| Build/recruit/bounty/spell cards, inspection, research, objectives, minimap, start/help/end | `kingdom_ui.gd`, `minimap.gd` |
| Camera, touch/mouse/keyboard, pause/speed, complete save/load | `main.gd` |
| Original musical cues and ambience | `sound.gd`; offline-rendered WAV samples, enabled by a player gesture |

The simulation runs at 20 fixed ticks per second. It uses native `AStarGrid2D`, staggered decisions, spatial opponent buckets and at most 24 new paths per tick. Rendering consumes state/events and never advances combat or delayed spell damage. IDs preserve entity relationships in saves. Save validation completes before replacing the active kingdom. The minimap caches terrain in a small texture, avoiding thousands of polygon commands per frame.

Classic Kingdom preserves map geography and the original definition values. Ember Crown adds attack windups, equipment progression and the authored monastery/boss encounter to the same seeded geography. Native pathfinding, fixed-step scheduling, terrain shading and the Control-based interface produce some differences from the JavaScript presentation and moment-to-moment movement. Actors share walkable space without physical crowd separation, as in the prototype. The camera keeps the fixed illustrated isometric view. The Warlord uses his own armored sprite and portrait. See the [content authoring guide](content/README.md) to tune Godot Resources and edit the combat animation scene.

## Refresh source data and art

These optional tools use the frozen migration inputs in `tools/reference/`, including the prototype edits that were pending when the port began. Pass `--current-source` to the Node import/baking commands when intentionally importing later changes from `js/`. The game never loads this reference JavaScript, and these tools are not needed to run the checked-in project.

```sh
node godot/tools/export_data.mjs
node godot/tools/import_browser.mjs
python3 godot/tools/prepare_art.py
.venv/bin/python godot/tools/style_art.py
python3 godot/tools/bake_audio.py
node godot/tools/bake_effects.mjs
```

Unit, building and spell gameplay tuning now comes from the catalog Resources. Refreshing `data/balance.json` alone does not overwrite those authored definitions.

Run the metadata importer immediately before `prepare_art.py`: it restores original atlas coordinates before resampling to 3× logical resolution. That Python tool requires Pillow. Audio baking uses only Python's standard library. Effect baking uses Chrome's remote debugging endpoint on port 9231 and renders the original painted spell artwork into transparent animation atlases. None of these steps modifies the source artwork.

Run `style_art.py` after the base importer to restore the Royal palette, new civic renders, boss atlas, interface textures and mipmap import settings. It also works independently on the checked-in assets. Optional Blender rendering is documented with the art sources above. The UI uses Godot [nine-slice StyleBoxTexture materials](https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html) so borders retain their proportions at different window sizes.

## Verify

From the repository root:

```sh
/path/to/Godot --headless --path godot --script tests/map_test.gd
/path/to/Godot --headless --path godot --script tests/full_simulation_test.gd
/path/to/Godot --headless --path godot --script tests/extended_simulation_test.gd
/path/to/Godot --headless --path godot --script tests/milestone_test.gd
/path/to/Godot --headless --path godot --script tests/milestone_campaign.gd
/path/to/Godot --headless --path godot --script tests/journey_test.gd
/path/to/Godot --headless --path godot --script tests/shelter_test.gd
/path/to/Godot --headless --path godot --script tests/settlement_test.gd
/path/to/Godot --headless --path godot --script tests/settlement_campaign.gd
```

These check original RNG/map parity, 100 generated kingdoms, construction and economy, a full autonomous campaign, all spell effects and research, potion shopping and loot, save continuity/corruption, sanitation, and a controlled 30-minute run. Milestone checks cover Resources, training, equipment, boss mechanics, combat windups, save compatibility and a complete Ember Crown campaign. Reports are written under `reports/`. The immutable format-2 save in `tests/fixtures/` verifies older-save migration independently of generated reports.

For browser tests, export and serve the game, then start a separate Chrome with GPU acceleration and remote debugging. For example on macOS:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --no-first-run --no-default-browser-check --user-data-dir=/tmp/sovereign-godot-chrome --remote-debugging-port=9231 about:blank
node godot/tests/browser.mjs
node godot/tests/milestone_browser.mjs
node godot/tests/royal_browser.mjs
node godot/tests/settlement_browser.mjs
node godot/tests/journey_browser.mjs
node godot/tests/leisure_browser.mjs
```

Node 22+ supplies the built-in WebSocket client. `GODOT_TEST_URL`, `GODOT_CDP_URL` and `GODOT_BENCH_SECONDS` override the defaults. `GODOT_SKIP_BENCH=1` runs interaction checks only. The suite opens its own tab, uses real mouse/touch events for controls, and uses a test bridge for scenario setup and accelerated simulation. It checks desktop and 390px/DPR2 mobile layouts, research, casting, save/reload, seed controls and the ordinary player URL, then measures 100/300/1,000 actors. The harness disables browser caching so every run exercises the current export. `?test=1` explicitly enables the automation bridge; ordinary player URLs do not expose it.

For a focused fresh-page profile, run `node godot/tests/performance.mjs 1000`. After starting the container on port 8132, `node godot/tests/hosting.mjs` checks health, 404 handling, MIME types, gzip delivery and decoded file integrity. Set `GODOT_REPORTS_DIR` for browser/hosting runs to store results separately without replacing the local benchmark reports.

Godot uses the [MIT license](https://godotengine.org/license/). Original project art is reused, and the bundled fonts retain their [Alegreya](assets/Alegreya-OFL.txt) and [Cinzel](assets/Cinzel-OFL.txt) licenses.
