# Authoring Sovereign content

Open `godot/project.godot` in Godot. The game loads `content/catalog.tres`, which references the unit, building, spell, item and mission resources in these folders. Double-click a `.tres` file and edit its exported fields in the Inspector, save, then restart play. These resources are now the runtime source for those definitions; `data/balance.json` retains the original potion, map and economy tables.

- `units/warrior.tres`: health, damage, armor, range, movement and recruitment cost. The `properties` dictionary contains additional class-specific values such as bravery and wizard mana.
- `buildings/warriors.tres`: building cost/health and the guild upgrade’s price, training time, added capacity and support bonuses.
- `spells/heal.tres`: research, price, mana, cooldown and area. Extra effect parameters are in `properties`.
- `items/runeblade.tres`: slot, rank and actual attack/armor bonuses. Heroes equip a higher-ranked item in each slot, leaving other items in the chest.
- `missions/ember_crown.tres`: boss health, slam warning/radius/damage/cooldowns, enrage threshold, reveal condition and the recovery window before arrival.

The catalog copies definition data for each simulation, so playing cannot mutate the source assets. Duplicate a definition and add its reference to the appropriate catalog list to register it. New archetypes still require matching art, UI registration and behavior; new mechanics require game code. Existing tuning can be edited without changing gameplay code. Keep IDs unique and stable, because saved games reference them.

Open `scenes/combat_cue.tscn` to edit and preview the `cue` animation. Its AnimationPlayer drives a normalized progress property. The world samples that timeline using simulation time, so effects freeze on pause, follow game speed, and resume consistently from a save. At most 80 visible effect scenes are retained. Neither the animation nor rendering decides damage.

The Ember Crown layers authored encounters onto the seeded map. The Ashen Monastery uses a guaranteed dry, reachable graveyard foundation. After two lairs fall it is revealed; freeing it creates relic treasure and starts a 30-second recovery window. The Warlord then arrives, marks his ground slam before impact, and calls two reinforcements once below half health. Victory requires his defeat and all eight lairs.

The original campaign is available as **Classic Kingdom** in the welcome screen. Save format 3 includes mission state, equipment, guild training and pending attacks; original format-2 saves load as classic kingdoms. Both use the existing local save slot, so loading older saves remains straightforward. Older versions of the game cannot read format-3 saves.

Verification from the repository root:

```sh
/path/to/Godot --headless --path godot --script tests/milestone_test.gd
/path/to/Godot --headless --path godot --script tests/milestone_campaign.gd
# Export and serve the browser build, then start test Chrome on port 9231.
node godot/tests/milestone_browser.mjs
```

See `reports/milestone-systems.json`, `milestone-campaign.json` and `milestone-browser.json` for results. The campaign test uses normal construction, recruitment, paid upgrades/research/bounties, and autonomous heroes. Browser test setup uses the explicit `?test=1` bridge for controlled scenarios.
