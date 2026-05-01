# Game Flow Design

**Date:** 2026-03-07 (consolidated 2026-04-18)
**Status:** Implemented — except `BossEvent` wiring and `GameOverPanel`/`VictoryPanel` (see banners)

Merged from: `game-scene-design.md`, `world-map-system.md`, and the `DialogueConsequences` section of `dialogue-system.md`

---

## Overview

This document defines the authoritative node tree for `scenes/game.tscn`, the `game.gd` state machine and signal contracts, the world map navigation system, and `DialogueConsequences`. Changing any of these means updating this file.

---

## game.tscn Node Tree

```
Game                Node2D              scripts/game.gd
├── Background      CanvasLayer         layer = -1; always behind everything
│   └── BG          TextureRect         viewport-fill background image
├── Player          Player (Node2D)     scenes/player.tscn; static child, persists across run
├── EventContainer  Node                runtime parent for active events
├── DialogueConsequences  Node          scripts/dialogue_consequences.gd
├── Music           Node                grouping node, no script
│   ├── BGM         AudioStreamPlayer   looping background music
│   └── Ambience    AudioStreamPlayer   looping ambient sound
├── HurtOverlay     CanvasLayer         layer = 3; red tint flash on player damage
│   └── HurtRect    ColorRect           full-viewport dark red, alpha = 0 at rest
└── GUI             CanvasLayer         layer = 4; all HUD elements
    ├── MainMenu    Control             shown at start; hidden when game begins
    ├── WorldMap    WorldMap            shown after start; hidden when dungeon selected
    ├── PlayerHUD   Control             persistent — shown during all non-menu game states
    ├── PauseMenu   Control             toggled by ESC
    ├── CombatHUD   Control             shown only during CombatEvent
    ├── DialoguePanel   DialoguePanel   shown during dialogue sequences
    ├── SkillCheckPanel SkillCheckPanel shown during skill checks
    ├── ShopPanel   ShopPanel           shown during ShopEvent
    ├── LevelUpPanel    LevelUpPanel    shown between events when pending_stat_points > 0
    ├── CharacterCreation   Control     shown on new game start
    ├── GameOverPanel   GameOverPanel   (planned) shown on player death
    └── VictoryPanel    VictoryPanel    (planned) shown on boss defeat
```

> **Planned:** `GameOverPanel` and `VictoryPanel` are part of the 2026-04-17 game-end design and are **not yet built**. See [[daily/2026-04-17]] for the punch list and [[detailed/gui-design.md]] for node-tree specs.

---

## Node Rationale

### Background (CanvasLayer -1)
Viewport-fill `TextureRect`. Layer -1 renders behind all game elements.

### Player (Player scene)
Static child of `game.tscn` — not instantiated dynamically. Persists across the entire run. `game.gd._ready()` calls `set_player($Player)` to register and wire signals. Static placement is appropriate because the Player is always present and never needs to be freed within a run.

### EventContainer (Node)
Bare `Node`. Events are instantiated and added as children via `add_child(event)` before `start_event(event)`. On completion, the event is freed. Keeps event lifecycle visible in the editor's Remote tab.

### DialogueConsequences (Node)
Child of `Game` — lives as a sibling of `Player` and `GUI`. `game.gd` holds an `@onready` reference and passes it to `gui.show_dialogue()`. See the `DialogueConsequences` section below.

### Music (Node)
Grouping container. `game.gd` controls transitions via `$Music/BGM` and `$Music/Ambience`. Streams are `@export AudioStream` vars on `game.gd` — no hardcoded paths. `AudioStreamPlayer` (non-2D) because music is non-positional. Ambience starts in `_ready()` and loops continuously.

### HurtOverlay (CanvasLayer, layer = 3)
`HurtRect` is a `ColorRect` filling the full viewport (anchors: full rect), base color `Color(0.6, 0.0, 0.0, 0.0)`. Player gets a reference via `set_hurt_overlay()` and tweens alpha on `take_damage()`. Tween logic stays in `player.gd`; the node lives in the game scene. Layer 3 puts it above the game world but below GUI (layer 4). Lives here rather than under `Player` because a `ColorRect` child of a `Node2D` not at the viewport origin would not reliably cover the screen.

### GUI (CanvasLayer, layer = 4)
All HUD elements. See [[detailed/gui-design.md]] for internal node structures and the full `gui.gd` API.

---

## State Enums — `scripts/enums.gd`

