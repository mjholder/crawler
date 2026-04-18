# Character System Design

**Date:** 2026-03-05 (consolidated 2026-04-18)
**Status:** Implemented

Merged from: `equipment-system.md`, `inventory-system.md`, `player-node-implementation.md`, `player-classes-and-leveling.md`

---

## Overview

This document covers everything about the player character: shared enumerations, equipment data and visual nodes, inventory storage, the player node itself, stat calculation, classes, and leveling. Changing any item, equip, inventory, or level feature means updating this file.

---

## Shared Enumerations — `scripts/enums.gd`

`class_name Enums` holds all game-wide enumerations. Neither `Player` nor `Equipment` owns these — both reference `Enums`.

```gdscript
enum Stat {
    STRENGTH,     # 0
    DEFENSE,      # 1
    CONSTITUTION, # 2
    AGILITY,      # 3
    SPIRIT,       # 4
    LUCK          # 5
}

enum Slot { WEAPON, HANDS, FEET, LEGS, TORSO, HEAD }
```

Numeric keys are used when assigning `stat_modifiers` in `.tres` files — e.g. `{ 0: 10.0 }` adds +10 STRENGTH. Six named body slots cover all non-ring equipment; rings are managed as a fixed-size array on `Inventory`.

> **Note:** `TurnState`, `NodeType`, and `NodeState` also live in `enums.gd` — they are documented in `game-flow.md`.

---

## EquipmentData Resource

```gdscript
class_name EquipmentData
extends Resource    # scripts/equipment_data.gd

@export var item_name: String = ""
@export var description: String = ""
@export var sprite_frames: SpriteFrames
@export var equip_sfx: AudioStream
@export var unequip_sfx: AudioStream
@export var stat_modifiers: Dictionary  # Enums.Stat → float
@export var scene: PackedScene          # Equipment or Weapon scene to instantiate
@export var slot: Enums.Slot = Enums.Slot.WEAPON
@export var is_ring: bool = false
@export var price: int = 0
```

`stat_modifiers` uses `Enums.Stat` keys. An armor piece that grants +15 defense and +5 constitution:
```gdscript
{ Enums.Stat.DEFENSE: 15.0, Enums.Stat.CONSTITUTION: 5.0 }
```
Omitted stats contribute zero.

- `scene` — `PackedScene` instantiated when equipped. Weapons → `weapon.tscn`; non-weapon gear → `equipment.tscn`. If null, `_setup_equipment` skips node instantiation (stat layer still works — reads `stat_modifiers` directly).
- `slot` — which named slot this targets. Ignored when `is_ring == true`.
- `is_ring` — routes equip calls through `Inventory.equip_ring` rather than a named slot.
- `price` — base value for `ShopEvent` buy/sell calculation. `0` = not priced (treated as a data bug by shops).

### WeaponData extends EquipmentData

```gdscript
class_name WeaponData
extends EquipmentData    # scripts/weapon_data.gd

@export var attack_sfx: AudioStream
```

Adds an attack sound. Weapon-specific data (damage type, special attack properties) can be added here as those systems are designed.

---

## Equipment Node Trees

### `equipment.tscn` — script: `equipment.gd`

```
Equipment           Node2D              scripts/equipment.gd
├── Sprite          AnimatedSprite2D    SpriteFrames swapped from EquipmentData on load
├── AnimationPlayer AnimationPlayer     multi-phase animation sequences
└── SFX             Node
    ├── EquipPlayer     AudioStreamPlayer2D
    └── UnequipPlayer   AudioStreamPlayer2D
```

### `weapon.tscn` — inherits `equipment.tscn`, script: `weapon.gd`

```
Weapon              Node2D              scripts/weapon.gd
├── Sprite          AnimatedSprite2D
├── AnimationPlayer AnimationPlayer
└── SFX             Node
    ├── EquipPlayer     AudioStreamPlayer2D
    ├── UnequipPlayer   AudioStreamPlayer2D
    └── AttackPlayer    AudioStreamPlayer2D
```

