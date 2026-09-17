# Sovereign — Settlement Roguelite Plan

- Date: 2026-09-17
- Status: Agreed direction; implementation pending
- Long-term target: Steam Early Access

## Product direction

One settlement is one run. The next major milestone turns the existing kingdom simulation into a complete loop of starting, playing, finishing, unlocking options, and starting again.

**Choose starting conditions → build a kingdom → overcome its threats → win or lose → earn Renown and unlock options → start a new settlement.**

The player remains a monarch who influences autonomous heroes through buildings, services, recruitment, and bounties. Different starting choices and province conditions should encourage different strategies.

LLMs are development tools only. They may help author and review personalities, dialogue, encounter ideas, and other static content. Shipped content is reviewed and baked into the game. Gameplay, hero decisions, and narration have no runtime LLM calls, model downloads, API keys, or inference services. The complete game works offline.

## Scope boundaries

- Each settlement has a clear beginning and a victory or defeat ending.
- Each new run introduces a fresh town and hero cast.
- Persistent progression unlocks alternative strategies; the initial options must be sufficient to win.
- Use the existing Ember Crown scenario for the first complete loop.
- Reuse the existing geography generator, buildings, four hero classes, equipment, spells, and economy.
- Keep the next milestone focused on the run loop, a small amount of variation, and persistent unlocks.

A campaign map, connected settlements, traveling hero roster, persistent capital, and multi-settlement campaign simulation are outside this milestone. New hero classes, expanded social systems, and a large technology tree are deferred. Hero journeys are a core mechanic of this milestone: their stages and support needs must be visible for the whole roster in a dedicated overview.

## What resets and what persists

| Resets with each new settlement | Persists in the player profile |
| --- | --- |
| Map, buildings, and local objectives | Unlocked charters and starting packages |
| Treasury, research, and guild upgrades | Earned and spent Renown |
| Heroes, levels, equipment, and local memories | Run records and notable hero summaries |
| Active threats, treasure, and spell state | Best results and discovered content |

Journey stages and transition history shape individual runs now; richer personality and social memory can deepen them later. Heroes do not travel to the next settlement. A chronicle may preserve their stories without preserving their combat power.

## First playable milestone

### 1. Starting choices

Add a compact run setup flow that shows the province conditions and lets the player choose one unlocked royal charter or starting package.

Each choice needs an understandable benefit and cost. For example, a charter could make guilds cheaper while reducing tax income. Exact values require playtesting.

Start with a few alternatives rather than a branching upgrade tree. Preserve essential services and viable recruitment options in every starting configuration. Show the seed and support replaying a known configuration.

### 2. Province modifiers

Add a small pool of conditions that change construction, recruitment, economy, or threat priorities. Candidate ideas include:

- Restless undead: graveyards create stronger pressure, with an appropriate reward advantage.
- Costly recruitment: heroes cost more to invite, but the kingdom receives a compensating starting benefit.
- Rich ruins: treasure becomes more valuable while frontier threats become more dangerous.

These are design candidates, not committed balance rules. Initially use one province modifier per run to keep combinations understandable and testable. Existing lake, coast, and river geography supplies additional variation.

Keep modifier definitions separate from the base content. Apply them once when constructing a run; loading a save must not apply them again.

### 3. Run ending and Renown

Replace the simple win/lose transition with a result screen containing:

- Outcome and objective progress.
- Meaningful accomplishments and major losses.
- Notable heroes, using facts already recorded by the simulation.
- Renown earned and a clear explanation of the award.
- Access to unlocks and a direct path into the next settlement.

Award Renown for completed accomplishments, with an additional victory reward. Defeats can still produce progress. Merely starting or immediately abandoning a run earns nothing. Repeatedly farming renewable enemies must not produce unlimited Renown.

Run completion and its reward must be recorded once. Reloading a result, restoring an earlier save of the same run, or reopening the game must not duplicate that award. This is ordinary local-save consistency, not an online anti-cheat system.

### 4. Persistent unlocks

Use one currency: **Renown**. Offer a small set of alternative charters and starting packages.

