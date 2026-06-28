# Ideas & Backlog

Loose ideas, future directions, and things that aren't ready to be tasks yet.
No commitment implied — this is a thinking space.

Resolved ideas (shipped or dropped) are moved out to [[ideas-archive.md]] to keep this
backlog lean. Ideas with a foundation shipped but real work left stay here as `partially done`.

---

## Format

**Idea:** [Short title]
**Added:** YYYY-MM-DD
**Notes:** [Free-form description, rough thoughts, inspiration sources]
**Status:** `raw` | `worth exploring` | `partially done` | `shelved` | `moved to plan`
(`completed` and `abandoned` ideas move to [[ideas-archive.md]].)

---

**Idea:** Attack & weapon clarity (tooltips + equipment descriptions)
**Added:** 2026-06-21
**Notes:** There's currently no way to learn what an attack does without already knowing it from the code — picking "Assassinate" off the action list doesn't say what it does or who it targets. Two related UI surfaces: (1) in-combat tooltips on action buttons, showing effect and target type before committing to a turn; (2) a weapon description in the inventory/equip screen listing the attacks it grants, so gear choices are informed by actual combat behavior, not just stat deltas. Both point at the same underlying gap: attacks and weapons need a player-facing description, not just internal effect data.
**Status:** `worth exploring`

---

**Idea:** Character Creation Layers — Background + Patron Saint
**Added:** 2026-05-30
**Notes:**
Add two new layers to character creation alongside the existing class pick, giving the player a three-part build identity. Inspired by Elder Scrolls birthsigns and Daggerfall-era character creation, but themed to the gothic tone of this project.

**Three layers, three roles:**
- **Class** *(existing)* — *what you can do.* Stats, growth rates, starting loadout, spell roster. The trained archetype.
- **Background** *(new)* — *who you were.* Civilians take up arms in trying times. Small stat shift, starting gold, one unique passive. Static across the entire run.
- **Patron Saint** *(new)* — *what watches over you.* A divine contract that intervenes at dramatic moments. Evolves across the three acts (Survival / Identity / Expression). Often comes with a tithe.

Synergies are meaningful but not required — a Mage / Cloistered Scholar / Saint of the Veil reads as a deliberate caster build, while a Warrior under Saint of the Veil is a thematic mess the player can still make work. Builds-by-non-synergy are a feature.

**Background design**
- Minor stat bump (and optionally a small drawback to match the gothic tone).
- Starting gold value.
- One unique, static passive tied to the character's former life.
- Framing: "civilians forced to adventure." Each background should answer *what did this person do before, and what trace did it leave on them?*
- Example: **Failed Business Owner** — starts with more gold, gains a gold-reward multiplier on event rewards, and gets a shop price modifier (cheaper buys, better sells).
- Other archetypes to explore: Disgraced Knight, Plague Survivor, Cloistered Scholar, Tomb Robber, Heretic, Wayward Acolyte.

**Patron Saint design**
- Each saint is a lineage of three `BlessingData` tiers — one per act. At act transitions, the current tier is removed and the next is applied. New `lineage_id: StringName` field on `BlessingData` ties them together.
- Triggers are *conditional and dramatic*, not always-on stat bumps. Saints feel like intervention, not passive buffs.
- Each tier broadens the trigger and/or adds a new dimension; numerical magnitude is the weakest lever.
- Example: **Saint of Ambush**
  - *Tier 1* — first attack of combat deals 2x damage.
  - *Tier 2* — first attack of every round deals 3x damage and applies bleed.
  - *Tier 3* — first attack against a full-HP enemy is a guaranteed crit, restores HP on kill, applies bleed.
- **Tithe scales with tier.** Late-game saints are dangerous pacts: bigger boons, steeper costs. (e.g. Tier 2 Ambush also starts every combat at −10% HP; Tier 3 lets enemies first-strike you too.)
- Saints are *unique* — run-acquired blessings can give general bonuses, but only saints provide their specific signature shape. This protects the choice from being outscaled by late-game loot.

**Ascension via shrine events**
- A new event type: shrine/altar at the end of each act. The player visits their saint's shrine, makes an offering, and ascends to the next tier.
- Offers a meaningful choice — *ascend* (take the next tier and its tithe) or *decline* (keep current tier, take gold/items instead). Reinforces the dark-bargain feel and gives saints diegetic presence in the world.

**Implementation surfaces**

