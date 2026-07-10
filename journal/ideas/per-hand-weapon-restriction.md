# Per-Hand Weapon Restriction + Offhand Moveset

**Added:** 2026-07-03
**Summary:** `hand_restriction` enum + per-hand movesets with a hand-selection UI and animated mirrored offhand weapons; implemented 2026-07-03.

## Notes
Weapons should carry a `hand_restriction` enum (`MAINHAND_ONLY`, `OFFHAND_ONLY`, `EITHER`) so the equip UI can enforce which slot they're dragged into. Default is `MAINHAND_ONLY` — existing weapons need no changes. For weapons flagged `EITHER`, an optional `as_offhand_attacks` array defines a different moveset when the weapon is in the offhand slot; if omitted, `attacks` is used for both hands. The existing `offhand_attacks` field on `WeaponData` should be renamed `locked_offhand_attacks` to disambiguate — it means "actions the locked offhand gets when *this* two-hander is in the mainhand," not "what this weapon does when *it* is in the offhand." Needs a detailed design pass before implementing — the rename touches content and `_rebuild_hand_actions()`.

## Shipped
**(2026-07-03):** implemented; scope grew to include a hand-selection UI (highlight + arrow-cycle, mirroring combat targeting) and animated mirrored offhand weapons. See [[design.md]] and [[daily/2026-07-03]].

## Remaining
None — shipped and closed.
