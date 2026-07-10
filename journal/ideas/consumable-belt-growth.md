# Consumable belt growth mechanics

**Added:** 2026-04-20
**Summary:** Grow the consumable belt past its per-class starting size via equipment slots or level-up milestones.

## Notes
MVP ships with a fixed `starting_consumable_slots` per class and a `Inventory.set_belt_size()` helper. Expansion mechanic is deferred. Two plausible directions: (a) specific equipment (e.g., a utility belt item) grants `+N` belt slots via a new `bonus_consumable_slots` field on `EquipmentData`, composable with the existing stat-modifier layer; (b) level-up or milestone rewards unlock a slot at certain levels. Infrastructure is already in place — just needs a source-of-truth for the delta and a call into `set_belt_size()`.
