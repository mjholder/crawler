# Spell Casting System

**Added:** 2026-05-06
**Summary:** Learned-spell magic system with mana, prep slots, casting foci in a new OFFHAND slot, tomes, and class-tagged loot.

## Notes
Full magic system built around learned spells, mana, and casting equipment. Brainstormed in full — decisions are fairly settled, this is ready to move toward planning.

**Mana** is a second resource derived from SPIRIT the same way max health derives from CON. Fully restored between world map nodes, no regen during a dungeon node. Players ration mana across all encounters in a run.

**Learned spells** form a persistent roster. From that roster the player prepares a limited active subset before entering a dungeon. **Prep slots** are a flat integer on the player, set by class base (like `starting_consumable_slots` on `PlayerClassData`) and increased by equipment modifiers. Cantrips are just spells with `mana_cost = 0` — no special flag needed.

**Innate weapon spells** are defined directly on a staff or spellbook `WeaponData`, registered into the player action list on equip like normal weapon attacks. They bypass prep slots entirely and append to the prepared list.

A new **OFFHAND slot** is added to `Enums.Slot`. It can hold a shield, a casting focus (orb/tome/catalyst), or be left empty. Two-handed weapons lock the offhand using the existing dungeon lock pattern. Spellcasting is not hard-locked by class — any class can equip a focus and cast. The economy enforces specialization naturally: low SPIRIT means low mana and few slots. A warrior who finds a focus with a good innate cantrip gets real hybrid value with no friction.

**Tomes** are a third item type (`TomeData extends EquipmentData`) that teach spells. They live in the bag as ordinary items — clicking a tome in the bag consumes it and learns its spell (the hover detail shows "Teaches: <spell>"); there is no separate tome section. They have gold value for any class. Learning is blocked by the dungeon lock — you can't study mid-dungeon — because it routes through the dungeon-locked bag. Exception: the **sanctified room**, a rare dungeon event that lifts the inventory lock temporarily (already supported via `allows_inventory = true` on the base `Event` class).

**Loot pools** use explicit class tags on each `EquipmentData` (array of class affinities, plus a universal tag for gear that always appears). Two pools at drop time: primary is class-aligned gear, secondary is off-class gear for selling or surprise hybrid builds. Ratio is a tuning lever, roughly 70/30. Stat-weighted rolling was considered but explicit tags were preferred for authorial control and handcrafted intent.

## Shipped
- **Foundation (2026-05-08):** mana resource (`max_mana = effective_SPI × mana_modifier + class_mana_bonus`), `SpellData` registered as player actions through `execute_action`/targeting, `OFFHAND` slot, prep slots (mirrors the consumable belt), innate weapon spells, `spell_cost_multiplier` on `EquipmentData`, mage armor via `BlessingData.stat_modifiers`, plus cast animations on `Weapon`. See [[design.md]] "Spell casting system — foundation design" and [[daily/2026-05-08]].
- **Tomes + learn UI (2026-07-03):** `TomeData extends EquipmentData` folded into the bag; clicking a tome calls `player.learn_spell` and the detail panel shows "Teaches: <spell>". See [[daily/2026-07-03]].
- **Two-handed offhand lock + per-hand restriction (2026-07-03):** `hand_restriction` (`MAINHAND_ONLY`/`OFFHAND_ONLY`/`EITHER`), `as_offhand_attacks`, `locked_offhand_attacks`, and animated mirrored offhand weapons.
- **Loot tags (partial):** `affinity_tags: Array[StringName]` field exists on `EquipmentData`.

## Remaining
- Class-affinity **dual-pool drops** — the `affinity_tags` field exists but the primary/secondary (~70/30) drop selection logic is not wired.
- Spell **prep-UI polish** — the `InventoryPanel` prep UI still auto-fills the first unprepared spell; needs a scrollable learned-spells picker.
- Real authored offhand content (shield → Brace, foci) and any remaining spell-animation polish.
