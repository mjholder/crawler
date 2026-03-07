# Game Scene Design

**Date:** 2026-03-07
**Status:** Pre-implementation design

---

## Overview

This document defines the authoritative node tree for `scenes/game.tscn` and the wiring strategy for all global-level systems: Player, Events, UI, and Music. It is the source of truth before implementing any of these systems in the game scene.

The guiding principle is loose coupling: `game.gd` acts as the thin coordinator. It wires participants together and to the UI, but does not inspect their internals. All communication between systems uses signals.

---

## Node Tree

```
Game                Node2D              scripts/game.gd
├── Background      CanvasLayer         layer = -1; always behind everything
│   └── BG          TextureRect         viewport-fill background image
├── Player          Player (Node2D)     scenes/player.tscn; static child, persists across run
├── EventContainer  Node                runtime parent for active events
├── Music           Node                grouping node, no script
│   ├── BGM         AudioStreamPlayer   looping background music
│   └── Ambience    AudioStreamPlayer   looping ambient sound
├── HurtOverlay     CanvasLayer         layer = 3; red tint flash on player damage
│   └── HurtRect    ColorRect           full-viewport dark red, alpha = 0 at rest
└── GUI             CanvasLayer         layer = 4; all HUD elements
    ├── CombatHUD   Control             shown during CombatEvent, hidden otherwise
    │   ├── PlayerHUD   Control         player health bar and name
    │   ├── EnemyHUD    Control         enemy health bar and name
    │   └── ActionMenu  Control         player action buttons
    └── CombatLog   RichTextLabel       scrolling history of combat events
```

---

## Node Rationale

### Background (CanvasLayer, layer = -1)

Holds a viewport-fill `TextureRect`. Already present in `game.tscn`. Layer -1 renders behind all game elements.

### Player (Player scene)

The Player scene is placed as a **static child** of Game in `game.tscn` — not instantiated dynamically. It persists across the entire run. `game.gd._ready()` calls `set_player($Player)` to register it and wire signals.

Static placement is appropriate because the Player is always present from game start and never needs to be freed or re-instantiated within a run.

### EventContainer (Node)

Bare `Node` with no script. Events are instantiated externally and added as children via `add_child(event)` before `start_event(event)` is called. On event completion, the event is freed and removed. This keeps event lifecycle visible in the editor's Remote tab during runtime.

### Music (Node)

Grouping container, no script. `game.gd` controls music transitions directly via `$Music/BGM` and `$Music/Ambience`. Music streams are `@export AudioStream` vars on `game.gd`, assigned in the inspector — no hardcoded paths.

`AudioStreamPlayer` (non-2D) because music is non-positional.

### HurtOverlay (CanvasLayer, layer = 3)

**Resolves the open question in `player-node-implementation.md`:** the overlay lives on a dedicated `CanvasLayer` in the game scene rather than under the Player node. Since the Player node may not be at the viewport origin, a `ColorRect` child of Player would not reliably cover the screen.

`HurtRect` is a `ColorRect` set to fill the full viewport (anchors: full rect), base color `Color(0.6, 0.0, 0.0, 0.0)` (transparent at rest). `player.gd` gets a reference to it via `set_hurt_overlay()` and tweens its alpha on `take_damage()`. Tween logic stays in `player.gd`; the node lives in the game scene.

Layer 3 puts it above the game world but below the GUI (layer 4).

### GUI (CanvasLayer, layer = 4)

Holds all HUD elements. Already present in `game.tscn`. Internal designs for CombatHUD, PlayerHUD, EnemyHUD, ActionMenu, and CombatLog are out of scope for this document — each will get its own design document.

**CombatHUD** — shown during CombatEvent, hidden otherwise. `game.gd` calls `show()` in `start_event()` and `hide()` in `_on_event_complete()`.

**CombatLog** — scrolling text. Lives outside CombatHUD so it can persist across events if needed.

---

## Loading and Wiring

### Player

The Player scene is a static child of `game.tscn`. In `game.gd._ready()`:

```gdscript
func _ready() -> void:
    set_player($Player)
    $Player.set_hurt_overlay($HurtOverlay/HurtRect)
```

