# SOVEREIGN — Game Design & Technical Specification

**Version:** 0.1.0-draft
**Author:** Andriy Batutin (AiCapitalist)
**Last Updated:** 2026-09-17
**Target:** Steam Early Access
**Engine:** HTML5 Canvas (browser-native, desktop wrapper for Steam)

---

## 1. Project Overview

### 1.1 Elevator Pitch

Sovereign is a fantasy kingdom sim with **indirect control** — a modern reimagining of Majesty: The Fantasy Kingdom Sim (2000). The player rules a kingdom by building structures, setting bounties, and managing the economy. Heroes are autonomous agents with personalities, goals, and self-preservation instincts. The player cannot directly command them — only incentivize, equip, and pray.

**Tagline:** *A crown. A kingdom. A little chaos.*

### 1.2 Core Fantasy

You are a ruler, not a general. You create the conditions for success but cannot guarantee it. Your heroes have their own ideas about what's worth dying for. Your job is to make the right things worth dying for.

### 1.3 Genre & Positioning

- **Primary genre:** Real-time strategy / Kingdom management sim
- **Subgenre:** Indirect-control sim (heroes act autonomously)
- **Closest comparisons:** Majesty (2000), Majesty 2 (2009), Gold Gold Adventure Gold (2025)
- **Primary differentiator: The Journey System** — heroes live the Hero's Journey (Campbell/Jung monomyth). They arrive as uncertain newcomers, refuse the call, eventually commit, face ordeals, transform or break into shadow, and return changed. The player shapes these arcs through kingdom-building decisions, not direct commands. No other kingdom sim has character arcs. This is Sovereign's unique art style.
- **Secondary differentiators:** AI-powered journey narration; roguelite campaign structure
- **Target audience:** Strategy/sim players who remember Majesty; colony sim fans (Rimworld, Dwarf Fortress, Against the Storm); narrative-emergent-gameplay fans; players interested in AI-driven storytelling

### 1.4 Platform & Technology

- **Runtime:** HTML5 Canvas, JavaScript
- **Desktop wrapper:** Tauri (preferred for binary size) or Electron (fallback for compatibility)
- **Steam integration:** Steamworks SDK via `steamworks.js` or `greenworks`
- **Minimum Steam integration:** App initialization, achievements (optional for EA), cloud saves (optional for EA)
- **Current state:** Playable browser prototype at Cloud Run URL, ~40 minutes of core gameplay

---

## 2. Core Design Philosophy

### 2.1 The Fun Model

The core pleasure loop is: **decide → observe → react → learn → decide better.**

Unlike direct-control RTS (fun = execution skill) or pure city builders (fun = optimization), Sovereign's fun comes from **watching consequences unfold from decisions you made minutes ago** and learning the implicit language of indirect control.

### 2.2 Fun Generators (Ranked by Priority)

1. **Autonomous agent comedy/drama** — Heroes make decisions that are simultaneously logical (from their perspective) and absurd (from yours). A warrior going to the tavern instead of fighting the dragon is frustrating AND hilarious. Heroes must be wrong often enough to be funny, right often enough to be useful.

2. **Legible cause-and-effect chains** — The player must always be able to trace backwards: "I lost because I didn't build X, which meant hero Y couldn't do Z, which left opening W." Satisfying losses > random losses. If the player can articulate what they'd do differently, they'll replay. If they can't, they quit.

3. **Economy as control language** — Bounties, tax rates, building placement are the "verbs" the player speaks. Each hero class "hears" these verbs differently based on personality. Learning this language IS the core engagement loop.

4. **Escalating plate-spinning** — Early game is manageable. Mid-game introduces competing priorities (defense vs hero investment vs expansion). Late game should feel like barely-controlled chaos where earlier preparation pays off.

5. **Anecdote generation** — If players tell stories about what happened in their game to other people, you've won. This is downstream of good autonomous behavior + legible causality. Design for narrative emergence.

### 2.3 Anti-Patterns to Avoid

- **False indirect control:** If bounties always work and heroes always obey, you've made a regular RTS with extra steps. The friction IS the game.
- **Opaque failure:** Player loses and doesn't know why → instant uninstall. Every loss must be diagnosable.
- **Dead air:** If nothing interesting happens for 30+ seconds, the systems aren't generating enough situations. Target one meaningful decision every 15–30 seconds during active play.
- **Runaway economies:** Gold-only-goes-up = no tension. Gold-only-goes-down = punishing. The player's gold balance should oscillate between abundance and scarcity.
- **Hero interchangeability:** If all heroes behave the same, there's nothing to learn. Each class must have distinct behavioral patterns the player can learn and exploit.

---

## 3. Game Loop Architecture

### 3.1 Micro Loop (30-second cycle)

```
OBSERVE kingdom state (threats, hero status, economy)
    → DECIDE on action (place bounty, build structure, adjust economy)
    → WATCH heroes respond (accept/reject bounty, prioritize differently)
    → EVALUATE outcome (hero succeeds/fails/does something unexpected)
    → ADJUST strategy
```

### 3.2 Session Loop (20–40 minute scenario)

```
FOUNDING PHASE (minutes 0-5):
    Place initial buildings, recruit first heroes, establish economy
    → Low threat, learning the map, setting up infrastructure

GROWTH PHASE (minutes 5-15):
    Expand territory, upgrade buildings, heroes level up
    → Threats increase, competing resource demands emerge
    → First meaningful decisions about specialization

CRISIS PHASE (minutes 15-30):
    Major threats appear, multiple simultaneous problems
    → Economy is strained, hero losses matter
    → Player's earlier preparation is tested

RESOLUTION (minutes 25-40):
    Either the player overcomes the crisis through preparation + adaptation
    OR the kingdom falls and the player understands why
```

### 3.3 Meta Loop (Cross-Session Progression)

**Roguelite campaign structure:**

```
CAMPAIGN MAP: series of scenario nodes with branching paths
    → Each node is one SESSION LOOP (a "reign")
    → Completing a scenario unlocks:
        - New hero classes (persistent unlock)
        - New building types (persistent unlock)
        - Kingdom upgrades (persistent, affect starting conditions)
        - New scenario types / map modifiers
    → Failing a scenario:
        - Lose in-run progress
        - Keep meta-progression unlocks
        - Can retry or choose different path
```

This structure means:
- Each run is self-contained (20–40 minutes)
- Failure is expected and educational
- Content is gated behind progression (stretches existing systems)
- Players always feel forward momentum even on failure

---

## 4. Systems Design

### 4.1 Economy System

#### 4.1.1 Resources

| Resource | Source | Sink | Role |
|----------|--------|------|------|
| **Gold** | Taxes, hero loot, trade | Bounties, building, upgrades | Primary indirect control currency |
| **Reputation** | Completed bounties, hero survival | Hero recruitment cost | Determines which heroes show up |
| **Influence** | Building variety, kingdom size | Special abilities, edicts | Late-game control amplifier |

#### 4.1.2 Tax & Revenue Model

- **Tax rate** is player-adjustable (low / medium / high / emergency)
- Higher taxes → more gold income → lower hero happiness → heroes leave or refuse bounties
- Lower taxes → less gold → happier heroes → more willing to take risks
- **Marketplace buildings** generate passive income based on hero traffic
- **Heroes spend gold** at player-built shops (potions, equipment) — this gold recirculates to the treasury as tax

#### 4.1.3 Economy Health Indicators (Visible to Player)

- Treasury balance (absolute gold)
- Income/expense rate (gold per minute, net)
- Hero satisfaction index (aggregate mood)
- Threat pressure (incoming danger level)

The economy should create **tension between spending on safety vs spending on growth.** The player who over-invests in defense stagnates. The player who over-invests in expansion gets overwhelmed.

### 4.2 Hero System — The Journey Architecture

**CORE DIFFERENTIATOR: This is Sovereign's unique art style.**

