# Dual-Action Combat (Mainhand / Offhand)

**Added:** 2026-06-30
**Summary:** Split the player turn into two independently-gated per-hand action slots with an explicit End Turn.

## Notes

Combat currently gives the player one action per turn (attack, or a registered weapon action), which makes turns feel flat — click one button, repeat. Proposal: split the turn into two independent action slots, one per hand, gated separately rather than sharing a turn-wide action count.

Structure:

Each hand has its own action(s) and its own "used this turn" flag (`_mainhand_used`, `_offhand_used`), both reset at the start of the player's turn.

Actions can be used in any order — mainhand and offhand aren't sequenced, they're just two independently-gated buttons (or button groups) that disable once spent.

A new End Turn button lets the player explicitly pass — including declining to use a hand at all. Turn no longer auto-ends on the first action; `execute_action` sets a hand's `_used` flag instead of emitting `turn_ended` directly.

Consumables and cantrips keep their existing free-action behavior (no turn cost) — this system only governs mainhand/offhand.

What each hand can grant:

Mainhand: attack (existing), or spell casting for casters.

Offhand: a shield → Brace/Parry (defensive, likely SELF-targeted, possibly a "reduce/negate next incoming hit" duration effect); a second weapon → a second attack-like action; a focus → a second spell slot or a defensive cantrip.

Unarmed is a real loadout, not a null case — bare mainhand and/or offhand grant a baseline punch action rather than nothing.

Two-handed weapons — the open question:

An empty (unequipped) offhand and a locked offhand (from a two-handed weapon) are explicitly not the same outcome. Empty offhand still yields whatever baseline (e.g. unarmed punch) applies. Locked offhand means the two-handed weapon has to compensate for the lost second action somehow — candidate approaches: the weapon grants actions for both "hands" itself (e.g. a heavy swing that occupies the mainhand slot plus a follow-through that occupies the offhand slot), or the weapon's single action is deliberately stronger/more complex to offset losing the second button. Not resolved — needs its own pass once the base two-action system is in.

Complementary idea (separate thread): enemy attack pattern system — giving enemies multiple actions/telegraphed sequences instead of one fixed `_perform_action` — pairs well with this since the player having two actions to allocate makes "what is the enemy about to do" a meaningful thing to react to. Worth exploring together but tracked separately.

Inspiration: Wanting turns to involve more than one meaningful click; existing OFFHAND slot and two-handed lock (shipped in spell system foundation) already gate equipment this way passively — this makes that gating actionable rather than just stat-modifying.

## Shipped

**(2026-07-02):** the two-action framework, per [[design.md]] "Dual-action combat: per-hand action gating, explicit turn end, focus-granted casting" and [[daily/2026-07-02]]. `Player` replaced its single `_actions` registry with per-hand registries (`_hand_actions[Hand]`) gated by `_mainhand_used`/`_offhand_used` (reset in `begin_turn()`). `execute_action(hand, name)` no longer ends the turn — it marks the hand used; the turn ends only via the explicit `end_turn()` (End Turn button or stun `pass_turn()`), now the sole place `_tick_statuses()` + `turn_ended` fire. Hand action sets derive from the held item in `_rebuild_hand_actions()` (attacks + prepared repertoire iff a **focus**, else weapon `innate_spells`; empty hand falls back to a shared unarmed `Punch`). A two-handed weapon locks the offhand and supplies its support action(s) via `offhand_attacks`. `attacks` + `grants_casting` promoted from `WeaponData` to `EquipmentData`. `gui.gd` builds two button groups + End Turn, auto-creating fallback nodes when the scene lacks `MainhandActions`/`OffhandActions`/`EndTurnButton`. Two-action loop play-tested in-game.

## Remaining

Hand-author the CombatHUD dual-action layout in the scene (`MainhandActions` / `OffhandActions` / `EndTurnButton` under `ActionMenu`) to replace the auto-created fallback nodes. v1 keeps offhand actions **non-animating** — animated offhand weapons are deferred to v2 (`_do_attack`/`_do_cast` and equipment signal wiring hardcode the mainhand WEAPON scene). The two-handed-weapon offhand-compensation approach (weapon grants both-hand actions vs. a single stronger action) is still unresolved.
