# Enemy System Design

**Date:** 2026-03-01 (consolidated 2026-04-18)
**Status:** Implemented

Consolidated from: `skeleton-enemy.md`

---

## Overview

All enemies extend the base `Enemy` class (`enemy.gd`). The base class owns the turn hook, turn gate, extension hooks, and signal emission. Subclasses declare their behavioral state machine, override `_is_turn_complete()`, and implement `_perform_action()`. They do not touch `take_turn()`, `take_damage()`, or `_die()`.

CombatEvent signal wiring (how enemies are connected to the event) is documented in [[detailed/event-system.md]].

---

## Base Enemy Class — `enemy.gd`

### State

```gdscript
class_name Enemy
extends Node2D

@export var enemy_name: String = ""
@export var max_health: float = 20.0
@export var attack_damage: float = 5.0
@export var experience_value: int = 10

var health: float
var is_dead: bool = false
var _turn_pending: bool = false
```

### Signals

```gdscript
signal attack(damage: float)
signal damaged(amount: float)
signal died
signal turn_ended
```

### Turn Hook Pattern

```gdscript
func take_turn() -> void:
    if is_dead: return
    _turn_pending = true
    _perform_action()
    # turn_ended is NOT emitted here

func _perform_action() -> void:
    pass  # virtual — subclasses override

func _process(_delta: float) -> void:
    if _turn_pending and _is_turn_complete():
        _turn_pending = false
        turn_ended.emit()

func _is_turn_complete() -> bool:
    return true  # default: fires on next frame; subclasses override
```

`game.gd` calls `enemy.take_turn()` uniformly for all enemy types. It connects to `turn_ended` and does not care when it fires — simple enemies that don't override `_is_turn_complete()` end their turn on the very next frame.

**Why `_process()` + hook instead of `await`:** `await` inside `_perform_action` makes every subclass a coroutine — an invasive base class change. Emitting `turn_ended` manually from subclasses breaks the signal contract; `CombatEvent` must trust that `turn_ended` always comes from the base class. The `_process()` hook keeps ownership clean: base class emits, subclass declares readiness.

### Extension Hooks

Do nothing in the base class. Safe to override. Leading underscore follows the equipment extension pattern.

```gdscript
func _on_ready() -> void:
    pass

func _on_damaged(amount: float) -> void:
    pass

func _on_death() -> void:
    pass
```

### Damage and Death

```gdscript
func take_damage(amount: float) -> void:
    if is_dead: return
    health -= amount
    damaged.emit(amount)
    _on_damaged(amount)
    if health <= 0.0:
        _die()

func _die() -> void:
    is_dead = true
    _on_death()
    died.emit()
```

`_die()` sets `is_dead = true`, calls `_on_death()`, then emits `died`. This order is intentional — subclasses can inspect `is_dead` in `_on_death()` and the signal fires last so listeners see the final state.

### Inspector Defaults

Set in the subclass scene, not hardcoded in `enemy.gd`. All are `@export` so different variants can share the same script with different inspector values.

---

## Skeleton — Concrete Enemy

**Date:** 2026-03-01 (updated 2026-04-17)

The first concrete enemy type. Extends `Enemy` with a full behavioral state machine, a multi-phase AnimationPlayer attack, and turn gating via `_is_turn_complete()`.

### Node Tree

```
Skeleton            Node2D            scripts/skeleton.gd
├── Sprite          AnimatedSprite2D  named animation states; SpriteFrames resource
├── AnimationPlayer AnimationPlayer   sequences multi-phase animations (attack)
└── SFX             Node              grouping container, no script
    ├── AttackPlayer    AudioStreamPlayer2D
    ├── HurtPlayer      AudioStreamPlayer2D
    └── DeathPlayer     AudioStreamPlayer2D
```

### Node Rationale

**Skeleton (Node2D root)** — Plain `Node2D`, not a physics body. Turn-based game — no physics, collision, or movement.

**Sprite (AnimatedSprite2D)** — Named animation states over `Sprite2D` + texture-swapping: intention-revealing transitions (`play("hit")` vs `_sprite.texture = TEXTURE_HIT`), emits `animation_finished` for non-looping animations, and adding multi-frame animation is purely additive — add frames to the `SpriteFrames` resource, no script changes.

**AnimationPlayer** — Owns the multi-phase attack sequence. The `"attack"` animation has two method call tracks:
- `t=0`: calls `_sprite.play("windup")`
- `t=N`: calls `_sprite.play("swing")` (N tuned in editor)

When finished, `_on_anim_player_finished()` calls `_transition(State.IDLE)`.

Single-state animations (`hit`, `death`) are played directly on `AnimatedSprite2D` — no `AnimationPlayer` involvement.

