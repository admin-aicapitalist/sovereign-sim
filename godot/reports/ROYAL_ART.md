# Royal presentation pass

The subsequent [character release](CHARACTERS.md) replaces the unit artwork
shown in these historical screenshots. The Royal interface and environment
remain part of the current game.

The Godot game now uses a consistent medieval palette: slate civic roofs,
terracotta timber buildings, warm limestone, crimson heraldry, aged brass,
dark timber and parchment. Cinzel establishes the headings; Alegreya and its
italic companion carry body text and the title-screen motto.

## Play and inspect

- [Live game](https://sovereign-432652279722.us-central1.run.app/)
- [Local browser build](http://127.0.0.1:8131/)
- [Title screen](royal-welcome.png)
- [Developed kingdom](royal-kingdom.png)
- [Phone interface](royal-mobile.png) and [phone title screen](royal-mobile-welcome.png)
- [Tablet interface](royal-tablet.png)
- [Spell command cards](royal-spell-cards.png)
- [Armored Ember Warlord](royal-warlord.png) and [victory screen](royal-victory.png)

The kingdom screenshot uses the existing laboratory fixture to show the full
building collection. Start a normal game to play either campaign. The browser
build is deployed as Cloud Run revision `sovereign-00010-rr2`; the source project
and artwork are portable.

## Implementation

- A composed title screen presents the actual kingdom behind a smooth scrim,
  heraldic crest and restrained drifting motes. The loading page shares that identity.
- Native nine-slice wood, parchment and brass materials retain their borders
  at different screen sizes. Command cards give illustrations, names and costs
  separate space. Spell and bounty symbols sit in contrasting medallions.
- A compact campaign summary leaves more of the map visible. Expanding
  Objectives shows the full lair list; the encounter panel grows when needed.
- Four civic buildings are freshly rendered in Blender. Existing character
  and scenery sheets are refinished from the original masters.
- The Ember Warlord has an original armored model variant, eight poses,
  a dedicated portrait, stable foot anchors and one correctly placed health bar.
- Meadow variation, animated shoreline glints and quiet cloud shadows add
  terrain depth. Mipmaps stabilize distant views; closer sprites retain linear filtering.

## Verification

- Live revision `sovereign-00010-rr2` serves 100% of traffic.
  [Hosting verification](royal-deployed-hosting.json) confirms gzip, content
  types, health, 404 responses and byte-for-byte export integrity.
  [Live browser checks](royal-deployed-browser.json) pass all eight groups
  with no browser or engine errors. [Live title screen](royal-deployed-welcome.png).
- [Asset audit](royal-assets.json): 59 manifest textures; all eight boss poses
  are distinct and have unclipped transparent margins.
- [Native simulation](royal-simulation.json): 108 checks, no failures; the
  autonomous classic campaign reaches victory.
- [Native milestone systems](milestone-systems.json): 402 checks, no failures.
- [Full browser regression](royal-regression.json): construction, recruitment,
  bounties, research, spellcasting, save/load, endings, seeds and touch controls pass.
- [Mission browser regression](royal-milestone.json): campaign selection, guild
  training, relic equipment, boss warning/impact, save continuity, mobile help,
  victory and replay pass with no browser or engine errors.
- [Presentation layouts](royal-browser.json): desktop 1440×900, phone 390×844
  at DPR 2, tablet 768×1024, and live resizing between desktop and phone.
- [Crowded-scene measurement](royal-performance.json): 1,000 actors, approximately
  954 visible, averaged 50.9 FPS with a 21.7 ms 95th-percentile frame and zero
  dropped simulation time. This is a five-second local Chrome measurement on
  an Apple M4 Pro at 1440×900, following a three-second warmup, not a mobile benchmark.

Build sizes are recorded in [download.json](download.json). Mipmaps and the
additional art increase the compressed export to approximately 22.7 MB.

## Reproduce the art

See the [source artwork guide](../../assets/art/royal/README.md). All art tools
run locally; there is no runtime image service or external font dependency.
The existing simulation data and saved-game format are retained.
