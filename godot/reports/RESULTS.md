# Godot browser migration trial

The existing isometric art and a complete small campaign work in Godot's browser export. This is enough to keep Godot under consideration for development tooling and future native builds. It is not evidence that a complete rewrite is faster or cheaper than continuing the JavaScript game.

The browser cost is concrete: approximately **50.85 MB uncompressed / 20.64 MB gzip** for this stock-template export. About 10 MB of the compressed total is the engine WASM and 10.5 MB is the content pack. The gzip number is calculated from the files, not a measured CDN transfer; the local test server serves uncompressed files. See [exact file sizes](download.json).

## Browser measurements

Recorded September 14, 2026, with Godot 4.7.2 release export, headless Chrome 152, Apple M4 Pro Metal graphics, 1440×900 viewport and device pixel ratio 1. The export used one thread and ran with `crossOriginIsolated=false`.

| Actors | Average FPS | Frame p95 | Simulation tick p95 |
| ---: | ---: | ---: | ---: |
| 100 | 60.0 | 16.67 ms | 0.60 ms |
| 300 | 60.0 | 16.67 ms | 1.00 ms |
| 1,000 | 53.6 | 21.71 ms | 3.10 ms |

Each case has 3 seconds of warm-up followed by 15 seconds of measurement. Simulation runs at 20 Hz while drawing follows the browser. Frame intervals come from Godot's process clock; the harness also records elapsed wall time. A 60 FPS ceiling limits the smaller cases. The run recorded no dropped simulation time and no JavaScript or engine errors. [Raw browser results](browser.json), [1,000-actor screenshot](crowd-1000.png).

The crowd contains two-thirds warriors and one-third goblins placed on open ground. Their normal AI, A* navigation and damage calculations run. Very high health keeps the population constant. The camera is zoomed out and draws approximately 99, 296 and 960 actors respectively; some are covered by the interface. Path requests are capped at 24 per simulation tick, and the report includes deferred requests. At high density most actors settle into melee combat, so this is a sustained combat/rendering test rather than a worst-case test of 1,000 continuously moving pathfinders. There is no physics-based crowd separation.

These results are from one high-end machine and a short synthetic workload. They do not establish mobile, Safari, Firefox, low-end laptop, long-session or full-game performance. No equivalent workload was measured in the original JavaScript implementation, and the Godot slice omits several of its systems.

## Behavior verified

- The imported map has a route from the settlement to its single lair; paths stay on traversable tiles.
- Placement rejects occupied ground and charges only accepted construction. Workers finish a guild automatically; capacity and recruitment costs apply.
- Heroes follow paid bounties, fight, collect loot and win the campaign. Tax income, bounty refunds/payouts and Palace defeat are exercised.
- Save/load preserves actors, paths, timers, money, bounties and 64-bit RNG state. A restored simulation continues identically in the native regression. Invalid saves are rejected before active state is replaced.
- The browser suite uses real mouse placement and recruitment/bounty buttons, pauses/resumes, reloads the page, restores a saved kingdom and reaches victory. The normal player URL starts without the automation bridge.
- Screenshots confirm the original illustrated isometric presentation: [kingdom](kingdom.png), [victory](victory.png).

The native simulation suite also passes. Its p95 tick times are roughly 0.30 / 0.62 / 2.18 ms for 100 / 300 / 1,000 actors on this Mac. These are simulation-only numbers, not native rendering or browser FPS. [Raw native results](native.json).

## What this means for a browser-first game

Keeping the fixed isometric look is practical: the trial reuses the existing PNG artwork instead of requiring a new 3D art pipeline. Godot supplies scene/UI tooling, native pathfinding and a runnable web build, but gameplay and interface code still require a port.

Before expanding this experiment into the main game, test real target browsers/devices, set an acceptable first-load budget, and port another representative system such as fog plus magic/audio. A reduced engine template and narrower asset pack are possible size optimizations; their savings are not measured here. The [official web-export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) describes reduced templates and browser constraints.

The trial leaves mobile/touch UX, dynamic map generation, research/shops/alchemy, magic, audio, sanitation, fog, minimap and campaign parity for later. [Scope and reproduction instructions](../README.md).
