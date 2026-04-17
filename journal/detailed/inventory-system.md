# Inventory System — Design

**Date:** 2026-04-04 (updated 2026-04-17)
**Status:** Implemented

This document covers the architecture of the inventory system: the `Inventory` node that acts as the single API for all item management, the expanded slot model, how storage is represented, and the changes required to `Player` and `EquipmentData`.

---

## Overview

The `Inventory` node lives under `Player` and owns all item state: what is equipped in each named slot, what rings are worn, and what is sitting in the bag. External code (combat, loot, UI, save/load) talks to `Inventory` only — it never writes directly to `Player`.

`Inventory` manages **data** (`EquipmentData` resources). Equipment **nodes** (`Equipment`, `Weapon`) remain children of `Player` and are created/destroyed in response to `Inventory` signals. The separation keeps the visual layer out of the inventory logic and consistent with the existing signal-based UI separation pattern.

---

## Enums.Slot Expansion

`Enums.Slot` gains six named body slots. Rings are **not** an enum value — they are managed as a fixed-size array on `Inventory` so the count can be changed at runtime (e.g. a powerup granting a third ring slot).

```gdscript
enum Slot {
    WEAPON,
    HANDS,
    FEET,
    LEGS,
    TORSO,
    HEAD
}
```

---

## EquipmentData — Added Field

To allow `Inventory` to instantiate the correct `Equipment` node from data alone, `EquipmentData` gains a `scene` reference:

```gdscript
@export var scene: PackedScene  # Equipment or Weapon scene to instantiate
```

When equipping, `Inventory` emits a signal carrying the `EquipmentData`. `Player` receives it, calls `data.scene.instantiate()`, sets `node.data = data`, and adds it as a child. This keeps scene instantiation on the Player where it belongs without Inventory reaching into the scene tree.

---

## Node Tree

```
Player                  Node2D              scripts/player.gd
├── Inventory           Node                scripts/inventory.gd
└── SFX                 Node
    └── ...
```

`Inventory` is a plain `Node` — no visuals. The Player gets a reference to it in `_ready()` via `@onready`.

---

## `inventory.gd`

### State

```gdscript
class_name Inventory
extends Node

@export var max_bag_size: int = 20
@export var max_rings: int = 2

var _equipped: Dictionary = {}   # Enums.Slot -> EquipmentData
var _rings: Array = []           # Array of EquipmentData or null, length = max_rings
var _bag: Array[EquipmentData] = []
```

`_rings` is initialized in `_ready()` to an array of `null` values with length `max_rings`. Using an untyped `Array` allows `null` entries to represent empty ring slots.

```gdscript
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

`slot_changed` and `ring_changed` carry both the incoming and outgoing data. Either can be `null` (slot becoming empty, or filling from empty). `Player` uses these to manage Equipment node lifecycle.

### Named Slot API

```gdscript
# Equip data to a named slot. If the slot is occupied, the old item is sent
# to the bag. If the bag is full, the old item is lost.
func equip(slot: Enums.Slot, data: EquipmentData) -> void:
    var old: EquipmentData = _equipped.get(slot, null)
    if old != null:
        add_to_bag(old)
    _equipped[slot] = data
    slot_changed.emit(slot, data, old)


# Remove the item in a named slot and send it to the bag.
# If the bag is full, the item is lost.
func unequip(slot: Enums.Slot) -> void:
    if not _equipped.has(slot):
        return
    var old: EquipmentData = _equipped[slot]
    _equipped.erase(slot)
    add_to_bag(old)
    slot_changed.emit(slot, null, old)


func get_equipped(slot: Enums.Slot) -> EquipmentData:
    return _equipped.get(slot, null)
```

### Ring API

```gdscript
# Equip a ring into the first open slot. Returns false if all slots are full.
func equip_ring(data: EquipmentData) -> bool:
    for i in range(_rings.size()):
        if _rings[i] == null:
            _rings[i] = data
            ring_changed.emit(i, data, null)
            return true
    return false


# Equip a ring to a specific index, displacing the current occupant to the bag.
func equip_ring_at(index: int, data: EquipmentData) -> void:
    if index < 0 or index >= _rings.size():
        return
    var old = _rings[index]
    _rings[index] = data
    if old != null:
        add_to_bag(old)
    ring_changed.emit(index, data, old)