```gdscript
enum TurnState { NO_TURN, PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, DIALOGUE, VICTORY }

enum NodeType { DUNGEON, SHOP, REST }
# Planned: BOSS (not yet in enums.gd — added when game-end system is implemented)

enum NodeState { LOCKED, AVAILABLE, COMPLETED }
```

> See [[detailed/character.md]] for `Enums.Stat` and `Enums.Slot`.

---

## Loading and Wiring

### Player (in `game.gd._ready()`)

```gdscript
func _ready() -> void:
    set_player($Player)
    $Player.set_hurt_overlay($HurtOverlay/HurtRect)
    _gui.node_selected.connect(_on_world_node_selected)
    _gui.dialogue_complete.connect(_on_dialogue_complete)
    _gui.skill_check_complete.connect(_on_gui_skill_check_complete)
    _gui.character_created.connect(_on_character_created)
    # ... other _ready() wiring
```

`set_player()` wires `turn_ended`, `died`, `damaged`, `gold_changed`, `experience_changed`.

### Music Transitions

```gdscript
func _start_combat_music() -> void:
    if _combat_music == null: return
    $Music/BGM.stream = _combat_music
    $Music/BGM.play()

func _start_exploration_music() -> void:
    if _exploration_music == null: return
    $Music/BGM.stream = _exploration_music
    $Music/BGM.play()
```

`_combat_music` and `_exploration_music` are `@export AudioStream` vars assigned in the inspector.

### Events

```gdscript
func start_event(event: Event) -> void:
    $EventContainer.add_child(event)
    current_event = event
    event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
    if event is CombatEvent:
        var ce := event as CombatEvent
        ce.player_attacked.connect(_on_player_attacked)
        ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
        _gui.show_combat_hud()
        _start_combat_music()
    if event is BossEvent:
        (event as BossEvent).boss_defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
    elif event is DialogueEvent:
        (event as DialogueEvent).dialogue_requested.connect(_on_dialogue_requested)
    elif event is SkillCheckEvent:
        var sce := event as SkillCheckEvent
        sce.skill_check_requested.connect(_on_skill_check_requested)
        sce.dialogue_requested.connect(_on_dialogue_requested)
    elif event is ShopEvent:
        var se := event as ShopEvent
        se.shop_requested.connect(_on_shop_requested)
        se.stock_changed.connect(_on_shop_stock_changed)
        player.inventory.bag_changed.connect(_on_shop_bag_changed)
    event.start()
```

---

## game.gd Signal Contract

### Signals game.gd listens to

| Signal | Source | Connected in |
|---|---|---|
| `turn_ended` | Player | `set_player()` |
| `died` | Player | `set_player()` |
| `damaged(amount)` | Player | `set_player()` |
| `gold_changed(new_total)` | Player | `set_player()` |
| `experience_changed(new_total)` | Player | `set_player()` |
| `event_complete` | Event | `start_event()` (one-shot) |
| `player_attacked(damage)` | CombatEvent | `start_event()` — CombatEvent only |
| `enemy_turns_complete` | CombatEvent | `start_event()` — CombatEvent only |
| `dialogue_requested(data)` | DialogueEvent / SkillCheckEvent | `start_event()` |
| `skill_check_requested(stat, label)` | SkillCheckEvent | `start_event()` |
| `shop_requested(...)` | ShopEvent | `start_event()` |
| `stock_changed(stock)` | ShopEvent | `start_event()` |
| `inventory.bag_changed` | Player.Inventory | `start_event()` — ShopEvent only |
| `node_selected(node)` | GUI (relayed from WorldMap) | `_ready()` |
| `dialogue_complete` | GUI (relayed from DialoguePanel) | `_ready()` |
| `skill_check_complete(success)` | GUI (relayed from SkillCheckPanel) | `_ready()` |
| `boss_defeated` *(planned)* | BossEvent | `start_event()` (CONNECT_ONE_SHOT) |
| `quit_to_main_requested` | GUI (from PauseMenu; planned: also GameOverPanel / VictoryPanel) | `_ready()` |

### Signals GUI connects to (via game.gd)

| Signal | Source | Routed to | Connected in |
|---|---|---|---|
| `damaged(amount)` | Player | `gui.update_player_health()` | `set_player()` |
| `gold_changed` | Player | `gui.update_player_gold()` | `set_player()` |
| `experience_changed` | Player | `gui.update_player_xp()` | `set_player()` |
| `damaged(amount)` | Enemy (per instance) | `gui.update_enemy_health_bar()` | `start_event()` |
| `died` | Enemy (per instance) | `gui.remove_enemy_health_bar()` | `start_event()` |

