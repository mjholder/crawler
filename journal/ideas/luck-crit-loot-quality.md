# Luck — Crit Chance & Loot Quality

**Added:** 2026-07-20
**Summary:** LCK drives crit chance (combat) and loot quality (out-of-combat) — explicitly not dodge, keeping AGI as sole dodge owner.

## Notes

LCK drives two things: crit chance (combat) and loot quality (out-of-combat, its non-combat identity). Explicitly NOT dodge — AGI owns dodge exclusively; splitting it muddies both stats' one-job clarity.

**Crit chance = LCK / 100 (linear).** Your crit % is literally your luck number — maximally legible, no hidden constant. Uninvested builds sit ~10% (faint shimmer, not a balance factor); a build that maxes LCK approaches ~100% crit as a genuine heavy-investment payoff — on-brand with soft-gating (you CAN build the crit machine, it just costs your whole stat economy). Linear only works because of the new low-start/high-growth stat system (base ~10, main stat reaches 100 only with real investment, see [[ideas/attribute-distribution-leveling]]); under the old 50 baseline linear gave an absurd 50% floor. Same fix AGI dodge / DEF already got.

**Crit = double the entire hit, one concept:** 2x damage AND 2x status stacks. Base multiplier 2x; backgrounds/saints can bend it (e.g. a luck-themed patron). "Doubles the whole hit" beats "doubles damage" — player never has to remember which parts crits touch.

Stack-doubling is **strict**: only doubles applied stack count on STACK-policy statuses (crit a 2-stack bleed → 4 stacks). Duration-based / control statuses (stun, etc.) get the 2x damage but NOT doubled duration — keeps luck as a damage/DoT amplifier, not free double-length hard control. (REFRESH / MAX_DURATION policies are under review separately; strict scope sidesteps the "refreshes twice" question either way.)

**Loot quality:** LCK improves drop quality. Math deferred — out-of-combat, doesn't tangle with combat tuning.

**Playtest flags**
- Composes multiplicatively with flurry / per-hit-status builds: LCK + light weapon + DoT means many high-crit hits each doubling stacks. Likely a feature (paid for with the whole stat economy) but the interaction to watch when tuning.
- Crit multiplier and the LCK/100 slope are provisional until playtest.

**Synergy note:** retroactively buffs Saint of Ambush T3 (guaranteed crit) — its bleed now doubles too — and rides cleanly on existing gated-bleed logic (a fully-absorbed crit still applies no bleed).

## Shipped

## Remaining

Everything — this is a design proposal, not yet implemented.