Heroes are not static utility functions. Each hero lives a version of the Hero's Journey (Campbell/Jung monomyth) within the simulation. They arrive as uncertain newcomers, face calls to adventure, refuse, eventually commit, transform through ordeal, and return changed. The journey stage a hero is in determines their behavior more powerfully than any stat. This produces emergent narrative arcs — every hero playthrough tells a different story, and the player's kingdom-building decisions shape which stage each hero reaches.

No other kingdom sim has this. Majesty had flat stat agents. Rimworld has personality traits. Sovereign has character arcs.

#### 4.2.1 Jungian Archetypes (Early Access Scope: 6 archetypes)

Each hero class maps to a Jungian archetype that defines their journey pattern, their shadow (failure mode), and what drives them forward.

| Class | Jungian Archetype | Journey Drive | Shadow (Failure Mode) | Calling Bounty Type |
|-------|-------------------|---------------|----------------------|-------------------|
| **Warrior** | The Hero | Confront the greatest threat | Cowardice — broken by ordeal, becomes passive | Kill bounties on major threats |
| **Ranger** | The Explorer | Map the unknown, push into darkness | Rootlessness — mapped everything, leaves the kingdom | Explore bounties into fog of war |
| **Wizard** | The Sage | Seek forbidden knowledge and power | Hubris — overreaches, takes on things beyond capability | Retrieve bounties for magical artifacts |
| **Cleric** | The Caregiver | Protect and heal companions | Martyrdom — loses bonded companion, becomes self-destructive | Defend bounties protecting buildings/heroes |
| **Rogue** | The Trickster | Subvert the rules, find the clever path | Nihilism — bored, nothing left to exploit, turns destructive | Kill bounties on weakened targets; steal quests |
| **Barbarian** | The Rebel | Defy death, rage against order | Self-destruction — rage consumes, takes suicidal bounties | Any combat bounty, the more dangerous the better |

#### Current first-level direction: Persona versus Shadow

The playable settlement uses **Persona ↔ Shadow dynamics**, with the journey retained as context rather than a linear upgrade ladder. A crushing defeat below 20% health can interrupt any phase, including Mastery. Warriors stop fighting, Rangers stop exploring, Wizards withhold spells, and Thieves stop their guild work. They withdraw toward the castle; ordinary healing does not restore purpose. The king must fund a named hero’s recovery at a guild or Temple, followed by safe practice there. Experience and the interrupted calling survive; relapse remains possible.

Refusing and Shadow heroes spend personal gold at an **Inn** or **Brothel** near the castle. Available Thieves steal from distracted patrons, keeping half and depositing half in their own guild bank. The king can confiscate an operating guild bank, with a kingdom-wide 120-second cooldown. Venue fees become taxes delivered by collectors. Spending and theft transfer existing money; leisure does not cure Shadow.

Heroes enter guilds, Temples, Inns and Brothels to shelter and rest. Occupants disappear from outdoor combat and emerge when ready; losing the building releases them. Animated lights and an occupancy pennant show when someone is inside, while building panels and the all-hero overview expose names, locations and activity. The shadow venues use dark architecture with animated courtesans, drinking and street brawling. See [indoor rules and art](godot/reports/LEISURE.md).

The live **Hero Journeys** menu foregrounds Persona/Shadow, interrupted purpose, purse, location and the king’s next action for every hero. It links to **Guild banks & leisure**. See [implemented rules and validation](godot/reports/JOURNEYS.md) for current values and migration. This direction supersedes the passive Shadow recovery triggers and mandatory linear progression described in the original design below; the broader class and social-system proposals remain future scope.

#### 4.2.2 The Journey State Machine

Every hero progresses through journey stages. Stages modify a base personality vector (see 4.2.4) via multipliers. The player cannot directly advance a hero's journey — they can only create the conditions that enable or block transitions.

```
JOURNEY STAGES:

┌──────────────┐
│ 1. ORDINARY  │ Hero arrives. Cautious, unremarkable. Hangs around
│    WORLD     │ tavern, buys basic gear, takes only easy bounties.
│              │ Player may think: "this hero is useless."
└──────┬───────┘
       │ TRIGGER: A "calling bounty" appears matching hero's archetype
       ▼
┌──────────────┐
│ 2. THE CALL  │ Hero NOTICES the calling bounty (visible UI cue:
│              │ hero looks at bounty board, exclamation mark, pauses).
│              │ Does not accept yet. Internal conflict begins.
└──────┬───────┘
       │ TIME PASSES (hero deliberates 30-90 seconds game time)
       ▼
┌──────────────┐
│ 3. REFUSAL   │ Hero approaches bounty board, considers, walks away.
│              │ Returns to tavern/comfort zone. May repeat this cycle
│              │ 1-3 times. Player's job: create conditions that tip
│              │ the balance (build temple, hire allies, raise bounty).
└──────┬───────┘
       │ TRIGGER: conditions met (see 4.2.3 Transition Triggers)
       ▼
┌──────────────┐
│ 4. THRESHOLD │ Hero ACCEPTS the calling bounty. Behavior shifts:
│   CROSSING   │ increased bravery, commitment. Won't turn back easily.
│              │ Actively seeks allies for the quest.
└──────┬───────┘
       │ Hero journeys toward bounty target
       ▼
┌──────────────┐
│ 5. TESTS &   │ Hero encounters obstacles en route. If other heroes
│    ALLIES    │ are on same bounty, they form a party. BONDS form
│              │ between heroes who fight together (persistent memory).
│              │ Hero gains experience, may level up mid-journey.
└──────┬───────┘
       │ Hero reaches the bounty target
       ▼
┌──────────────┐
│ 6. THE       │ Hero confronts the big threat. Highest stakes moment.
│    ORDEAL    │ Two outcomes:
│              │   SUCCESS → proceed to REWARD
│              │   FAILURE (survives) → regress to SHADOW
│              │   DEATH → resonates with witnesses (see 4.2.5)
└──────┬───────┘
       │                          │
       ▼ (success)                ▼ (failure, survived)
┌──────────────┐          ┌──────────────┐
│ 7. REWARD &  │          │ 7b. SHADOW   │
│    RETURN    │          │              │
│ Hero returns │          │ Hero regresses│
│ transformed. │          │ into archetype│
│ More powerful │          │ shadow mode.  │
│ but also more│          │ Behavior      │
│ wilful and   │          │ becomes       │
│ independent. │          │ dysfunctional │
│              │          │ until healed. │
└──────┬───────┘          └──────┬───────┘
       │                          │
       ▼                          │ TRIGGER: healing event
┌──────────────┐                  │ (see 4.2.3)
│ 8. MASTERY   │                  │
│ (optional)   │◄─────────────────┘
│ Hero at peak.│
│ May begin a  │
│ NEW journey  │
│ cycle at     │
│ higher stakes│
└──────────────┘
```

#### 4.2.3 Journey Transition Triggers

Transitions are NOT automatic. The player must create the conditions. This is the core game mechanic — the player's kingdom-building decisions shape hero arcs.

**REFUSAL → THRESHOLD CROSSING** (hero commits to the quest):
| Condition | Effect | Player Action Required |
|-----------|--------|----------------------|
| Allies available | Hero sees other heroes nearby willing to join | Build matching guild, post overlapping bounties |
| Safety net exists | Healing temple or potion shop within range | Build temple or potion shop near the threat |
| Bounty premium | Bounty gold raised above hero's refusal threshold | Spend more gold on the bounty |
| Reputation high | Kingdom reputation makes hero proud to serve | Complete other bounties, maintain hero satisfaction |
| Time pressure | Threat escalation makes inaction feel worse than risk | Let threat approach — urgency overrides fear |
| Bond call | A bonded companion already accepted the bounty | Let bonds form through earlier shared quests |

