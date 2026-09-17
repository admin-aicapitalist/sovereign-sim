# Sovereign — First Level: The Ashen March

- Date: 2026-09-17
- Status: Implemented locally; balance tuning and human playtesting pending
- Branch: `feat/settlement-first-level`
- Foundation: the existing Godot Ember Crown scenario
- Agreed format: a standard replayable run with light onboarding

The local implementation and verification are recorded in [Settlement verification](godot/reports/SETTLEMENT.md). The pacing windows below remain design targets; automated campaigns do not establish player completion time.

## 1. The experience

**Build a small kingdom worth fighting for, watch its unlikely heroes recover the Ashen Monastery, and overcome the Ember Warlord. Take their stories and earned Renown into the next settlement.**

The level should make three things clear through play:

1. Buildings, services, and gold change what autonomous heroes choose to do.
2. Preparing heroes and protecting the town compete for the same treasury.
3. A settlement ends, but its accomplishments open different ways to begin again.

Working title: **The Ashen March**. Present it as a normal province to settle from the first session. Replays use the same scenario and objectives, with fresh geography and heroes unless the player requests the same configuration.

Target **20–30 minutes at normal speed**, excluding pauses and menus. Experienced players may finish sooner. This is a playtest target, not a timer or a reason to inflate enemy health. The existing [automated Ember Crown report](godot/reports/milestone-campaign.json) finishes in about 614 simulation seconds; that does not establish a new player's completion time.

Briefing draft:

> The old road ends beneath the ruins of the Ashen Monastery. Raise a settlement here, keep its people safe, and reclaim the march from the Ember Warlord. Your heroes will choose their own battles. Give them a reason to choose yours.

## 2. How the two source documents apply

Use [SETTLEMENT_ROGUELITE_PLAN.md](SETTLEMENT_ROGUELITE_PLAN.md) for milestone scope. Use [SOVEREIGN_SPEC.md](SOVEREIGN_SPEC.md), especially its fun model and first-scenario proposal, for the player experience.

| Topic | Decision for this level |
| --- | --- |
| Run structure | One settlement is one complete run; Renown and alternative starts persist. |
| Technology | Extend the active Godot game and its content resources. |
| Heroes | Warrior, Ranger, Wizard, and Thief. The Temple provides recovery and spell research; it does not recruit Clerics. |
| Character stories | The Journey is a core feature: implement Persona/Shadow dynamics, conditional commitment, interrupted journeys, king-funded recovery and recurring setbacks for the four existing classes. Track all heroes together in a live overview. Social bonds and additional classes remain later work. |
| Narration | Short authored text, selected from recorded events; entirely offline. |
| Progression | Alternative starts with tradeoffs. Basic services and all four classes remain available from the first run. |
| Art | Use the existing illustrated kingdom, royal interface, and Ember encounter assets. |

The spec's campaign map, runtime advisor, additional classes, and JavaScript desktop architecture do not become dependencies of this level.

## 3. Starting the settlement

The setup screen shows the objective, geography preview, seed, starting charter, province condition, and expected duration. Choosing **Found this settlement** or **Resume saved settlement** starts time immediately. Space and the Pause button let the player stop time to inspect the town and controls; setup and menus hold time while open.

Generate a fresh seed by default, including on the first session. Show its province condition before the player chooses an available charter; allow rerolling or entering a seed. Start with the **Crown Charter** available and show the unlockable alternative with its tradeoff. Seed `41972` remains a regression reference, not a prescribed opening. First-time players receive a few dismissible hints; scenario rules, enemy behavior, and rewards are the same on every run with the same configuration.

Retain the existing starting settlement:

- Palace, three cottages, three peasants, two guards, one tax collector.
- 1,500 treasury gold; no pre-recruited heroes or completed guilds.
- Existing recruitment, potion research, guild training, Temple research, and royal spells.
- Free resting at a surviving guild or the Palace; the Temple improves recovery.

One viable opening to validate is a Warriors' Guild and Marketplace, followed by two Warriors and Healing potion research. Using current prices:

| Opening expense | Gold |
| --- | ---: |
| Warriors' Guild | 350 |
| Marketplace | 250 |
| Two Warriors | 200 |
| Healing potion research | 150 |
| First attack bounty | 100 |
| **Total / remaining from the starting grant** | **1,050 / 450** |

This leaves a real choice: another guild, a guard tower, more recruits, or a reserve. The table demonstrates affordability, not combat balance. Heroes buy potions with their own money; research does not automatically equip the party. Teach that distinction when the first hero shops.

All buildings remain accessible. Tooltips explain the Temple, advanced research, and sanitation when inspected or when a relevant warning appears. The player chooses their opening freely; hints explain controls and consequences without prescribing a build order.

## 4. Geography and visual composition