---

## Event Queue and Dungeon Progression

### State

```gdscript
var _pending_event_configs: Array[Dictionary] = []
var _event_index: int = 0
var _active_world_node: WorldMapNode = null
```

### Handlers

```gdscript
func _on_world_node_selected(node: WorldMapNode) -> void:
    _active_world_node = node
    _pending_event_configs = node.generate_event_configs()
    _event_index = 0
    _gui.hide_world_map()
    _start_next_dungeon_event()

func _start_next_dungeon_event() -> void:
    if _event_index >= _pending_event_configs.size():
        _on_dungeon_complete()
        return
    var config := _pending_event_configs[_event_index]
    _event_index += 1
    var event := (config["scene"] as PackedScene).instantiate() as Event
    event.initialize(config["data"])
    $EventContainer.add_child(event)
    start_event(event)

func _on_dungeon_complete() -> void:
    _gui.show_world_map()
    if _active_world_node:
        _gui.world_map_on_dungeon_complete(_active_world_node)
    _active_world_node = null
    _pending_event_configs.clear()
    _event_index = 0
```

### `_on_event_complete()` Extension

After existing cleanup (signal disconnect, `queue_free`, rewards, optional level-up):
```gdscript
_start_next_dungeon_event()
```

### Shared Teardown Helper

```gdscript
func _teardown_current_event() -> void:
    if current_event == null: return
    # disconnect all signals for whatever event type is active
    # queue_free the event
    current_event = null
    _gui.hide_combat_hud()
    _start_exploration_music()
```

Used by both `_on_player_died()` and `_on_boss_defeated()`.

---

## Boss and Game-End Flows

### Player Dies

```gdscript
func _on_player_died() -> void:
    state = Enums.TurnState.GAME_OVER
    _teardown_current_event()
    _gui.show_game_over()
```

> **Planned:** `_gui.show_game_over()` and the `GameOverPanel` are not yet built.

### Boss Defeated

```gdscript
func _on_boss_defeated() -> void:
    state = Enums.TurnState.VICTORY
    _apply_rewards(current_event.rewards)   # must run BEFORE teardown
    _teardown_current_event()
    _active_world_node = null
    _pending_event_configs.clear()
    _event_index = 0
    if player.pending_stat_points > 0:
        _gui.show_level_up(player.level, player.pending_stat_points, player.build_stats_dict())
        return
    _gui.show_victory()
```

`_on_level_up_complete()` checks `state == VICTORY` and routes to `_gui.show_victory()` instead of `_finish_event()`.

> **Planned:** `_gui.show_victory()` and the `VictoryPanel` are not yet built.

---

## DialogueConsequences

`scripts/dialogue_consequences.gd` — child node of `game.tscn` under `Game`.

`game.gd` holds an `@onready` reference and passes it to `gui.show_dialogue()`. `DialoguePanel` calls `consequences.execute(action, value)` on each node load. Methods defined on the class are the consequences — dispatched by name via `call()`.

Adding a new consequence type = add a method to this class. No other file changes needed.

```gdscript
class_name DialogueConsequences
extends Node

var _game: Game

func _ready() -> void:
    _game = get_parent() as Game

# Called by DialoguePanel on each node load.
func execute(action: String, value: Variant) -> void:
    if has_method(action):
        call(action, value)
    else:
        push_warning("DialogueConsequences: unknown action '%s'" % action)

# --- Consequence Methods ---

func give_item(value: Variant) -> void:
    pass

func give_gold(value: Variant) -> void:
    pass

func set_flag(value: Variant) -> void:
    pass

func trigger_event(value: Variant) -> void:
    pass
```

`_game.current_event` gives access to the active event if a consequence needs it. Pass it at dispatch time rather than storing a reference.

---

## WorldMap

### Node Tree

```
WorldMap            Control             scripts/world_map.gd
├── Background      TextureRect         handcrafted art — connections already drawn
└── NodeContainer   Node                all WorldMapNode children, positioned to match art
    ├── StartNode   WorldMapNode        (COMPLETED on _ready)
    ├── Row1Node1   WorldMapNode
    ├── Row1Node2   WorldMapNode
    ├── Row1Node3   WorldMapNode
    ├── Row2Node1 … Row2Node3
    ├── Row3Node1 … Row3Node3
    └── EndNode     WorldMapNode        (stub / future BOSS node)
```

