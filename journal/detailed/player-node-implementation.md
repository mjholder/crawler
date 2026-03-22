# Player Node — Scene Design

**Date:** 2026-03-05
**Status:** Implemented (modified — see implementation notes below)

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

## Implementation Notes

The following diverged from this design during implementation:

- **`Sprite` and `AnimationPlayer` were removed from the Player scene.** All visual output (attack animation, idle sprite) is owned by the equipped `Weapon` node. The Player has no sprite of its own.
- **State machine simplified to `{ IDLE, DEAD }`.** `ATTACKING` and `HIT` were removed — with no sprite, there is nothing to animate from the Player's side. `_transition()` only sets `_state`.
- **Turn gating uses `_attack_animation_pending` flag** instead of an `ATTACKING` state. The flag is set in `_do_attack()` when a weapon is equipped, and cleared by `_on_weapon_animation_finished()` when `Weapon.animation_finished` fires.
- **`equip_weapon(frames: SpriteFrames)` was replaced by `equip(slot: Enums.Slot, item: Equipment)`.** The new method handles child node management, signal wiring, and audio in one place.
- **Signal is named `attack`, not `attacked`.**

The sections below retain their original design rationale where still relevant, with corrections inline.

---

## Node Tree

```
Player              Node2D              scripts/player.gd
└── SFX             Node                grouping container, no script
    ├── AttackPlayer    AudioStreamPlayer2D
    ├── HurtPlayer      AudioStreamPlayer2D
    └── DeathPlayer     AudioStreamPlayer2D
```

`Sprite` and `AnimationPlayer` were removed — all visual output is owned by the equipped `Weapon` node, which is added as a child of `Player` at runtime via `equip()`.

> **Note:** The hurt overlay is NOT a child of this scene. It lives as `HurtOverlay/HurtRect` (a `ColorRect` on a `CanvasLayer`) under `Game` in `game.tscn`. `game.gd._ready()` calls `$Player.set_hurt_overlay($HurtOverlay/HurtRect)` to pass a reference. `player.gd` tweens its alpha on `take_damage()`. See `game-scene-design.md` for the full rationale.

---

## Node Rationale

### Player (Node2D root)

Plain `Node2D`, same reasoning as the skeleton. No physics body — turn-based, no movement or collision needed.

### Sprite and AnimationPlayer

**Removed from the Player scene.** All sprite and animation work is owned by the equipped `Weapon` node (`equipment.tscn` / `weapon.tscn`). The `Weapon` node is added as a child of the Player when equipped, so its sprites appear in the correct world position without any `Sprite` node on the Player itself.

The animation table below is preserved as reference — these animations are defined in the weapon's `SpriteFrames` resource, not the Player scene:

| Animation | Source images | Loop |
|---|---|---|
| `idle`   | `BattleAxeIdleFiltered.png`   | yes |
| `attack` | windup + swing frames         | no  |

The `AnimationPlayer` on `weapon.tscn` is reserved for future multi-phase sequences (e.g. separate windup → swing tracks). For the current single-phase attack, `_sprite.play("attack")` is called directly.

### HurtOverlay

The hurt overlay is **not a child of this scene**. It is owned by `game.tscn` as `HurtOverlay/HurtRect` — a `ColorRect` set to full-viewport size on a `CanvasLayer` (layer 3). This avoids world-space positioning issues that would arise from a `ColorRect` child of a `Node2D` that is not at the viewport origin.

`game.gd._ready()` calls `$Player.set_hurt_overlay($HurtOverlay/HurtRect)` to pass the reference. `player.gd` stores it and tweens its alpha up then back to zero with `create_tween()` when `take_damage()` is called. The sprite state change (`_transition(State.HIT)`) handles the equipment-sprite half of damage feedback.

### SFX (Node)

Bare `Node` grouping container, no script — same as skeleton.

### AttackPlayer / HurtPlayer / DeathPlayer (AudioStreamPlayer2D)

One player per sound type so they cannot cut each other off. No stream assigned at scene creation. All play calls are null-guarded: `if player.stream != null: player.play()`.

---

## Animation System

### Behavioral State Machine

```gdscript
enum State { IDLE, DEAD }
var _state: State = State.IDLE
```

`_transition(next: State)` sets `_state` only — no sprite calls, since the Player has no sprite.

| State | Purpose |
|---|---|
| `IDLE` | At rest; `_is_turn_complete()` may return true (also depends on `_attack_animation_pending`) |
| `DEAD` | Player is dead; `_is_turn_complete()` returns true |

`ATTACKING` and `HIT` were removed. Attack progress is tracked by the `_attack_animation_pending` flag instead (see Turn Gate below). `HIT` was removed because there is no hurt sprite on the Player — damage feedback is handled by `_flash_hurt_overlay()` and SFX only.

