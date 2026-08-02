# Weapon Anatomy — Power and Scaling as Two Tunable Axes

**Added:** 2026-07-28
**Summary:** Split weapon damage into two authored numbers on `WeaponData` — flat `power` and stat-coefficient `scaling` — so attacks own only the shape and one weapon-level change re-tunes all its attacks coherently.

## Notes
A weapon's damage is composed from two authored numbers rather than baked into the
attack's damage expression. `power` (flat) and `scaling` (stat coefficient) live on
`WeaponData`; attacks own only the shape.

Requires exposing weapon-side variables to `StatExprEval` alongside the stat vars.
Shared attack effects get rewritten as ratios:
```
chop_damage.tres   -> "power * 1.2 + strength * scaling"
slash_damage.tres  -> "power * 0.8 + strength * scaling"
```
Battle Axe (power 20, scaling 0.5) then yields Chop `24 + STR*0.5`, Slash `16 + STR*0.5`.
One weapon-level change re-tunes all its attacks coherently instead of drifting
per-effect. No new resources per weapon, no duplicated effects.

**One-stat-one-job.** Each weapon declares exactly one scaling stat. Daggers scale AGI,
axes scale STR, no weapon sums two. This survives at the read site: you look at the
weapon and know which stat matters. Retroactively legitimizes `flail_damage.tres`
(`"agility * 0.6"`), which had already drifted this way in content ahead of the
doctrine.

**Do NOT nerf the AGI coefficient to price in dodge** (rejected AGI/4 vs STR/2). The
dodge-streak halving ([[ideas/consecutive-attack-dodge-decay]]) already caps AGI's
defensive value within a round, and a visibly worse coefficient makes AGI weapons feel
bad in the exact number the player reads every turn. Differentiate on `power` instead —
daggers get low power with an equal scaling rate, and find their payoff in riders
(bleed, poison stacks) rather than raw numbers. Same legible math, better fit for AGI's
identity.

**THE LAW: smithing only ever moves `power`. Rarity only ever moves `scaling`.** A
fully-upgraded common can never become a rare, the two systems can't collapse into each
other, and max upgrade level per rarity tier falls out as a natural cap rather than a
bolted-on rule.

**Item instances, not duplicated resources.** A looted "Fine Balance Battle Axe +2"
can't be a `.tres` on disk. Rejected: `duplicate()` the base and mutate it (fat saves,
and base-weapon rebalances never reach items already in a save). Chosen shape: a
runtime instance holding a ref to the base `WeaponData` plus `upgrade_level` and rolled
tags, composed at read time into effective power/scaling. Saves stay small, rebalancing
propagates to existing items, and the content editor only ever authors bases and tags.

**Open:** attack preview must show composed math, not authored math — the overlay
should read the instance's effective numbers so a +2 axe displays `24 + STR*0.5`, not
the base 20. `compute_attack_preview` needs the instance, not just
`attack_data + source_stats`. Extends the preview work in
[[ideas/player-facing-legibility]].

**Open:** smith transfer/reforge — move a tag from a beloved old weapon into a
higher-tier one, consuming the old. Makes investment portable and turns replacing a
favorite into a decision rather than a loss.

**Open:** whether ratio-per-attack lives on `AttackData` or stays embedded in the
effect expression string.

**Open:** spells sit outside this entirely (flat authored damage, no stat term) — see
[[ideas/mana-as-capacity]].

## Shipped
Phase 17 (2026-07-31) — see [[architecture.md]] §4, [[daily/2026-07-31]].
- `power`/`scaling`/`scaling_stat` on `WeaponData`, exposed to `StatExprEval` via an optional
  `context` dict (neutral `scale` var binds the weapon's declared scaling stat).
- Shared + inline attack effects rewritten as ratios `power * K + scale * scaling`; the 7 damage
  weapons authored with power/scaling. `Effect.apply()` threads `context` end-to-end.
- Runtime `ItemInstance` (base ref + `upgrade_level` + `rarity` + tags) composing effective
  power/scaling at read time; saves store instance dicts (legacy string fallback).
- Smithing (power-only) and rarity (scaling-only) as the two mutation paths — THE LAW enforced in
  the `ItemInstance` accessors. Code/debug API only (`smith`/`set_rarity`), no smithy UI.
- Preview reads composed numbers: `AttackPreview.compute` derives weapon context internally, and
  `humanize_expression` renders `power + scale * scaling` as `20 + STR × 0.5`.
- **Resolved — ratio placement (updated 2026-08-01):** the per-attack coefficient K is now an
  authored field `AttackData.power_coefficient` (default 1.0), surfaced to expressions as the `coeff`
  var, so every weapon hit is the uniform `power * coeff + scale * scaling`. (Initially K lived baked
  in the expression string; moved onto `AttackData` when K became a **buffable** knob — see below.)
- **Shipped 2026-08-01 — K is a buffable knob.** All attacks flattened to K=1.0; `coeff` resolves per
  hit as `(power_coefficient + Σ coefficient_add) * Π coefficient_mult` from active statuses
  (`Combatant.get_attack_coeff_add`/`_mult`). `AttackCoeffBuffEffect` (`ADD`/`MULTIPLY`) authors both
  buff kinds; preview hides `coeff` at 1.0 and shows it when buffed. See [[daily/2026-08-01]].

## Remaining
- **Smith transfer/reforge** — move a tag from an old weapon into a higher-tier one, consuming the
  old. Still open (needs the smithy UI + economy hook, deliberately parked).
- Loot-quality (LCK) roll odds that would populate rolled tags on drops — parked in
  [[ideas/luck-crit-loot-quality]]; nothing generates non-default instances yet.
- Spells stay outside this system (flat authored damage, no stat term) — see
  [[ideas/mana-as-capacity]].
