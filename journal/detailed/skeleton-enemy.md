# Skeleton Enemy — Scene Design

**Date:** 2026-03-01
**Status:** Designed, not yet implemented

This document covers the node tree design, rationale, and sprite/audio behaviour for the Skeleton enemy scene. It is more detailed than a `design.md` entry — the kind of reasoning you want to re-read before touching the scene months from now.

---

## Context

The skeleton is the first concrete enemy type. All five sprite states already exist as rendered pixel art stills:

- `SkeletonIdleFiltered.png`
- `SkeletonWindupFiltered.png`
- `SkeletonSwingFiltered.png`
- `SkeletonHitFiltered.png`
- `SkeletonDeathFiltered.png`

The base enemy infrastructure is in place: `enemy.gd` defines stats, the turn hook (`_perform_action`), extension hooks (`_on_ready`, `_on_damaged`, `_on_death`), and signal emission. The skeleton extends all of this — it does not change the base class.

---

## Node Tree

```
Skeleton            Node2D            scripts/skeleton.gd
├── Sprite          AnimatedSprite2D  named animation states; SpriteFrames resource
├── AnimationSequencer  Timer         drives async sprite state transitions
└── SFX             Node              grouping container, no script
    ├── AttackPlayer    AudioStreamPlayer2D
    ├── HurtPlayer      AudioStreamPlayer2D
    └── DeathPlayer     AudioStreamPlayer2D
```

---

## Node Rationale

### Skeleton (Node2D root)

Script: `skeleton.gd`, which extends `Enemy` (which extends `Node2D`).

Plain `Node2D`, not `Area2D` or `CharacterBody2D`. This is a turn-based game — there is no physics, no collision, no movement. The skeleton is positioned by whoever instantiates the scene. Adding a physics body would be dead weight and noise in the inspector.

### Sprite (AnimatedSprite2D)

Plays named animations from a `SpriteFrames` resource. The resource is configured in the editor with five animations — one per state — each containing a single frame for now:

| Animation name | Source image | Loop |
|---|---|---|
| `idle` | `SkeletonIdleFiltered.png` | yes |
| `windup` | `SkeletonWindupFiltered.png` | no |
| `swing` | `SkeletonSwingFiltered.png` | no |
| `hit` | `SkeletonHitFiltered.png` | no |
| `death` | `SkeletonDeathFiltered.png` | no |

`skeleton.gd` calls `_sprite.play("idle")` etc. — no texture preloads in the script, no texture swapping. The `SpriteFrames` resource owns the asset references.

**Why AnimatedSprite2D over Sprite2D?**

`Sprite2D` with texture-swapping works for still images but treats every state as an identical operation (assign a texture). `AnimatedSprite2D` gives named, intention-revealing state transitions (`play("hit")` is clearer than `_sprite.texture = TEXTURE_HIT`), emits `animation_finished` when a non-looping animation ends (useful once states have multiple frames), and makes adding real frame-by-frame animation later a purely additive change — just load more frames into the existing animation in the `SpriteFrames` resource, no script changes.

It also makes visual effects straightforward: scaling the sprite (zoom in on an attack), modulating its colour (red flash on hit), or tweening any property is done directly on the node with `create_tween()` and targets `_sprite.scale`, `_sprite.modulate`, etc. None of that requires a different node type.

**Single-frame timing note:** For now, all non-looping animations have one frame, so `animation_finished` fires immediately after `play()`. State sequencing (windup → swing → idle) is still driven by the `AnimationSequencer` Timer. When animations gain real frames, the Timer delays can be tuned or replaced with `animation_finished` connections.

### AnimationSequencer (Timer)

One-shot timer that drives the sprite state sequence *after* a turn ends. It does not block the turn loop.

See **Animation Timing** below for why this exists.

Properties:
- `one_shot = true` — each phase re-starts the timer explicitly; it does not loop.
- `autostart = false`

### SFX (Node)

A bare grouping `Node` with no script. Its only purpose is to keep the three audio players off the root level, making the node tree readable in the editor. It carries no logic.

### AttackPlayer / HurtPlayer / DeathPlayer (AudioStreamPlayer2D)

One player per sound type so they can't cut each other off. All three have no stream assigned at scene creation — no SFX files exist yet. `skeleton.gd` null-guards every play call: `if player.stream != null: player.play()`. Nothing breaks while the audio files are absent.

**Why AudioStreamPlayer2D and not AudioStreamPlayer?**

`AudioStreamPlayer2D` attenuates and pans based on the node's position relative to the audio listener. In a dungeon crawler the skeleton will have a position in 2D space, so spatial audio is appropriate. It costs nothing at prototype scale and avoids a node-swap refactor later when spatial audio actually matters.

The combat ambient track (`skyrim---combat-2.wav`) is NOT placed here. It's ambient/background and belongs on `Game` or `CombatEvent`, not on a per-enemy node.

---

## Animation Timing

`turn_ended` is emitted by `enemy.gd`'s `_process()` function, not inside `take_turn()`. This allows animation sequences to gate the turn — the signal only fires once the enemy returns to `IDLE` (or `DEAD`).

