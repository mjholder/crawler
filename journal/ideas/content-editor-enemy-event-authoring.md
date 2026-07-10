# Content editor — enemy and event authoring support

**Added:** 2026-05-21
**Summary:** Bring enemy and event authoring into the content editor so the full encounter loop runs outside Godot.

## Notes
The tool currently covers equipment, attacks, effects, blessings, and classes. Enemies and events are the other major authoring surface — making a new enemy means setting stats, AI behavior, drops, and wiring it into an event; making a new event means defining waves, rewards, and any special scripting. Both involve enough cross-resource wiring that the inspector is genuinely painful. Adding them to the content editor would let the full encounter design loop (enemy stats → event composition → shop/reward tuning) happen outside Godot.

## Shipped
- Event authoring — `EventEditor` with per-type forms (Combat / Dialogue / SkillCheck / Rest) via the `.tres`-wraps-JSON wrapper pattern (see [[design.md]] "Events exposed in content editor", 2026-05-22).
- Enemy Patterns / Enemy Moves sidebar entries (`EnemyMoveData` authoring) added 2026-07-03 (see [[daily/2026-07-03]]).

## Remaining
- Enemy authoring — there is no dedicated enemy editor; enemies are only referenced inside `CombatEventForm`. Need a form for stats, AI behavior, and drops.
