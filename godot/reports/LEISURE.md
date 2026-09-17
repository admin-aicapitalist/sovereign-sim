# Shadow venues and indoor heroes

The Brothel has black slate and timber, deep wine walls, crimson velvet, red lanterns and a heart sign. Two clothed adult courtesans sway, fan themselves and beckon from the porch. The Inn uses soot-dark timber, amber windows and muted red drapery. Outside, a patron lifts his tankard while two men trade drunken jabs and recoil.

These four scenery loops have 16 rendered frames each at 4 fps. They use the same geometry and material helpers as the existing characters. Feet share a fixed anchor across frames; people participate in the world’s depth ordering. The shared game clock drives people, flickering lights and cloth, including pause and speed controls. Scenery neither creates simulation actors nor consumes gameplay RNG. Unfinished and destroyed venues have no scenery performers.

[Animated cast preview](leisure-cast.webp) · [Brothel in game](leisure-brothel.png) · [Inn in game](leisure-inn.png) · [Phone](leisure-mobile.png)

## Shelter and visibility

- Heroes approach an entrance before going inside. All four guilds, the Temple, the Inn and the Brothel support occupancy; the Palace is a fallback.
- Wounded heroes recover indoors and leave at about 86% health. Temples provide faster recovery. Paid venue visits also restore 2 health per game second. Physical recovery and leisure do not cure Shadow.
- Refusing or Shadow heroes wait indoors between visits. Funded royal recovery and homecoming reflection take place inside their actual service building.
- Indoor heroes are hidden from the world sprite/selection layers and excluded from outdoor targeting, attacks, projectiles, spellcasting and scouting. A destroyed shelter releases its living residents at the entrance.
- Paying patrons spend personal gold after entering. Thieves must enter the same venue to steal; fees, guild cuts and confiscation cooldowns retain their existing rules.
- Occupied buildings show animated lights and a pennant above the roof, with an occupant count. The pennant is crimson when a resident is in Shadow, otherwise gold. Selection lists names, activity and health, with journal buttons. Hero Journeys shows `Inside <building>` for every resident; Find hero focuses their building.
- Saves retain each hero’s indoor building ID. Invalid references, unfinished shelters and contradictory combat/travel state are rejected before changing the live settlement. Older saves resume with their heroes outside.

[Guild occupancy](leisure-warriors.png) · [Temple occupancy](leisure-temple.png) · [All heroes](leisure-overview.png) · [Phone roster](leisure-mobile-overview.png)

## Reproduce the art

From the repository root, with Blender and Pillow installed:

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/art/render_buildings.py -- --only inn brothel --resolution 1152 --samples 48 --output /tmp/sovereign-shadow-venue-art
.venv/bin/python godot/tools/finish_leisure.py /tmp/sovereign-shadow-venue-art
blender --background --factory-startup --python-exit-code 1 --python godot/tools/render_leisure_cast.py -- --output /tmp/sovereign-leisure-cast
.venv/bin/python godot/tools/finish_leisure_cast.py /tmp/sovereign-leisure-cast
```

The building finisher preserves projected porch/lantern positions in `data/assets.json`. The cast finisher writes four atlases and `data/leisure_cast.json`. PNGs and metadata are sufficient to run the game; Blender is only needed to author new art. [Atlas measurements](leisure-art.json) include frame counts, texture dimensions and clipping checks.

## Verification

- [Shelter simulation](shelter-systems.json): 76 checks covering entrances, all seven service types, protected occupants, real autonomous travel/recovery/exit, loss of shelter, paid rest, Shadow persistence and save validation.
- [Journey/economy simulation](journey-systems.json): 112 checks; physical visits, theft and funded recovery now cross actual entrances.
- [Browser checks](leisure-browser.json): rendered animation and exact pause for every service type, resident panels/journals, focus and roster locations, save/load, departure, collapse, 2× clock and phone layout.
- Existing browser suites: all five journey/economy groups and all seven settlement groups pass on desktop and phone. The shared test loader now waits for canvas sizing and modal layout before clicking.
- Existing settlement checks: 77 pass. Standalone simulation: 108 pass. [All 12 settlement campaigns](settlement-campaign.json) reach victory after a mid-run save/load, taking 404–572 game seconds with 0–1 hero deaths. These are automated playthroughs, not human balance testing.

The browser evidence comes from the local WebGL build. This change has not been deployed.
