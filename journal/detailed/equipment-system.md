# Equipment System — Design

**Date:** 2026-03-21
**Status:** Designed, not yet implemented

This document covers the architecture of the equipment system: the shared `Enums` class, the `EquipmentData` resource hierarchy, the `Equipment` base node and its `Weapon` subclass, and how the Player integrates equipped items into stat calculations and visual feedback.

---

## Overview

Equipment is a **visual component with data attached**. Each piece of equipment owns its own sprites, animation, and audio. Its serializable data — stat modifiers, asset references, display info — is held in a `Resource` that can be swapped to produce a different item without touching the scene.

The Player owns combat logic entirely. Equipment does not attack, defend, or take actions. It reacts to signals from the Player and contributes modifier values that the Player reads during calculations.

---

## Shared Enumerations — `scripts/enums.gd`

A dedicated file with `class_name Enums` holds all game-wide enumerations. Neither `Player` nor `Equipment` owns these — both reference them from `Enums`.

```gdscript
class_name Enums

enum Stat {
    STRENGTH,
    DEFENSE,
    CONSTITUTION,
    AGILITY,
    SPIRIT,
    LUCK
}

enum Slot {
    WEAPON,
    ARMOR
}
```

**Why a shared file:** Both `Player` and `Equipment` need `Stat` and `Slot`. Placing them on either class creates an awkward ownership dependency. A neutral `Enums` class avoids that. Turn state and any other future game-wide enums can be added here as the project grows — e.g. `game.gd`'s local `State` enum could migrate here when it needs to be referenced from outside.

---

## Resource Hierarchy

Equipment data is serialized as a `Resource` so items can be defined in the editor and loaded at runtime without instantiating a full scene per item.

### `EquipmentData` (base resource)

```gdscript
class_name EquipmentData
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var sprite_frames: SpriteFrames
@export var equip_sfx: AudioStream
@export var unequip_sfx: AudioStream
@export var stat_modifiers: Dictionary  # Enums.Stat → float
```

`stat_modifiers` uses `Enums.Stat` keys. An armor piece that grants +15 defense and +5 constitution would be:

```gdscript
{ Enums.Stat.DEFENSE: 15.0, Enums.Stat.CONSTITUTION: 5.0 }
```

Omitted stats contribute zero — no entry needed for unmodified stats.

### `WeaponData extends EquipmentData`

```gdscript
class_name WeaponData
extends EquipmentData

@export var attack_sfx: AudioStream
```

Weapons add an attack sound on top of the base resource. Weapon-specific data (special attack properties, damage type, etc.) can be added here as those systems are designed.

---

## Node Tree

### `equipment.tscn` — base scene, script: `equipment.gd`

```
Equipment           Node2D              scripts/equipment.gd
├── Sprite          AnimatedSprite2D    SpriteFrames swapped from EquipmentData on load
├── AnimationPlayer AnimationPlayer     multi-phase animation sequences
└── SFX             Node                grouping container, no script
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

`weapon.tscn` inherits the base scene and adds `AttackPlayer` under `SFX`. No other structural differences.

---

## `equipment.gd`

Owns the node wiring, data loading, modifier access, and equip/unequip visuals.

```gdscript
class_name Equipment
extends Node2D

# --- Data ---
@export var data: EquipmentData

# --- Node References ---
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
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
    if _equip_player.stream != null:
        _equip_player.play()


func play_unequip() -> void:
    if _unequip_player.stream != null:
        _unequip_player.play()
```

Extension hooks follow the same leading-underscore convention used by `enemy.gd`. They do nothing in the base class and are safe to override in subclasses:

```gdscript
func _on_equipped() -> void:
    pass

func _on_unequipped() -> void:
    pass
```

---

## `weapon.gd`

Reacts to the Player's `attack` signal. Does not own attack logic — only plays animation and sound in response.

```gdscript
class_name Weapon
extends Equipment

@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer


func _ready() -> void:
    super._ready()
    if data is WeaponData:
        _attack_player.stream = (data as WeaponData).attack_sfx


func _on_player_attacked() -> void:
    if _attack_player.stream != null:
        _attack_player.play()
    _anim_player.play("attack")