# Remove the ring at index and send it to the bag.
func unequip_ring(index: int) -> void:
    if index < 0 or index >= _rings.size() or _rings[index] == null:
        return
    var old = _rings[index]
    _rings[index] = null
    add_to_bag(old)
    ring_changed.emit(index, null, old)


func get_rings() -> Array:
    return _rings.duplicate()
```

### Bag API

```gdscript
# Returns false and does nothing if the bag is full.
func add_to_bag(data: EquipmentData) -> bool:
    if _bag.size() >= max_bag_size:
        return false
    _bag.append(data)
    bag_changed.emit()
    return true


func remove_from_bag(data: EquipmentData) -> void:
    var index := _bag.find(data)
    if index == -1:
        return
    _bag.remove_at(index)
    bag_changed.emit()


func is_bag_full() -> bool:
    return _bag.size() >= max_bag_size


func get_bag() -> Array[EquipmentData]:
    return _bag.duplicate()
```

### Utility

```gdscript
# Returns all currently equipped EquipmentData across named slots and rings.
# Used by Player.get_effective_stat().
func get_all_equipped() -> Array[EquipmentData]:
    var result: Array[EquipmentData] = []
    for data in _equipped.values():
        result.append(data)
    for ring in _rings:
        if ring != null:
            result.append(ring)
    return result
```

---

## Player Changes

### Removed

- `var _equipped: Dictionary` — moves to `Inventory`
- `func equip(slot, item)` — replaced by `_inventory.equip(slot, data)`

### Added

```gdscript
@onready var _inventory: Inventory = $Inventory
```

In `_ready()`, connect inventory signals:

```gdscript
_inventory.slot_changed.connect(_on_slot_changed)
_inventory.ring_changed.connect(_on_ring_changed)
```

### Equipment Node Lifecycle

`Player` responds to `slot_changed` and `ring_changed` to manage scene-tree children. Both follow the same pattern:

```gdscript
func _on_slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData) -> void:
    if old_data != null:
        _teardown_equipment(slot, old_data)
    if new_data != null:
        _setup_equipment(slot, new_data)


func _setup_equipment(slot: Enums.Slot, data: EquipmentData) -> void:
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

### Effective Stat Calculation

`get_effective_stat()` reads from `EquipmentData.stat_modifiers` directly via `get_all_equipped()` instead of iterating Equipment nodes:

```gdscript
func get_effective_stat(stat: Enums.Stat) -> float:
    var base := _get_base_stat(stat)
    var bonus := 0.0
    for data in _inventory.get_all_equipped():
        if data.stat_modifiers.has(stat):
            bonus += data.stat_modifiers[stat]
    return base + bonus
```

---

## Data Flow

### Equipping an item from the bag

```
caller → _inventory.equip(Slot.TORSO, armor_data)
  Inventory: moves old torso data to bag (if any), sets _equipped[TORSO]
  Inventory: emits slot_changed(TORSO, armor_data, old_data)
Player: _on_slot_changed → _teardown_equipment(old), _setup_equipment(new)
  _setup_equipment: instantiates node, add_child, play_equip, _on_equipped
```

### Unequipping

```
caller → _inventory.unequip(Slot.TORSO)
  Inventory: erases slot, appends data to bag
  Inventory: emits slot_changed(TORSO, null, old_data)
Player: _on_slot_changed → _teardown_equipment(old), nothing for new
  _teardown_equipment: finds Equipment child by data identity, plays unequip, queue_free
```

### Expanding ring slots

```
player._inventory.max_rings += 1
player._inventory._rings.append(null)
```

The ring array grows by one empty slot. No signal needed — UI reads `get_rings()`.

---

## Open Questions

- **Lost items when bag is full:** If the bag is full when a slot displacement occurs, the old item is silently lost. A `item_lost(data)` signal could be added later for combat-log feedback.
- **Ring visual slots:** Rings may or may not have scene representations (no animation, no equip sound). If `EquipmentData.scene` is null, `_setup_equipment` should guard and skip node instantiation cleanly.
- **Save/load:** `Inventory` holds only `Resource` values — `_equipped`, `_rings`, and `_bag` are all serializable. The save system can call `get_all_equipped()` and `get_bag()` and reconstruct state via `equip()` calls on load without needing to touch Equipment nodes directly.
- **Slot validation:** Nothing prevents equipping a `WeaponData` to `Slot.TORSO`. A `valid_slots: Array[Enums.Slot]` field on `EquipmentData` could enforce this when item generation or the UI is built, without changing `Inventory` internals.