**SFX (Node)** — Bare grouping container. One AudioStreamPlayer2D per sound type so they can't cut each other off. `AudioStreamPlayer2D` (not 2D-less) for spatial audio — appropriate for a positioned enemy in 2D space.

All play calls are null-guarded: `if player.stream != null: player.play()`. Nothing breaks while audio files are absent.

### Behavioral State Machine

```gdscript
enum State { IDLE, ATTACKING, HIT, DEAD }
var _state: State = State.IDLE
```

Used for:
- **Turn gating** — `_is_turn_complete()` returns `_state == State.IDLE or _state == State.DEAD`
- **Interrupt detection** — `_on_damaged` checks `if _state == State.ATTACKING` to stop the `AnimationPlayer`
- **Guard clauses** — hooks return early if `_state == State.DEAD`

`_transition(next: State)` keeps animation name and state in sync:

```gdscript
func _transition(next: State) -> void:
    _state = next
    match _state:
        State.IDLE:      _sprite.play("idle")
        State.ATTACKING: _anim_player.play("attack")   # AnimationPlayer drives windup → swing
        State.HIT:       _sprite.play("hit")
        State.DEAD:      _sprite.play("death")
```

### SpriteFrames Animations

| Animation | Source image | Loop |
|---|---|---|
| `idle` | `SkeletonIdleFiltered.png` | yes |
| `windup` | `SkeletonWindupFiltered.png` | no |
| `swing` | `SkeletonSwingFiltered.png` | no |
| `hit` | `SkeletonHitFiltered.png` | no |
| `death` | `SkeletonDeathFiltered.png` | no |

`windup` and `swing` are not called directly from script — the `AnimationPlayer`'s method call tracks drive them at the right times.

### Node Wiring

```gdscript
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer

func _on_ready() -> void:
    _anim_player.animation_finished.connect(_on_anim_player_finished)
    _sprite.animation_finished.connect(_on_sprite_animation_finished)
    _transition(State.IDLE)

func _on_anim_player_finished(_anim_name: StringName) -> void:
    _transition(State.IDLE)

func _on_sprite_animation_finished() -> void:
    if _state == State.HIT:
        _transition(State.IDLE)
```

### `_perform_action()` Override

```gdscript
func _perform_action() -> void:
    if _attack_player.stream != null: _attack_player.play()
    _transition(State.ATTACKING)   # triggers AnimationPlayer "attack"
    attack.emit(attack_damage)
```

### Extension Hook Overrides

```gdscript
func _on_damaged(amount: float) -> void:
    if _hurt_player.stream != null: _hurt_player.play()
    if _state == State.ATTACKING:
        _anim_player.stop()        # interrupt attack
    _transition(State.HIT)

func _on_death() -> void:
    if _death_player.stream != null: _death_player.play()
    _transition(State.DEAD)
```

### Inspector Defaults

Set in `skeleton.tscn`, not hardcoded in `skeleton.gd`:

```
enemy_name       = "Skeleton"
max_health       = 20.0
attack_damage    = 6.0
experience_value = 15
```

### What skeleton.gd Does NOT Override

| Method | Reason |
|---|---|
| `take_turn()` | Base handles `is_dead` guard and `_turn_pending` flag — must stay there |
| `take_damage()` | Base handles health subtraction, `damaged` signal, and calling `_die()` |
| `_die()` | Base handles `is_dead = true`, calls `_on_death()`, emits `died` — order is correct |

---

## Extension Pattern for New Enemies

**Inspector-only variant (stat/visual differences only):** Reuse `skeleton.gd` with different `@export` values and a different `SpriteFrames` resource in the scene. No new script needed.

**Behavioral subclass (different AI or attack pattern):** Extend `Skeleton` or `Enemy` directly. Override:
- `_perform_action()` — what the enemy does on its turn
- `_is_turn_complete()` — when the turn ends (if animations differ from the base)
- `_on_damaged()` — interrupt logic if needed
- `_on_death()` — death effect if needed

Do **not** override `take_turn()`, `take_damage()`, or `_die()` — these own the core contract.

For a subclass that needs different animation timing, override `_is_turn_complete()` to match the new state machine. The base `_process()` loop requires no changes.

---

## Future Considerations

- **Adding SFX:** Assign an `AudioStream` in the inspector. No code changes needed.
- **Multiple frames per state:** Add frames to `SpriteFrames`, set FPS. Attack sequence timing tuned in the AnimationPlayer timeline. No script changes.
- **Visual effects:** Tween `_sprite.scale` for zoom punch on attack, `_sprite.modulate` for red flash on hit, `_sprite.modulate.a` for death fade — all via `create_tween()` in the relevant hook.
- **Skeleton variants:** Subclass `Skeleton` for behaviour differences; reuse with different inspector values for stat-only variants.
- **Reaction windows / parry prompts:** If needed, the async turn loop change belongs on `enemy.gd` and `CombatEvent`, not here.
