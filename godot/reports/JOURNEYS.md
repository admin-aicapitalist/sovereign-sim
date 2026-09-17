# Hero Journeys — Persona, Shadow and the castle economy

**Hero Journeys** is the live overview of every hero: Persona or Shadow, interrupted/current journey, location, activity, personal purse, support needed and an action. Shadow heroes sort first and have their own filter. There is no numbered progression ladder. Journals are optional detail. **Guild banks & leisure** opens the economy menu; the kingdom pauses while managing banks, and resumes its previous state when returning.

## Persona and Shadow

A journey describes what a hero is doing; Persona/Shadow describes whether they can pursue that purpose. A living hero reduced below 20% health by damage enters Shadow from **any** journey phase, including arrival, homecoming and Mastery. Their phase, calling objective, completed journeys, XP and equipment remain intact. Another defeat can cause another relapse.

| Hero | Persona | Shadow | Royal intervention |
| --- | --- | --- | --- |
| Warrior | Confronts threats | Cowardice: refuses combat and bounties | Supervised drills at an operating Warriors’ Guild |
| Ranger | Explores the frontier | Withdrawal: stops exploration and bounties | Guided map work at an operating Rangers’ Lodge |
| Wizard | Uses learned magic | Hubris: withholds spells and bounties | Mentorship at an operating Temple |
| Thief | Pursues opportunities and steals from patrons | Disillusionment: refuses bounties and guild theft | Reconciliation at an operating Thieves’ Guild |

Shadow heroes retreat and linger near the castle. They do not acquire nearby combat targets. Physical healing still works, but **health, elapsed time, new bounties, newly revealed terrain, research and leisure cannot clear Shadow**.

The king funds a named hero’s support from their row: **80g** goes into the service building’s tax reserves. The hero must then reach that building, have at least 60% health and spend **25 seconds** there without enemies within six tiles. Travel, unsafe conditions and low health do not count. The progress is saved. Lost facilities or another crushing blow interrupt the arrangement and require renewed support; repeated clicks cannot charge twice.

Recovery restores Persona. A previously committed hero reconsiders the interrupted call in Refusal, retaining its objective and experience. Ended offers release the hero to seek another call. A recovered veteran keeps Mastery and completed-journey bonuses. No hero is permanently immune to Shadow.

Calls, hesitation, commitment, ordeals and homecoming remain journey context: calls take 30–90 seconds to consider; Refusal needs 60% health plus a healthy nearby hero, healing supplies/a nearby Temple, or a 150g reward. Successful objectives lead to homecoming and reflection; completed journeys add 2 attack each, capped at 20. Mastery heroes prefer offers worth 150g or targets with 500+ maximum health.

## Spending, theft and guild banks

| Mechanic | Local rules |
| --- | --- |
| Inn | Costs 180g to build. A visit costs the patron 8g. |
| Brothel | Costs 240g to build. A visit costs the patron 14g. |
| Patrons | Heroes considering/refusing a call or stuck in Shadow visit operating venues within 16 tiles of the castle. Each paid visit lasts 18s; another can begin after 30s. Broke heroes shelter in their home guild, falling back to the Palace. Venues in danger are avoided. |
| Venue income | The fee leaves the hero’s purse and enters venue tax reserves. A collector must deliver it to the Palace. No passive venue income is created. |
| Theft | An available Persona thief approaches a living non-thief patron. The thief enters the patron’s venue and takes 25% of the remaining purse, rounded down, capped at 20g. Each thief has a saved 20s cooldown. The patron must have at least 4g and be inside an operating venue. |
| Guild cut | Half the stolen amount, rounded down, enters the thief’s own operating guild bank; the thief keeps the remainder. A lost guild cannot receive new deposits. |
| Confiscation | Transfer one operating guild’s full bank into the royal treasury. The **120s cooldown is kingdom-wide**, so multiple guilds cannot bypass it. Empty/invalid seizures do not consume the cooldown. Collectors cannot take guild-bank reserves. |

The economy menu shows every operating Thieves’ Guild bank, the next seizure time and build actions for both venues and the guild. Guild selection also exposes its bank and confiscation action. Hero rows show where their money is being spent; journals record visits and thefts.

## Indoor shelter

Heroes walk to a building’s entrance, disappear inside, and emerge on walkable ground. Guilds and Temples handle physical recovery and journey reflection; paid Inn/Brothel visits also restore health. Indoor rest never clears Shadow without royal support. Buildings protect their occupants from outside combat until destroyed, then release them. Occupied buildings flicker with light and fly a waving pennant: gold normally, crimson if a Shadow hero is inside. The building panel lists residents, activity and health; Hero Journeys shows each indoor location. Find hero focuses their shelter. See [art, rules and verification](LEISURE.md).

## Saves and verification

Version-two journey data separates aspect from phase and persists recovery arrangements, visits and theft cooldowns. Version-one journeys migrate; existing Shadow stays Shadow. Earlier settlements without journeys begin tracking at the saved time. Court bank balances and the kingdom-wide seizure timer live in the saved settlement. Malformed state is rejected before the live world changes. Standalone chronicles also use indoor physical recovery; Persona/Shadow and the castle economy remain settlement rules.

- [Journey and economy checks](journey-systems.json): 112 checks, including all four persistent Shadows, relapse, support, lost recovery sites, purse/bank conservation, cooldowns, migration and malformed saves.
- [Browser checks](journey-browser.json): roster visibility, inline support, real-time decisions/theft, confiscation, phone layout, saved recovery and cooldowns, and paid construction of both venues. All five groups pass.
- [Settlement campaigns](settlement-campaign.json): all 12 configurations win with autonomous heroes and paid construction, recruitment, research, bounties and targeted royal recovery. Wins take about **404–572 simulation seconds**, with **0–1 hero deaths**. Human pacing and economic balance remain provisional.
- Existing settlement rules: 77 checks pass. Standalone simulation: 108 checks pass. The seven settlement-browser groups and four desktop/phone/tablet layout groups also pass.

The new buildings are authored with the repository’s Blender geometry/material helpers in `tools/art/render_buildings.py`, then finished with `godot/tools/finish_leisure.py`. No runtime model calls are used. Social bonds, additional classes and a full personality vector remain future work.

[Desktop overview](journey-overview.png) · [Phone overview](journey-mobile.png) · [Shadow filter](journey-mobile-recovery.png) · [Guild banks](journey-guild-banks.png) · [New venues in the settlement](journey-leisure-buildings.png)
