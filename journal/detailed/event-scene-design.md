# Event Scene Design

**Date:** 2026-03-05
**Status:** Pre-implementation design

---

## Overview

Captures the intended node tree and signal contract for the base `Event` scene and `CombatEvent` scene before implementation begins. Neither has a `.tscn` file yet — both exist only as scripts. This document is the source of truth for the scene structure.

---

## Node Trees

### Base Event

```
Event               Node2D          scripts/event.gd
```

Just the root node. `event.gd` already has the phase state machine (SETUP → RUNNING → RESOLUTION → COMPLETE). No child nodes at the base level — subclasses add their own structure.

In Godot 4, CombatEvent's scene inherits the base Event scene and extends it.

### CombatEvent

```
CombatEvent         Node2D          scripts/combat_event.gd
└── Enemies         Node            container; enemy scenes instantiated here at runtime
```

`Enemies` is a bare grouping `Node` with no script. Enemy scenes are added as children at runtime via `add_enemy()`. `_enemies: Array[Enemy]` on the script holds them for logical iteration; the node gives a clean editor grouping.

Music and ambient audio live on `Game`, not on events.

---

## Signal Contract

### Signals CombatEvent emits

| Signal | Emitted when |
|---|---|
| `player_attacked(damage: float)` | An enemy attacked — re-emitted from `enemy.attacked` |
| `player_attack_resolved(enemy: Enemy, damage: float)` | Player's attack landed on a specific enemy — for UI/combat log |
| `enemy_turns_complete` | All living enemies have finished their turns |
| `event_complete` | Inherited from Event; all enemies dead, combat over |

### Methods game.gd calls on CombatEvent

| Method | When called |
|---|---|
| `add_enemy(enemy: Enemy)` | Before `start()` to register participants |
| `receive_player_attack(enemy: Enemy, damage: float)` | When player attacks; applies damage to the specified enemy |
| `run_enemy_turns()` | Called by game.gd when player turn ends |

---

## Enemy Connection Pattern

### `add_enemy(enemy: Enemy)` does three things

1. Appends to `_enemies: Array[Enemy]`
2. Calls `$Enemies.add_child(enemy)` to place the enemy in the scene tree
3. Connects `enemy.died` → `_on_enemy_died()`

`enemy.attack` is connected in `_on_setup()` so the signal is live when the event starts.

### `receive_player_attack(enemy: Enemy, damage: float)`

- Applies damage directly to the specified enemy via `enemy.take_damage(damage)`
- Emits `player_attack_resolved(enemy, damage)` for UI/combat log

Target selection (which enemy the player is attacking) is the concern of game.gd or a future targeting system — CombatEvent just applies damage to whichever enemy is passed.

### Death tracking in `_on_enemy_died()`

- Skip or optionally clean up the reference (dead enemies are skipped via `is_dead` during turn loops)
- If all `_enemies` have `is_dead == true`, call `_advance_phase()` → RESOLUTION → COMPLETE → `event_complete`

`enemy.died` is connected per-enemy in `add_enemy()`, not in `_on_setup()`, so it survives across phases.

---

## Turn Loop

game.gd calls `(current_event as CombatEvent).run_enemy_turns()` in `_run_enemy_turns()`.

### Inside `run_enemy_turns()` on CombatEvent

1. Build a list of living enemies from `_enemies` (skip `is_dead`)
2. Connect to the first enemy's `turn_ended` signal (one-shot)
3. Call `enemy.take_turn()`
4. On `turn_ended`: advance to next living enemy; if none remain, emit `enemy_turns_complete`

game.gd connects `enemy_turns_complete` → `_on_enemy_turns_complete()` → `_start_player_turn()`.

Sequencing logic lives inside CombatEvent. game.gd only knows "enemy turns started / enemy turns done".

**Why not game.gd driving the loop directly?** game.gd would need to know how many enemies exist and which ones are alive — that is CombatEvent's concern. Routing through CombatEvent keeps game.gd enemy-type-agnostic.

---

## Changes Required in game.gd

In `start_event()`, when `event is CombatEvent`, also connect:

