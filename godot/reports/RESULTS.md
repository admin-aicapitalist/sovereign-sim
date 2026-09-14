# Full Godot port — verification

The complete existing game runs in native GDScript and exports for browsers while retaining the illustrated isometric presentation. The full port is on `migration/godot-full`; the earlier trial is retained on `migration/godot-slice`. No production deployment is included.

## Gameplay and maps

**230 gameplay assertions passed, with no failures.** [Campaign and system tests](full-simulation.json), [extended tests](full-extended.json).

- An autonomous eight-lair campaign won at **586.7 simulation seconds**, with eight bounty payouts, eight recruits, potion shopping/use and physical loot collection. This scenario uses scripted spending and bounty placement, while heroes choose paths and fight through the normal simulation.
- Tests cover construction, guild capacity, taxes, retreat, XP, physical loot, potion prerequisites/capacity/buffs, Temple research, all seven spell effects, wizard mana and decisions, delayed impacts, fog targeting, sanitation and demolition.
- Save/load preserves the map, entity IDs, paths, RNG streams, inventories, studies, buffs, cooldowns and in-flight spell impacts. Restored simulations continue deterministically. Corrupt arrays, actors and research are rejected before the active kingdom changes.
- A controlled **30-minute** scenario exercises raids, replacement staff, the ten-minute troll and repeated saves. Palace health is raised to keep that scenario running; it is a longevity test, not a balance or victory claim. Dead actor cleanup is also tested above its retention threshold.
- Six reference seeds match the original JavaScript RNG rolls, region/lair layout, every terrain tile and tree counts. Another **100 generated kingdoms** have dry foundations, reachable campaign lairs and walkable starting spawns. [Map results](full-maps.json).

## Browser and presentation

The actual release export passed mouse construction/recruitment, attack/exploration bounty controls, research, paid spell casting, pause/speed, complete page-reload persistence, malformed-save recovery, victory/defeat/replay, fresh maps and typed seed names. The victory screen is tested by loading the completed native campaign save; the browser harness does not claim a separately played full campaign. Ordinary player URLs do not expose the automation bridge.

A 390×844 CSS-pixel viewport at DPR 2 passed touch pan/tap, zoom, minimap navigation, selection, horizontal card swipes and scrollable help/research. Desktop controls were tested at 1440×900. There were **no JavaScript or engine errors**. Tests disable browser caching so they load the current export. [Raw browser report](full-browser.json).

Visual checks: [kingdom](full-kingdom.png), [spellbook](full-spellbook.png), [healing](full-healing.png), [mobile kingdom](full-mobile.png), [mobile research](full-mobile-research.png), [victory](full-victory.png).

## Rendering measurements

Recorded 2026-09-14, Godot 4.7.2 release export, headless Chrome 152, Apple M4 Pro Metal graphics, 1440×900, DPR 1, one thread and `crossOriginIsolated=false`.

| Actors | Average FPS | Frame p95 | Simulation tick p95 |
| ---: | ---: | ---: | ---: |
| 100 | 60.0 | 16.67 ms | 2.20 ms |
| 300 | 60.0 | 16.67 ms | 3.70 ms |
| 1,000 | 50.4 | 21.97 ms | 9.10 ms |

Each case has 3 seconds of warm-up and 15 seconds of measurement, with a 20 Hz simulation. No simulation time was dropped. The camera is zoomed out; approximately 98, 291 and 954 actors are drawn. The profiler also records main-loop, world drawing, UI and minimap costs in the raw report. [1,000-actor screenshot](full-crowd-1000.png).

The crowd mixes warriors and goblins with high health, runs their normal AI/pathfinding/combat, and reveals the map. At high density many units settle into melee. This measures sustained full-map rendering and combat, not 1,000 continuously pathfinding actors. Path requests remain capped at 24 per tick and deferred requests are reported. There is no physical crowd separation. The minimap uses a cached texture instead of thousands of per-frame tile polygons.

These measurements describe this machine and workload. Mobile input/layout was tested through Chrome emulation; real phones, Safari, Firefox and low-end hardware still need release testing. No equivalent full-game workload was benchmarked in the JavaScript version.

## Delivery

The stock-template export is **48.96 MB uncompressed / 19.06 MB estimated gzip**. About 10.05 MB of the compressed payload is the engine and 8.90 MB is the game pack. Sizes are computed from the files, not an internet download measurement. [Exact sizes](download.json).

The local container build passed health/404 checks, correct WASM MIME type, gzip delivery and byte-for-byte verification of decompressed HTML/JS/WASM/PCK against the export. [Hosting results](full-hosting.json). The Python development server serves uncompressed files.

The source balance and seeded geography are preserved. Native navigation/scheduling, terrain shading and the Godot interface differ in some details from the JavaScript implementation. JavaScript prototype and trial saves have different formats. [Run, export and reproduce the checks](../README.md).