### Equipment Swapping

```gdscript
func equip(slot: Enums.Slot, item: Equipment) -> void:
    # ... handles old item teardown, signal disconnection, remove_child
    _equipped[slot] = item
    add_child(item)
    item.play_equip()
    item._on_equipped()
    if slot == Enums.Slot.WEAPON:
        attack.connect((item as Weapon)._on_player_attacked)
        (item as Weapon).animation_finished.connect(_on_weapon_animation_finished)
```

`equip()` manages the full lifecycle: removes the old item, connects/disconnects signals, and adds the new item as a child. Swapping weapons is transparent to `game.gd`.

---

## Turn Gate

`execute_action()` currently emits `turn_ended` immediately. This must change so `game.gd` waits for the attack animation to complete before starting the enemy turn.

Pattern is identical to `enemy.gd`:

```gdscript
var _turn_pending: bool = false
var _attack_animation_pending: bool = false

func execute_action(action_name: String) -> void:
    if is_dead or _turn_pending or not _actions.has(action_name):
        return
    _actions[action_name].call()
    _turn_pending = true
    # turn_ended is NOT emitted here

func _process(_delta: float) -> void:
    if _turn_pending and _is_turn_complete():
        _turn_pending = false
        turn_ended.emit()

func _is_turn_complete() -> bool:
    return not _attack_animation_pending and (_state == State.IDLE or _state == State.DEAD)

func _on_weapon_animation_finished() -> void:
    _attack_animation_pending = false
```

`_attack_animation_pending` is set to `true` in `_do_attack()` when a weapon is equipped, and cleared when `Weapon.animation_finished` fires. This gates the turn on the weapon's visual completing, not just the damage calculation.

`game.gd` is unchanged — it still connects to `turn_ended` and does not care when it fires.

---

## Signals

| Signal | Emitted when | Connected by |
|---|---|---|
| `turn_ended` | `_process()` detects `_is_turn_complete()` after an action | `game.gd` in `set_player()` |
| `attack(damage: float)` | `_do_attack()` | `game.gd` → `CombatEvent.receive_player_attack`; also `Weapon._on_player_attacked` |
| `damaged(amount: float)` | `take_damage()` | `game.gd` → `_gui.update_player_health` |
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
    if _equipped.has(Enums.Slot.WEAPON):
        _attack_animation_pending = true
    attack.emit(_calculate_damage())
```

**Adding future actions:** call `register_action("action_name", _do_action_name)` in `_register_actions()`. The new callable follows the same pattern: transition to appropriate state, emit intent signal, play SFX. No changes to `execute_action()`, `_process()`, or the turn gate are required.

---

## Node Wiring

```gdscript
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer

var _hurt_overlay: ColorRect = null      # set via set_hurt_overlay() from game.gd
var _attack_animation_pending: bool = false
var _equipped: Dictionary = {}           # Enums.Slot → Equipment
```

`_hurt_overlay` is not wired in `_ready()` — `game.gd` passes a reference via `set_hurt_overlay($HurtOverlay/HurtRect)` after the player is in the tree. This avoids world-space positioning issues from a `ColorRect` child of the Player node.

Signal connections made in `_ready()`:

```gdscript
func _ready() -> void:
    health = max_health
    _register_actions()
    _transition(State.IDLE)
```

`_on_weapon_animation_finished` is connected dynamically inside `equip()` when a weapon is equipped, not in `_ready()`.

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

- **Hurt and death sprites:** `BattleAxeHurt` and `BattleAxeDeath` renders do not exist yet. The `hurt` and `death` animation names should still be created in the SpriteFrames resource with placeholder single frames so the state machine works before the art is ready.

---

## Future Considerations

- **Multiple equipment slots:** `equip(slot: Enums.Slot, item: Equipment)` already handles multiple slots — adding a new slot means adding an entry to `Enums.Slot` and optionally handling its signal wiring in `equip()`. No structural changes to the Player node tree are needed since each equipped item manages its own visuals as a child node.
- **Action-to-animation coupling:** Today each action callable directly calls `_transition()`. If many actions share animation logic, a mapping (`Dictionary[String, State]`) could centralise this — but not worth adding until there are three or more actions.
- **Visual effects:** Tween `_sprite.scale` for a punch on attack, tween `_sprite.modulate` for a flash on hurt. All done with `create_tween()` in the relevant handler, no structural changes needed.
- **Adding SFX:** Assign an `AudioStream` to any player node in the inspector. No code changes needed.
- **Multi-phase actions:** Any future action needing its own sprite sequence (e.g. a two-hit combo) gets a new named animation on the `AnimationPlayer` with its own method call tracks. No structural changes to the node tree or turn gate.