*New:*
- `BackgroundData` resource — stat shift, `starting_gold`, passive effect references.
- `starting_background: BackgroundData` and `starting_patron: BlessingData` fields on the character creation flow.
- `lineage_id` field on `BlessingData`.
- New modifier fields the failed-business-owner needs: a player-side gold-reward multiplier read by `_apply_rewards`, and a player-side shop price multiplier stacked onto `ShopData`'s existing multipliers.
- Shrine event type (mirrors existing event pattern; lives in dungeon slot system).

*Reused:*
- `add_blessing` / `remove_blessing` already handle tier swaps cleanly.
- `BlessingData.subscriptions` already supports conditional/proc triggers via the lifecycle signal bus.
- Character creation panel just needs two more pick steps after class.

**Open questions for plan-time**
- How many backgrounds and saints? First pass: 6 of each (matches the six existing stats; 6×6×N classes is plenty of variety without overwhelming).
- Do backgrounds have drawbacks (to rhyme with saint tithes), or stay net-positive?
- What happens if the player skips a shrine? (Defer tier-up to a later shrine? Lose the tier entirely?)
- Are shrines guaranteed at end-of-act, or do they appear in a node slot the player has to navigate to?

**Parked / v2 directions**
- *Branching saint evolutions* — Act 2 offers 2–3 paths within the same saint. Lineage system already supports this; just adds authoring + design work.
- *Non-combat saints* — Saint of the Locked Door, Saint of Liars, etc. — saints whose signature triggers fire on skill checks or dialogue rather than combat. Would broaden the appeal of the choice for build types that aren't combat-focused.

**Status:** `partially done` — see [[design.md]] and [[daily/2026-06-07]].
**Shipped (Phase 1, 2026-06-07):** `BackgroundData` + `PatronSaintData` (+ `lineage_id` on `BlessingData`), player integration (`_setup_background`/`_setup_patron`, gold-reward/shop multipliers), content-editor authoring, hand-built 4-step wizard UI, sample content. Saints ship at tier 1, fully playable; `ascend_patron()` and `_patron_tier_index` are in place.
**Remaining (Phase 2):** shrine/altar ascension event type and the "act" concept it needs; the "first attack deals Nx damage" proc needs a new effect type. Parked/v2: branching saint evolutions, non-combat saints.

---

**Idea:** Content editor — enemy and event authoring support
**Added:** 2026-05-21
**Notes:**
The tool currently covers equipment, attacks, effects, blessings, and classes. Enemies and events are the other major authoring surface — making a new enemy means setting stats, AI behavior, drops, and wiring it into an event; making a new event means defining waves, rewards, and any special scripting. Both involve enough cross-resource wiring that the inspector is genuinely painful. Adding them to the content editor would let the full encounter design loop (enemy stats → event composition → shop/reward tuning) happen outside Godot.
**Status:** `partially done`.
**Shipped:** event authoring — `EventEditor` with per-type forms (Combat / Dialogue / SkillCheck / Rest) via the `.tres`-wraps-JSON wrapper pattern (see [[design.md]] "Events exposed in content editor", 2026-05-22).
**Remaining:** enemy authoring — there is no dedicated enemy editor; enemies are only referenced inside `CombatEventForm`. Need a form for stats, AI behavior, and drops.

---

**Idea:** Content editor — inline sub-resource creation from dropdown
**Added:** 2026-05-21
**Notes:**
When a field expects a resource ref (e.g. a weapon's `attacks` array, or an attack's `effects` array), the dropdown currently only lets you pick an existing file. The missing flow is: click "new" in that dropdown, choose the concrete type (e.g. `AttackData`, `DamageEffect`), give it a name/path, and it's created and immediately wired in. Pairs naturally with a breadcrumb bar — if you're authoring a weapon and create a new attack inline, you should be able to navigate into that attack's form, then navigate back up to the weapon. Without the breadcrumb, you'd have to find the new file in the sidebar to finish filling it in, which breaks the authoring flow for a weapon that needs two or three new attacks at once.
**Status:** `worth exploring`

---

<!-- Add ideas below, newest first -->

**Idea:** Combat Feel & Pacing
**Added:** 2026-05-15
**Notes:**
A single combat encounter should last 5–8 player turns. Encounters are designed to be taxing but winnable — the real difficulty is attrition across a full dungeon, not any single fight. Early dungeons are forgiving warm-ups where misplay is required to be in real danger. Later dungeons force the player to weigh fighting vs resting.