```gdscript
ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
```

Disconnect both `player_attacked` and `enemy_turns_complete` in `_on_event_complete`.

In `_run_enemy_turns()`, replace the current stub:

```gdscript
func _run_enemy_turns() -> void:
    (current_event as CombatEvent).run_enemy_turns()
```

Add handler:

```gdscript
func _on_enemy_turns_complete() -> void:
    _start_player_turn()
```

Player attack routing:

```gdscript
# Target selection lives here or in a future targeting system
(current_event as CombatEvent).receive_player_attack(target_enemy, damage)
```

---

## Waves — Future Flexibility

Waves are out of scope for the initial implementation. When added, CombatEvent refills `_enemies` internally and loops through the turn sequence again without changes to game.gd. `enemy_turns_complete` fires between waves only if game.gd needs a beat — otherwise CombatEvent suppresses it and starts the next wave directly. The `_on_enemy_died()` all-dead check becomes wave-aware (don't advance phase if more waves remain), but that logic stays entirely inside CombatEvent.

---

---

## DialogueEvent

**Date:** 2026-03-29

### Node Tree

```
DialogueEvent       Node2D          scripts/dialogue_event.gd
```

Root node only — no children. Dialogue rendering lives entirely in GUI (`DialoguePanel`). `DialogueEvent` is a thin event wrapper that loads data and hands it off.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `dialogue_requested(data: Dictionary)` | Event enters RUNNING — carries the loaded dialogue tree |
| `event_complete` | Inherited from Event; emitted when dialogue is confirmed complete |

### Methods game.gd calls on DialogueEvent

| Method | When called |
|---|---|
| `on_dialogue_complete()` | Called from `_on_gui_dialogue_complete()` when the player dismisses the final dialogue node |

### Phase Flow

`start()` calls `_on_setup()` (load JSON from `dialogue_json_path`) then immediately `_on_running()` (emit `dialogue_requested`). The event stays in RUNNING while the player navigates dialogue. When the panel emits `dialogue_complete`, `game.gd` restores the turn state and calls `on_dialogue_complete()`, which calls `_advance_phase()` — this transitions RUNNING → RESOLUTION → COMPLETE atomically, emitting `event_complete`.

`_on_resolution()` is not overridden. Nothing to do between dialogue ending and event completing at this stage.

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is DialogueEvent:
    var de := event as DialogueEvent
    de.dialogue_requested.connect(_on_dialogue_requested)
```

`_on_dialogue_requested(data)` saves the current turn state to `_pre_dialogue_state`, sets state to `DIALOGUE`, and calls `_gui.show_dialogue(data, _dialogue_consequences)`.

Cleanup in `_on_event_complete()`:
```gdscript
elif current_event is DialogueEvent:
    (current_event as DialogueEvent).dialogue_requested.disconnect(_on_dialogue_requested)
```

### Signal Flow

```
game.start_event(dialogue_event)
  → de.dialogue_requested.connect(_on_dialogue_requested)
  → de.start()
    → _on_setup(): load JSON
    → _on_running(): emit dialogue_requested(data)
  → game._on_dialogue_requested(data) → start_dialogue(data)
    → save state, set DIALOGUE, gui.show_dialogue()
  → [player navigates dialogue tree]
  → gui.dialogue_complete → game._on_gui_dialogue_complete()
    → restore state
    → de.on_dialogue_complete() → _advance_phase()
      → RESOLUTION → COMPLETE → event_complete.emit()
  → game._on_event_complete() → disconnect, _finish_event()
```

---

## Signal Flow Summary

**Enemy attacks player:**
`enemy.attack(damage)` → CombatEvent re-emits `player_attacked(damage)` → game.gd → `player.take_damage(damage)`

**Player attacks enemy:**
game.gd calls `receive_player_attack(target_enemy, damage)` → `target_enemy.take_damage(damage)` + CombatEvent emits `player_attack_resolved(enemy, damage)`

**Combat ends:**
`enemy.died` → `_on_enemy_died()` → all dead check → `_advance_phase()` → `event_complete` → game.gd