**ORDEAL → SHADOW** (hero fails and breaks):
- Hero health drops below 20% during ordeal and they flee
- Bonded companion dies during the ordeal (Caregiver archetype)
- Bounty target escapes or is completed by someone else (Hero archetype — denied their moment)
- Hero uses all resources and returns with nothing (Sage archetype)

**SHADOW → RECOVERY** (hero heals from failure):
| Archetype | Shadow Behavior | Recovery Trigger |
|-----------|----------------|-----------------|
| Hero (Warrior) | Refuses all combat bounties, stays near palace | Completes 2-3 small/easy bounties successfully → confidence rebuilds |
| Explorer (Ranger) | Paces walls, won't leave safe zone | Player opens NEW unexplored region (new map area) → curiosity reignites |
| Sage (Wizard) | Hoards gold, refuses to use spells | Player builds library or research building → intellectual drive returns |
| Caregiver (Cleric) | Reckless with own life, doesn't heal others | New hero arrives that Cleric bonds with → protective instinct returns |
| Trickster (Rogue) | Steals from player treasury, sabotages | Player posts a "trick" bounty (unusual/creative objective) → engagement returns |
| Rebel (Barbarian) | Takes suicide bounties, ignores self-preservation | Survives a near-death fight (randomly) → rage becomes purposeful again |

**REWARD → MASTERY / NEW CYCLE:**
- After returning transformed, hero enters a cooldown (rest, spend gold, socialize)
- After cooldown, hero may begin a new journey cycle at higher stakes
- Each completed cycle makes the hero MORE POWERFUL but LESS CONTROLLABLE
- Mastery heroes have strong opinions — they may reject bounties they consider "beneath them" or take on challenges without a bounty because ego demands it
- The player's BEST heroes are their most UNCONTROLLABLE ones — this is the central tension

#### 4.2.4 Hero Data Model

Each hero combines a base personality vector (set at spawn, varies within archetype range) with journey stage modifiers that override the base.

```
Hero = {
    // Identity
    name:           string,
    class:          enum (WARRIOR, RANGER, WIZARD, CLERIC, ROGUE, BARBARIAN),
    archetype:      enum (HERO, EXPLORER, SAGE, CAREGIVER, TRICKSTER, REBEL),

    // Base personality (set at spawn, varies within archetype range)
    // These are the SEED — journey stage MULTIPLIES them
    base_personality: {
        bravery:          float [0.0 - 1.0],
        greed:            float [0.0 - 1.0],
        loyalty:          float [0.0 - 1.0],
        sociability:      float [0.0 - 1.0],
        self_preservation: float [0.0 - 1.0],
    },

    // Journey state (the core system)
    journey: {
        stage:            enum (ORDINARY_WORLD, CALL, REFUSAL, THRESHOLD,
                                TESTS_ALLIES, ORDEAL, REWARD_RETURN,
                                SHADOW, MASTERY),
        cycles_completed: int,        // how many full journeys
        calling_bounty:   BountyId?,  // the bounty that called them
        shadow_type:      enum?,      // which shadow manifestation (if in SHADOW)
        stage_entered_at: tick,       // when they entered current stage
        refusal_count:    int,        // times they've approached and walked away
    },

    // Memory (feeds into journey transitions)
    memory: {
        events:       list[JourneyEvent],  // last 10 significant events
        bonds:        list[HeroId],        // heroes they've fought alongside
        traumas:      list[Location],      // places associated with failure
        victories:    list[Location],      // places associated with triumph
        witnessed_deaths: list[HeroId],    // companions they saw die
    },

    // Standard RPG state
    stats: {
        health:       int,
        max_health:   int,
        level:        int (1-10 for EA),
        xp:           int,
        equipment:    list[Item],
        gold:         int,
        satisfaction: float [0.0 - 1.0],
    },

    current_goal:   enum (IDLE, BOUNTY, SHOPPING, RESTING, FLEEING,
                          EXPLORING, DELIBERATING, SHADOW_BEHAVIOR),
}
```

#### 4.2.5 Effective Personality Calculation

The hero's actual behavior at any moment is their base personality modified by their journey stage. This is the key mechanic — the same hero behaves differently at minute 5 vs minute 20.

```
JOURNEY STAGE MODIFIERS (multiply base personality):

ORDINARY_WORLD:
    bravery:          × 0.5   // cautious newcomer
    greed:            × 1.2   // motivated by gold (still mercenary)
    loyalty:          × 0.3   // no attachment to kingdom yet
    sociability:      × 0.8   // will group but won't seek it
    self_preservation: × 1.5  // very careful with their life
    → Result: hero hangs around tavern, takes only safe bounties

CALL:
    bravery:          × 0.7   // stirring but uncertain
    greed:            × 0.8   // gold matters less, something bigger calls
    loyalty:          × 0.5   // considering commitment
    sociability:      × 1.0   // looking for allies
    self_preservation: × 1.3  // still cautious
    → Result: hero notices calling bounty, visibly deliberates

REFUSAL:
    bravery:          × 0.4   // fear wins temporarily
    greed:            × 1.0   // retreats to material comfort
    loyalty:          × 0.4   // pulls away from obligation
    sociability:      × 1.2   // seeks comfort in company
    self_preservation: × 1.8  // maximum caution
    → Result: hero approaches bounty board and walks away, drinks at tavern

THRESHOLD:
    bravery:          × 1.3   // committed, past the point of no return
    greed:            × 0.5   // not about gold anymore
    loyalty:          × 1.2   // pledged to the cause
    sociability:      × 1.5   // actively seeks party members
    self_preservation: × 0.7  // willing to risk more
    → Result: hero accepts bounty, recruits allies, marches toward target

TESTS_ALLIES:
    bravery:          × 1.2   // tested and holding
    greed:            × 0.4   // focused on the mission
    loyalty:          × 1.5   // bonds forming with companions
    sociability:      × 1.8   // peak team behavior
    self_preservation: × 0.8  // accepts danger for companions
    → Result: hero fights alongside allies, bonds form, gains XP

ORDEAL:
    bravery:          × 1.5   // all-in, peak courage
    greed:            × 0.2   // irrelevant in the moment
    loyalty:          × 1.5   // fighting for companions and kingdom
    sociability:      × 1.2   // relies on party
    self_preservation: × 0.5  // willing to die for this
    → Result: hero engages boss/main threat with full commitment

REWARD_RETURN:
    bravery:          × 1.4   // confident, proven
    greed:            × 1.5   // wants recognition and reward
    loyalty:          × 1.0   // served the kingdom, expects reciprocity
    sociability:      × 1.3   // wants to celebrate
    self_preservation: × 0.9  // knows they can survive
    → Result: hero returns, spends gold, celebrates, is more effective

SHADOW:
    (varies by archetype — see SHADOW BEHAVIORS table in 4.2.3)
    General pattern: one trait goes extreme, others collapse
    Hero_Shadow:      bravery × 0.1, self_preservation × 2.0
    Explorer_Shadow:  bravery × 0.3, loyalty × 0.1 (won't leave safe zone)
    Sage_Shadow:      greed × 2.0, sociability × 0.2 (hoards, isolates)
    Caregiver_Shadow: self_preservation × 0.1, sociability × 0.3 (death wish)
    Trickster_Shadow: loyalty × -0.5 (actively works against player)
    Rebel_Shadow:     self_preservation × 0.0, bravery × 2.0 (suicidal)

MASTERY:
    bravery:          × 1.6   // proven hero, deep courage
    greed:            × 0.8   // above petty concerns
    loyalty:          × 0.6   // serves own sense of purpose, not player
    sociability:      × 1.0   // selective about companions
    self_preservation: × 0.6  // fears little
    → Result: powerful but independent. Takes big bounties unprompted.
             May REFUSE bounties they consider "beneath them."
             The player's BEST heroes are their LEAST CONTROLLABLE.
```

#### 4.2.6 Decision Loop (Journey-Aware)

