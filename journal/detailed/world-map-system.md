# World Map System Design

**Date:** 2026-04-01 (updated 2026-04-17)
**Status:** Implemented — except `## Boss Nodes` (see banner in that section)

---

## Overview

Two-layer navigation system sitting between the player and individual events. The **World Map** is a handcrafted branching graph — the player picks a path through dungeon nodes, cannot backtrack, and always visits the same number of nodes regardless of route. Each **World Map Node** (initially just dungeons) owns its event pool and generates a linear sequence of events when entered. The **Dungeon** runs that sequence to completion before returning the player to the World Map.

The World Map lives as a persistent panel in the GUI CanvasLayer — hidden during a dungeon, forced open when a dungeon completes, and optionally openable by the player mid-dungeon.

---

## New Files

| File | Role |
|---|---|
| `scripts/world_map_node.gd` | Individual node — state, visuals, event generation |
| `scenes/world_map_node.tscn` | Node scene |
| `scripts/world_map.gd` | Graph — state transitions, signal relay to game.gd |
| `scenes/world_map.tscn` | Map scene: background art + all positioned nodes |

---

## Changes to Existing Files

| File | Change |
|---|---|
| `scripts/event.gd` | Add `initialize(data: Dictionary)` virtual method |
| `scripts/combat_event.gd` | Remove `@export var event_json_path`; override `initialize()` |
| `scripts/dialogue_event.gd` | Same |
| `scripts/skill_check_event.gd` | Same |
| `scripts/enums.gd` | Add `NodeType` and `NodeState` enums |
| `scripts/game.gd` | Event queue; world map wiring; show/hide map |
| `scripts/gui.gd` | `show_world_map()` / `hide_world_map()`; relay `node_selected` |

---

## Enums

Added to `enums.gd`:

```gdscript
enum NodeType { DUNGEON, SHOP, REST }
enum NodeState { LOCKED, AVAILABLE, COMPLETED }
```

> **Planned:** `BOSS` is listed in `## Boss Nodes` below but is **not yet in `scripts/enums.gd`**. It will be appended when the game-end system is implemented.

---

## Event Base Class — `initialize()`

`event.gd` gains one new virtual method:

```gdscript
func initialize(data: Dictionary) -> void:
    pass
```

Each subclass overrides `initialize()` to store the relevant keys from `data`. `_on_setup()` then reads from those stored vars instead of loading a file. The `@export var event_json_path` is removed from all subclasses.

### Example — `SkillCheckEvent`

Before:
```gdscript
@export var event_json_path: String = ""

func _on_setup() -> void:
    var text = FileAccess.get_file_as_string(event_json_path)
    var data = JSON.parse_string(text)
    _stat = Enums.Stat[data["stat"]]
    _label = data["label"]
    # ...
```

After:
```gdscript
func initialize(data: Dictionary) -> void:
    _stat = Enums.Stat[data["stat"]]
    _label = data["label"]
    _on_success_path = data.get("on_success", "")
    _on_failure_path = data.get("on_failure", "")
    rewards = data.get("rewards", {})

func _on_setup() -> void:
    pass  # data already set by initialize()
```

The same pattern applies to `CombatEvent` and `DialogueEvent`.

---

## `WorldMapNode`

### Node Tree

```
WorldMapNode        Control             scripts/world_map_node.gd
└── NodeButton      TextureButton       visual + click detection
```

`TextureButton` uses its built-in normal/disabled texture slots for AVAILABLE vs LOCKED/COMPLETED states. `WorldMapNode` is positioned in the scene to match the background art.

### Script