`weapon.tscn` adds `AttackPlayer` under `SFX`. No other structural differences.

---

## `equipment.gd`

```gdscript
class_name Equipment
extends Node2D

@export var data: EquipmentData

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _equip_player: AudioStreamPlayer2D = $SFX/EquipPlayer
@onready var _unequip_player: AudioStreamPlayer2D = $SFX/UnequipPlayer

func _ready() -> void:
    if data:
        _sprite.sprite_frames = data.sprite_frames
        _equip_player.stream = data.equip_sfx
        _unequip_player.stream = data.unequip_sfx
    _sprite.play("idle")

func get_modifier(stat: Enums.Stat) -> float:
    if data == null or not data.stat_modifiers.has(stat):
        return 0.0
    return data.stat_modifiers[stat]

func play_equip() -> void:
    if _equip_player.stream != null: _equip_player.play()

func play_unequip() -> void:
    if _unequip_player.stream != null: _unequip_player.play()

# Extension hooks — do nothing in base, safe to override:
func _on_equipped() -> void:
    _scale_sprite_to_viewport()

func _on_unequipped() -> void:
    pass
```

### Animations

Every `SpriteFrames` resource assigned to an equipment item must define at minimum:

| Animation | Loop | Notes |
|---|---|---|
| `idle` | yes | Default resting state |
| `attack` | no | Weapons only — played on `_on_player_attacked()` |

For single-phase attack, `AnimatedSprite2D` is driven directly. `AnimationPlayer` is present for future multi-phase sequences but is not in the current attack path.

---

## `weapon.gd`

Reacts to the Player's `attack` signal. Does not own attack logic — only plays animation and sound.

```gdscript
class_name Weapon
extends Equipment

signal animation_finished

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer

func _ready() -> void:
    super._ready()
    if data is WeaponData:
        _attack_player.stream = (data as WeaponData).attack_sfx
    _sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_player_attacked(damage: float) -> void:
    if _attack_player.stream != null:
        _attack_player.play()
    _sprite.play("attack")

func _on_sprite_animation_finished() -> void:
    if _sprite.animation == &"attack":
        animation_finished.emit()
        _sprite.play("idle")
```

The Player connects `attack` → `weapon._on_player_attacked()` when equipping. Weapon never reaches into the Player.