```
hero_decide(hero, game_state):

    effective = compute_effective_personality(hero)

    // JOURNEY-SPECIFIC BEHAVIOR (overrides standard loop)
    if hero.journey.stage == CALL:
        if calling_bounty_visible(hero, game_state):
            show_deliberation_animation(hero)
            return DELIBERATING

    if hero.journey.stage == REFUSAL:
        if ticks_since(hero.journey.stage_entered_at) % REFUSAL_CYCLE == 0:
            approach_and_reject_bounty_board(hero)  // visible to player!
        if check_threshold_conditions(hero, game_state):
            transition(hero, THRESHOLD)
            accept_bounty(hero, hero.journey.calling_bounty)
            return BOUNTY
        return IDLE  // back to tavern

    if hero.journey.stage == SHADOW:
        return shadow_behavior(hero)  // archetype-specific dysfunction

    // STANDARD DECISION LOOP (modified by effective personality)
    1. survival_check:
        if hero.health < hero.stats.max_health × 0.2 × effective.self_preservation:
            return FLEE

    2. needs_check:
        if hero.satisfaction < 0.3:
            return REST or SHOP

    3. bounty_evaluation:
        for bounty in active_bounties(game_state):
            attractiveness = evaluate_bounty(hero, bounty, effective)
            // Journey stage affects threshold:
            // ORDINARY_WORLD heroes need high attractiveness
            // MASTERY heroes only take bounties above their "dignity threshold"
            if attractiveness > stage_threshold(hero.journey.stage):
                accept_bounty(hero, bounty)
                return BOUNTY

    4. personality_driven:
        // Explorer archetype: wander toward fog of war
        // Trickster archetype: look for exploitable situations
        // Caregiver archetype: follow bonded companions
        return archetype_idle_behavior(hero, effective)

    5. default:
        return IDLE  // tavern, train, wander
```

#### 4.2.7 Bond System

Heroes who go through TESTS_ALLIES together form bonds. Bonds are persistent within a run and have mechanical effects:

```
Bond = {
    hero_a: HeroId,
    hero_b: HeroId,
    formed_at: tick,
    shared_events: list[Event],  // battles survived together
    strength: float [0.0 - 1.0], // increases with shared experiences
}

BOND EFFECTS:
- Bonded heroes seek each other when forming parties (+sociability toward each other)
- If a bonded companion takes a bounty, the hero is more likely to join (bypasses some refusal)
- If a bonded companion DIES, grief event triggers:
    → Caregiver archetype: may enter SHADOW
    → Hero archetype: rage bonus, then sadness
    → All archetypes: trauma memory at death location
- Bonds visible to player (UI indicator: heroes standing together, shared icon)
- Bonds are the Caregiver's primary journey driver — they journey FOR their bonded companions
```

#### 4.2.8 Death Resonance

When a hero dies, it's not just a stat removal. It ripples through the system:

```
on_hero_death(dead_hero, witnesses, game_state):
    for hero in witnesses:
        hero.memory.witnessed_deaths.append(dead_hero.id)
        hero.memory.traumas.append(dead_hero.death_location)

        // Bond death
        if dead_hero.id in hero.memory.bonds:
            hero.satisfaction -= 0.3
            if hero.archetype == CAREGIVER:
                transition(hero, SHADOW)  // Caregiver's breaking point
            elif hero.journey.stage == ORDEAL:
                // Companion death during ordeal intensifies the moment
                hero.base_personality.bravery += 0.1  // permanent mark

        // Journey impact
        if hero.journey.stage in [ORDINARY_WORLD, CALL, REFUSAL]:
            hero.journey.refusal_count += 1  // death makes them more cautious
        elif hero.journey.stage in [THRESHOLD, TESTS_ALLIES]:
            // Already committed — death of ally makes them MORE determined
            effective_bravery *= 1.2  // temporary rage/determination boost

    // Kingdom-wide effect
    game_state.kingdom.reputation -= reputation_value(dead_hero)
    broadcast_event(HERO_DEATH, dead_hero)  // narrator can comment
```

#### 4.2.9 The Central Design Tension

The journey system creates the game's core dilemma for the player:

**Your best heroes are your least controllable.**

- A MASTERY warrior won't take bounties "beneath them" (weak monsters)
- A MASTERY wizard may pursue dangerous knowledge without a bounty
- A MASTERY rogue may steal from the treasury if bored
- A MASTERY ranger may simply leave to explore beyond the map

The player must constantly balance:
- **Cultivating heroes** (enabling their journey → they become powerful)
- **Managing heroes** (keeping powerful heroes aligned with kingdom needs)
- **Replacing heroes** (accepting that transformed heroes may leave or die, and new ones must be grown)

This is the Majesty fantasy fully realized: **you are a ruler, not a general.** Your subjects have their own lives, their own arcs, their own dignity. You can create conditions for heroism, but you cannot command it.

### 4.3 Building System

#### 4.3.1 Building Categories (Early Access Scope: 12–15 building types)

**Recruitment Buildings** (spawn hero types):
| Building | Heroes | Cost | Upgrade |
|----------|--------|------|---------|
| Warrior Guild | Warriors | Low | Improves warrior equipment |
| Rangers' Lodge | Rangers | Low | Extends ranger sight range |
| Wizard Tower | Wizards | High | Unlocks advanced spells |
| Temple | Clerics | Medium | Healing aura radius |
| Thieves' Den | Rogues | Medium | Increases rogue stealth |
| Barbarian Camp | Barbarians | Low | Increases barbarian spawn rate |

**Economy Buildings:**
| Building | Function | Notes |
|----------|----------|-------|
| Marketplace | Heroes buy/sell items; generates tax revenue | Core economy building |
| Blacksmith | Heroes buy/upgrade weapons | Increases hero combat effectiveness |
| Potion Shop | Heroes buy healing potions | Increases hero survival rate |
| Inn / Tavern | Heroes rest, restore satisfaction | Prevents heroes from leaving |
| Tax Collector | Increases tax rate efficiency | Reduces gold leakage |

**Defense Buildings:**
| Building | Function | Notes |
|----------|----------|-------|
| Guard Tower | Automated ranged defense | Passive protection, doesn't need heroes |
| Wall Segment | Blocks enemy pathing | Funnels threats |
| Palace | Player's HQ, lose this = lose scenario | Upgradeable, grants global bonuses |

#### 4.3.2 Building Placement Rules

- Buildings have influence radius (visible to player)
- Overlapping influence from complementary buildings creates synergy bonuses (e.g., marketplace near blacksmith = heroes equip faster)
- Building placement IS strategic decision-making — where you build determines hero patrol paths and response times
- Buildings can be destroyed by enemies if undefended

### 4.4 Monster / Threat System

#### 4.4.1 Threat Categories (Early Access: 4 factions)

| Faction | Behavior | Threat Type | Countered By |
|---------|----------|-------------|-------------|
| **Undead** | Slow, numerous, attack at night | Attrition / swarm | Clerics (bonus damage), guard towers |
| **Beasts** | Fast, attack supply lines | Economy disruption | Rangers (tracking), warriors |
| **Dark Cult** | Intelligent, target specific buildings | Surgical strikes | Rogues (detection), wizards |
| **Dragon** (late game) | Single overwhelming threat, area denial | Boss encounter | Full party coordination, requires preparation |

#### 4.4.2 Threat Escalation Model

```
threat_level = base_threat + (time_elapsed × escalation_rate) + (kingdom_value × aggression_modifier)

- base_threat: scenario-defined starting danger
- escalation_rate: increases over time, forcing player to act
- kingdom_value: richer kingdoms attract bigger threats
- aggression_modifier: per-faction, varies by scenario

KEY DESIGN RULE: threat must always slightly outpace the player's
comfort level. If the player feels safe, escalation is too slow.
If the player feels hopeless, escalation is too fast.
```