Death should feel like education, not punishment. The player should leave a failed run understanding what they didn't know — a new enemy mechanic, an interaction they hadn't seen — and feel like they can prepare better next time. Enemies have consistent, learnable patterns. Visible states (wind-up animations, status icons) telegraph intent without explicitly showing next-turn damage like Slay the Spire. The player learns what those states mean through experience.

Health is a primary resource, not a buffer. Healing is scarce and deliberate. The tension across a dungeon is "do I have enough left for what comes next," not just "can I win this fight."

Each combat turn should require meaningful decisions informed by enemy state. Weapons and spells have intent. Smart play means responding to what the enemy is setting up — bracing before a big hit, swinging when the enemy is in setup, targeting priority threats.

Enemy HP and active buffs/debuffs are visible. Hidden information is not part of the tension — readable enemies that surprise through new mechanics is.

**Status:** `worth exploring`

---

**Idea:** Run Structure & Act Progression
**Added:** 2026-05-15
**Notes:**
A full run targets 1–1.5 hours. Runs should feel meaningfully different — class unlocks, boons, spells, and loot variety ensure that even the same starting loadout doesn't produce the same run twice.

The emotional arc follows three acts:

**Act 1 — Survival.** The player enters with a vague plan seeded by their class and starting boon. Gear is generalist: raw DEF, HP, basic damage. The player is asking "can I stay alive" not "what am I building." Enemy patterns are simple and teachable. The boon is the only real build signal.

**Act 2 — Identity.** The player finds one or two pieces specific to a build direction and starts making cuts — dropping generalist gear for things that fit. Gear has a type: a weapon that combos with a spell, armor that rewards a playstyle. Higher tier gear has passive or active features that multiply power. Enemy complexity ramps here. Synergies start clicking, the game opens up, and smart decisions need to align with the emerging build.

**Act 3 — Expression.** The player knows what they're building. Gear has multiple interacting properties. Play is about fine-tuning and pruning — knowing when *not* to equip something even if raw stats are better. Enemy design can be more exotic because the player has real tools to respond creatively. Smart play matters most here.

Each act is balanced independently against what the player *should* have at that stage. Act 1 enemies are tuned against a generalist loadout. Act 3 enemies assume real synergies exist.

**Status:** `worth exploring`

---

**Idea:** Spell Casting System
**Added:** 2026-05-06
**Notes:**
Full magic system built around learned spells, mana, and casting equipment. Brainstormed in full — decisions are fairly settled, this is ready to move toward planning.

**Mana** is a second resource derived from SPIRIT the same way max health derives from CON. Fully restored between world map nodes, no regen during a dungeon node. Players ration mana across all encounters in a run.

**Learned spells** form a persistent roster. From that roster the player prepares a limited active subset before entering a dungeon. **Prep slots** are a flat integer on the player, set by class base (like `starting_consumable_slots` on `PlayerClassData`) and increased by equipment modifiers. Cantrips are just spells with `mana_cost = 0` — no special flag needed.

**Innate weapon spells** are defined directly on a staff or spellbook `WeaponData`, registered into the player action list on equip like normal weapon attacks. They bypass prep slots entirely and append to the prepared list.

A new **OFFHAND slot** is added to `Enums.Slot`. It can hold a shield, a casting focus (orb/tome/catalyst), or be left empty. Two-handed weapons lock the offhand using the existing dungeon lock pattern. Spellcasting is not hard-locked by class — any class can equip a focus and cast. The economy enforces specialization naturally: low SPIRIT means low mana and few slots. A warrior who finds a focus with a good innate cantrip gets real hybrid value with no friction.

**Tomes** are a third item type (`TomeData`) that teach spells. They sit in the bag, have gold value for any class, and trigger a dedicated learn interface on use. Learning is blocked by the dungeon lock — you can't study mid-dungeon. Exception: the **sanctified room**, a rare dungeon event that lifts the inventory lock temporarily (already supported via `allows_inventory = true` on the base `Event` class).

**Loot pools** use explicit class tags on each `EquipmentData` (array of class affinities, plus a universal tag for gear that always appears). Two pools at drop time: primary is class-aligned gear, secondary is off-class gear for selling or surprise hybrid builds. Ratio is a tuning lever, roughly 70/30. Stat-weighted rolling was considered but explicit tags were preferred for authorial control and handcrafted intent.