Nodes per run: 1 (start, auto-completed) + 3 (one per row) + 1 (end stub) = 5.

### WorldMap Script

```gdscript
class_name WorldMap
extends Control

signal node_selected(node: WorldMapNode)

@export var initial_nodes: Array[NodePath]

func _ready() -> void:
    for child in $NodeContainer.get_children():
        if child is WorldMapNode:
            child.set_state(Enums.NodeState.LOCKED)
            child.node_selected.connect(_on_node_selected)
    for path in initial_nodes:
        var node := get_node(path) as WorldMapNode
        if node: node.set_state(Enums.NodeState.AVAILABLE)

func on_dungeon_complete(completed_node: WorldMapNode) -> void:
    completed_node.set_state(Enums.NodeState.COMPLETED)
    for path in completed_node.connected_nodes:
        var next := get_node(path) as WorldMapNode
        if next and next.state == Enums.NodeState.LOCKED:
            next.set_state(Enums.NodeState.AVAILABLE)

func _on_node_selected(node: WorldMapNode) -> void:
    node_selected.emit(node)
```

### gui.gd Changes

```gdscript
signal node_selected(node: WorldMapNode)

func show_world_map() -> void:    $WorldMap.show()
func hide_world_map() -> void:    $WorldMap.hide()

func world_map_on_dungeon_complete(node: WorldMapNode) -> void:
    $WorldMap.on_dungeon_complete(node)
    show_world_map()

func _on_world_map_node_selected(node: WorldMapNode) -> void:
    node_selected.emit(node)
```

`$WorldMap.node_selected` connected to `_on_world_map_node_selected` in `gui.gd._ready()`.

---

## WorldMapNode

### Node Tree

```
WorldMapNode        Control             scripts/world_map_node.gd
└── NodeButton      TextureButton       visual + click detection
```

`TextureButton` built-in normal/disabled slots for AVAILABLE vs LOCKED/COMPLETED visuals.

### Script

```gdscript
class_name WorldMapNode
extends Control

signal node_selected(node: WorldMapNode)

# State
@export var node_type: Enums.NodeType = Enums.NodeType.DUNGEON
var state: Enums.NodeState = Enums.NodeState.LOCKED

# Visuals
@export var texture_available: Texture2D
@export var texture_locked: Texture2D
@export var texture_completed: Texture2D

# Graph
@export var connected_nodes: Array[NodePath]

# Dungeon config (node_type == DUNGEON)
@export var dungeon_depth: int = 4
@export var combat_scene: PackedScene
@export var combat_json_dir: String
@export var dialogue_scene: PackedScene
@export var dialogue_json_dir: String
@export var skill_check_scene: PackedScene
@export var skill_check_json_dir: String
@export var miniboss_scene: PackedScene
@export var miniboss_json_path: String

# Debug fallbacks (used when a json_dir yields no files)
@export var debug_combat_json_path: String
@export var debug_dialogue_json_path: String
@export var debug_skill_check_json_path: String

# Shop config (node_type == SHOP)
@export var shop_scene: PackedScene
@export var shop_data: ShopData

# Boss config (node_type == BOSS — planned)
@export var boss_scene: PackedScene
@export var boss_data_json_path: String
```

### State Transitions

```gdscript
func set_state(new_state: Enums.NodeState) -> void:
    state = new_state
    _update_visuals()
    $NodeButton.disabled = state != Enums.NodeState.AVAILABLE

func _update_visuals() -> void:
    match state:
        Enums.NodeState.AVAILABLE:  $NodeButton.texture_normal = texture_available
        Enums.NodeState.LOCKED:     $NodeButton.texture_normal = texture_locked
        Enums.NodeState.COMPLETED:  $NodeButton.texture_normal = texture_completed

func _on_node_button_pressed() -> void:
    if state == Enums.NodeState.AVAILABLE:
        node_selected.emit(self)
```

### `generate_event_configs() -> Array[Dictionary]`

Returns `Array[Dictionary]` of `{ "scene": PackedScene, "data": Dictionary }`. Called by `game.gd` when the player selects the node. `game.gd` owns instantiation.

