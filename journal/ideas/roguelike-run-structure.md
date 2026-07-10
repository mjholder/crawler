# Roguelike Run Structure

**Added:** 2026-02-22
**Summary:** Design pillar: run-based multi-floor descent with themed floors and four core encounter types, kept theme-agnostic and data-driven.

## Notes
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
