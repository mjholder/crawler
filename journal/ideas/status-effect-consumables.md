# Status-effect consumables (cure / remove)

**Added:** 2026-04-20
**Summary:** A cure/remove-status consumable, now unblocked by Effect System v2 — authored as an Effect .tres calling remove_status.

## Notes
Add a `CURE` variant to `ConsumableData.Effect` once a status-effect system exists. Depends on: statuses being a first-class player state (poison, bleed, stun), and the dispatcher in `game.gd` knowing how to clear them. Parking until statuses ship.

**Update (2026-06-21):** the blocking dependency is met — statuses are now first-class via Effect System v2 (`StatusData`, `apply_status`/`remove_status`, see [[design.md]] 2026-05-02). This is now actionable: a cure consumable would be a new `Effect` subclass that calls `remove_status` by tag, authored as a `.tres` and dropped into `ConsumableData.effects` (no enum needed under the unified Effect pipeline).