Keep the existing 88 × 88 generator, eight original lairs, roads, bridges, and expansion clearings. Validate a readable route from town to nearby threats to monastery across generated seeds. Geography variants may rotate or bend this route.

| Area | Gameplay role | Presentation |
| --- | --- | --- |
| Palace clearing | Safe place to learn building, recruitment, recovery, and tax delivery | Warm stone, lit windows, readable construction space and short service routes |
| Near roads and two approachable lairs | First exploration and attack decisions; remove sources of pressure | Clearly distinguish the road ahead from unexplored woodland |
| Ashen Monastery | Main expedition; relic reward and announcement of the coming boss | Existing graveyard foundation with a distinct nameplate, restrained ash and ember accents |
| Remaining borderlands | Optional equipment, income, and pressure reduction before the final battle | Fog conceals distant sites; discovering a frontier lair visibly announces its activation |

Placement acceptance: dry foundations, reachable sites, room for the opening buildings, and an approach to the monastery that does not require clearing every frontier lair. Optional frontier lairs remain dangerous when activated; “optional” refers to the victory requirement.

Keep the current warm settlement / cool wilderness palette, with ember red reserved for the monastery threat and boss warning. Essential warnings need shape and text as well as color. The slam telegraph must remain visible beneath units and spell effects. Reuse existing art before commissioning additional assets.

## 5. Playable arc

The timings below are desired pacing windows. Progress follows the simulation and accomplishments, with no forced wait for a scheduled chapter.

| Beat | Target window | Player decision | Feedback and progression |
| --- | --- | --- | --- |
| Found a home | 0–4 min | Where to place a guild and market; how much gold to reserve | Workers build; recruits arrive; first hint explains autonomy. |
| Make the first offer | 4–8 min | Post an attack bounty or invest in scouting; increase the reward or improve support | See a hero answer, fight, withdraw, or buy supplies. First original lair falls. |
| Secure an approach | 8–13 min | Clear another threat, add a class, or protect tax routes | After two original lairs are destroyed, reveal the monastery. Introduce its reward and the consequence of clearing it. |
| Recover the monastery | 13–21 min | Commit now or first fund potions, equipment, guild training, and Temple magic | Clearing the site grants its existing 250 gold reward and Runeblade treasure, then starts a visible recovery countdown. |
| Face the Warlord | 21–30 min | Fund the boss bounty while preserving town defense and spell reserves | Warlord arrives at the monastery. Heroes choose when to engage and try to evade marked slams. |
| Record the reign | Immediately on outcome | Read what happened; buy an alternative charter or save Renown; start again | Persist the result once and offer the next settlement directly. |

Exploration is useful but never a mandatory click. Heroes may discover the monastery naturally. Discovering it early exposes its briefing; clearing it early advances the encounter immediately without waiting for the two-lair reveal threshold. The reveal threshold is a discovery aid, not an invisible barrier. A fast or unusual opening must not strand the objectives or replay an event.

### Threat pacing changes proposed for this scenario

- Delay scheduled raids on the Palace until **180 simulation seconds**. Existing nearby defenders still fight when approached; the opening is not invulnerable. Apply the rule consistently to spawn assignment and monster behavior, including enemies whose home was destroyed.
- Retain existing dormant frontier lairs and their discovery/attack activation. Their initial defenders still exist. Announce that exploring farther can wake new pressure.
- Extend the monastery's boss-arrival delay from **30 to 90 seconds**. Show this consequence before the player attacks the site, then display the saved countdown.
- Disable the unrelated automatic Hill Troll arrival at 600 seconds for this run configuration. Ordinary lairs supply the competing threat while the Warlord supplies the climax.
- Start with the existing Warlord health and damage; try a **2.4-second slam warning** instead of 1.8 seconds. Keep autonomous dodging and the existing single reinforcement event below half health. Validate whether injured heroes can escape, recover, and return.
- The Warlord initially guards the monastery, as in the current behavior. His arrival starts an encounter the player can prepare to engage; the countdown is not a Palace-destruction deadline.

These values are first playtest candidates. Tune early hero survival, warning readability, and travel time before adding difficulty systems. Give the player room to replace an early casualty. Avoid unexplained reinforcements or a guaranteed heroic rescue.

## 6. Heroes carry the story

Use saved Persona/Shadow state and journey context to direct the existing autonomous AI: arrival, a calling offer, hesitation, supported commitment, ordeal, return or Shadow, and another cycle. Guidance follows each hero's real transition conditions and accomplishments. It does not require a named hero to survive.

