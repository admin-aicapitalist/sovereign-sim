# Run logging

Recording is automatic from the start of a settlement or standalone run. Open **Run logs** in the top controls, province setup, title, or settlement result, then choose **Export run log**. The browser downloads `sovereign-run-<id>.json`; native builds show the exported file's path. Attach that file when reporting a playthrough. No logs are uploaded automatically.

Logging begins with this version. Loading an older save creates a checkpoint and records what happens from that point forward; it cannot reconstruct an earlier unrecorded playthrough.

## Captured information

- Initial and resumed world checkpoints, seed, frozen run configuration, content definitions, engine version, wall-clock start, and test-session identification.
- Player button/card actions, keyboard commands, placement/cast coordinates, save/load requests, and test commands (explicitly marked).
- Every AI decision, actor identity/state/targets/destination, health at decisions, and the support gates evaluated during calling/refusal.
- Every applied damage event with attacker, target, amount and health before/after; destruction, level/equipment changes, potion use, royal/wizard spells, and spell healing.
- All journey explanations and settlement story events, including Shadow, recovery, leisure, theft, and bank confiscation. These are copied before the short UI histories discard old entries.
- Entity and economic changes: building activation/completion/upgrades, recruits and raiders, purses, taxable revenue, kingdom gold, research, loot and bounties. Potion purchases, tax collections/deliveries, loot collections, and bounty payouts identify their participants and amounts.
- A world sample every five game seconds: actor positions, HP/mana, path progress, current journeys, building HP/construction/spawn timers, treasury, statistics and RNG state.
- The final result and world checkpoint, once per recording segment. Resuming an already completed save can create a new segment with its own final checkpoint.

This is a diagnostic event timeline, not a video or guaranteed replay file. Continuous movement, regeneration, timer countdowns and rendering frames are sampled rather than emitted every simulation tick. UI actions and semantic event hooks retain exact game timestamps; some entity/economic changes are observed at the end of their tick. Use `segment` plus `seq` for identity and file order for chronology. Loading an older save can move game time backward: the new `run.resumed` checkpoint marks that branch in the timeline.

For a compact first review, run `python3 godot/tools/review_run.py /path/to/sovereign-run-<id>.json`. It produces event counts, hero identities/damage, Palace damage, samples by game minute, and a journey/notice timeline. It keeps resume segments distinct and rejects duplicate event identities.

## Storage and failures

Browser data uses IndexedDB `sovereign-run-logs-v1` on the preview's origin. Native logs append batches to `user://run-logs/<run-id>.jsonl`. Logs are independent of the active save and retain prior runs. Test URLs use `sovereign-run-logs-test-v1` and native tests use temporary directories. Never use test namespaces to recover a real player's run.

Pending batches are handed to storage every wall-clock second and immediately after button actions/manual saves. Browser acceptance means queued until the storage transaction completes; the menu reports pending events and errors. Browser export includes queued events even if a write failed. **Retry saving logs** retries persistence. The HUD flags storage errors. Clearing site data, browser eviction/private browsing, or deleting native files can remove logs; export important runs. An abrupt crash/close can lose the last unflushed second and any writes still pending. Native failures retain pending batches in memory until a successful write or application exit.

JSON exports contain `format: 1`, `game`, run metadata, and ordered `events`. Each event has `segment`, `seq`, `time` (game seconds), `event`, and `data`. No full log is embedded in the gameplay save, and recording does not consume gameplay RNG. Do not infer that a quiet final sample proves there was no earlier damage: inspect the event stream.

## Verification

`tests/run_log_test.gd` checks identical complete simulation snapshots with logging on/off, damage-to-Shadow causality, potion data, history beyond the UI cap, native append/export, resume segments, storage failure retention, final checkpoint uniqueness, and preserving separate runs. `tests/run_log_browser.mjs` checks actual downloads, reload/resume persistence, injected write failure with export/retry, final outcomes, and phone access. Reports are [native](run-log-systems.json) and [browser](run-log-browser.json).

The first-level [loop review](LOOP_REVIEW.md) distinguishes the observed balance gaps from this recording implementation.