```gdscript
class_name WorldMapNode
extends Control

signal node_selected(node: WorldMapNode)

# --- State ---
@export var node_type: Enums.NodeType = Enums.NodeType.DUNGEON
var state: Enums.NodeState = Enums.NodeState.LOCKED

# --- Visuals ---
@export var texture_available: Texture2D
@export var texture_locked: Texture2D
@export var texture_completed: Texture2D

# --- Graph ---
@export var connected_nodes: Array[NodePath]

# --- Dungeon config (used when node_type == DUNGEON) ---
@export var dungeon_depth: int = 4

@export var combat_scene: PackedScene
@export var combat_json_dir: String

@export var dialogue_scene: PackedScene
@export var dialogue_json_dir: String

@export var skill_check_scene: PackedScene
@export var skill_check_json_dir: String

@export var miniboss_scene: PackedScene
@export var miniboss_json_path: String
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

Called by `game.gd` when the player selects the node. Returns a list of config dicts — `dungeon_depth - 1` random entries from the pool, then the miniboss. `game.gd` owns instantiation; the node only produces data.

Each config dict has the shape: `{ "scene": PackedScene, "data": Dictionary }`.

```gdscript
func generate_event_configs() -> Array[Dictionary]:
    var configs: Array[Dictionary] = []

    for i in range(dungeon_depth - 1):
        var config := _build_random_event_config()
        if not config.is_empty():
            configs.append(config)

    var boss_data := _load_json(miniboss_json_path)
    configs.append({ "scene": miniboss_scene, "data": boss_data })

    return configs

func _build_random_event_config() -> Dictionary:
    var candidates: Array[Dictionary] = []
    if combat_scene:
        candidates.append({ "scene": combat_scene, "dir": combat_json_dir, "debug": debug_combat_json_path })
    if dialogue_scene:
        candidates.append({ "scene": dialogue_scene, "dir": dialogue_json_dir, "debug": debug_dialogue_json_path })
    if skill_check_scene:
        candidates.append({ "scene": skill_check_scene, "dir": skill_check_json_dir, "debug": debug_skill_check_json_path })

    if candidates.is_empty():
        return {}

    var pick: Dictionary = candidates[randi() % candidates.size()]
    var files := _get_json_files(pick["dir"])

    var path: String
    if files.is_empty():
        push_warning("[WorldMapNode] No JSON files found in '%s' — falling back to debug file." % pick["dir"])
        path = pick["debug"]
    else:
        path = files[randi() % files.size()]

    return { "scene": pick["scene"], "data": _load_json(path) }
```

Each event type gets a paired debug fallback export:

```gdscript
@export var debug_combat_json_path: String
@export var debug_dialogue_json_path: String
@export var debug_skill_check_json_path: String
```

These are set in the editor to point at the existing example JSON files. They are only used when a type's `json_dir` yields no files.

func _get_json_files(dir_path: String) -> Array[String]:
    var files: Array[String] = []
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return files
    dir.list_dir_begin()
    var file := dir.get_next()
    while file != "":
        if file.ends_with(".json"):
            files.append(dir_path.path_join(file))
        file = dir.get_next()
    return files

func _load_json(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    return JSON.parse_string(text)
```

---

## `WorldMap`

### Node Tree

```
WorldMap            Control             scripts/world_map.gd
├── Background      TextureRect         handcrafted art — lines already drawn
└── NodeContainer   Node                all WorldMapNode children, positioned to match art
    ├── StartNode   WorldMapNode        stub (COMPLETED on _ready)
    ├── Row1Node1   WorldMapNode
    ├── Row1Node2   WorldMapNode
    ├── Row1Node3   WorldMapNode
    ├── Row2Node1   WorldMapNode
    ├── Row2Node2   WorldMapNode
    ├── Row2Node3   WorldMapNode
    ├── Row3Node1   WorldMapNode
    ├── Row3Node2   WorldMapNode
    ├── Row3Node3   WorldMapNode
    └── EndNode     WorldMapNode        stub
```

Total nodes visited per run: 1 (start, auto-completed) + 3 (one per row) + 1 (end, stub) = 5.

Connections are sparse — set via `connected_nodes` NodePath exports in the editor. Not every node in a row connects to every node in the next row.

### Script

