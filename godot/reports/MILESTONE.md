# Ember Crown milestone

Implemented on `feature/ember-crown`, retaining the browser-first illustrated isometric game. Classic Kingdom remains selectable on the welcome screen.

## Play and authoring

- Godot Resource assets define all 11 units, 12 buildings, seven spells, four equipment items and the mission. The Inspector exposes their tuning fields; `content/catalog.tres` registers the definitions.
- A reusable AnimationPlayer scene provides impact, death, upgrade and relic cues. Ember Crown attacks wind up before damage. Effects follow simulation time, including pause, speed and save/load, and visible effect instances are capped at 80.
- Hero guilds can train to tier II: two additional recruit slots, 25% building health, and support of +4 attack/+2 armor to their own heroes while the guild stands.
- Heroes recover and automatically equip better weapons and armor from physical treasure. Replaced equipment stays available for others, and equipped items drop on death.
- Two destroyed lairs reveal the Ashen Monastery. Clearing it awards relics and a 30-second recovery window before the Ember Warlord arrives. His marked slam precedes real damage; heroes attempt to dodge. Half-health enrage calls reinforcements and shortens the slam cooldown. Victory requires the boss and all eight lairs.

The encounter uses the existing seeded map and graveyard foundation. The Warlord reuses a scaled, tinted troll sprite. [Editor authoring instructions](../content/README.md), [run/export instructions](../README.md).

## Verification

Recorded 2026-09-14 with Godot 4.7.2.

| Check | Result |
| --- | --- |
| New content and systems | 402 assertions, zero failures; includes parity for every original unit/building/spell field, training, equipment, boss mechanics, windup timing and save validation |
| Original simulation suites | 108 + 122 assertions pass; original campaign still wins at 586.7 seconds; controlled 30-minute soak passes |
| Maps | Six reference maps match; 100 generated kingdoms pass foundation, reachability and spawn checks |
| Ember Crown campaign | Victory at 614.25 simulation seconds, ten recruits, one guild upgrade, nine relic pickups, four boss slams, all eight lairs cleared |
| New browser flows | Six grouped checks pass, no engine/JavaScript errors: campaign choice, paid training/recruitment, relic recovery, boss warning/impact, save/reload, mobile scrolling/actions and victory/replay |
| Original browser suite | Eight grouped flows pass with no engine/JavaScript errors; includes mouse/touch controls, research, casting, save migration, endings, seeds and player URL |
| Web export | 49.03 MB uncompressed; 19.09 MB estimated gzip |

The native campaign uses normal construction, paid upgrades/research/bounties, and autonomous heroes. It does not increase friendly health or inject combat damage. Its roughly 10-minute victory is a scripted strategy result, not a promise of play duration or broad balance validation. Browser scenarios use the explicit test bridge for setup and accelerated time; victory presentation loads the completed native campaign save.

[System results](milestone-systems.json), [campaign results](milestone-campaign.json), [browser results](milestone-browser.json), [exact export sizes](download.json). Original suite reports and screenshots are retained as the pre-milestone baseline.

Save format 3 preserves mission state, equipment, guild training and pending attacks. The existing browser/native save slot is retained. An immutable, real format-2 save in `tests/fixtures/legacy-v2-save.zip` verifies older-save loading as Classic Kingdom. Older game builds cannot read new saves.

## Browser performance

Measured on headless Chrome 152, Apple M4 Pro Metal, desktop 1440×900/DPR 1, single-threaded WebGL 2. Each workload runs three seconds of warm-up and 15 seconds of measurement.

| Actors | Average FPS | Frame p95 | Simulation tick p95 |
| ---: | ---: | ---: | ---: |
| 100 | 60.0 | 16.67 ms | 2.20 ms |
| 300 | 60.0 | 16.67 ms | 3.70 ms |
| 1,000 | 46.5 | 21.67 ms | 10.00 ms |

No simulation time was dropped. The stress workload uses classic combat with high-health warriors/goblins and a revealed map; about 98/291/954 actors are drawn. It measures sustained rendering/combat, not continuously pathfinding crowds or a full boss encounter. The 1,000-actor result is below the pre-milestone 50.4 FPS baseline; ordinary campaign-sized workloads remain near 60 FPS on this machine. These are local measurements, not phone-performance guarantees. [Raw regression and performance report](milestone-regression-browser.json).

## Visual checks and remaining limits

[Welcome](milestone-welcome.png), [guild training](milestone-training.png), [equipment](milestone-equipment.png), [boss warning](milestone-warlord.png), [impact](milestone-impact.png), [mobile inspector](milestone-mobile-equipment.png), [mobile help](milestone-mobile-help.png), [victory](milestone-victory.png).

Desktop is checked at 1440×900; mobile controls/layout use Chrome emulation at 390×844 and DPR 2. Physical phones, Safari, Firefox and low-end devices still need release testing. Heroes share walkable space without physical crowd separation. New archetypes still need matching art and UI/behavior registration; adding new mechanics requires game code.

This branch is verified locally. The deployed Cloud Run release remains the original full port described in [the deployment record](RESULTS.md).