```gdscript
func generate_event_configs() -> Array[Dictionary]:
    if node_type == Enums.NodeType.BOSS:
        return _build_boss_config()
    if node_type == Enums.NodeType.SHOP:
        return _build_shop_config()
    # DUNGEON (default):
    var configs: Array[Dictionary] = []
    for i in range(dungeon_depth - 1):
        var config := _build_random_event_config()
        if not config.is_empty(): configs.append(config)
    var boss_data := _load_json(miniboss_json_path)
    configs.append({ "scene": miniboss_scene, "data": boss_data })
    return configs

func _build_random_event_config() -> Dictionary:
    var candidates: Array[Dictionary] = []
    if combat_scene: candidates.append({ "scene": combat_scene, "dir": combat_json_dir, "debug": debug_combat_json_path })
    if dialogue_scene: candidates.append({ "scene": dialogue_scene, "dir": dialogue_json_dir, "debug": debug_dialogue_json_path })
    if skill_check_scene: candidates.append({ "scene": skill_check_scene, "dir": skill_check_json_dir, "debug": debug_skill_check_json_path })
    if candidates.is_empty(): return {}
    var pick: Dictionary = candidates[randi() % candidates.size()]
    var files := _get_json_files(pick["dir"])
    var path: String
    if files.is_empty():
        push_warning("[WorldMapNode] No JSON files in '%s' — falling back to debug file." % pick["dir"])
        path = pick["debug"]
    else:
        path = files[randi() % files.size()]
    return { "scene": pick["scene"], "data": _load_json(path) }

func _build_shop_config() -> Array[Dictionary]:
    return [{ "scene": shop_scene, "data": { "shop": shop_data } }]

func _build_boss_config() -> Array[Dictionary]:
    return [{ "scene": boss_scene, "data": _load_json(boss_data_json_path) }]
```

### Boss Node — Planned

> **Status: Planned.** `NodeType.BOSS` enum entry not yet in `enums.gd`.

`NodeType.BOSS` is an explicit run terminator — generates exactly one `BossEvent` config. Defeating the boss calls `game.gd._on_boss_defeated()`, not `_on_dungeon_complete()`. The world map is not re-shown.

**Miniboss vs boss:** Every DUNGEON node ends in a **miniboss** (a normal `CombatEvent` that completes normally). A **boss** (NodeType.BOSS) is run-terminating — a `BossEvent` that emits `boss_defeated`. Names are similar but behaviours are distinct.

---

## Signal Flow Diagrams

### Player selects a dungeon node

```
[player clicks WorldMapNode]
  → WorldMapNode._on_node_button_pressed()
    → node_selected.emit(self)
  → WorldMap._on_node_selected(node) → node_selected.emit(node)
  → gui._on_world_map_node_selected(node) → node_selected.emit(node)
  → game._on_world_node_selected(node)
    → node.generate_event_configs() → _pending_event_configs
    → gui.hide_world_map()
    → _start_next_dungeon_event()
      → instantiate event from config[0]
      → event.initialize(config["data"])
      → start_event(event)
```

### Dungeon runs to completion

```
[each event completes]
  → game._on_event_complete()
    → cleanup current event
    → _start_next_dungeon_event()
      → start_event(next event) OR _on_dungeon_complete()

[all events done]
  → game._on_dungeon_complete()
    → gui.world_map_on_dungeon_complete(_active_world_node)
      → WorldMap.on_dungeon_complete(node) → mark COMPLETED, unlock connected
      → gui.show_world_map()
```

### Boss defeated

```
[all boss enemies dead]
  → BossEvent._advance_phase() override → boss_defeated.emit()
  → game._on_boss_defeated()
    → state = VICTORY
    → _apply_rewards → _teardown_current_event → null dungeon state
    → pending_stat_points > 0 ? gui.show_level_up : gui.show_victory
```

### Player dies

```
[player.health reaches 0]
  → player._die() → died.emit()
  → game._on_player_died()
    → state = GAME_OVER
    → _teardown_current_event()
    → gui.show_game_over()          [planned]
```

---

## Open Questions

- **End node behaviour** — Resolved in design (NodeType.BOSS). Implementation pending — see [[daily/2026-04-17]].
- **Start node** — Currently auto-completed by unlocking `initial_nodes`. If it needs content (intro cutscene), revisit `_ready()` init logic.
- **Dungeon modifiers** — Reserve `@export var modifier: Resource` on `WorldMapNode`; leave null for now.
- **Pool weighting** — `_build_random_event_config()` picks uniformly. Weighted pool possible via `weight: int` field if needed.
- **EnemyHUD multi-enemy support** — First pass connects to a single enemy; expand when multi-enemy encounters are designed.
- **CombatLog content** — Text format, what gets logged, scrolling behaviour — future document.