#### 4.4.3 Spawn System

- Monster lairs / dungeons exist on the map at scenario start
- Lairs spawn monsters at intervals; destroying the lair stops spawns
- Some lairs are hidden — require ranger exploration to reveal
- Destroying lairs rewards gold and may unlock new map regions

### 4.5 Bounty / Indirect Control System

#### 4.5.1 Bounty Types

| Bounty Type | Target | Effect | Typical Cost |
|-------------|--------|--------|-------------|
| **Kill** | Specific enemy or lair | Heroes attack target | Medium-High |
| **Explore** | Fog-of-war region | Heroes reveal map area | Low |
| **Defend** | Building or area | Heroes patrol zone | Medium (recurring) |
| **Retrieve** | Item or resource | Heroes fetch something from dangerous area | High |
| **Escort** | NPC or caravan | Heroes protect moving target | Medium |

#### 4.5.2 Bounty Acceptance Logic

Bounty evaluation uses the journey-modified effective personality (Section 4.2.5), not raw base stats. This means the same hero evaluates the same bounty differently depending on their journey stage.

```
should_accept(hero, bounty):
    effective = compute_effective_personality(hero)  // journey-modified

    // JOURNEY OVERRIDE: calling bounty handling
    if hero.journey.stage == CALL and bounty == hero.journey.calling_bounty:
        return false  // not yet — hero is deliberating (see REFUSAL stage)
    if hero.journey.stage == REFUSAL and bounty == hero.journey.calling_bounty:
        return check_threshold_conditions(hero, game_state)  // only if conditions met
    if hero.journey.stage == MASTERY and bounty.difficulty < hero.dignity_threshold:
        return false  // "beneath me" — mastery heroes reject easy work

    // STANDARD EVALUATION (with journey-modified personality)
    perceived_danger = estimate_danger(bounty.target, hero.memory)
    perceived_reward = bounty.gold × effective.greed
    class_fit = ARCHETYPE_AFFINITY[hero.archetype][bounty.type]
    social_factor = count_allies_on_bounty(bounty) × effective.sociability
    bond_factor = bonded_companion_on_bounty(hero, bounty) × 2.0
    memory_factor = check_trauma_penalty(hero, bounty.location)

    score = (perceived_reward + class_fit + social_factor + bond_factor)
            - (perceived_danger × effective.self_preservation)
            - memory_factor

    return score > stage_threshold(hero.journey.stage)
    // stage_threshold: high for ORDINARY_WORLD, low for THRESHOLD/MASTERY
```

#### 4.5.3 Player Communication

The player should NEVER see the math. Instead, the UI communicates through behavioral cues:
- Hero approaches bounty board → considers → walks away = "bounty not attractive enough"
- Hero takes bounty eagerly = "good match"
- Hero takes bounty hesitantly (slow walk) = "barely worth it"
- Multiple heroes competing for same bounty = "over-rewarded, save gold"
- No heroes approach = "raise the bounty or build the right guild"

---

## 5. Novel Features

### 5.0 Primary Differentiator: The Journey System

**The Journey System (Section 4.2) IS the novel feature.** It is not a bolt-on — it is the game's unique art style.

No other kingdom sim has hero arcs. Majesty had flat stat agents. Rimworld has personality traits but not structured narrative progression. Dwarf Fortress has emotional complexity but not mythic structure. Sovereign is the first indirect-control sim where heroes live the Hero's Journey, and the player's kingdom-building decisions shape which stage each hero reaches.

The AI/LLM features below exist to SERVE the journey system — to make the arcs legible, narratable, and memorable. They are not the differentiator. The journey is.

### 5.1 Design-Time LLM Generation (Content Pipeline)

Use LLMs during development to generate journey-aware content, then bake it into the game as static data. The game works fully offline with no runtime API dependency.

**Generate with LLMs, keyed to journey stages and archetypes:**
- Hero names and backstory blurbs (per archetype)
- **Journey narration lines:** text for each (archetype × stage × transition) combination
  - "Aldric the warrior approaches the bounty board... and turns away." (REFUSAL)
  - "Something has changed in Mirela. She walks toward the eastern dungeon with purpose." (THRESHOLD)
  - "Korvin returns from the dragon's lair a different man. He no longer flinches at shadows." (REWARD_RETURN)
  - "Serena stares at the place where Aldric fell. She will not heal anyone today." (SHADOW — Caregiver)
- **Bond narration:** text for bond formation, bond loss, grief events
- Event descriptions and scenario briefings
- Item descriptions and lore text

**Tooling:** Content generation pipeline that takes `(archetype, journey_stage, event_type, personality_bucket)` and produces batches of text variants. Run on local GPU (RTX 3090) or via API during dev. Export as JSON data files.

**Volume target:** ~1,500 narration lines for EA (6 archetypes × 9 journey stages × ~28 situation variants). This covers the common cases with enough variety that players don't see repeats within a session.

### 5.2 Runtime AI Feature: The Royal Advisor (Optional, Online)

A single LLM-powered feature, journey-aware:
- Clearly marked as AI-powered in the UI
- Optional — game is fully playable without it
- Narrates hero journeys and provides strategic guidance

**Implementation:**

```
ROYAL ADVISOR:
    Input: current game state snapshot (JSON)
        - kingdom stats (gold, buildings, heroes, threats)
        - hero journey states (who is in CALL, REFUSAL, SHADOW, etc.)
        - recent journey transitions (who just crossed threshold, who entered shadow)
        - bond graph (who is bonded to whom)
        - recent events (last 5 significant events)
        - player's recent actions
    Output: 1-3 sentences of contextual, journey-aware commentary

    Trigger: on journey stage transitions OR every 60-90 seconds

    Tone: medieval advisor who understands the mythic weight of what's happening

    JOURNEY-AWARE EXAMPLES:

        [REFUSAL stage]
        "Your Majesty, Aldric has approached the bounty board three times now
         and turned away each time. The eastern dungeon haunts him still. He
         needs to see that he won't face it alone — another sword at his side
         might tip his courage."

        [THRESHOLD crossing]
        "Mirela has taken the bounty. Watch her stride — that is not a woman
         walking toward gold. Something has called her, and she has answered."

        [SHADOW entry — Caregiver]
        "Serena has not healed a soul since Korvin fell. She walks the walls
         at night. She is not looking for enemies, Your Majesty — she is
         looking for a reason to stay."

        [MASTERY — hero refusing bounties]
        "Theron considers your bounty on the river goblins and... laughs.
         A man who slew the dragon does not chase goblins. Perhaps a worthier
         challenge would rouse him, or perhaps he serves his own legend now."

    API: Anthropic Messages API (claude-sonnet-4-6)
    System prompt includes: archetype descriptions, journey stage definitions,
        current hero journey states, bond graph
    Latency budget: <3 seconds (advisory, not blocking gameplay)
    Cost management: rate-limit to 1 call per 60 seconds max
    Fallback: if API unavailable, use pre-generated journey narration from
              the baked content pool (Section 5.1)
```

### 5.3 Journey Narration System (Hybrid)

Every journey stage transition and notable hero decision surfaces a short narration line. This is the primary mechanism for making the journey system LEGIBLE to the player.

**Trigger events that generate narration:**
- Hero enters CALL (notices calling bounty)
- Hero enters REFUSAL (approaches board and walks away)
- Hero crosses THRESHOLD (commits to quest)
- Bond forms between heroes (shared combat survival)
- Hero enters ORDEAL (engages boss/main threat)
- Hero completes journey (REWARD_RETURN)
- Hero enters SHADOW (fails and breaks)
- Hero recovers from SHADOW
- Hero reaches MASTERY
- Bonded companion dies
- MASTERY hero refuses a bounty

**Offline mode (default):** Pull from pre-generated text bank, matched on `(archetype, journey_stage, event_type)`. The 1,500-line bank from Section 5.1 covers these.

