# Status effects clear at combat end (equipment/background effects excluded)

**Added:** 2026-07-08
**Summary:** Combat-inflicted statuses wipe at fight end while equipment/background statuses persist; groundwork shipped, dependent status entries remain.

## Notes
All combat-inflicted statuses (poison, bleed, burn, stun, buffs) should wipe when a fight ends — nothing does this today; enemies get it for free by being deleted at combat end, but the player's `_active_statuses` has no equivalent clear. A blanket clear-everything would also strip legitimate on-equip permanent statuses (`duration: -1` statuses granted by worn gear/backgrounds, meant to persist across the whole run, including through non-combat events like dialogue), so the clear needs to tell combat-inflicted statuses apart from equipment-granted ones. Proposed: a `source` flag on `StatusData` (`COMBAT` vs `EQUIPMENT`), defaulting to `COMBAT`; the exit hook only sweeps `COMBAT`-flagged instances. Likely lives in the same combat-exit lifecycle that already tears down enemy health bars, so it fires uniformly regardless of how the fight ended.

Also settled alongside this: `on_tick` stays combat-turn-scoped only — no synthetic "turn" for non-combat events just to make ticking generic. Anything that needs to fire outside combat (e.g. a gold-generating background passive) should be authored as a `ProcDef` off the lifecycle bus instead, which already fires for every event type — flat stat modifiers and proc-based passives already work everywhere with no changes needed; only `on_tick`-shaped effects are combat-only by design.

## Shipped
**(2026-07-08):** the clear-at-combat-end groundwork. The category landed as `persistence: { COMBAT, PERSISTENT }` on `StatusData` (default `COMBAT`) — renamed from the proposed `source: { COMBAT, EQUIPMENT }` to avoid colliding with `StatusInstance.source: Node` and to cover background/blessing-granted statuses, not just gear. `Combatant.clear_combat_statuses()` sweeps `COMBAT` instances from the player at `CombatEvent._on_exit()` (the single exit choke point covering victory and death); `on_expire` intentionally not fired on the forced clear. See [[design.md]] "Combat-inflicted statuses clear at combat end" and [[daily/2026-07-08]].

## Remaining
The actual status entries this unblocks (Bleed, burst-Burn, Shatter/Brace, elemental signatures).
