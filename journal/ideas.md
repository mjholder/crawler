# Ideas & Backlog

Loose ideas, future directions, and things that aren't ready to be tasks yet.
No commitment implied — this is a thinking space.

---

## Format

**Idea:** [Short title]
**Added:** YYYY-MM-DD
**Notes:** [Free-form description, rough thoughts, inspiration sources]
**Status:** `raw` | `worth exploring` | `shelved` | `moved to plan`

---

<!-- Add ideas below, newest first -->

**Idea:** Combat Balance — Defense, Dodge, and Armor Tiers
**Added:** 2026-05-07
**Notes:**
Reworking the first-pass flat defense subtraction which nullifies weak enemies entirely and can't be balanced across both ends of the damage scale.

**Defense** moves to percentage-based damage reduction rather than flat subtraction. Formula TBD but something in the range of `damage * (1 - defense_ratio)` — every enemy always deals some damage regardless of the gap in power.

**Dodge** is introduced as a separate evasion layer driven by AGI. Formula something like `agility * 0.003`, capped around 40–50%. Resolved as a roll before damage is applied. Keeps AGI meaningful as a defensive stat without muddying the DEF formula.

**Armor tiers** represent a tradeoff triangle rather than a strict progression. No stat gating — equipment pools are class-aligned at the loot/shop level, not locked by requirements:
- **Heavy armor** — high DEF modifier, negative AGI modifier, high `spell_cost_multiplier` (e.g. `1.5`). Warriors absorb hits but are slow and poor casters.
- **Leather armor** — moderate DEF modifier, neutral or small positive AGI modifier, neutral spell cost. Rogues get protection without losing evasiveness.
- **Robes/clothes** — little to no DEF modifier, low `spell_cost_multiplier` (e.g. `0.8`) or SPI bonus. Mages are fragile but cast efficiently.

**Spell cost multiplier** is a new float field on `EquipmentData` (`spell_cost_multiplier: float = 1.0`). Applied multiplicatively across all equipped pieces at cast time. Feeds into the spell system design.

**Mage defense** — pure mages start with a mage armor spell (a `BuffEffect` on `Enums.Stat.DEFENSE`) rather than relying on gear. Hybrid classes can start with light armor instead.

**UI** — inventory detail panel diffs the candidate item's `stat_modifiers` against the currently equipped item and displays deltas in green/red. Active stat effects (from gear and buffs) are displayed in a dedicated active effects panel so the player can see what's contributing and from where.

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

**Status:** `worth exploring`

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
**Status:** `worth exploring`

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
**Status:** `shelved`

---

**Idea:** Group dialogue UI components in a shared container
**Added:** 2026-03-25
**Notes:** Instead of placing dialogue UI nodes individually, wrap them in a container so they scale together as a unit. Makes it easier to maintain consistent proportions when adjusting resolution or layout.
**Status:** `worth exploring`

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

---

**Idea:** Core Player Stats
**Added:** 2026-02-22
**Notes:**
Seven base stats that drive all character interactions:

- **Health** — derived from Constitution; total hit points before death/down
- **Defense** — base damage mitigation; also influenced by Agility (passive dodge) and equipped armor
- **Strength (STR)** — damage for power-type melee weapons (swords, axes, maces, hammers); also used as the stat check for equipping heavy armor and high-requirement weapons
- **Constitution (CON)** — determines max health pool; also governs resistance to status effects (poison, stun, curse, etc.)
- **Agility (AGI)** — passive defense contribution (harder to hit); damage for finesse weapons (daggers, rapiers, shortbows) and ranged weapons; stat check for equipping finesse-class weapons and light armor
- **Spirit (SPI)** — occult/devotional magic; power drawn from communion with an unknown higher being rather than study or intellect; governs spell damage, mana/resource pool, and potency of magical effects; not evil per se but deals in forces beyond mortal understanding
- **Luck (LCK)** — crit chance on attacks; improves loot quality/rarity on drops; small flat bonus on skill/stat checks

Weapon class gating:
- STR check → heavy armor, two-handers, warhammers, etc.
- AGI check → finesse melee (daggers, rapiers), ranged (bows, crossbows), light armor
- SPI check → staves, spell catalysts, occult-focus items

Damage scaling intent:
- STR weapons scale off STR
- AGI weapons scale off AGI
- SPI weapons/spells scale off SPI
- Hybrid weapons (e.g. a quick shortsword) TBD — maybe the higher of the two, or a split

Questions to resolve:
- Are stats fixed at character creation or do they grow on level-up?
- Integer values or derived modifiers (e.g. D&D-style bonus from stat)?
- Does Defense stack additively with armor or use a formula (e.g. diminishing returns)?
- How does LCK interact with skill checks — flat bonus, reroll, or just a small ±%?
- Does SPI also affect non-damage magic (buffs, curses, summons) or is it purely offensive scaling?
- Is there a separate resource (mana, devotion, favour) tied to SPI, or do spells have cooldowns/charges?
- Could INT be added later as a distinct arcane path, or is SPI the only magic stat?

**Status:** `worth exploring`

---

**Idea:** Grid-Based Equipment System
**Added:** 2026-02-22
**Notes:**
Players equip gear that occupies grid cells on a character sheet — similar to Resident Evil / Diablo-style inventory but applied to the body. Each equipment slot (torso, legs, head, hands, feet, fingers, wrists, neck) maps to a region of the grid. Items have shapes that must fit within their valid region(s).

Categories to support:
- **Armor** — heavy/light/none; contributes to physical defense, movement penalties
- **Clothing** — wearable over or under armor; can provide stat bonuses, environmental resistances
- **Weapons** — one-handed, two-handed, ranged, off-hand; define attack type, damage dice, reach, special move unlocks
- **Shields** — occupy off-hand slot; block/parry modifiers, maybe size affects coverage vs. mobility
- **Jewelry** — rings (fingers), necklaces (neck), bracelets (wrists); typically small grid footprint, high modifier density

Modifier considerations to design early:
- Attack modifiers: damage type (slash/pierce/blunt/magic), bonus to-hit, crit range, special effects on hit
- Defense modifiers: damage reduction per type, block chance, dodge modifier, elemental resistances
- Passive stat changes: STR/DEX/INT/etc. bumps, max HP/MP, speed
- Encumbrance: total weight of equipped gear affecting move speed, stamina drain, stealth
- Set bonuses: wearing multiple pieces from the same set could unlock extra effects
- Condition slots: some gear could have gem/rune sockets for further customization

Grid design questions to resolve:
- Fixed body-silhouette grid vs. flat inventory grid with slot restrictions?
- Allow overlapping slots (e.g., ring worn on same finger as another ring) or strict exclusion?
- How does gear interact with race/body-type differences (size, limb count)?

Integration points to keep in mind from the start:
- Combat system needs to query equipped weapon(s) for attack resolution
- Defense calculation needs to aggregate all equipped armor/shield values per damage type
- AI enemies should support the same equipment structure for consistent rules
- Loot drops should generate items that fit the grid schema
- UI will need a dedicated equipment screen — grid layout makes this visual and tactile

**Status:** `worth exploring`