**Online mode (optional):** Generate contextual narration via LLM that references the specific hero name, their history, their bonds, and the exact situation. Cache generated lines for reuse across similar situations.

**UI presentation:** Narration lines appear as floating text near the hero or in a scrolling event log panel. Short, evocative, never interrupting gameplay. The player should feel like they're reading the story of their kingdom unfolding.

---

## 6. Content Scope — Early Access Launch

### 6.1 Minimum Viable Content

| Category | EA Launch Target | Full Release Target |
|----------|-----------------|-------------------|
| Hero classes | 6 | 10–12 |
| Building types | 12–15 | 25–30 |
| Monster factions | 4 | 6–8 |
| Scenarios/maps | 5–8 | 15–20 |
| Difficulty levels | 3 | 3 + custom modifiers |
| Hero level cap | 10 | 20 |
| Meta-progression unlocks | 8–12 | 25–30 |
| Gameplay per run | 20–40 minutes | 20–60 minutes |
| Total playtime to see most content | 5–8 hours | 20–40 hours |

### 6.2 Scenario Design (EA: 5–8 scenarios)

Each scenario is a distinct map + starting conditions + win/loss condition + unique twist.

| # | Name | Twist | Teaches |
|---|------|-------|---------|
| 1 | **The First Settlement** | Tutorial-lite. Low threats, generous economy. | Core building + bounty mechanics |
| 2 | **Rat King's Domain** | Sewer spawns constantly. Must find and destroy hidden lair. | Exploration bounties, ranger utility |
| 3 | **The Greedy Wizard** | Wizard NPCs demand high pay and steal treasury gold. | Economy management, tax balancing |
| 4 | **Night Siege** | Undead attack every night, escalating. Daytime is safe for building. | Defense building, day/night cycle strategy |
| 5 | **The Dragon Approaches** | Dragon arrives at minute 25. Everything before is preparation. | Long-term planning, hero leveling, full party coordination |
| 6 | **Rival Kingdom** | Competing AI kingdom on same map. Race to control resources. | Expansion vs defense tradeoff |
| 7 | **Cursed Gold** | Gold income is high but heroes get cursed the more gold they carry. | Risk management, alternative economy strategies |
| 8 | **The Exodus** | Heroes leave at increased rate. Must maintain satisfaction while fighting threats. | Hero satisfaction management, tavern/temple investment |

### 6.3 Procedural Elements

Even within hand-crafted scenarios, randomize:
- Monster lair placement (within zones)
- Hero personality vectors (within class ranges)
- Hero names and backstory text (from pre-generated pool)
- Resource node locations
- Event timing (within windows)

This ensures scenario replays feel different even on the same map.

### 6.4 Roguelite Campaign Structure (EA)

```
CAMPAIGN MAP (EA version):
    3 acts, each with 2-3 scenario nodes
    Act 1: introductory scenarios (The First Settlement, Rat King)
    Act 2: intermediate (Night Siege, The Greedy Wizard, Rival Kingdom)
    Act 3: climactic (The Dragon Approaches)

    Between scenarios:
        - Choose next scenario from 2 options (branching path)
        - Spend meta-currency to unlock hero classes / building types
        - Choose a "kingdom edict" modifier for next run (+gold/-defense, etc.)

    Meta-progression persists across campaign resets
    Completing the campaign unlocks harder modifiers for replayability
```

---

## 7. Technical Architecture

### 7.1 Runtime Stack

```
┌─────────────────────────────────────────┐
│           Desktop Wrapper (Tauri)         │
│  ┌─────────────────────────────────────┐ │
│  │         HTML5 Canvas Renderer        │ │
│  │  ┌──────────┐  ┌─────────────────┐  │ │
│  │  │ Game Loop │  │   UI Overlay    │  │ │
│  │  │ (JS)     │  │   (DOM/CSS)     │  │ │
│  │  └────┬─────┘  └────────┬────────┘  │ │
│  │       │                  │           │ │
│  │  ┌────┴──────────────────┴────────┐  │ │
│  │  │        Game State Manager       │  │ │
│  │  │  ┌──────┐ ┌──────┐ ┌────────┐  │  │ │
│  │  │  │Heroes│ │Econ  │ │Threats │  │  │ │
│  │  │  │System│ │Engine│ │Manager │  │  │ │
│  │  │  └──────┘ └──────┘ └────────┘  │  │ │
│  │  └────────────────────────────────┘  │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │      Steamworks Bridge (optional)    │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │   LLM API Client (optional, async)   │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 7.2 Game Loop

```javascript
// Target: 60 FPS render, 10 TPS simulation
const SIMULATION_TICK_MS = 100; // 10 ticks per second
const RENDER_TARGET_MS = 16.67; // 60 fps

