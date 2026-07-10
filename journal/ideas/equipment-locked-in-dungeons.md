# Equipment locked in dungeons ("bad air")

**Added:** 2026-04-20
**Summary:** Lock equipment swaps to safe nodes/shrines inside a dungeon — the bad air won't let you re-armor mid-run.

## Notes
Players cannot equip or unequip *equipment* (armor, weapons, rings) while inside a dungeon — those decisions are locked to safe nodes between runs, rest sites, and shops. Lore: the bad air means concentrating long enough to swap armor is impossible. Identify items on pickup so the player always knows what's in the bag. Calibrate loot drops toward the next floor or run broadly, so finds feel like future rewards rather than taunts. Consecrated rooms (shrines) in longer dungeons act as safe rooms where the bad air doesn't reach — equip swaps are allowed there. **Consumables follow different rules** (see [[ideas/consumable-handling-mid-dungeon]]): they can be picked up mid-dungeon and handled freely at the point of pickup, but the bag is sealed once something is inside. Dungeon types affect pressure: short floors have no shrine, long floors (e.g. catacombs) have several.

## Shipped
The core equip lock — `_dungeon_locked` in `inventory_panel.gd` disables equip/unequip inside a dungeon; `allows_inventory` on the base `Event` exists for shrine-style exceptions.

## Remaining
identify-on-pickup, the consecrated-room equip window actually wired to a shrine event, loot calibration toward the next floor, and the consumable directional rules (see [[ideas/consumable-handling-mid-dungeon]]).