Unlocks should create choices with tradeoffs. Avoid a mandatory ladder of permanent damage, health, or income bonuses. Do not lock basic healing or other essential counters behind repeated losses.

The initial version can use the run setup and result screens for progression. A separate elaborate metagame screen is unnecessary.

## Implementation sequence

### Step 1 — Run and profile state

- Introduce a run identity and configuration: seed, scenario, starting choice, modifier, and relevant content version.
- Separate the active settlement save from the persistent player profile.
- Store Renown, unlocks, completed-run identities, and compact run records in the profile.
- Design recoverable saves and completion handling so an interruption cannot silently lose or duplicate progression.
- Preserve existing save compatibility. Legacy standalone saves must not accidentally grant new progression rewards.

Acceptance: an active run survives save/load, a new run resets local state, and profile progress survives application restart.

### Step 2 — Complete the loop using Ember Crown

- Connect run setup to the existing simulation.
- Handle both victory and defeat through a shared completion flow.
- Calculate and persist the result and Renown award.
- Add the result screen and next-settlement action.

Acceptance: a player can finish a run, receive its award once, and start a fresh settlement without restarting the application. Defeat follows the same complete flow.

### Step 3 — Meaningful variation and unlocks

- Add the initial starting choices and province modifiers as authored data.
- Expose their effects clearly before the run starts.
- Add purchases with visible costs and immediate profile persistence.
- Ensure base definitions remain unchanged between runs.

Acceptance: two different configurations encourage different opening decisions, and an unlocked choice can be used in the next run. The initial configuration remains winnable.

### Step 4 — Feedback and playtesting

- Explain why the run ended and where Renown came from.
- Surface actual hero accomplishments in the results.
- Watch new players complete the loop without developer guidance.
- Tune repetitive openings, unclear tradeoffs, difficulty spikes, and reward pacing.

Acceptance: players understand their outcome, can identify what they would change next time, and voluntarily start another settlement.

## Engineering integration

The active game is the Godot project. Extend its existing simulation and content system rather than implementing a second game loop.

| Existing area | Planned responsibility |
| --- | --- |
| `godot/scripts/main.gd` | Run setup, new-run transitions, save/profile coordination |
| `godot/scripts/simulation.gd` | Apply run configuration and expose factual accomplishments |
| `godot/scripts/mission.gd` | Existing Ember Crown objectives and outcome conditions |
| `godot/scripts/kingdom_ui.gd` | Setup, result, and unlock interfaces |
| `godot/scripts/content/` and `godot/content/` | Authored starting choices and modifier definitions |
| New focused run/profile modules | Progression rules, completion records, persistence |

Keep progression independent of rendering. Save the selected conditions with the run so loading resumes the same rules. Run records should identify their configuration; identical seeds alone do not describe identical runs after modifiers are introduced.

## Verification

- Exercise victory, defeat, save/resume, and starting the next run.
- Check reward consistency across repeated completion, reloads, and interrupted writes.
- Verify purchases cannot overspend Renown or duplicate unlocks.
- Check that modifiers are applied exactly once and never mutate shared base definitions.
- Run the relevant existing simulation, mission, save-compatibility, and UI checks after integration.
- Playtest starting configurations for viable strategies and meaningful differences.

Automated campaigns demonstrate that scenarios can complete; human playtesting is needed to establish clarity, pacing, difficulty, and replay appeal.

## Deferred after the loop works

- Additional objective types, such as surviving an assault or recovering a specific relic.
- Hero traits, consequential memories, and small relationship systems within a run.
- A richer chronicle built from recorded events.
- More modifiers, starting choices, and content unlocks, guided by observed strategy variety.

## Path from this milestone to Steam Early Access

This milestone establishes the replay structure. It does not by itself establish release readiness.

Before Early Access, complete and validate a desktop release, prioritizing Windows; onboarding; readable settings and controls; reliable autosaves and recovery; and performance on representative player hardware. The current checked-in export configuration targets Web, so desktop packaging and testing remain explicit work.

Expand scenario variety after the first loop proves enjoyable. Set the eventual content scope from playtests rather than assuming that a larger unlock pool guarantees replayability.

The product test is: **Does the next settlement make the player reconsider their strategy and want to play again?**