| Actual behavior | Useful player-facing explanation | Available response |
| --- | --- | --- |
| A wounded hero returns home | “Returning to recover.” | Allow recovery; provide a closer Temple or potion supply. |
| A hero shops before answering a flag | “Buying supplies before heading out.” | Keep services reachable and let the purchase complete. |
| A hero chooses a different bounty | Explain that hero's current goal and the competing offer | Change rewards, recruit another class, or wait for recovery. |
| A Ranger explores | “Scouting the borderlands.” | Place an exploration bounty on a useful approach. |
| A hero equips the Runeblade | Name the actual collector and show the equipment change | Inspect them and support the next expedition. |

Do not label ordinary retreat as a psychological shadow state or claim heroes have bonds the simulation does not track. Avoid scripted refusals merely to demonstrate independence. If heroes accept nearly every offer in playtests, record it as a balance issue.

Keep selected-hero status visible. Add a compact factual event record sufficient to retain recruitment, major objective participation, relic equipment, and deaths, including heroes removed from the live actor list. Result examples must use those facts: “Wren discovered the monastery” only if discovery attribution was recorded. Otherwise describe the settlement's discovery without naming a hero.

The **Hero Journeys** menu exposes every hero's narrative stage, location, current call, unmet conditions and next support action together. It stays live, supports pausing, and filters Shadow, support needs, quests, recovery, Mastery and fallen heroes. A defeat can interrupt any phase; the king funds supervised recovery while the hero retains experience. Refusing heroes visit the new Inn and Brothel, spending personal gold. Thieves steal from patrons, bank half, and the king can confiscate guild funds once per 120 game seconds through Guild banks & leisure. Stages are saved simulation states that affect decisions. Journals provide optional XP, equipment and history detail. Finishing enemies and lairs grants combat XP; claiming an exploration bounty grants 20 XP and can immediately trigger a level. Guild training and equipment strengthen heroes separately from levels and completed journeys. See [implemented journey rules](godot/reports/JOURNEYS.md).

Limit onboarding to four short contextual hints: recruiting from a completed guild, posting or increasing a bounty, understanding a wounded hero's retreat, and distinguishing hero shopping money from the treasury. Show at most one at a time, allow dismissal or disabling all hints, and retain seen-hint preferences across sessions. There is no tutorial checklist or required action before objectives advance. Pause and speed controls remain available throughout. Monastery, raid, and defeat messages are ordinary scenario feedback on every run.

## 7. Victory, defeat, and rewards

**Proposed victory:** the Ember Warlord is defeated and the Palace is standing. Monastery clearance is the natural prerequisite for his arrival. Remaining lairs are optional preparation and bonus accomplishments; no cleanup objective follows the boss.

This deliberately changes the existing Ember Crown requirement of defeating the boss **and all eight lairs**. Store the new objective rules with the run configuration. Existing standalone saves retain their original objectives and do not acquire progression rewards. Clear objective copy must distinguish the two rulesets.

**Defeat:** the Palace falls. Resolve Palace destruction before victory if both occur in the same simulation step. An empty treasury or temporarily having no heroes is recoverable and does not independently end the run.

**Save and leave:** preserve the active run. **Abandon settlement:** explicitly finish it as abandoned and award only already completed accomplishments. A start followed by immediate abandonment earns zero.

Freeze gameplay when the outcome is resolved. Boss victory does not require someone to collect the Crown drop or a specific hero to survive. Display equipment ownership only where collection actually occurred.

Proposed Renown table, recorded once per run:

| Accomplishment | Renown | Limit |
| --- | ---: | --- |
| First original lair destroyed | 2 | Once |
| Second original lair destroyed | 2 | Once |
| Ashen Monastery recovered | 3 | Once; may also count toward the first two original lairs |
| Victory | 8 | Once; no additional boss-kill currency award |
| Original frontier lair destroyed | 1 each | At most two bonus Renown |
| Renewable enemies, generated infestations, playtime alone | 0 | No farmable award |

A typical victory earns **15–17 Renown**. Losing after two lairs earns 4; losing after also recovering the monastery earns 7, before any frontier bonus. A fast monastery-first victory may earn less for skipping the second-lair accomplishment. Use original site identities, not the generic kill counter, for these awards.

The result screen shows outcome, objective progress, treasury and losses, up to three notable heroes, and an itemized Renown award. For defeat, report the observed final attack and relevant facts such as destroyed services or fallen heroes. Do not infer an unrecorded strategic cause as fact.

Primary action: **Found another settlement**. Also offer **Replay these conditions**, access to charter purchases, and a return to the title screen. Replaying a configuration creates a new run identity; loading the completed run only displays its recorded result.

## 8. A reason to start again

Keep the initial variation pool small:

| Charter | Availability | Effect and tradeoff |
| --- | --- | --- |
| Crown Charter | Available immediately | Baseline prices and the 1,500-gold grant; general-purpose opening. |
| Guild Compact | Purchase for 10 Renown | Recruitment-building construction costs −15%, rounded up; periodic Palace, cottage, and Marketplace tax generation −10%. Recruitment, research, loot, and bounty prices stay at their normal values. |