**Status:** `partially done` — foundation shipped 2026-05-08, see [[design.md]] "Spell casting system — foundation design" and [[daily/2026-05-08]].
**Shipped:** mana resource (`max_mana = effective_SPI × mana_modifier + class_mana_bonus`), `SpellData` registered as player actions through `execute_action`/targeting, `OFFHAND` slot, prep slots (mirrors the consumable belt), innate weapon spells, `spell_cost_multiplier` on `EquipmentData`, mage armor via `BlessingData.stat_modifiers`.
**Remaining:** tomes (`TomeData`) + learn UI, class-affinity loot tags + dual-pool drops, the two-handed offhand lock, spell animations, and prep-UI polish (the `InventoryPanel` prep UI is dynamic/unpolished).

---

**Idea:** World lore — the Forgotten Entity and the war
**Added:** 2026-04-20
**Notes:** The bad air has a source: a dormant entity, forgotten by name, that was awakened by the scale of death from a regional war fought between major powers. The war killed soldiers and civilians indiscriminately; mass death without religious rites is what fed or triggered the awakening. The entity wasn't summoned — it starved into dormancy long ago, and the war was the meal that woke it. Knowledge of it once existed (priests built shrines for reasons they no longer understood — ritual abstracted the original purpose), but that knowledge was lost or suppressed. The bad air *is* the entity's influence spreading outward. Unconsecrated sites fell first — charnel grounds, plague pits, battlefield graves. Consecrated sites like the catacombs are holding, but the entity is pressing against them; some shrines may already be failing or corrupted on deeper floors. The player arrives mid-escalation: containment is still possible but not guaranteed. Design implications: dungeon difficulty can track proximity to the entity's influence (unconsecrated = already claimed, catacombs = contested frontier); shrine reliability could degrade over run progression as a late-game pressure; charnel ground dungeons could feature risen dead from *both* factions still in opposing armor, with loot from either side. The entity stays unnamed and unexplained for now — "forgotten" is the horror.
**Status:** `worth exploring`

---

**Idea:** Dungeon types and naming
**Added:** 2026-04-20
**Notes:** Different dungeon types carry different lore weight and mechanical pressure. Draft taxonomy (shrine count tracks religious intent at time of burial, not floor length): **Catacombs** — longest, most undead, most shrines; priests consecrated these heavily because faith compelled it, not because they understood the threat; multiple safe rooms throughout; hardest but most protected. **Ossuary** — bone storage, less devout than catacombs; shorter, fewer shrines. **Undercroft** — beneath a church or manor, not fully religious; medium length, one shrine at best. **Vault** — noble family burial, secular; compact, no shrines, unprotected. **Plague pit** — mass burial, no rites; short, unstable, zero shrines; not easy despite being short. **Charnel ground** — battlefield dead from the war, unclaimed; chaotic layout, fast and brutal; no consecration; dead from both factions still in opposing armor. The pattern: places where the church *cared* have shrines; places where nobody did have none. Charnel grounds are especially interesting — they're where the entity woke up first.
**Status:** `worth exploring`

---

**Idea:** Equipment locked in dungeons ("bad air")
**Added:** 2026-04-20
**Notes:** Players cannot equip or unequip *equipment* (armor, weapons, rings) while inside a dungeon — those decisions are locked to safe nodes between runs, rest sites, and shops. Lore: the bad air means concentrating long enough to swap armor is impossible. Identify items on pickup so the player always knows what's in the bag. Calibrate loot drops toward the next floor or run broadly, so finds feel like future rewards rather than taunts. Consecrated rooms (shrines) in longer dungeons act as safe rooms where the bad air doesn't reach — equip swaps are allowed there. **Consumables follow different rules** (see below): they can be picked up mid-dungeon and handled freely at the point of pickup, but the bag is sealed once something is inside. Dungeon types affect pressure: short floors have no shrine, long floors (e.g. catacombs) have several.
**Status:** `partially done`.
**Shipped:** the core equip lock — `_dungeon_locked` in `inventory_panel.gd` disables equip/unequip inside a dungeon; `allows_inventory` on the base `Event` exists for shrine-style exceptions.
**Remaining:** identify-on-pickup, the consecrated-room equip window actually wired to a shrine event, loot calibration toward the next floor, and the consumable directional rules (own entry below).

---