gameLoop() {
    const now = performance.now();

    // Simulation update (fixed timestep)
    while (accumulatedTime >= SIMULATION_TICK_MS) {
        updateHeroDecisions();    // hero AI evaluation
        updateEconomy();           // gold flows, tax collection
        updateThreats();           // monster spawning, movement
        updateBounties();          // bounty status, expiration
        updateBuildings();         // construction progress, effects
        updateCombat();            // damage resolution
        updateEvents();            // trigger scenario events
        collectAnalytics();        // telemetry snapshot
        accumulatedTime -= SIMULATION_TICK_MS;
        tickCount++;
    }

    // Render (variable timestep, interpolated)
    render(interpolation);
    requestAnimationFrame(gameLoop);
}
```

### 7.3 Save System

```
SAVE STATE = {
    scenario_id: string,
    tick_count: int,
    rng_seed: int,              // for deterministic replay
    kingdom: {
        gold: int,
        reputation: float,
        influence: float,
        tax_rate: enum,
        buildings: Building[],
    },
    heroes: Hero[],              // full state including memory
    threats: Threat[],
    bounties: Bounty[],
    map_state: {
        revealed_tiles: Set<TileId>,
        destroyed_lairs: Set<LairId>,
    },
    meta_progression: {          // persists across runs
        unlocked_classes: Set<ClassName>,
        unlocked_buildings: Set<BuildingName>,
        campaign_progress: CampaignState,
        total_runs: int,
    },
    analytics: SessionAnalytics,  // for fun measurement
}
```

### 7.4 File Structure

```
sovereign/
├── src/
│   ├── core/
│   │   ├── game-loop.js
│   │   ├── state-manager.js
│   │   ├── save-system.js
│   │   └── rng.js                 // seeded PRNG for determinism
│   ├── systems/
│   │   ├── hero-system.js         // hero AI, decisions, memory
│   │   ├── economy-system.js      // gold flows, taxes, pricing
│   │   ├── threat-system.js       // monster spawning, behavior
│   │   ├── bounty-system.js       // bounty creation, evaluation
│   │   ├── building-system.js     // construction, effects, synergy
│   │   ├── combat-system.js       // damage, death, loot
│   │   └── event-system.js        // scenario triggers, scripted events
│   ├── journey/
│   │   ├── journey-machine.js     // journey state machine (core differentiator)
│   │   ├── archetypes.js          // Jungian archetype definitions & shadow behaviors
│   │   ├── transitions.js         // transition trigger evaluation
│   │   ├── bonds.js               // hero bond formation, grief, companion tracking
│   │   ├── effective-personality.js // journey-stage × base-personality multipliers
│   │   ├── death-resonance.js     // ripple effects of hero death
│   │   └── narration.js           // journey narration (baked text + optional LLM)
│   ├── ai/
│   │   ├── hero-brain.js          // decision tree per hero (journey-aware)
│   │   ├── personality.js         // base personality vector math
│   │   ├── memory.js              // hero event memory (traumas, victories, bonds)
│   │   └── advisor-client.js      // Royal Advisor LLM API client
│   ├── content/
│   │   ├── scenarios/             // scenario definitions (JSON)
│   │   ├── hero-data/             // class definitions, name pools, dialogue
│   │   ├── building-data/         // building stats, costs, effects
│   │   ├── monster-data/          // faction definitions, spawn tables
│   │   └── text/                  // flavor text, event descriptions
│   ├── rendering/
│   │   ├── canvas-renderer.js
│   │   ├── ui-overlay.js          // DOM-based UI layer
│   │   ├── camera.js
│   │   ├── sprites.js
│   │   └── particles.js
│   ├── analytics/
│   │   ├── telemetry.js           // in-game metrics collection
│   │   ├── session-recorder.js    // action log for playtest analysis
│   │   └── fun-metrics.js         // derived fun indicators
│   └── platform/
│       ├── steam-bridge.js        // Steamworks integration
│       └── save-cloud.js          // Steam cloud save adapter
├── data/
│   ├── generated/                 // LLM-generated content (baked)
│   │   ├── hero-names.json        // per archetype name pools
│   │   ├── journey-narration.json // ~1500 lines: archetype × stage × event
│   │   ├── bond-narration.json    // bond formation, grief, companion text
│   │   ├── shadow-narration.json  // per-archetype shadow behavior descriptions
│   │   ├── event-descriptions.json
│   │   └── advisor-lines.json     // fallback lines when LLM unavailable
│   └── balance/                   // tuning parameters (hot-reloadable)
│       ├── economy.json
│       ├── hero-classes.json
│       ├── threat-curves.json
│       └── scenario-params.json
├── tools/
│   ├── content-gen/               // LLM content generation pipeline
│   │   ├── generate-hero-text.js
│   │   ├── generate-events.js
│   │   └── generate-advisor.js
│   ├── balance-tool/              // live tuning dashboard
│   └── analytics-viewer/          // playtest data visualization
├── dist/                          // build output
├── package.json
└── tauri.conf.json                // desktop wrapper config
```

---

## 8. Analytics & Fun Measurement System

### 8.1 Philosophy

Measure player behavior, not player opinions. The analytics system runs during all playtests and optionally in production (opt-in telemetry). Its purpose is to answer: **"Is this fun?"** through behavioral proxies.

### 8.2 Core Metrics (Collected Every Tick)

```javascript
SessionAnalytics = {
    // Engagement metrics
    session_duration_seconds: int,
    actions_per_minute: float[],           // time series, 1-minute buckets
    pause_count: int,                       // how often player pauses
    pause_durations: float[],               // thinking vs disengagement

    // Economy health
    gold_balance_history: int[],            // sampled every 30 seconds
    gold_income_rate: float[],
    gold_expense_rate: float[],
    bounty_total_spent: int,
    tax_rate_changes: {tick, old_rate, new_rate}[],

    // Hero behavior
    bounties_posted: int,
    bounties_accepted: int,
    bounties_rejected: int,                 // hero saw but declined
    bounties_completed: int,
    bounties_failed: int,                   // hero died or fled
    hero_deaths: int,
    hero_deaths_by_class: Map<ClassName, int>,
    hero_departures: int,                   // heroes who left the kingdom
    avg_hero_satisfaction: float[],          // time series

    // JOURNEY METRICS (the differentiator — track these closely)
    journey_transitions: {tick, hero_id, archetype, from_stage, to_stage}[],
    journeys_completed: int,                // heroes reaching REWARD_RETURN
    shadow_entries: int,                    // heroes entering SHADOW
    shadow_recoveries: int,                 // heroes recovering from SHADOW
    mastery_reached: int,                   // heroes reaching MASTERY
    refusal_cycles: Map<HeroId, int>,       // how many times each hero refused
    avg_ticks_in_refusal: float,            // how long heroes stay stuck in REFUSAL
    bonds_formed: int,
    bonds_broken_by_death: int,
    calling_bounties_generated: int,        // how many calling bounties appeared
    threshold_conditions_met: {tick, hero_id, condition_type}[],  // what tipped heroes

    // Threat tracking
    buildings_destroyed: int,
    lairs_destroyed: int,
    threat_level_history: float[],          // time series
    closest_threat_to_palace: float[],      // distance time series

    // Decision quality
    time_between_actions: float[],          // interarrival times
    action_types: {tick, action_type, target}[],  // full action log

    // Session outcome
    outcome: enum (WIN, LOSS_PALACE_DESTROYED, LOSS_BANKRUPT,
                   LOSS_ALL_HEROES_LEFT, QUIT),
    quit_tick: int | null,                  // when they stopped if QUIT
}
```

### 8.3 Derived Fun Indicators

Compute these from raw metrics after each playtest session:

```
ENGAGEMENT SCORE:
    - actions_per_minute sustained above 2.0 for >80% of session = GOOD
    - actions_per_minute drops below 1.0 for >60 seconds = DEAD AIR (bad)
    - session_duration > 1.5× scenario_expected_time = HOOKED
    - session_duration < 0.5× scenario_expected_time = BOUNCED

ECONOMY OSCILLATION INDEX:
    - Compute variance of gold_balance_history
    - High variance (player oscillates rich/poor) = GOOD tension
    - Low variance, always high = NO TENSION (economy too easy)
    - Low variance, always low = PUNISHING (economy too hard)
    - Monotonically decreasing = DEATH SPIRAL (balance broken)

HERO SYSTEM HEALTH:
    - bounties_accepted / bounties_posted ratio:
        > 0.8 = heroes too obedient (indirect control too easy)
        0.4 - 0.8 = good friction
        < 0.4 = heroes too independent (player feels powerless)
    - hero_deaths / session_duration:
        > 1 per minute = too lethal
        1 per 3-5 minutes = good tension
        < 1 per 10 minutes = too safe

JOURNEY SYSTEM HEALTH (critical — this is the differentiator):
    - journeys_completed / session: target 1-3 per 30-minute session
        0 = journey triggers too rare or REFUSAL too sticky
        > 4 = journeys too easy, arcs feel trivial
    - avg_ticks_in_refusal:
        < 30 seconds = REFUSAL too easy to overcome (no tension)
        30-120 seconds = good deliberation window
        > 180 seconds = hero stuck, player can't figure out how to help
    - shadow_entries / journeys_attempted:
        < 10% = ordeal too easy, no stakes
        20-40% = good failure rate, meaningful risk
        > 50% = ordeal too hard, heroes break constantly
    - shadow_recoveries / shadow_entries:
        < 30% = recovery triggers too hard to create (shadows feel permanent)
        50-80% = good redemption arc frequency
        > 90% = shadow has no weight, recovery too easy
    - bonds_formed per session: target 2-5
        0 = party formation not happening (check TESTS_ALLIES triggers)
        > 8 = bonds too cheap, dilutes emotional weight
    - mastery_reached per session: target 0-1
        Mastery should feel rare and earned. If >2 heroes reach mastery
        in a 30-minute session, the journey is too fast.

LEGIBILITY SCORE (requires post-session survey OR narration test):
    - After loss, can player articulate cause? (binary, from playtest)
    - % of hero decisions with visible behavioral cue = target >90%

ANECDOTE INDEX (qualitative, from playtest):
    - Count of unsolicited story-telling moments during/after session
    - "Tell me what happened" test → story vs mechanics description
```

### 8.4 Automated Balance Alerts

Set up threshold alerts during development:

```
ALERT CONDITIONS:
    - dead_air_seconds > 45 in any session → pacing problem
    - economy_oscillation < threshold → economy needs retuning
    - bounty_acceptance_ratio outside [0.35, 0.85] → hero AI needs adjustment
    - hero_death_rate outside [0.15, 0.5] per minute → combat balance off
    - quit_before_50%_scenario_time in >30% of sessions → early game broken
    - win_rate outside [30%, 70%] per scenario → difficulty needs adjustment
