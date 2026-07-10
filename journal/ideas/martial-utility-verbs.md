# Martial utility verbs — Bleed, Shatter, Brace

**Added:** 2026-07-08
**Summary:** Non-magic verb set (Bleed/Shatter/Brace) mirroring the elemental matrix; systems shipped, `.tres` content and Sentinel kit unauthored.

## Notes
Non-magic counterpart to the elemental caster matrix — same discipline (a small repeatable verb set, tuned once, reused across weapon types/classes) applied to martial classes instead of casters. Natural home for the still-open Sentinel shield-kit design pass (shield bash inflicting Shatter, Brace as the Sentinel's signature stance).

**Bleed** — deliberately built to feel different from Poison, not a reskin:
- *Gated application.* Only applies if the triggering hit actually reduces HP — fully-absorbed hits don't bleed; overflow past armor, or an explicit pierce, does. Can't be authored as a `DamageEffect` + `StatusEffect` side by side in an attack's effects list (no shared awareness between them today) — needs a single composite effect that deals damage, checks HP before/after, and only then applies the status. Same check makes "big/piercing hits still bleed" fall out for free, and creates a combo lever — pierce + bleed on one attack reliably bleeds a fully-armored target a normal hit couldn't touch.
- *Doesn't tick down.* Reuses the existing `duration: -1` (permanent) convention already used internally for on-equip statuses — likely free, assuming `_tick_statuses()` treats `-1` the same regardless of source. Traded against the harder application gate.
- *Weaker from enemies.* Pure balance/authoring — enemy moves already can't scale off STR (enemies only expose DEFENSE as a real stat), so enemy numbers are hand-tuned literals already. No new mechanism.
- *Cure path.* Needs a way off since it doesn't expire — a dedicated cure consumable, or folding `remove_status` onto an existing heal item. Decide per-item later.

**Shatter** — suppresses armor refresh for X rounds. `refresh_armor()` is only called from two places (`player.begin_turn()`, `CombatEvent._on_round_started()`), so a suppression flag just needs those two sites to check it first. Symmetric — usable by the player against armored enemies or by enemies against the player. Structural sibling to pierce (pierce bypasses one hit; Shatter denies the safety net for a stretch) — burst-through vs. lockout, not a duplicate. Pairs with a "shatter brute" sparring archetype as the DEF-stacking counter-test.

**Brace** — a one-round armor bonus. Adds flat armor directly to current armor (clamped to max) and raises `max_armor` for that round, touching those fields directly rather than routing through a stat buff or `refresh_armor()`. Works as a bonus on a normal refresh, and as a way to claw back armor when Shatter has suppressed the round's refresh — giving Brace and Shatter a legible counter-relationship.

## Shipped
**(2026-07-09):** the *systems*, ready for `.tres` authoring (no content authored yet). Bleed → `GatedBleedEffect` (deals damage, applies its status only if HP actually dropped; combos with `pierce`). Shatter → `StatusData.suppresses_armor_refresh` gating `refresh_armor()` (symmetric player/enemy). Brace → `BraceEffect` (raises `max_armor`/`armor` directly, resets on next refresh). Bleed's status reuses `duration:-1` + `persistence:COMBAT`. See [[design.md]] "Elemental & martial status-verb systems" and [[daily/2026-07-09]].

## Remaining
Author the `.tres` (bleed weapon/status, shatter status + shield-bash, brace stance), Sentinel shield-kit pass, Bleed cure path, balance.
