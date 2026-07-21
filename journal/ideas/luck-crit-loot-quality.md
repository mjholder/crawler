# Luck — Crit Chance & Loot Quality

**Added:** 2026-07-20
**Summary:** LCK drives crit chance (combat) and loot quality (out-of-combat) — explicitly not dodge, keeping AGI as sole dodge owner.

## Notes

LCK drives two things: crit chance (combat) and loot quality (out-of-combat, its non-combat identity). Explicitly NOT dodge — AGI owns dodge exclusively; splitting it muddies both stats' one-job clarity.

**Crit chance = LCK / 100 (linear).** Your crit % is literally your luck number — maximally legible, no hidden constant. Uninvested builds sit ~10% (faint shimmer, not a balance factor); a build that maxes LCK approaches ~100% crit as a genuine heavy-investment payoff — on-brand with soft-gating (you CAN build the crit machine, it just costs your whole stat economy). Linear only works because of the new low-start/high-growth stat system (base ~10, main stat reaches 100 only with real investment, see [[ideas/attribute-distribution-leveling]]); under the old 50 baseline linear gave an absurd 50% floor. Same fix AGI dodge / DEF already got.

**Crit = double the entire hit, one concept:** 2x direct damage AND 2x the *stacks applied*. A crit doesn't separately double DoT tick damage — it doubles what the hit applies, so a 3-burn attack applies 6 burn on a crit (each stack ticks normally). Base multiplier 2x; backgrounds/saints can bend it (e.g. a luck-themed patron). "Doubles the whole hit" beats "doubles damage" — player never has to remember which parts crits touch.

**Every status is stack-based (2026-07-21 — see [[design.md]]).** `stack_policy` was removed; stacks are the single lever, so a crit uniformly doubles the stacks applied. What that means follows each status's cool-down style: a deeper DoT pool for bleed/burn/poison, and — because a decaying status's lifetime *is* its stack count — doubled duration for stuns and buffs (a 1-turn stun → 2, a 3-turn buff → 6). This intentionally reverses the earlier "strict: no duration doubling" rule.

**Loot quality:** LCK improves drop quality. Math deferred — out-of-combat, doesn't tangle with combat tuning.

**Playtest flags**
- Composes multiplicatively with flurry / per-hit-status builds: LCK + light weapon + DoT means many high-crit hits each doubling stacks. Likely a feature (paid for with the whole stat economy) but the interaction to watch when tuning.
- Crit multiplier and the LCK/100 slope are provisional until playtest.

**Synergy note:** retroactively buffs Saint of Ambush T3 (guaranteed crit) — its bleed now doubles too — and rides cleanly on existing gated-bleed logic (a fully-absorbed crit still applies no bleed).

## Shipped

**Crit chance (2026-07-21).** LCK/100 linear crit for attacks and spells, shared damage path.
`Combatant.roll_crit()` + `CRIT_MULTIPLIER` (2.0); `game.gd` rolls once per target and threads a
`crit_mult` into `Effect.apply` so the whole hit doubles — direct damage, and the stacks a status
applies. Covers `DamageEffect`, `StatusEffect`, `ChainDamageEffect`, `GatedBleedEffect` (Saint of
Ambush bleed doubles), and `BuffEffect`. Crit flag rides `take_damage` → `damaged(amount, is_crit,
total_amount)` → a distinct gold `-N!` `DamageNumber` + a combat-log line. Enemies gained a `luck`
export (default 0) so crits can be authored per-enemy later.

**Status model unified on stacks (2026-07-21).** `StatusData.stack_policy`/`StackPolicy` removed;
all statuses are stack-based (cool-down set by `stack_decays` / `burst_on_turn_start`). Crit = ×2
stacks for everything, which reads as a deeper DoT pool or (for decaying stuns/buffs) doubled
duration. `BuffEffect` grants `duration × crit_mult` stacks — "crit buffs" last twice as long.

## Remaining

- **Loot quality** — LCK → drop quality (out-of-combat). Math still deferred.
- **Tuning** — crit multiplier and the LCK/100 slope stay provisional. Class luck baselines (40–55)
  still predate the low-start stat curve, so crit rate sits ~40–55% until
  [[ideas/attribute-distribution-leveling]] retunes them.
- **Saint/background crit-multiplier benders** — hook for a luck-themed patron to shift the 2×.
