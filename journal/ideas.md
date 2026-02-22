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
