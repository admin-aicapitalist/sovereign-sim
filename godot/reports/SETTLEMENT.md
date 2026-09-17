# The Ashen March — local implementation

Implemented on `feat/settlement-first-level`. This build is local only; no deployment or push was performed.

## Play

Open the Godot project and press F5, or use [the local browser build](http://127.0.0.1:8131/) while the development server is running. Choose a province condition and an available charter, then **Found this settlement**. Founding and resuming start time immediately. Press Space or Pause to stop time when needed.

Victory requires defeating the Warlord while the Palace stands. Clearing the monastery starts a 90-second countdown; other lairs are optional. Results record Renown and factual hero accomplishments, offer the Guild Compact purchase, and lead directly into another settlement. Reign → Save and leave preserves an unfinished run; Reign → Abandon finishes it with partial accomplishment rewards.

The setup uses a geography preview, persistent primary action and four dismissible in-game hints. All four existing hero classes and essential services are available immediately. The game makes no runtime model calls.

Open **Hero Journeys** to see the entire roster's stages, locations, calling objectives, blockers and next support actions in one live menu. Stages now affect real decisions, including refusal, commitment, ordeal, Shadow recovery and Mastery. Journals provide optional XP, equipment and history detail. See [journey rules, scope and verification](JOURNEYS.md).

## Verification

| Check | Result |
| --- | --- |
| Settlement systems | 77 checks pass: configuration, restored modifiers, natural/early monastery discovery, countdown and enrage persistence, boss victory, simultaneous defeat, partial/capped rewards, recovery receipts, duplicate completion, purchases, hints, corrupt saves, legacy compatibility, hero guidance, exploration leveling, event deduplication and saved history. |
| Existing mission systems | 402 checks pass. |
| Existing full simulation | 108 checks pass, including the original autonomous campaign. |
| Settlement campaigns | All 12 combinations pass: both charters × both conditions × lake/coast/river seeds. Every run resumes from a save; construction, recruitment, research and bounties are paid; heroes act autonomously. |
| Settlement browser flow | Desktop and 390px/DPR2 checks pass: time advances and friendly units move after founding, resuming and replay; Pause, Space and the Reign menu control time correctly. Also covers construction/recruitment, saving/leaving, interrupted profile writes, older-save restoration, purchase, abandonment, defeat and fresh runs. |
| Standalone mission browser flow | Six groups pass, including legacy mission selection, guild training, relics, boss telegraphs, save/load, mobile controls and results. |

Evidence: [settlement systems](settlement-systems.json), [campaign matrix](settlement-campaign.json), [settlement browser checks](settlement-browser.json). The browser scenario uses the explicit test bridge to arrange combat outcomes; campaign checks exercise autonomous play without combat cheats.

The initial local build left both founding and resuming paused, making the kingdom appear frozen. Those actions now start the simulation immediately; completed results stay paused. The browser regression reproduced the old behavior and now verifies elapsed time and unit positions using real browser frames without advancing the test clock.

Exploration previously accumulated XP without checking for a level until a later combat kill. Exploration and combat now use the same immediate leveling path. Hero UI checks cover empty and populated rosters, journal copy, recovery history, support navigation, save/load, phone layout and preservation of the player's pause state through nested views.

Save/resume campaigns exposed two existing issues that are fixed here: lair loot used an integer remainder operation on a JSON-restored float counter; fireball splash and thief distraction compared mixed actor/building values directly. They now normalize the counter and compare entity identities. Focused regression checks cover these paths.

## Persistence

Format 4 saves contain a run identity and resolved configuration. Active settlements and profiles use separate checksummed storage with backups. A saved completion receipt allows an interrupted profile write to recover; completed identities prevent reloaded results or earlier saves from granting the reward twice. Purchases write the profile before becoming available. Storage failures retain a retry path and prevent replacing an unfinished completion.

Standalone formats 2 and 3 retain their previous save slot, balance and victory rules, and grant no Renown. Browser tests use a separate settlement namespace from normal player URLs.

## Pacing still needs human playtesting

With journey decisions enabled, the automated policy wins in **377–557 simulation seconds** (about 6.3–9.3 minutes), with **0–2 hero deaths**. These results demonstrate viable configurations; they do not establish the proposed 20–30-minute player pacing, difficulty, clarity or replay appeal. The setup therefore does not advertise an unverified duration. The five-player gates in the [level plan](../../FIRST_SETTLEMENT_LEVEL_PLAN.md) remain pending.

## Local screenshots

- [Province setup](settlement-setup.png)
- [Run result](settlement-result.png)
- [Storage retry](settlement-storage-retry.png)
- [Phone setup](settlement-mobile-setup.png)
- [Phone defeat result](settlement-mobile-defeat.png)
- [Hero journal](settlement-hero-journal.png)
- [Phone hero journal](settlement-hero-mobile.png)
- [Phone hero roster](settlement-heroes-mobile.png)
