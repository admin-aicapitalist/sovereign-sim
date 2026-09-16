# Magic and combat release

[Play the deployed game](https://sovereign-432652279722.us-central1.run.app/).
Cloud Run revision `sovereign-00012-dzn` serves 100% of traffic. The previous
character-art revision, `sovereign-00011-8gs`, is available for rollback.
The packed game SHA-256 is
`3ef05223aff7054ff43bbd66b7685c9b12c889624d411e2ef452e23a7f564ed8`.

Seven spells now have native, continuously animated effects that respond to the
actual caster, recipients and damage events. Wizards have an additional
**128 casting frames** with projected palm and staff sockets. Combat adds weapon
arcs, directional sparks, recoil, reactive wards, detailed projectiles, and
18 original stereo sound cues.

[Watch the in-game animation reel](arcane-reel.webp), view the
[spell gallery](arcane-showcase.png), or inspect the
[eight-direction casting performance](arcane-casting.webp).

## Spell identities

| Spell | Animation and response |
| --- | --- |
| Healing Light | Jade and gold ribbons rise around the actual healed recipients. |
| Arcane Ward | Blue facets surround protected units; shields flare where hits land. |
| Haste | Amber wind ribbons follow moving units and curl around their feet. |
| Lightning Bolt | A branching sky strike chains through the enemies that took damage, with brief secondary pulses. |
| Frost Nova | Rendered quartz formations emerge around the target; frost remains at slowed units' feet. |
| Meteor | An inscribed warning contracts beneath a rotating molten stone and turbulent fire trail. Damage triggers an eruption, fragments, ground cracks, smoke and a brief camera impulse. |
| Far Sight | A luminous iris opens inside a constellation of violet stars. |

Ground inscriptions sit beneath characters. Matter and additive light use
separate CanvasItem passes. The fire plume is a native Godot shader. Original
Blender assets provide mineral facets and molten rock; procedural smoke supplies
the softer aftermath. The palette, metal/cloth figures and inscribed circles
complement the existing medieval UI and world art.

## Timing, control and persistence

The simulation still controls damage, mana, gold, cooldowns and targeting. Wizard
spell effects retain their immediate gameplay timing; the new artwork plays the
release and recovery. Ember Crown's basic-attack wind-up uses the charging poses.
Moving wizards retain their walk cycle while casting light follows their hands
and staff. Idle staff glints remain subtle.

Effect time interpolates the fixed simulation step. Pausing freezes geometry,
particles, shader turbulence and casting poses; changing game speed advances
them together. The meteor warning ends on the tick that applies its damage, and
that tick creates the eruption. The camera impulse affects the world and is
capped at four screen pixels. Pointer placement follows the shaken transform.

Optional visual metadata records actual recipients, projectile origins, effect
IDs and character directions. New saves preserve the casting direction; older
version-3 saves infer it as before. Malformed optional fields are rejected before
mutating the kingdom. Presentation consumes no simulation randomness.

## Validation

- [Spell/casting checks](arcane-systems.json): 421 native checks, including atlas
  bounds and sockets, real healing costs, meteor timing, armor, projectiles,
  old saves and malformed metadata.
- [Character regression](arcane-character-regression.json): 3,497 checks covering
  the existing 1,728 frames, directions, worker poses and previous saves.
- [Campaign regression](arcane-campaign.json): 108 checks and autonomous victory.
- [Campaign systems](arcane-campaign-systems.json): 402 checks covering the boss,
  equipment, upgrades and save continuation.
- [Full browser regression](arcane-full-browser.json): controls, audio toggle,
  construction, recruitment, research, saves, victory/defeat, touch interaction,
  and a player URL without the automation bridge.
- [Effect browser checks](arcane-browser.json): all seven real casts, wizard poses,
  pixel-identical paused fire/particles, meteor save/reload, wards, melee, projectiles, budget
  enforcement and the 390px DPR2 phone viewport.
- [Boss browser checks](arcane-boss-browser.json): the warning, pause/save/reload,
  animated impact, relic equipment, training and completed mission flow.
- [Sound analysis](arcane-audio.json): 18 stereo clips with peaks at or below 0.78;
  samples are generated offline without external recordings.
- [Deployed hosting](arcane-deployed-hosting.json): HTML, JavaScript, WASM and PCK
  match the local export byte for byte after decompression; MIME, health and 404
  responses pass. [Live spell checks](arcane-deployed-browser.json) repeat all
  seven casts and combat interactions on the published build, with no errors.
  [Deployment receipt](arcane-deployment.json).

## Performance

The renderer keeps at most 24 spell effects, 80 impact effects, 128 projectiles,
192 buff/caster actors and 32 fire plumes. It culls offscreen and invisible effects.
At high effect density it simplifies inscription ornaments, glow fringes and
particle counts. Normal casts retain the complete treatment. Damage labels are
bounded and repeated hits on the same recipient do not stack unreadable text.

[Crowd measurements](arcane-performance.json) on desktop Chrome / Apple M4 Pro,
1440 × 900, use three seconds of warm-up and 15 seconds of measurement:

| Actors | Average FPS | 95th-percentile frame | Dropped simulation time |
| --- | ---: | ---: | ---: |
| 100 | 60.0 | 16.7 ms | 0 |
| 300 | 60.0 | 16.7 ms | 0 |
| 1,000 | 41.4 | 25.0 ms | 0 |

The [synthetic saturation test](arcane-budget.json), with 24 overlapping spells
and 80 impacts held onscreen, averages 48.8 FPS over five seconds (66.7 ms
95th-percentile frame). This is an extreme density test through the debug bridge,
not a claim of sustained 60 FPS under every combat load. The phone checks emulate
a 390px DPR2 viewport; they are not measurements from a physical handset.

The exported game is approximately **37.54 MB gzip**, compared with 35.46 MB for
the previous character release.

## Editable sources

See [the authoring guide](../../assets/art/magic/README.md). The additional wizard
atlas remains separate from the base animations. Its lossless master and a saved
Blender casting pose are included. Animation poses are generated by Python rather
than stored as a Blender armature/timeline. Runtime code is in
`scripts/arcane_layer.gd`, `scripts/arcane_plume.gdshader` and `world_view.gd`.