```gdscript
class_name WorldMap
extends Control

signal node_selected(node: WorldMapNode)

# Set in editor — nodes that become AVAILABLE at game start (first row)
@export var initial_nodes: Array[NodePath]

func _ready() -> void:
    # Lock everything first
    for child in $NodeContainer.get_children():
        if child is WorldMapNode:
            child.set_state(Enums.NodeState.LOCKED)
            child.node_selected.connect(_on_node_selected)

    # Unlock the first row
    for path in initial_nodes:
        var node := get_node(path) as WorldMapNode
        if node:
            node.set_state(Enums.NodeState.AVAILABLE)

func on_dungeon_complete(completed_node: WorldMapNode) -> void:
    completed_node.set_state(Enums.NodeState.COMPLETED)
    for path in completed_node.connected_nodes:
        var next := get_node(path) as WorldMapNode
        if next and next.state == Enums.NodeState.LOCKED:
            next.set_state(Enums.NodeState.AVAILABLE)

func _on_node_selected(node: WorldMapNode) -> void:
    node_selected.emit(node)
```

---

## `game.gd` Changes

### New State

```gdscript
var _pending_event_configs: Array[Dictionary] = []
var _event_index: int = 0
var _active_world_node: WorldMapNode = null
```

### World Map Wiring (in `_ready()`)

```gdscript
_gui.node_selected.connect(_on_world_node_selected)
```

`gui.gd` relays `WorldMap.node_selected` → `gui.node_selected` (same pattern as `skill_check_complete`, `dialogue_complete`, etc.).

### New Handlers

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

After existing cleanup (signal disconnect, `queue_free`, etc.), add:

```gdscript
if not _pending_event_configs.is_empty() and _event_index <= _pending_event_configs.size():
    _start_next_dungeon_event()
```

This replaces any existing `_finish_event()` stub that led nowhere. The dungeon queue is now what drives progression.

---

## `gui.gd` Changes

```gdscript
signal node_selected(node: WorldMapNode)

func show_world_map() -> void:
    $WorldMap.show()

func hide_world_map() -> void:
    $WorldMap.hide()

func world_map_on_dungeon_complete(node: WorldMapNode) -> void:
    $WorldMap.on_dungeon_complete(node)
    show_world_map()

func _on_world_map_node_selected(node: WorldMapNode) -> void:
    node_selected.emit(node)
```

`$WorldMap.node_selected` is connected to `_on_world_map_node_selected` in `gui.gd._ready()`.

---

## Signal Flow

**Player selects a dungeon node:**
```
[player clicks WorldMapNode]
  → WorldMapNode._on_node_button_pressed()
    → node_selected.emit(self)
  → WorldMap._on_node_selected(node)
    → node_selected.emit(node)
  → gui._on_world_map_node_selected(node)
    → node_selected.emit(node)
  → game._on_world_node_selected(node)
    → node.generate_event_configs() → _pending_event_configs
    → gui.hide_world_map()
    → _start_next_dungeon_event()
      → instantiate event from config[0], add_child to EventContainer
      → event.initialize(config["data"])
      → start_event(event)
```

**Dungeon runs to completion:**
```
[each event completes]
  → game._on_event_complete()
    → cleanup current event
    → _start_next_dungeon_event()
      → start_event(next event) OR _on_dungeon_complete()

[all events done]
  → game._on_dungeon_complete()
    → gui.world_map_on_dungeon_complete(_active_world_node)
      → WorldMap.on_dungeon_complete(node)
        → node.set_state(COMPLETED)
        → connected nodes → set_state(AVAILABLE)
      → gui.show_world_map()
```

---

## Open Questions