The Compact encourages earlier class variety at a continuing income cost. A baseline victory buys it; partial successes can also accumulate enough Renown. It never grants permanent combat power. Display the changed costs and tax amounts before starting.

Choose exactly one province condition per run:

| Condition | Effect |
| --- | --- |
| Untroubled Province | Baseline rules, with no additional modifier effects. |
| Rich Ruins | Gold dropped by original frontier lairs +25%; ordinary enemies originating from those lairs have +10% maximum health, including initial defenders and later spawns. Bosses, the monastery reward, renewable infestations, and Renown are unaffected. |

Both conditions are available without Renown. Setup reveals the selected condition before the charter decision and allows a different seed. Begin human tests with the baseline, then test all four charter/condition combinations across the three geography types. “Next settlement” means a new run of this level in the initial milestone.

## 9. Implementation order

| Slice | Work | Completion evidence |
| --- | --- | --- |
| A. Run foundation | Add run identity/configuration, separate profile persistence, recoverable saves, and completion receipts. Persist seed, scenario, charter, condition, objective/balance versions, and resolved rules. | Resume the same conditions, preserve old saves, and award a finished run exactly once after restarts or interrupted writes. |
| B. Complete the current loop | Connect setup, existing Ember gameplay, both outcomes, Renown, results, and next-settlement transitions. | Win and lose without restarting the app; a new run resets town and cast while keeping profile progress. |
| C. First-level pacing | Add the proposed objective variant, raid delay, troll suppression, monastery countdown, out-of-order discovery handling, and contextual guidance. | Play the proposed opening and climax through ordinary player actions; no mandatory final map cleanup. |
| D. Replay choices | Add the two charters, two province conditions, and persistent purchase. | Different openings remain viable; modifiers apply once and never alter shared base content. |
| E. Readability and tuning | Add the minimal factual hero record, finish feedback, inspect varied seeds, and conduct first-player tests. | Players can explain a hero decision, diagnose their outcome, and start another settlement unprompted. |

Primary integration points: `godot/scripts/main.gd` for transitions and persistence coordination; focused new run/profile modules for progression; `simulation.gd`, `brain.gd`, and `mission.gd` for scenario rules and factual events; `kingdom_ui.gd` for setup, guidance, and results; content resources for authored configuration. Progression must work independently of rendering.

Changes to objective rules, modified unit definitions, timers, and event progress must survive save/load; retain hint preferences with profile/settings data. Restore the resolved configuration before rebuilding actors; future spawns use it too. Use a recoverable completion receipt keyed by run ID so neither loading an earlier save nor interruption between settlement and profile writes duplicates or loses the award. Surface storage failures with retry instead of reporting an unsaved purchase or award as complete.

## 10. Validation and design gates

Implementation checks should cover:

- Victory with optional lairs still standing, Palace defeat, simultaneous Palace/boss death, and abandonment with zero or partial accomplishments.
- Discovering and clearing the monastery before two other lairs; saving during its countdown and the boss fight; reinforcement and reveal events occurring once.
- First-opening construction space, reachable objectives, raid timing, and optional frontier activation across river, lake, and coastal geography.
- Hero replacement after an early death; recovery without a Temple; all essential services available with the initial profile.
- Partial and capped Renown awards; completed-run reload; older active-save restoration; interrupted persistence; purchases without sufficient funds.
- Modified initial and future enemies, configuration replay, new-run resets, and legacy save compatibility.
- Relevant existing mission, simulation, map, save, and browser checks. Update existing eight-lair expectations only for the new objective configuration.

Human playtest gates, initially with five new players:

1. At least four understand within five minutes that heroes choose their own actions and can locate the next useful control.
2. At least three finish a settlement within the target window, with enough evidence to tune failures and long idle stretches.
3. At least four can describe a concrete response they would change after a setback or defeat.
4. At least three voluntarily begin another settlement; record whether the charter/condition changes their opening.
5. Record first bounty, first lair, monastery, boss, deaths, major spending, idle stretches, and wall/simulation time. Investigate unavoidable early casualty chains and boss preparation that requires repeated replacement of the whole roster.

Automated victory establishes that a configuration can complete. Human tests decide whether the opening teaches, the hero behavior makes sense, and the ending earns another run.

## 11. Implemented direction

The local implementation uses the standard replayable format with light onboarding, victory at the Warlord's defeat, a live overview backed by real hero journeys, and a first charter unlock that changes spending priorities. The timing and balance values remain provisional. Human clarity, difficulty, and replay-appeal gates are still pending; see the verification record for completed automated checks.