`set_player()` already wires `turn_ended` and `died`. The `set_hurt_overlay()` call is the only new wiring added to Player.

### Events

Events are loaded externally and passed to `game.gd`. The caller:
1. Instantiates the event scene (e.g. `CombatEvent.instantiate()`)
2. Configures it (e.g. `event.add_enemy(skeleton)`)
3. Calls `game.start_event(event)`

`start_event()` adds the event to the scene tree, wires signals, and calls `event.start()`:

```gdscript
func start_event(event: Event) -> void:
    $EventContainer.add_child(event)
    current_event = event
    # ... existing signal wiring (event_complete one-shot, CombatEvent-specific signals)
    if event is CombatEvent:
        $GUI/CombatHUD.show()
        _start_combat_music()
    event.start()
```

On `_on_event_complete()`:

```gdscript
func _on_event_complete() -> void:
    # ... existing signal cleanup
    current_event.queue_free()
    current_event = null
    $GUI/CombatHUD.hide()
    _start_exploration_music()
```

### Music

`game.gd` drives music transitions directly:

```gdscript
func _start_combat_music() -> void:
    if _combat_music == null:
        return
    $Music/BGM.stream = _combat_music
    $Music/BGM.play()

func _start_exploration_music() -> void:
    if _exploration_music == null:
        return
    $Music/BGM.stream = _exploration_music
    $Music/BGM.play()
```

`_combat_music` and `_exploration_music` are `@export AudioStream` vars on `game.gd`, assigned in the inspector. Ambience (`$Music/Ambience`) starts in `_ready()` and loops continuously — it does not change between events.

### UI

UI nodes connect to participant signals; they do not call methods on participants. `game.gd` mediates where a direct connection is not possible (e.g. wiring EnemyHUD to a new enemy each event).

PlayerHUD connects to `player.damaged` and `player.died` once in `_ready()` — the player never changes.

CombatLog and EnemyHUD are wired per-event in `start_event()` and freed with the event on `event_complete`:

```gdscript
func start_event(event: Event) -> void:
    # ...
    if event is CombatEvent:
        var ce := event as CombatEvent
        ce.player_attacked.connect($GUI/CombatLog._on_player_attacked)
        ce.player_attack_resolved.connect($GUI/CombatLog._on_player_attack_resolved)
```

UI never references `game.gd`. `game.gd` passes signal connections to UI only when wiring per-event participants.

---

## Signal Contract

### Signals game.gd listens to

| Signal | Source | Connected in |
|---|---|---|
| `turn_ended` | Player | `set_player()` |
| `died` | Player | `set_player()` |
| `event_complete` | Event | `start_event()` (one-shot) |
| `player_attacked(damage)` | CombatEvent | `start_event()` — CombatEvent only |
| `enemy_turns_complete` | CombatEvent | `start_event()` — CombatEvent only |

### Signals UI connects to

| Signal | Source | Listener | Connected in |
|---|---|---|---|
| `damaged(amount)` | Player | PlayerHUD | `_ready()` |
| `died` | Player | PlayerHUD | `_ready()` |
| `damaged(amount)` | Enemy | EnemyHUD | `start_event()` |
| `died` | Enemy | EnemyHUD | `start_event()` |
| `player_attacked(damage)` | CombatEvent | CombatLog | `start_event()` |
| `player_attack_resolved(enemy, damage)` | CombatEvent | CombatLog | `start_event()` |

---

## Open Questions

- **EnemyHUD multi-enemy support:** First pass connects to a single enemy. Expand when multi-enemy encounters are designed.
- **Who calls `start_event()`?** For now, a debug call in `game.gd._ready()`. A floor/dungeon generator will own this later — out of scope for this document.
- **CombatLog content design:** Text format, what events are logged, scrolling behaviour — future document.

---

## What This Document Does Not Cover

- Internal node structure of CombatHUD, PlayerHUD, EnemyHUD, ActionMenu, or CombatLog
- Procedural floor and dungeon generation
- Scene transitions between floors or game states
- The full stat system (STR/CON/AGI/SPI/LCK)
