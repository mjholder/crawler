# Enemy Attack Patterns (Sequenced Moves + Telegraphing)

**Added:** 2026-06-30
**Summary:** Optional data-driven fixed-sequence move patterns for enemies, layered over the `_perform_action` hook.

## Notes

Every enemy currently has exactly one hardcoded behavior via `_perform_action()` override — no variety turn to turn. This is the enemy-side counterpart to the dual-action combat idea: once the player has more to decide per turn, enemies should too, and telegraphing what's coming gives the player something concrete to react to with their new second action (brace vs. attack vs. defensive spell).

Core structure — fixed sequence, not weighted/random (for v1):

New `EnemyPatternData` resource: an ordered list of "moves," each one modeled after the existing `AttackData` shape (name, target_mode, effects, icon/description) so enemy moves reuse the same Effect subclasses (`DamageEffect`, `StatusEffect`, etc.) already driving player attacks and spells — no new effect system needed.

Enemy gains an optional `pattern: EnemyPatternData` export and an instance-level `_pattern_index: int` cursor. Multiple enemies of the same type in one fight naturally run independent cursors since the index lives on the instance.

Base `_perform_action()` becomes data-driven when a pattern is assigned: read `pattern.moves[_pattern_index]`, apply its effects, advance the cursor (wrapping at the end — loop the sequence).

This is additive, not a replacement for the existing override hook — subclasses that need fully custom/code-driven behavior (boss phase transitions, conditional logic) still override `_perform_action()` directly. Patterns are for the common case; overrides remain for the special case.

Why fixed sequence first, not weighted/reactive:

A weighted pool (move chosen by rolled probability, possibly conditional on HP/state) is more organic but harder to telegraph honestly — you either commit to the roll early and telegraph the result, or show the player a probability, which is a UX problem of its own. A fixed sequence makes telegraphing trivial: "next move" is just `pattern.moves[_pattern_index]` before it's consumed, so the UI can peek at it for free. Weighted/reactive patterns are worth exploring later as a distinct extension, not a v1 requirement.

Telegraphing — **decided (2026-07-01): no explicit peek-ahead HUD.** The original idea here was to surface the upcoming move (icon/label) on the EnemyHUD before the enemy acts. Dropped in favor of **discovery through play**: the player learns a pattern by living through it (the wind-up *animation* and applied status icons are the telegraph), not by reading a "next move" label. This is the deliberate read of the **Combat Feel & Pacing** principle — "visible states telegraph intent without explicitly showing next-turn damage… the player learns what those states mean through experience." `peek_next_move()` stays in code as a harmless accessor (useful for tests/debug) but drives no UI. Note this also weakens the earlier "fixed sequence makes telegraphing trivial" argument for fixed-over-weighted — but fixed sequence stays the v1 choice on its own merits (simpler, learnable, authorable) and weighted/reactive remains the deferred extension.

Deferred / explicitly out of scope for this pass:

Weighted or probability-based move selection.

Patterns that branch based on player state (e.g. enemy reacts to the player having braced last turn) — this couples enemy AI to player action history and is a meaningfully bigger step than a self-contained sequence cursor. Flag as a future extension once dual-action combat and basic patterns both exist.

## Shipped

**(2026-07-01):** `EnemyMoveData` + `EnemyPatternData` resources, the optional `pattern` export + per-instance cursor on `Enemy`, data-driven `_emit_attack()` reusing the existing `Effect` pipeline, `PLAYER`/`SELF` targeting, content-editor schema registration, and a sample skeleton pattern (`skeleton_skirmisher.tscn`). Additive to the `_perform_action()` override hook. See [[design.md]] and [[daily/2026-07-01]].

**Dropped (2026-07-01):** the explicit **telegraphing HUD** — patterns are meant to be learned through play, not read off a label (see the Telegraphing note above). `peek_next_move()` remains as a code-only accessor.

## Remaining

Per-move sound wiring, and the deferred **weighted/reactive** selection extension.
