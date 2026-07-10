# Consecutive-attack dodge decay (per-round)

**Added:** 2026-07-05
**Summary:** AGI dodge chance halves per successful dodge within a round, resetting each round; shipped 2026-07-07 with nothing left.

## Notes
AGI-based dodge currently reads as more satisfying than DEF-based mitigation (binary dodge event vs. quiet flat damage reduction) — partly a starting-numbers issue, but also likely an inherent property of discrete vs. smooth defensive math worth keeping in mind separately. This idea addresses a related but distinct problem: uncapped flat dodge chance lets a high-AGI build occasionally no-sell an entire multi-attack round through variance, which undercuts the 5–8 turn attrition-based pacing goal.

Proposed fix: dodge chance halves after each successful dodge against the player within the same round, regardless of source — e.g., a 3-enemy round at 100% dodge: first attack rolls at 100% and is dodged, chance drops to 50% for the second, dodged again drops to 25% for the third, which lands. Resets to full at the start of the next round. Applies identically whether the pressure comes from multiple enemies or a single enemy's multi-attack move within one turn.

Only a successful dodge triggers the decay — an attack that misses for an unrelated reason (e.g. enemy-side accuracy debuff like blind) does not halve dodge chance, since the decay represents the player's own evasion being read/exploited, not just attack volume.

This gives evasive builds a strong, satisfying early-round payoff while preventing "untouchable" degenerate cases, and creates a legible counterplay axis for enemy design — an enemy (or encounter) with several attacks per turn becomes specifically good into AGI-heavy builds without being a hard counter, fitting the "some builds are naturally favored, nothing absolute" enemy philosophy. Pairs with the sparring-partner "evasive skirmisher" archetype already scoped.

Also flagged: this doesn't resolve the deeper open question of whether dodge (binary) and mitigation (smooth) should even be structurally symmetric, or whether AGI and DEF are meant to feel different on purpose — separate thread, likely folded into the balance-legibility baseline work once base stats/growth rates are revisited.

## Shipped
**(2026-07-07):** `Player._roll_dodge()` now halves dodge chance per successful dodge already made that round (`_dodge_streak`, reset in `begin_turn()`); only a *successful* dodge decays it. Shipped alongside the DEF→armor rework. See [[design.md]] "DEF is a refreshing per-round armor buffer; AGI dodge decays within a round" and [[daily/2026-07-07]].

## Remaining
None — shipped and closed.