- **End node behaviour** — _Resolved 2026-04-17 (design only; not yet implemented)._ End nodes will use `NodeType.BOSS` pointing at a `BossEvent` (see `## Boss Nodes` below and `event-scene-design.md § BossEvent`). Boss defeat triggers the victory flow in `game.gd._on_boss_defeated()`; the world map is not re-shown. No credits or run summary — the victory panel is the terminal UI. Until this lands, every dungeon terminates with a `miniboss_*` combat encounter and the map is re-shown on completion.
- **Start node** — Currently auto-completed by unlocking `initial_nodes` directly. If the start node needs to be a scene with its own content (intro cutscene, tutorial), revisit the `_ready()` init logic.
- **Dungeon modifiers** — `WorldMapNode` should eventually carry a modifier that applies a buff/debuff before events start. Reserve a field (`@export var modifier: Resource`) but leave it null for now.
- **Pool weighting** — `_create_random_event()` picks uniformly across available types. If certain event types should appear more or less often, a weighted pool (e.g. `Array[Dictionary]` with a `weight: int` field) could replace the uniform draw.
- **Empty pool guard** — ~~Resolved~~. If a type's `json_dir` yields no files, `_build_random_event_config()` falls back to the paired `debug_*_json_path` export and logs a `push_warning()`. Set debug paths to the existing example JSON files in the editor.
- **Event ownership** — ~~Resolved~~. `generate_event_configs()` returns plain data — no nodes are instantiated. `game.gd` instantiates each event from the config dict in `_start_next_dungeon_event()`, adds it to `$EventContainer`, calls `initialize()`, then passes it to `start_event()`.

---

## Boss Nodes

**Date:** 2026-04-17

> **Status: Planned — not yet implemented.** See `journal/daily/2026-04-17.md` for the implementation punch list (`NodeType.BOSS` enum addition, `boss_scene` / `boss_data_json_path` exports, `_build_boss_config()`, dispatch in `generate_event_configs()`).

**Miniboss vs boss — don't confuse them.** Every DUNGEON node currently ends in a **miniboss** combat encounter (`miniboss_scene` / `miniboss_json_path` exports in `WorldMapNode`, appended in `generate_event_configs()`). That's a normal `CombatEvent` that completes, awards rewards, and returns to the world map. A **boss** (planned) is run-terminating: a dedicated `BossEvent` subclass behind `NodeType.BOSS`, emitting `boss_defeated` instead of `event_complete`. The names are similar but the behaviours are distinct — keep them separate in both code and discussion.

`NodeType.BOSS` is an explicit terminator. It generates exactly one `BossEvent` config — no random pool, no miniboss appendage. Defeating it triggers the victory flow; the world map is not re-shown.

### Exports (in `world_map_node.gd`)

Added alongside the existing SHOP and REST sections:

```gdscript
# --- Boss Config ---
@export var boss_scene: PackedScene           # scenes/boss_event.tscn
@export var boss_data_json_path: String       # resources/events/boss/<name>.json
```

Reuses the existing `texture_available` / `texture_locked` / `texture_completed` exports — the editor assigns boss-distinct art per BOSS node instance. Dungeon-only exports (`dungeon_depth`, `combat_json_dir`, `miniboss_scene`, etc.) stay at defaults on BOSS instances and are simply unused.

### Builder

```gdscript
func _build_boss_config() -> Array[Dictionary]:
    return [{ "scene": boss_scene, "data": _load_json(boss_data_json_path) }]
```

### Dispatch

Added to `generate_event_configs()`:

```gdscript
if node_type == Enums.NodeType.BOSS:
    return _build_boss_config()
```

### Run Termination

A BOSS node is the last node in a run by design. Defeating the boss calls `game.gd._on_boss_defeated()`, which intercepts the completion flow and shows the victory panel directly — see `event-scene-design.md § BossEvent`. `_on_dungeon_complete()` is not called; `_active_world_node` is nulled in `_on_boss_defeated()`; no `on_dungeon_complete` propagation to the map.

Multiple BOSS nodes on one map are allowed mechanically (e.g. alternate-path bosses), but any `boss_defeated` signal ends the run. If future design requires non-terminating boss nodes (a mid-run mini-boss with boss-tier drops), a separate event subclass should be used rather than overloading BOSS.
