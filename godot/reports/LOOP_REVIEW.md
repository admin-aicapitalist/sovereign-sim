# First settlement loop review — 17 September 2026

The reported lack of Shadow and mid-game escalation is consistent with the implementation. The journey and leisure systems function, but the normal pressure loop rarely makes the player need them. This review records the current behavior and proposes the next gameplay changes; the logging patch does not change balance.

Compared [SOVEREIGN_SPEC.md](../../SOVEREIGN_SPEC.md), [the settlement plan](../../SETTLEMENT_ROGUELITE_PLAN.md), [the first-level plan](../../FIRST_SETTLEMENT_LEVEL_PLAN.md), and the current Godot simulation. The current Persona/Shadow direction in spec §4.2 supersedes the original passive recovery and mandatory linear journey proposals.

## Reproduction

[loop_audit.gd](../tests/loop_audit.gd) observes the existing paid campaign policy using Crown / Untroubled. It pays for construction, recruits, research, bounties, and royal Shadow support. It samples the world every 30 game seconds and watches Shadow counts and town danger every second. It changes no game rules. [Raw results](loop-audit.json):

| Seed | Victory time | Recruits | Hero deaths | Shadow entries | First Shadow | Palace damage |
| --- | --- | --- | --- | --- | --- | --- |
| 41972 | 12:03 | 13 | 0 | 1 | 8:06 | 0 |
| 0 | 8:39 | 13 | 0 | 0 | — | 0 |
| 4 | 7:40 | 10 | 0 | 0 | — | 0 |

Enemies spent 118, 92, and 58 seconds respectively within 12 tiles of the Palace, without damaging it. Proximity alone overstates effective pressure. These are comparison runs, not a replay of the player's unknown seed and decisions. The policy does not build thieves or leisure venues and automatically funds recovery, so these results cannot establish the leisure economy's value or human recovery difficulty. Three runs are a diagnostic sample, not a population estimate.

The harness counts distinct hero/calling pairs, not every journey attempt. Do not divide Shadow entries by that number and claim the spec's failure-rate metric. Existing completion tests demonstrate that the campaign is winnable, not that its intended pacing is present.

## Gaps that explain the playthrough

**1. Shadow depends on a narrow surviving-health threshold.** In [journey.gd](../scripts/journey.gd), `wounded` only enters Shadow after a hit leaves a living hero below 20% maximum HP. A normal retreat is correctly not Shadow, but the game does not track a consequential failed expedition or repeated unresolved setbacks either. A hero can repeatedly disengage, heal, and resume without suffering a lasting loss of purpose.

Standalone chronicles do not initialize settlement journeys. A future report must first distinguish that mode from low pressure in a settlement; the new log checkpoints identify it.

That threshold sits behind several protections: early retreat, automatic healing potions below 45% HP, 60 HP restored per level, guild armor, wizard healing, and safe indoor rest. Ordinary-stage retreat begins at 45%; even Tests begins at 24%. Rest heals on frequent AI decisions, and sheltered heroes cannot be attacked from outside. This combination makes the existing trigger rare against ordinary threats. Raising the threshold alone would turn prudent retreats into arbitrary psychological punishment.

**2. The founding → growth → crisis loop is incomplete.** Spec §§2 and 4.4 describe escalating competing priorities, with time and kingdom value contributing to threats. [simulation.gd](../scripts/simulation.gd) instead spawns one existing enemy type per active lair interval, with a six-unit home cap. The interval multiplier is `max(0.65, 1 - time / 2400)`: about 14% faster spawning at five minutes and 33% at ten. This adds frequency, not a new decision or threat role.

Cleared lairs permanently stop producing enemies while heroes gain levels, equipment, and spells. Frontier activation adds potential sources, but there is no organized raid budget, wealth/progress escalation, or phase that tests tax routes and services together. Free replacement workers, collectors, and guards also soften attrition. The first-level plan explicitly softened the opening and boss warning and disabled the old ten-minute Hill Troll, relying on ordinary lairs for competing pressure. It did not replace that removed escalation with a new middle act.

**3. The climax can wait for the player.** [mission.gd](../scripts/mission.gd) reveals the Monastery after two lairs or natural discovery, starts a 90-second arrival timer on its destruction, then lets the Warlord guard the ruins until approached. His half-health reinforcement is two goblins once. There is no later mustering pressure or onward attack that makes preparation compete with town defense. The first-level target of a 21–30 minute boss confrontation is a desired window, not a system that produces it; these paid policies win in 8–12 minutes.

**4. Refusal and the shadow economy rarely become strategic.** The support gate is healthy plus any one of an ally, supplies/Temple access, or a 150g bounty. A buddy or premium often clears Refusal on the next decision. Inn/Brothel spending → theft → guild bank → confiscation → royal recovery exists, but persistent refusal/Shadow is usually absent, so this loop has little demand. More decorative venue activity cannot solve that.

**5. Tests favored reachability and successful completion.** Journey/shelter tests deliberately inflict heavy damage to exercise Shadow and recovery. The campaign policy immediately supports Shadow and does not exercise leisure economics. These remain useful correctness tests, but they do not prove that natural play creates setbacks, economic choices, or a middle-game crisis. The new run logger supplies the missing playthrough evidence; old 96-event run histories and 16-entry hero journals were insufficient.

## Next gameplay patch

1. **Make failed expeditions consequential.** Keep safe retreat as a valid choice. Track commitment, meaningful combat, forced withdrawal, and unresolved repeat setbacks around an actual calling. Let a clearly signaled failed ordeal lead into persistent Shadow, retaining the hero's experience and interrupted purpose. Hero Journeys should state what broke their confidence and the king's recovery action. Strong support and smart preparation should still permit a run without Shadow.
2. **Add a visible middle-game threat sequence.** After the opening grace, use elapsed time plus settlement progress/value to muster announced raids from surviving threats or clearly announced map entrances. Introduce distinct pressures: a road raid that delays taxes, followed by coordinated attackers threatening a service building while the expedition is away. Tie strength to a bounded budget with recovery gaps. Destroying a lair must continue to remove its contribution; avoid invisible punishment for successful play.
3. **Connect the economic choices.** Make the king choose among guild growth, defending income/services, expedition support, and restoring a withdrawn hero. Preserve current money transfers and confiscation cooldown; measure whether stolen money and lost hero labor create a real tradeoff before changing prices or minting extra cash.
4. **Give the Warlord an announced consequence for indefinite delay.** After a preparation interval, muster a visible assault or advance toward the kingdom, with sufficient warning and room for recovery. Let an aggressive player engage early. Avoid forcing a fixed 30-minute wait.
5. **Validate human pacing and natural failure.** Review several seeds and cautious/aggressive strategies. Measure time in Refusal, Shadow reasons and duration, time away from class duties, recoveries, service outages, tax interruptions, warning-to-contact time, treasury swings, and damage to town. The original spec's 20–40% failed journeys and 30-minute session targets are tuning hypotheses; recalibrate them for this shorter Persona/Shadow settlement, rather than forcing a Shadow quota into each run.

Run the audit with `Godot --headless --path godot --script tests/loop_audit.gd`. Actual playthroughs can now be exported through **Run logs**; see [recording and review instructions](RUN_LOGS.md).