**Idea:** Consumable handling mid-dungeon ("only the dead remain still")
**Added:** 2026-04-20
**Notes:** Consumables have more freedom than equipment mid-dungeon, but still follow a directional rule. At the point of pickup the player can: (1) equip it to an empty belt slot, (2) swap it with an already-equipped consumable — the displaced item goes to the bag or is dropped, player chooses — or (3) put it in the bag. Once something is in the bag mid-dungeon, it stays there; the player cannot retrieve it to the belt. Lore: *"only the dead remain still"* — quick-swapping a vial from hand to belt is motion; rummaging through the bag is staying still, which is a bad omen in bad air. Design consequence: "put it in the bag" is a real commitment, not a neutral choice — it locks the item away until the dungeon is cleared. A full belt with a pickup creates genuine tension: swap (losing access to the old item) or bag (losing access to the new one). Rewards leaving belt slots open before descending as a form of preparation.
**Status:** `worth exploring`

---

**Idea:** "Bad air" as a lore thread
**Added:** 2026-04-20
**Notes:** The equipment-lock mechanic surfaces a broader lore question: what *is* the bad air? Implies the undead (or what controls them) have an active, spreading presence — not just set dressing. Could be seeded through shrine text, item flavor text, NPC warnings before a run, or environmental details. No codex dump needed; sprinkle it. The bad-air framing also opens space for environmental hazards, resistances, or consumables tied to that fiction (e.g., incense that wards bad air, giving a brief equip window). Parking as a worldbuilding thread to develop alongside dungeon content.
**Status:** `worth exploring`

---

**Idea:** Consumable belt growth mechanics
**Added:** 2026-04-20
**Notes:** MVP ships with a fixed `starting_consumable_slots` per class and a `Inventory.set_belt_size()` helper. Expansion mechanic is deferred. Two plausible directions: (a) specific equipment (e.g., a utility belt item) grants `+N` belt slots via a new `bonus_consumable_slots` field on `EquipmentData`, composable with the existing stat-modifier layer; (b) level-up or milestone rewards unlock a slot at certain levels. Infrastructure is already in place — just needs a source-of-truth for the delta and a call into `set_belt_size()`.
**Status:** `worth exploring`

---

**Idea:** Status-effect consumables (cure / remove)
**Added:** 2026-04-20
**Notes:** Add a `CURE` variant to `ConsumableData.Effect` once a status-effect system exists. Depends on: statuses being a first-class player state (poison, bleed, stun), and the dispatcher in `game.gd` knowing how to clear them. Parking until statuses ship.
**Update (2026-06-21):** the blocking dependency is met — statuses are now first-class via Effect System v2 (`StatusData`, `apply_status`/`remove_status`, see [[design.md]] 2026-05-02). This is now actionable: a cure consumable would be a new `Effect` subclass that calls `remove_status` by tag, authored as a `.tres` and dropped into `ConsumableData.effects` (no enum needed under the unified Effect pipeline).
**Status:** `worth exploring`

---

**Idea:** Group dialogue UI components in a shared container
**Added:** 2026-03-25
**Notes:** Instead of placing dialogue UI nodes individually, wrap them in a container so they scale together as a unit. Makes it easier to maintain consistent proportions when adjusting resolution or layout.
**Status:** `worth exploring`

---

**Idea:** Roguelike Run Structure
**Added:** 2026-02-22
**Notes:**
Core gameplay loop is run-based — the player descends through a dungeon, completes a run, then starts fresh. No persistent world between runs (or very minimal persistence TBD).

**Run structure:**
- A run is made up of several floors in sequence
- Each floor escalates in difficulty
- Each floor has a theme (e.g. crypt, sewers, forest depths, volcanic caves) — theme affects encounter types, enemy roster, environmental hazards, and possibly music/visuals
- End of a run = boss floor or escape condition TBD

**Encounter types per floor:**
- **Combat** — turn-based or real-time fights against enemies; core of most floors
- **Skill checks** — stat-based challenges (STR to force a door, AGI to squeeze through, SPI to sense a curse, LCK as a wildcard)
- **Loot** — treasure rooms, hidden caches, chests with risk/reward
- **Roleplay events** — text-based decision nodes; outcomes affect the current run (buffs, debuffs, story flavor, resource gain/loss)
- Possibly more types later: merchants, shrines, traps, rest sites

**Design principles to carry forward:**
- Keep it simple first — nail one floor with a handful of encounter types before expanding
- The stat and equipment systems should integrate naturally into skill checks and combat without special-casing
- Floor themes are a content/data concern; the underlying systems should be theme-agnostic
- Enemy difficulty scaling should be data-driven so floors can be tuned without code changes

**Long-term directions (not for now):**
- Multiple floor themes with curated encounter pools per theme
- Meta-progression between runs (unlocks, permanent upgrades)
- Branching floor paths — player chooses next floor theme
- Run modifiers or curses that persist across a whole run

**Status:** `worth exploring`