**How it works in `enemy.gd`:**

```gdscript
var _turn_pending: bool = false

func take_turn(target: Node) -> void:
    if is_dead:
        return
    _turn_pending = true
    _perform_action(target)
    # turn_ended is NOT emitted here

func _process(_delta: float) -> void:
    if _turn_pending and _is_turn_complete():
        _turn_pending = false
        turn_ended.emit()

func _is_turn_complete() -> bool:
    return true  # default: fires on next frame; subclasses override
```

Skeleton overrides the hook:

```gdscript
func _is_turn_complete() -> bool:
    return _state == State.IDLE or _state == State.DEAD
```

`game.gd` is unchanged — it still connects to `turn_ended` and doesn't care when it fires. Simple enemies that don't override `_is_turn_complete()` still end their turn on the very next frame (imperceptibly instant). The skeleton holds the turn until its animation sequence completes naturally.

**Three options were considered:**

**Option A — `await` inside `_perform_action`** — Rejected: makes every future enemy a coroutine, invasive base class change.

**Option B — emit `turn_ended` manually from `skeleton.gd`** — Rejected: breaks the signal contract; `CombatEvent` and `game.gd` must be able to trust that `turn_ended` always comes from the base class.

**Option C (chosen) — `_process()` + `_is_turn_complete()` hook** — Base class owns the emission timing, subclasses declare readiness through a clean override. The turn is genuinely held until the animation is done.

**`animation_finished` and the Timer's future:** The `AnimationSequencer` Timer currently drives the windup → swing → idle sequence and controls display duration. Once animations have real frames, `animation_finished` can replace the Timer entirely — when the last frame of `swing` plays, `_transition(State.IDLE)` is called, `_is_turn_complete()` returns true, and `turn_ended` fires. No structural changes needed.

---

## Enemy State

`AnimatedSprite2D` owns animation state natively — `_sprite.play("hit")` is both the instruction and the record. There is no need to mirror that in a parallel sprite enum.

What the script *does* need is a behavioral state enum, which serves a different purpose: game logic decisions that are independent of whichever animation is currently playing.

```gdscript
enum State { IDLE, ATTACKING, HIT, DEAD }
var _state: State = State.IDLE
```

This is used for:

- **Turn gating** — `_is_turn_complete()` returns `_state == State.IDLE or _state == State.DEAD`, which is what `enemy.gd`'s `_process()` checks before emitting `turn_ended`. The turn is held as long as the skeleton is in any other state.
- **Interrupt detection** — `_on_damaged` checks `if _state == State.ATTACKING` to know whether to cancel the `AnimationSequencer` Timer before playing the hit reaction.
- **Guard clauses** — hooks can return early if `_state == State.DEAD` to prevent stacking reactions on a dying enemy.
- **Future logic** — e.g. a skeleton variant that takes reduced damage while attacking, or prevents certain actions during a hit stun.

The animation name and the state value are kept in sync by `_transition(next_state: State)`, which sets `_state` and calls the matching `_sprite.play()`. They always move together but serve different masters: one for logic, one for visuals.

---

## Inspector Defaults

These are set in `skeleton.tscn`, not hardcoded in `skeleton.gd`. They remain `@export` vars on the base `Enemy` class, so different skeleton variants (armoured, archer, etc.) can share the same script with different inspector values.

```
enemy_name      = "Skeleton"
max_health      = 20.0
attack_damage   = 6.0
experience_value = 15
```

---

## What skeleton.gd Does NOT Override

| Method | Reason |
|---|---|
| `take_turn()` | Base handles `is_dead` guard and `turn_ended` emission — these must stay there |
| `take_damage()` | Base handles health subtraction, `damaged` signal, and calling `_die()` |
| `_die()` | Base handles `is_dead = true`, calls `_on_death()`, then emits `died` — this order is correct for the skeleton |

---

## Future Considerations

- **Adding SFX:** Assign an `AudioStream` to any of the three players in the inspector. No code changes needed.
- **Multiple frames per state:** Add frames to the relevant animation in the `SpriteFrames` resource. Set an appropriate FPS. The Timer delays can then be tuned to match, or replaced with `animation_finished` connections — no structural changes.
- **Visual effects:** Tween `_sprite.scale` for a zoom punch on attack, tween `_sprite.modulate` for a red flash on hit, tween `_sprite.modulate.a` to zero for a death fade. All done with `create_tween()` in the relevant hook, targeting the `AnimatedSprite2D` node directly.
- **Skeleton variants:** Subclass `Skeleton` for meaningful behaviour differences (e.g. a skeleton that sometimes skips the windup and attacks twice). For stat-only variants (armoured skeleton), just reuse `skeleton.gd` with different inspector values and a different `SpriteFrames` resource assigned in the scene.
- **Reaction windows / parry prompts:** If these are ever needed, the async turn loop change belongs on `enemy.gd` and `CombatEvent`, not here. The skeleton scene just needs its `_perform_action` to emit a signal the event can hook into.
