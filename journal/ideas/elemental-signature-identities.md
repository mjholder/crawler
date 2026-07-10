# Elemental signature identities — Poison, Fire, Lightning, Frost

**Added:** 2026-07-08
**Summary:** Concrete mechanics for four elemental signatures (Poison/Fire/Lightning/Frost); systems shipped, `.tres` content unauthored.

## Notes
Refines the signature-status column of the "Elemental caster kits" matrix above with concrete mechanics for four elements, settling several open questions from that entry.

**Poison** — classic stacking DoT. No changes needed: `stack_policy: STACK` already spawns independent ticking instances, so multiple applications naturally stack as several simultaneous flat ticks. Blight already leans on this.

**Fire (burn)** — burst DoT, replaces the shipped flat-tick version. Front-loaded damage that decays as the status runs out rather than a flat number every turn: at 3 stacks it hits for 3, decays to 2 and hits for 2, decays to 1 and hits for 1, then expires. Needs `on_tick`'s damage expression to read the status's own `turns_remaining` (not currently exposed to `StatExprEval` — today's `DamageEffect` only sees stat values + `max_health`/`health`). Once exposed, this is pure authoring: `duration: 3`, `on_tick: DamageEffect("turns_remaining")`, `stack_policy: REFRESH` (reapplying mid-burn re-ignites back to 3, correct "refresh" behavior). Sharpens the existing Fire-is-burst / Blight-is-attrition split already implicit in the matrix rather than introducing a new axis. To verify at implementation: whether `on_tick` reads `turns_remaining` before or after that turn's decrement (the first tick needs to see 3, not 2).

**Lightning** — chains to one random adjacent enemy at half damage. "Adjacent" = array-index-adjacent in the wave's enemy list (no real battlefield-position system exists, so this is the pragmatic placeholder — revisit only if a real formation system ever gets built). Can't be authored as two independent list effects, since `Effect.apply(source, target)` has no way to see the rest of the enemy roster — needs a self-contained effect that resolves the primary hit and internally reaches into the current `CombatEvent`'s enemy list to find and half-damage a neighbor. Small new plumbing (an Effect needing roster access, which nothing today requires), not a targeting-system change — the player still picks one target through the existing single-target flow.

**Ice / Frost** — merged into one element, chill dropped. The signature mechanic is just armor-pierce — no separate DoT/debuff needed. Pierce is a damage-shape property, not an inherently magical one, so it's not locked to a caster kit — mundane weapons can carry it too. Frost-as-caster-flavor can still exist later purely for itemization around the same generic pierce tag, without pierce being exclusive to it. Simplifies what the still-deferred magic-type roster pass has to account for.

## Shipped
**(2026-07-09):** the *systems*, ready for `.tres` authoring (no content authored yet). Fire → `BurstDamageEffect` (scales by `turns_remaining` via the new `Effect.apply_tick` hook). Lightning → `ChainDamageEffect` (arcs to the array-adjacent enemy via the scene tree). Frost → armor `pierce` threaded through `take_damage`/`_apply_defense` + `DamageEffect.pierce_expression`. Poison already worked (`STACK`). See [[design.md]] "Elemental & martial status-verb systems" and [[daily/2026-07-09]].

## Remaining
Author the actual element `.tres` (burst burn, chain bolt, pierce weapons/spells) + balance.
