# Player Node — Scene Design

**Date:** 2026-03-05
**Status:** Planned, not yet implemented

This document covers the node tree design, rationale, animation system, signal contract, and turn gate for the Player scene. It is intended to be read before implementing or modifying the player scene.

---

## Overview

`player.gd` already defines the core logic: stats, action registry, `take_damage()`, and signal emission. What it lacks is any visual or audio representation, and its turn gate is incomplete — `execute_action()` currently emits `turn_ended` immediately rather than waiting for animation to finish.

This plan adds:
- A node tree for visual and audio output
- An internal state machine mirroring the skeleton pattern
- A `_process()` / `_is_turn_complete()` turn gate so `turn_ended` fires only after animations complete
- An equipment swap mechanism (SpriteFrames swap on the AnimatedSprite2D)
- A screen-space hurt overlay for incoming damage feedback

---

## Node Tree

```
Player              Node2D              scripts/player.gd
├── Sprite          AnimatedSprite2D    SpriteFrames resource swapped on equip change
├── AnimationPlayer AnimationPlayer     sequences multi-phase animations (e.g. attack)
├── HurtOverlay     ColorRect           full-screen red tint; alpha tweened on damage
└── SFX             Node                grouping container, no script
    ├── AttackPlayer    AudioStreamPlayer2D
    ├── HurtPlayer      AudioStreamPlayer2D
    └── DeathPlayer     AudioStreamPlayer2D
```

---

## Node Rationale

### Player (Node2D root)

Plain `Node2D`, same reasoning as the skeleton. No physics body — turn-based, no movement or collision needed.

### Sprite (AnimatedSprite2D)

First-person view: the sprite represents the equipped weapon, not the player body. The battle axe sprites are the first concrete asset set.

Named animations are driven by the `SpriteFrames` resource configured in the editor. The script calls `_sprite.play("idle")` etc. — no texture references in code.

When equipment changes, `equip_weapon(frames: SpriteFrames)` swaps `_sprite.sprite_frames` and resets to `idle`. No structural scene changes are needed for new weapon types — only a new SpriteFrames resource.

**Why AnimatedSprite2D:** same rationale as the skeleton — named states, `animation_finished` signal, additive frame expansion later. See `skeleton-enemy.md` for the full argument.

| Animation | Source images | Loop |
|---|---|---|
| `idle`   | `BattleAxeIdleFiltered.png`   | yes |
| `windup` | `BattleAxeWindupFiltered.png` | no  |
| `swing`  | `BattleAxeSwingFiltered.png`  | no  |
| `hurt`   | TBD — sprite not yet rendered | no  |
| `death`  | TBD — sprite not yet rendered | no  |

`windup` and `swing` are separate sprite animations. Their sequencing is owned by the `AnimationPlayer`, not by the `AnimatedSprite2D`.

### AnimationPlayer

Owns all multi-phase animation sequences. For `attack`, it has a single `"attack"` animation with two method call tracks:

- At `t=0`: calls `_sprite.play("windup")`
- At `t=N`: calls `_sprite.play("swing")` (N tuned to the windup display duration)

When the `AnimationPlayer` animation finishes, its `animation_finished` signal fires and `_on_anim_player_finished()` calls `_transition(State.IDLE)`.

This keeps sequencing logic in the editor (timeline) rather than in timer callbacks. Adding or reordering phases is a timeline edit, not a code change. Other states that need multi-phase sequences (e.g. a charged attack) follow the same pattern — add a new named animation to the `AnimationPlayer`.

Single-state animations (`hurt`, `death`) are played directly on the `AnimatedSprite2D` and do not need an `AnimationPlayer` animation.

### HurtOverlay (ColorRect)

A full-viewport-sized `ColorRect` (dark red, e.g. `Color(0.6, 0.0, 0.0, 0.0)` at rest) that flashes on damage. `player.gd` tweens its alpha up then back to zero using `create_tween()` when `take_damage()` is called. It is always present and always transparent at rest.

This node handles the screen-effect half of incoming damage feedback. The sprite state change (`_transition(State.HIT)`) handles the equipment-sprite half.

> **Open question:** A `ColorRect` child of the Player `Node2D` is positioned in world space. If the player node is not at the viewport origin, the overlay may not cover the screen correctly. It may need to be placed on a `CanvasLayer` instead, or owned by a UI scene rather than the Player node. Resolve when the scene hierarchy for the full game screen is established.

### SFX (Node)

Bare `Node` grouping container, no script — same as skeleton.

### AttackPlayer / HurtPlayer / DeathPlayer (AudioStreamPlayer2D)

One player per sound type so they cannot cut each other off. No stream assigned at scene creation. All play calls are null-guarded: `if player.stream != null: player.play()`.

---

## Animation System

### Behavioral State Machine

```gdscript
enum State { IDLE, ATTACKING, HIT, DEAD }
var _state: State = State.IDLE
```

`_transition(next: State)` sets `_state` and calls the matching `_sprite.play()`. Logic and visuals always move together.

