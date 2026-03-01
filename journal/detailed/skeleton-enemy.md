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
├── Sprite          Sprite2D          display; texture swapped per state
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

### Sprite (Sprite2D)

Holds a single `Texture2D` reference, swapped at runtime to change the visual state. Textures are `preload`ed as class constants at the top of `skeleton.gd`.

**Why Sprite2D and not AnimatedSprite2D?**

`AnimatedSprite2D` is built for frame-by-frame spritesheets — a `SpriteFrames` resource with named animations that tick at a given FPS. The five skeleton assets are independent PNG files, not a sheet. Using `AnimatedSprite2D` here would mean creating a `SpriteFrames` resource with five single-frame "animations", which adds a layer of indirection that doesn't carry its weight.

`Sprite2D` with swapped `.texture` is the direct, correct tool for this asset format. When the pipeline moves to multi-frame spritesheets the migration path is: replace `Sprite2D` with `AnimatedSprite2D`, create a `SpriteFrames` resource, and change `_set_sprite_state()` from `texture = ...` to `play("idle")`. Everything else in the script stays the same.

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

This is the most important design decision in the skeleton scene.

### The conflict

`take_turn()` in `enemy.gd` is synchronous:

```gdscript
func take_turn(target: Node) -> void:
    if is_dead:
        return
    _perform_action(target)
    emit_signal("turn_ended")
```

`turn_ended` fires immediately after `_perform_action()` returns. If a skeleton wants to play a windup animation *before* dealing damage, and a swing animation *after*, and only then signal the turn is over — that sequence would need to block the return of `_perform_action()`.

Three options were considered:

**Option A — Make `take_turn` / `_perform_action` async (await-based)**

Change the base class to `async`, use `await timer.timeout` inside `_perform_action`. This would let animation sequences truly block before `turn_ended` fires.

Rejected. Invasive change to a settled architectural boundary. Every future enemy type becomes async, even ones that don't animate. `take_turn` becomes a coroutine that callers must `await`, which complicates the game loop significantly.

**Option B — Emit `turn_ended` from `skeleton.gd` manually**

Suppress the base class emission and emit at the end of the animation sequence from the skeleton itself.

Rejected outright. The architecture rule is: `turn_ended` is emitted by `take_turn()` in the base class. This is the single, trusted signal that `CombatEvent` and `game.gd` use to know a turn is over. Breaking it for one enemy type means the game loop's signal contract can no longer be trusted uniformly.

**Option C — Cosmetic async animation (chosen)**

`_perform_action()` applies damage immediately and returns. The sprite sequence (windup → swing → idle) plays out over subsequent frames in the background via the `AnimationSequencer` Timer, *after* `turn_ended` has already fired.

The turn logic is complete the moment `_perform_action` returns. The visual sequence is a retrospective cosmetic effect — it has no bearing on when the next player turn starts. The player does not perceive the difference in a turn-based game: the combat log conveys the narrative beat, not animation timing.

This is the model used by the vast majority of turn-based RPG engines. It keeps the base class clean, imposes no async complexity, and still gives full visual feedback.

**When this trade-off would need revisiting:** If a future design requires the player to *react* to an animation mid-sequence (e.g. a parry window, a dodge prompt), the turn loop would need to support async enemy actions. That change belongs on the base class and the event system, not on this scene.

---

## Sprite State Machine

States are defined in a `SpriteState` enum in `skeleton.gd`. All texture swaps go through a single internal method `_set_sprite_state(state: SpriteState)` — never directly.

```
_on_ready()
    └── IDLE

_perform_action(target)
    ├── apply damage to target
    ├── WINDUP (sprite set immediately)
    ├── play AttackSFX
    └── start timer (0.25s)
            └── timer fires → SWING
                    └── start timer (0.20s)
                            └── timer fires → IDLE

_on_damaged(amount)
    ├── stop timer (interrupt any in-progress attack sequence)
    ├── reset _anim_phase to 0
    ├── HIT
    ├── play HurtSFX
    └── start timer (0.20s)
            └── timer fires → IDLE

_on_death()
    ├── stop timer
    ├── reset _anim_phase to 0
    ├── DEATH
    └── play DeathSFX
        (no further transitions)
```

`_anim_phase` is an `int` counter that the timer's `timeout` callback reads to decide the next state. Using a counter on a single Timer is simpler than chaining multiple timers or nodes.

The `_on_damaged` path correctly handles the case where the skeleton is hit while its own attack animation is still playing out — `stop()` cancels the attack sequence cleanly before the hit reaction begins.

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
- **Multiple frames per state:** Replace `Sprite2D` with `AnimatedSprite2D`, create a `SpriteFrames` resource, change `_set_sprite_state` to call `play()`. The timer-based sequencing logic is unchanged or simplified.
- **Skeleton variants:** Subclass `Skeleton` for meaningful behaviour differences (e.g. a skeleton that sometimes skips the windup and attacks twice). For stat-only variants (armoured skeleton), just reuse `skeleton.gd` with different inspector values.
- **Reaction windows / parry prompts:** If these are ever needed, the async turn loop change belongs on `enemy.gd` and `CombatEvent`, not here. The skeleton scene just needs its `_perform_action` to emit a signal the event can hook into.