```

### 8.5 Playtest Protocol

**Minimum Viable Playtest (for each milestone):**

1. Recruit 5 testers (NOT friends — use r/Majesty, city builder Discords, strategy subreddits)
2. Record screen + webcam (with consent)
3. Tell them: "Play for as long as you want. Think aloud if comfortable."
4. Collect:
   - Session analytics (automatic)
   - Screen recording (manual)
   - Post-session interview (5 minutes):
     a. "Tell me what happened in your game."
     b. "What would you do differently?"
     c. "What confused you?"
     d. "Would you play again? Why/why not?"
5. Watch every recording. Note: laughs, leans forward, swears, long pauses, flat expression stretches.

**Playtest gates:**

| Milestone | Test Focus | Pass Criteria |
|-----------|-----------|---------------|
| 40 min prototype (NOW) | Core loop fun | 3/5 testers play past 15 min voluntarily |
| 2-hour build | Session replayability | 3/5 testers start a second run unprompted |
| 5-hour build (EA candidate) | Content depth | Median session >25 min, <20% quit-before-halfway |
| EA launch | First week retention | >50% of buyers play >3 sessions |

---

## 9. Steam Early Access Checklist

### 9.1 Account & Legal

- [ ] Steamworks developer account ($100 app credit)
- [ ] Tax documentation (W-8BEN for non-US)
- [ ] Banking info for payouts
- [ ] App ID created in Steamworks

### 9.2 Store Page (set up 4–6 weeks before launch)

- [ ] Short description (≤300 characters)
- [ ] Long description (features, what makes it unique)
- [ ] At least 5 screenshots (1280×720 or 1920×1080)
- [ ] Header capsule image (460×215)
- [ ] Library capsule image (600×900)
- [ ] Library hero image (3840×1240)
- [ ] Small capsule (231×87)
- [ ] Gameplay trailer (strongly recommended)
- [ ] Early Access questionnaire completed:
  - Why Early Access?
  - Approximate EA duration
  - Full version vs EA version differences
  - Current state of EA version
  - Pricing changes planned?
  - Community involvement plan

### 9.3 Build Requirements

- [ ] Windows executable (via Tauri/Electron wrapper)
- [ ] Steamworks SDK initialized on launch
- [ ] Steam overlay compatible
- [ ] Runs without internet (core game, Royal Advisor degrades gracefully)
- [ ] Save/load functional
- [ ] Settings menu (resolution, volume, key rebinding)
- [ ] Graceful error handling (no unhandled crashes)

### 9.4 Pricing Strategy

- **Recommended EA price:** $12.99–$14.99
- **Rationale:** Low enough to be impulse-buy for niche strategy fans. High enough to not signal "asset flip." Leaves room for price increase at 1.0.
- **Launch discount:** 10% for first week (standard practice, drives initial review volume)
- **Regional pricing:** Use Valve's recommended regional pricing matrix (automatic in Steamworks)

### 9.5 Launch Timing

- Set up store page **6+ months before planned launch** (wishlist accumulation)
- Participate in **Steam Next Fest** with a demo (massive visibility boost, free)
- Avoid launching during major Steam sales or alongside AAA releases
- Target **Tuesday or Thursday** launch (standard industry practice for visibility)

---

## 10. Development Priorities (Ordered)

### Phase 1: Core Loop Lock (Current → +4 weeks)

**Goal:** The 40-minute prototype becomes a single scenario that 3/5 playtesters voluntarily play past 15 minutes.

- [ ] Hero AI decision system (Section 4.2.2) with visible behavioral cues
- [ ] 6 hero classes with distinct behavior patterns
- [ ] Bounty system with acceptance/rejection logic
- [ ] Economy loop (gold in → gold out, oscillation)
- [ ] Basic threat escalation (one enemy faction)
- [ ] Win/loss conditions for one scenario
- [ ] Basic analytics collection (Section 8.2)
- [ ] First playtest round (5 testers)

### Phase 2: Content & Depth (+4 weeks → +10 weeks)

**Goal:** 3 scenarios playable, 2-hour total playtime, second-run replay motivation.

- [ ] 3 additional scenarios with distinct twists
- [ ] All 4 enemy factions implemented
- [ ] Building synergy system
- [ ] Hero memory system (Section 4.2.3)
- [ ] Hero narration (baked text, Section 5.3)
- [ ] Economy tuning pass based on Phase 1 analytics
- [ ] Procedural elements within scenarios (Section 6.3)
- [ ] Second playtest round

### Phase 3: Meta & Polish (+10 weeks → +16 weeks)

**Goal:** 5-8 scenarios, roguelite campaign, 5-8 hour playtime, EA-ready.

- [ ] Roguelite campaign structure (Section 6.4)
- [ ] Meta-progression unlocks
- [ ] Remaining 2-5 scenarios
- [ ] Difficulty levels (3 tiers)
- [ ] LLM content generation pipeline (Section 5.1) — generate baked text
- [ ] Royal Advisor integration (optional, online) (Section 5.2)
- [ ] Settings menu, save/load polish
- [ ] Third playtest round (EA readiness gate)

### Phase 4: Steam Prep (+16 weeks → +20 weeks)

**Goal:** Store page live, build wrapped, reviews passing.

- [ ] Tauri/Electron desktop wrapper
- [ ] Steamworks SDK integration
- [ ] Store page assets (screenshots, trailer, capsules)
- [ ] Store page copy and EA questionnaire
- [ ] Submit store page for review
- [ ] Submit build for review
- [ ] Steam Next Fest demo (if timing aligns)
- [ ] Launch

### Estimated Total Timeline: ~5 months from today (nights & weekends) to EA launch

This assumes the current 40-minute prototype has the rendering engine, basic entity system, and map working. If those need substantial rebuilding, add 4-6 weeks.

---

## Appendix A: Inspiration & Reference

- **Majesty: The Fantasy Kingdom Sim** (2000) — 19 missions, 10 hero types, 30 buildings, indirect control via bounties
- **Majesty 2** (2009) — 16 missions, 4 chapters, added direct control (widely considered a mistake by fans)
- **Gold Gold Adventure Gold** (2025-2026) — Majesty spiritual successor, launched EA "thin," core loop praised, depth criticized
- **Against the Storm** — Roguelite city builder structure (runs, meta-progression, modifiers)
- **Rimworld** — Emergent narrative through autonomous agents with personality systems
- **Dwarf Fortress** — Deep simulation generating stories; hero memory system inspiration

## Appendix B: Naming the Inspiration & Positioning

On the store page, social media, and community posts, **openly cite Majesty** AND **lead with the Journey System:**

> "Sovereign is a kingdom sim inspired by Majesty's legendary indirect-control design. Your heroes aren't units — they're characters living the Hero's Journey. They arrive as uncertain newcomers, refuse the call to adventure, and only commit when you've built a kingdom worth fighting for. They form bonds, face ordeals, transform through triumph — or break into shadow through failure. Your best heroes become your least controllable. You are a ruler, not a general."

The Majesty nostalgia hooks them. The Journey System is why they stay and tell their friends.

## Appendix C: Key Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Hero AI feels random, not emergent | Medium | Critical | Behavioral cues (Section 4.5.3), narration (Section 5.3), extensive playtesting |
| Economy too easy or too hard | High | High | Analytics-driven tuning (Section 8.3), hot-reloadable balance params |
| "Thin" EA launch gets Mixed reviews | Medium | High | Meet 5-hour content minimum, strong store page, Next Fest demo first |
| LLM Royal Advisor says something immersion-breaking | Medium | Low | Optional feature, fallback to baked text, rate-limited |
| Tauri/Electron wrapper introduces bugs | Low | Medium | Test wrapper early (Phase 1), keep game logic pure JS |
| Scope creep delays EA launch | High | High | Strict phase gates, playtest-driven go/no-go decisions |
| Nobody finds the game (discovery) | High | Medium | Next Fest, Majesty community outreach, AI narrative press hook |