| State | Purpose |
|---|---|
| `IDLE` | At rest; `_is_turn_complete()` returns true |
| `ATTACKING` | AnimationPlayer running the attack sequence; turn held |
| `HIT` | Hurt sprite + overlay flash; does not block the turn (player is hit on the enemy's turn, not their own) |
| `DEAD` | Death animation playing or complete; `_is_turn_complete()` returns true |

### Attack Sequence (AnimationPlayer)

The `AnimationPlayer` has a named animation `"attack"` with method call tracks:

1. `t=0` — `_sprite.play("windup")`
2. `t=N` — `_sprite.play("swing")` *(N tuned in editor to windup display duration)*
3. Animation ends → `animation_finished` fires → `_on_anim_player_finished()` → `_transition(State.IDLE)`

`_transition(State.ATTACKING)` calls `_anim_player.play("attack")` to start the sequence. No timer callbacks, no code changes needed to adjust timing — edit the timeline.

### Equipment Swapping

```gdscript
func equip_weapon(frames: SpriteFrames) -> void:
    _sprite.sprite_frames = frames
    _transition(State.IDLE)
```

All animation names (`idle`, `windup`, `swing`, `hurt`, `death`) must exist in every weapon's SpriteFrames resource. The script never references a specific weapon — only calls `_sprite.play("swing")` etc.

---

## Turn Gate

`execute_action()` currently emits `turn_ended` immediately. This must change so `game.gd` waits for the attack animation to complete before starting the enemy turn.

Pattern is identical to `enemy.gd`:

```gdscript
var _turn_pending: bool = false

func execute_action(action_name: String) -> void:
    if is_dead or not _actions.has(action_name):
        return
    _actions[action_name].call()
    _turn_pending = true
    # turn_ended is NOT emitted here

func _process(_delta: float) -> void:
    if _turn_pending and _is_turn_complete():
        _turn_pending = false
        turn_ended.emit()

func _is_turn_complete() -> bool:
    return _state == State.IDLE or _state == State.DEAD
```

`game.gd` is unchanged — it still connects to `turn_ended` and does not care when it fires.

---

## Signals

| Signal | Emitted when | Connected by |
|---|---|---|
| `turn_ended` | `_process()` detects `_is_turn_complete()` after an action | `game.gd` in `set_player()` |
| `attacked(damage: float)` | `_do_attack()` | `game.gd` → `CombatEvent.receive_player_attack` |
| `damaged(amount: float)` | `take_damage()` | UI (health bar) — not yet built |
| `died` | `_die()` | `game.gd` in `set_player()` |

No new signals are needed. The existing four cover all current communication requirements.

---

## Action System

Actions are registered as Callables in `_actions: Dictionary`. Each action callable is responsible for:
1. Triggering its animation state via `_transition()`
2. Emitting its intent signal (e.g. `attacked`)
3. Playing its SFX

`execute_action()` sets `_turn_pending = true` after calling the action. The action does not emit `turn_ended` — that is always the turn gate's job.

```gdscript
func _register_actions() -> void:
    register_action("attack", _do_attack)

func _do_attack() -> void:
    _play_sfx(_attack_player)
    _transition(State.ATTACKING)
    attacked.emit(attack_damage)
```

**Adding future actions:** call `register_action("action_name", _do_action_name)` in `_register_actions()`. The new callable follows the same pattern: transition to appropriate state, emit intent signal, play SFX. No changes to `execute_action()`, `_process()`, or the turn gate are required.

---

## Node Wiring

```gdscript
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _hurt_overlay: ColorRect = $HurtOverlay
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer
```

Signal connections made in `_ready()`:

```gdscript
func _ready() -> void:
    health = max_health
    _anim_player.animation_finished.connect(_on_anim_player_finished)
    _register_actions()
    _transition(State.IDLE)

func _on_anim_player_finished(_anim_name: StringName) -> void:
    _transition(State.IDLE)
```

---

## Inspector Defaults

Set in `player.tscn`, not hardcoded in `player.gd`:

```
player_name    = "Player"
max_health     = 100.0
attack_damage  = 10.0
```

---

## Open Questions

- **HurtOverlay placement:** `ColorRect` as a direct child works if the Player node is at the viewport origin. If not, it may need to live on a `CanvasLayer` or be owned by a UI scene. Resolve when the full scene hierarchy is established.
- **Hurt and death sprites:** `BattleAxeHurt` and `BattleAxeDeath` renders do not exist yet. The `hurt` and `death` animation names should still be created in the SpriteFrames resource with placeholder single frames so the state machine works before the art is ready.

---

## Future Considerations

- **Multiple equipment slots:** The current design covers one weapon sprite. When armour, shield, or off-hand slots are added, each slot would need its own `AnimatedSprite2D` node, with `equip_weapon()` generalised to `equip(slot: String, frames: SpriteFrames)`.
- **Action-to-animation coupling:** Today each action callable directly calls `_transition()`. If many actions share animation logic, a mapping (`Dictionary[String, State]`) could centralise this — but not worth adding until there are three or more actions.
- **Visual effects:** Tween `_sprite.scale` for a punch on attack, tween `_sprite.modulate` for a flash on hurt. All done with `create_tween()` in the relevant handler, no structural changes needed.
- **Adding SFX:** Assign an `AudioStream` to any player node in the inspector. No code changes needed.
- **Multi-phase actions:** Any future action needing its own sprite sequence (e.g. a two-hit combo) gets a new named animation on the `AnimationPlayer` with its own method call tracks. No structural changes to the node tree or turn gate.