`animation_finished` (Weapon signal, not `AnimatedSprite2D`'s) is what the Player listens to for turn gating — fires only when the attack animation ends.

### Signal Contract

| Signal | Emitted by | Connected to | Wired by |
|---|---|---|---|
| `attack(damage: float)` | `player.gd` | `weapon._on_player_attacked()` | `player._setup_equipment()` / `_teardown_equipment()` |
| `animation_finished` | `weapon.gd` | `player._on_weapon_animation_finished()` | `player._setup_equipment()` / `_teardown_equipment()` |

---

## Inventory Node

`Inventory` lives under `Player` and owns all item state. External code talks to `Inventory` only — never writes directly to `Player`.

`Inventory` manages **data** (`EquipmentData` resources). Equipment **nodes** remain children of `Player` and are created/destroyed in response to `Inventory` signals.

### Node Tree

```
Player                  Node2D              scripts/player.gd
├── Inventory           Node                scripts/inventory.gd
└── SFX                 Node
    └── ...
```

### State

```gdscript
class_name Inventory
extends Node

@export var max_bag_size: int = 20
@export var max_rings: int = 2

var _equipped: Dictionary = {}   # Enums.Slot -> EquipmentData
var _rings: Array = []           # Array of EquipmentData or null, length = max_rings
var _bag: Array[EquipmentData] = []

func _ready() -> void:
    _rings.resize(max_rings)
    _rings.fill(null)
```

### Signals

```gdscript
signal slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData)
signal ring_changed(index: int, new_data: EquipmentData, old_data: EquipmentData)
signal bag_changed()
```

Either `new_data` or `old_data` can be `null` (filling from empty or becoming empty). Player uses these to manage Equipment node lifecycle.

### Named Slot API

```gdscript
# Equip to a named slot. If occupied, old item goes to bag. If bag full, old item is lost.
func equip(slot: Enums.Slot, data: EquipmentData) -> void:
    var old: EquipmentData = _equipped.get(slot, null)
    if old != null: add_to_bag(old)
    _equipped[slot] = data
    slot_changed.emit(slot, data, old)

func unequip(slot: Enums.Slot) -> void:
    if not _equipped.has(slot): return
    var old: EquipmentData = _equipped[slot]
    _equipped.erase(slot)
    add_to_bag(old)
    slot_changed.emit(slot, null, old)

func get_equipped(slot: Enums.Slot) -> EquipmentData:
    return _equipped.get(slot, null)
```

### Ring API

```gdscript
# Equip into the first open ring slot. Returns false if all slots are full.
func equip_ring(data: EquipmentData) -> bool

# Equip to a specific index, displacing the current occupant to the bag.
func equip_ring_at(index: int, data: EquipmentData) -> void

func unequip_ring(index: int) -> void

func get_rings() -> Array  # returns duplicate
```

### Bag API

```gdscript
func add_to_bag(data: EquipmentData) -> bool   # returns false if full
func remove_from_bag(data: EquipmentData) -> void
func is_bag_full() -> bool
func get_bag() -> Array[EquipmentData]          # returns duplicate
```

### Utility

```gdscript
# Returns all equipped EquipmentData across named slots and rings.
# Used by Player.get_effective_stat().
func get_all_equipped() -> Array[EquipmentData]

# Resets all slots, rings, and bag. Called by player.initialize() on new game.
func clear() -> void
```

### Expanding Ring Slots

```gdscript
player._inventory.max_rings += 1
player._inventory._rings.append(null)
```

No signal needed — UI reads `get_rings()`.

---

## Equipment Node Lifecycle

Player responds to `slot_changed` and `ring_changed` to manage scene-tree children. Both follow the same pattern.

```gdscript
# Connected in player._ready():
_inventory.slot_changed.connect(_on_slot_changed)
_inventory.ring_changed.connect(_on_ring_changed)

func _on_slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData) -> void:
    if old_data != null: _teardown_equipment(slot, old_data)
    if new_data != null: _setup_equipment(slot, new_data)


func _setup_equipment(slot: Enums.Slot, data: EquipmentData) -> void:
    if data.scene == null: return     # rings or gear without visuals — stat layer still works
    var node := data.scene.instantiate() as Equipment
    node.data = data
    add_child(node)
    node.play_equip()
    node._on_equipped()
    if slot == Enums.Slot.WEAPON:
        attack.connect((node as Weapon)._on_player_attacked)
        (node as Weapon).animation_finished.connect(_on_weapon_animation_finished)


func _teardown_equipment(slot: Enums.Slot, data: EquipmentData) -> void:
    for child in get_children():
        if child is Equipment and child.data == data:
            child.play_unequip()
            child._on_unequipped()
            if slot == Enums.Slot.WEAPON:
                attack.disconnect((child as Weapon)._on_player_attacked)
                (child as Weapon).animation_finished.disconnect(_on_weapon_animation_finished)
            child.queue_free()
            return
```

---

## Player Node

### Node Tree

```
Player              Node2D              scripts/player.gd
└── SFX             Node
    ├── AttackPlayer    AudioStreamPlayer2D
    ├── HurtPlayer      AudioStreamPlayer2D
    └── DeathPlayer     AudioStreamPlayer2D
```

`Sprite` and `AnimationPlayer` were removed — all visual output is owned by the equipped `Weapon` node added as a child at runtime.

The hurt overlay is **not a child of this scene**. It lives as `HurtOverlay/HurtRect` (a `ColorRect` on `CanvasLayer 3`) in `game.tscn`. `game.gd._ready()` calls `$Player.set_hurt_overlay($HurtOverlay/HurtRect)`.

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

### Turn Gate

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

`_attack_animation_pending` is set in `_do_attack()` when a weapon is equipped, cleared when `Weapon.animation_finished` fires. `game.gd` is unchanged — it connects to `turn_ended` and doesn't care when it fires.

### Node Wiring

```gdscript
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer

var _hurt_overlay: ColorRect = null      # set via set_hurt_overlay() from game.gd
var _attack_animation_pending: bool = false

func _ready() -> void:
    health = max_health
    _register_actions()
    _transition(State.IDLE)
    _inventory.slot_changed.connect(_on_slot_changed)
    _inventory.ring_changed.connect(_on_ring_changed)
```

All play calls are null-guarded: `if player.stream != null: player.play()`.

### Action System

```gdscript
func _register_actions() -> void:
    register_action("attack", _do_attack)

func _do_attack() -> void:
    _play_sfx(_attack_player)
    if _inventory.get_equipped(Enums.Slot.WEAPON) != null:
        _attack_animation_pending = true
    attack.emit(_calculate_damage())
```

Adding future actions: call `register_action("action_name", _do_action_name)` in `_register_actions()`. Follow the same pattern: play SFX, emit intent signal. No changes to `execute_action()`, `_process()`, or turn gate needed.

### Player Signals

| Signal | Emitted when | Connected by |
|---|---|---|
| `turn_ended` | `_process()` after `_is_turn_complete()` | `game.gd` in `set_player()` |
| `attack(damage: float)` | `_do_attack()` | `game.gd` → `CombatEvent.receive_player_attack`; also `Weapon._on_player_attacked` |
| `damaged(amount: float)` | `take_damage()` | `game.gd` → `gui.update_player_health()` |
| `died` | `_die()` | `game.gd` in `set_player()` |
| `gold_changed(new_total: int)` | `add_gold()` | `game.gd` → `gui.update_player_gold()` |
| `experience_changed(new_total: int)` | `add_experience()` | `game.gd` → `gui.update_player_xp()` |

---

## Effective Stat Calculation

```gdscript
func get_effective_stat(stat: Enums.Stat) -> float:
    var base := _get_base_stat(stat)
    var bonus := 0.0
    for data in _inventory.get_all_equipped():
        if data.stat_modifiers.has(stat):
            bonus += data.stat_modifiers[stat]
    return base + bonus

func _get_base_stat(stat: Enums.Stat) -> float:
    match stat:
        Enums.Stat.STRENGTH:     return strength
        Enums.Stat.DEFENSE:      return defense
        Enums.Stat.CONSTITUTION: return constitution
        Enums.Stat.AGILITY:      return agility
        Enums.Stat.SPIRIT:       return spirit
        Enums.Stat.LUCK:         return luck
    return 0.0
```

Reads from `EquipmentData.stat_modifiers` directly — not from Equipment nodes. Stat math works even when an item has no scene (e.g. rings without visuals).

`_calculate_damage()` and `_apply_defense()` call `get_effective_stat()` rather than reading raw floats directly.

---

## PlayerClassData Resource

```gdscript
class_name PlayerClassData
extends Resource    # scripts/player_class_data.gd

@export var class_name_text: String = ""
@export var description: String = ""

# Starting Stats
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# Health — flat bonus on top of CON-derived base max health
@export var class_health_bonus: float = 0.0

# Per-Level Growth — Enums.Stat -> float; applied automatically each level
@export var growth_rates: Dictionary = {}

# Starting Equipment
@export var starting_equipped: Dictionary = {}   # Enums.Slot -> EquipmentData
@export var starting_rings: Array[EquipmentData] = []
@export var starting_bag: Array[EquipmentData] = []
```

**File location:** `resources/classes/warrior.tres`, `rogue.tres`, etc.

**Warrior example:**

| Field | Value |
|---|---|
| class_name_text | "Warrior" |
| strength | 60.0, constitution | 55.0, agility | 40.0 |
| class_health_bonus | 20.0 |
| growth_rates | `{ STR: 3.0, CON: 2.0 }` |
| starting_equipped | `{ WEAPON: battle_axe.tres, TORSO: leather_chest, … }` |

---

## Max Health Formula

```
base_max_health = effective_CON * health_modifier
max_health = base_max_health + class_health_bonus
```

`health_modifier` is an exported tuning var on Player (e.g. `2.0`). Max health is recalculated whenever stats change. When max health increases, current health increases by the same delta.

```gdscript
@export var health_modifier: float = 2.0

func _recalculate_max_health() -> void:
    var old_max := max_health
    var effective_con := get_effective_stat(Enums.Stat.CONSTITUTION)
    max_health = (effective_con * health_modifier) + _class_data.class_health_bonus
    var delta := max_health - old_max
    if delta > 0.0:
        health += delta
    else:
        health = minf(health, max_health)
```

Called from `_on_slot_changed`, `_on_ring_changed`, and after stat point allocation.

---

## Player Initialization

```gdscript
var _class_data: PlayerClassData

func initialize(p_name: String, class_data: PlayerClassData) -> void:
    _class_data = class_data
    player_name = p_name
    strength = class_data.strength
    defense = class_data.defense
    constitution = class_data.constitution
    agility = class_data.agility
    spirit = class_data.spirit
    luck = class_data.luck
    gold = 0
    _inventory.clear()
    _recalculate_max_health()
    health = max_health
    _setup_starting_equipment(class_data)

func _setup_starting_equipment(class_data: PlayerClassData) -> void:
    for slot_key in class_data.starting_equipped:
        _inventory.equip(slot_key as Enums.Slot, class_data.starting_equipped[slot_key])
    for ring in class_data.starting_rings:
        _inventory.equip_ring(ring)
    for item in class_data.starting_bag:
        _inventory.add_to_bag(item)
```

`gold = 0` and `_inventory.clear()` ensure a clean state when starting a new run. `clear()` resets `_equipped`, `_rings`, and `_bag`.

`base_damage` was removed from Player — unarmed damage will be handled by an "unarmed" weapon resource auto-equipped when no other weapon is present.

---

## Leveling System

### State on Player

```gdscript
var level: int = 1
var experience: int = 0
var pending_stat_points: int = 0

signal leveled_up(new_level: int)
```

### XP Curve

```gdscript
@export var xp_base: float = 100.0
@export var xp_growth_factor: float = 1.15

func xp_to_next_level() -> int:
    return int(xp_base * pow(xp_growth_factor, level - 1))
```

| Level | XP Required | Cumulative |
|---|---|---|
| 1→2 | 100 | 100 |
| 2→3 | 115 | 215 |
| 5→6 | 175 | 697 |
| 10→11 | 325 | 2,030 |

### Level-Up Logic

```gdscript
func add_experience(amount: int) -> void:
    experience += amount
    while experience >= xp_to_next_level():
        experience -= xp_to_next_level()
        _level_up()
    experience_changed.emit(experience)

func _level_up() -> void:
    level += 1
    _apply_growth_rates()
    pending_stat_points += 3
    leveled_up.emit(level)

func _apply_growth_rates() -> void:
    for stat_key in _class_data.growth_rates:
        _add_to_base_stat(stat_key as Enums.Stat, _class_data.growth_rates[stat_key])
    _recalculate_max_health()
```

Multiple level-ups in a single XP grant handled by the `while` loop.

### Free Point Distribution

```gdscript
func spend_stat_point(stat: Enums.Stat) -> void:
    if pending_stat_points <= 0: return
    _add_to_base_stat(stat, 1.0)
    pending_stat_points -= 1
    _recalculate_max_health()
    stats_changed.emit(build_stats_dict())

func _add_to_base_stat(stat: Enums.Stat, amount: float) -> void:
    match stat:
        Enums.Stat.STRENGTH:     strength += amount
        Enums.Stat.DEFENSE:      defense += amount
        Enums.Stat.CONSTITUTION: constitution += amount
        Enums.Stat.AGILITY:      agility += amount
        Enums.Stat.SPIRIT:       spirit += amount
        Enums.Stat.LUCK:         luck += amount
```

---

## Character Creation Flow

### Sequence

```
MainMenu
  └── [Start Button pressed]
       └── Character Creation Screen shown
            ├── Name input (LineEdit)
            ├── Class picker (list of PlayerClassData)
            └── [Continue pressed]
                 └── game.gd receives (name, class_data)
                      ├── player.initialize(name, class_data)
                      └── start_game() → show world map
```

### gui.gd Changes

```gdscript
signal character_created(player_name: String, class_data: PlayerClassData)

@onready var _character_creation: Control = $CharacterCreation
```

`_on_start_button_pressed()` shows the character creation screen instead of emitting `start_requested`. The creation screen emits `character_created` when confirmed. `start_requested` signal is removed.

### game.gd Changes

```gdscript
# In _ready():
_gui.character_created.connect(_on_character_created)
# Remove: _gui.start_requested.connect(start_game)
# Remove: _setup_starting_equipment()

func _on_character_created(p_name: String, class_data: PlayerClassData) -> void:
    player.initialize(p_name, class_data)
    _gui.start_game()
    _gui.show_world_map()
    _gui.update_player_health(player.health, player.max_health)
    _gui.update_player_stats(player.build_stats_dict())
```

---

## Level-Up UI Flow

### When It Triggers

At the end of `game.gd._on_event_complete()`, after rewards are applied:

```gdscript
func _on_event_complete() -> void:
    # ... existing cleanup ...
    _apply_rewards(current_event.rewards)
    if player.pending_stat_points > 0:
        _gui.show_level_up(player.level, player.pending_stat_points, player.build_stats_dict())
        return  # Don't proceed to _finish_event yet
    _finish_event()

func _on_level_up_complete() -> void:
    if state == Enums.TurnState.VICTORY:
        _gui.show_victory()
    else:
        _finish_event()
```

### Signal Chain

```
Player.leveled_up(level) → game.gd stores info
Event completes → game.gd checks pending_stat_points
  → gui.show_level_up(...)
    → LevelUpPanel shown
      → player.spend_stat_point() on each +
      → Confirm pressed → level_up_complete signal
        → game.gd._on_level_up_complete() → _finish_event() or show_victory()
```

---

## Open Questions

- **Unarmed weapon:** Needs its own `.tres` resource and logic to auto-equip when no weapon is present. `base_damage` was removed — this dependency is not yet resolved.
- **Class-specific actions:** Should classes unlock unique actions (e.g. rogue's "backstab")? Not in scope — can be layered on via action registration in `initialize()`.
- **Lost items when bag is full:** If the bag is full during slot displacement, the old item is silently lost. A `item_lost(data)` signal could be added for combat-log feedback.
- **Ring visual slots:** If `EquipmentData.scene` is null, `_setup_equipment` already guards — stat layer still works.
- **Slot validation:** Nothing prevents equipping a `WeaponData` to `Slot.TORSO`. A `valid_slots: Array[Enums.Slot]` field on `EquipmentData` could enforce this.
- **ArmorData / armor.gd:** `Armor extends Equipment` with no additions initially. A block action or damage-reduction hook added in `armor.gd` when that mechanic is designed.
- **Level cap:** Not defined — can be added as an export var when content scope is clearer.
- **Respec:** Not planned.
- **XP display:** HUD should show progress toward next level ("XP: 45/115") once leveling lands in the UI.
