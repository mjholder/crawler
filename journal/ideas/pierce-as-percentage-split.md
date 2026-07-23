# Pierce as a percentage split instead of a flat armor reduction

**Added:** 2026-07-23
**Summary:** Replace flat pierce (armor - pierce) with a two-stream split: a ratio of the hit goes straight to HP, the remainder hits armor normally.

## Notes

Current pierce reduces how much armor can absorb a hit (`effective_armor = armor - pierce`),
which means it does nothing unless the hit was already near-overflowing. Pierce 5 vs 20 armor on
a 10-damage hit = zero HP damage. The tag promises flesh damage and pays out only on hits that
were mostly getting through anyway — backwards, since pierce should matter most against a fat
buffer. Flat pierce also fails to auto-scale across acts, which was the whole reason the
[[ideas/def-refreshing-ward]] rework beat percentage mitigation.

Replace with a two-stream split. Pierce ratio of the hit goes straight to HP and never touches
armor; the remainder hits the buffer normally and overflows to HP if the buffer is spent.
Example: 20 damage, 50% pierce, enemy at 5 armor → 10 straight to HP; of the other 10, 5 is
absorbed and 5 overflows. 15 total to HP, armor drained to 0. Pierce is a strict upgrade — it
can never reduce total damage vs. an unarmored target.

Armor drains only by the absorbed portion, which preserves the current "pierce bypasses, doesn't
consume" intent with no special case.

Rounding: `to_hp = floor(amount * ratio)`, remainder to armor. Uniform and defender-favored at
every tier — 5 damage at 50% = 2 HP / 3 armor, at 75% = 3 HP / 2 armor. Works on floats, so no
need to commit to integer damage. At 100% the floor is a no-op.

Authored granularity restricted to quarters (25/50/75/100) to keep mental math at halving and
quartering; 100% reads as "ignores armor entirely" for the high end. Multiple sources clamp at
1.0. Upgrading pierce in 25% batches is the intended progression axis for weapons/enchants.

Known consequence: truncation creates a soft damage threshold per tier. 25% pierce needs a 4+
hit to do anything, 50%/75% need 2+. A flurry of 1-damage hits gets no pierce at all — accepted
deliberately (tiny hits shouldn't effectively have 100% pierce), but it means low-damage
multi-hit weapons shouldn't carry low pierce tiers. Authoring consideration, not a bug.

Touches: `Player._apply_defense` / `Enemy._apply_defense`, `take_damage` signatures (pierce
becomes a ratio, not an amount), `DamageEffect.pierce_expression`, and any authored `.tres` using
pierce. Frost/Ice identity is the main consumer — percentage pierce reads much better as "cold
reaches the bone" than a flat number did (see [[ideas/elemental-signature-identities]]). Shatter
stays distinct: shatter opens a window by suppressing refresh, pierce is a constant tax (see
[[ideas/martial-utility-verbs]]).

## Shipped

**2026-07-23** — Full mitigation-signature change. `_apply_defense` on Player and Enemy now does
the two-stream split (`to_hp = floor(amount * clamp(pierce, 0, 1))`, remainder to armor);
`pierce_expression` on `DamageEffect`/`ChainDamageEffect`/`GatedBleedEffect` is reinterpreted as a
0–1 ratio (default 0.5, clamped). Attack tooltips surface it (`… = N damage · 50% armor pierce`).
`lunge.tres` migrated to `0.5`. Sidecar linter warns on out-of-`[0,1]` numeric pierce literals;
content-editor USER_GUIDE documents the field. See [[design.md]] — Pierce is a percentage split.

## Remaining

Pierce-ratio authoring on weapons/enchants as a 25%-batch progression axis, and Frost identity
`.tres` tuning (its main consumer) — folded into [[ideas/elemental-signature-identities]].