```

The Player connects `attack` → `weapon._on_player_attacked()` when equipping. Weapon never reaches into the Player.

---

## Player Integration

### Slot dictionary

```gdscript
var _equipped: Dictionary = {}  # Enums.Slot → Equipment
```

### `equip()`

```gdscript
func equip(slot: Enums.Slot, item: Equipment) -> void:
    if _equipped.has(slot):
        var old: Equipment = _equipped[slot]
        old.play_unequip()
        old._on_unequipped()
        if slot == Enums.Slot.WEAPON:
            attack.disconnect(old._on_player_attacked)
        remove_child(old)
    _equipped[slot] = item
    add_child(item)
    item.play_equip()
    item._on_equipped()
    if slot == Enums.Slot.WEAPON:
        attack.connect(item._on_player_attacked)
```

Signal wiring is handled inside `equip()` — no external wiring needed. The Player owns the connection because it owns the signal.

### Effective stat calculation

```gdscript
func get_effective_stat(stat: Enums.Stat) -> float:
    var base: float = _get_base_stat(stat)
    var bonus: float = 0.0
    for item in _equipped.values():
        bonus += item.get_modifier(stat)
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

`_calculate_damage()` and `_apply_defense()` call `get_effective_stat()` instead of reading the raw floats directly:

```gdscript
func _calculate_damage() -> float:
    return base_damage + (get_effective_stat(Enums.Stat.STRENGTH) * 0.5)

func _apply_defense(amount: float) -> float:
    return maxf(amount - get_effective_stat(Enums.Stat.DEFENSE), 0.0)
```

Base stats on the Player remain as `@export` floats. `get_effective_stat()` adds the layer on top without changing how those values are set or inspected.

### Removing `equip_weapon()`

The existing `equip_weapon(frames: SpriteFrames)` on `player.gd` is replaced by `equip(slot, item)`. The new method handles visuals, audio, signal wiring, and old-item teardown in one place.

---

## Signal Contract

| Signal | Emitted by | Connected to | Wired by |
|---|---|---|---|
| `attack(damage: float)` | `player.gd` | `weapon._on_player_attacked()` | `player.equip()` |

No new signals are added to `Equipment` or `Weapon` at this stage. Equipment is a receiver, not a broadcaster.

---

## Animations

All animations are driven by named states on the `AnimatedSprite2D`, same pattern as the Skeleton. Every `SpriteFrames` resource assigned to an equipment item must define at minimum:

| Animation | Loop | Notes |
|---|---|---|
| `idle` | yes | Default resting state |
| `attack` | no | Weapons only — played on `_on_player_attacked()` |

The `AnimationPlayer` can own multi-phase sequences (e.g. windup → swing) via method call tracks, identical to the pattern on the Player and Skeleton. For a weapon with a simple single-phase attack, the AnimationPlayer is unused and the sprite plays `attack` directly.

---

## Open Questions

- **Armor visuals:** Armor may have no meaningful animation — does it need a `Sprite` and `AnimationPlayer` at all, or should those be optional? For now the base scene includes them; an empty `SpriteFrames` is benign.
- **Unequip destination:** `equip()` currently calls `remove_child()` on the old item. Should it be freed, or returned to an inventory node? Left open until the inventory system is designed.
- **Slot expansion:** Adding a new slot (ring, off-hand, etc.) means adding an entry to `Enums.Slot` and optionally handling its signal wiring in `equip()`. No structural changes to `Equipment` or its subclasses.

---

## Future Considerations

- **ArmorData / armor.gd:** `Armor extends Equipment` with no additions initially — purely stat modifiers. A block action or damage-reduction hook could be added to `armor.gd` when that mechanic is designed.
- **Active abilities from equipment:** If a piece of gear should register a new action on the Player (e.g. a staff unlocking "Cast"), `_on_equipped()` / `_on_unequipped()` hooks are the right place — the weapon calls `player.register_action()` on equip and deregisters on unequip. The Player is passed in via those hooks when that system is needed.
- **Multiple items of the same slot:** `equip()` already handles displacement — the old item is removed before the new one is added. Swapping is free.
- **Stat system evolution:** `_get_base_stat()` on the Player is the single point that reads raw `@export` floats. When the stat system matures, only that method changes.
