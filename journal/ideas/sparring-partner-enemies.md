# Sparring-Partner Enemy Archetypes (for balance testing)

**Added:** 2026-06-28
**Summary:** A small purpose-built enemy roster, each exercising one stat axis, that doubles as a tuning harness and real content.

## Notes

Trial-and-error balance needs enemies that *exercise* specific mechanics, not just stat blocks. A small purpose-built roster doubles as a tuning harness and as real content; each archetype maps to a stat axis, so it also serves as a legibility check (if a DEF build can't survive the glass cannon, DEF is undervalued):
- **Glass cannon** — high damage, low HP/DEF; punishes no-defense builds, rewards stuns/burst/dodge.
- **DoT-immune brute** — high HP, ignores poison/burn/bleed; forces direct damage, counters pure attrition.
- **Buffer / support** — buffs allies or shields itself; makes the player value `weaken`, stuns, and priority targeting (the "respond to enemy intent" goal in [[ideas/combat-feel-and-pacing]]).
- **Evasive skirmisher** — high AGI, hard to hit; rewards accuracy / `mark` and AOE that doesn't rely on landing single hits.
- **Enrager / wind-up** — telegraphs a big hit over several turns (the brace-before-the-hit decision from [[ideas/combat-feel-and-pacing]]).

Enemy authoring isn't in the content editor yet (see [[ideas/content-editor-enemy-event-authoring]]), so these would be hand-written `.tres` for now.

## Shipped

Nothing from this roster. A `skeleton_skirmisher.tscn` exists (2026-07-01), but it is a sample demonstrating the enemy attack-pattern *system*, not one of these balance-testing archetypes.
