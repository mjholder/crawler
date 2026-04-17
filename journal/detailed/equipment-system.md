# Equipment System — Design

**Date:** 2026-03-21 (updated 2026-04-17)
**Status:** Implemented

This document covers the architecture of the equipment system: the shared `Enums` class, the `EquipmentData` resource hierarchy, and the `Equipment` base node and its `Weapon` subclass.

Storage (named slots, rings, bag), equip/unequip flow, and the `Inventory` node API live in `inventory-system.md` — this doc stops at the Equipment node and its `EquipmentData`.

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
    STRENGTH,     # 0
    DEFENSE,      # 1
    CONSTITUTION, # 2
    AGILITY,      # 3
    SPIRIT,       # 4
    LUCK          # 5
}

enum Slot { WEAPON, HANDS, FEET, LEGS, TORSO, HEAD }
```

Numeric keys are used when assigning `stat_modifiers` in `.tres` files — e.g. `{ 0: 10.0 }` adds +10 STRENGTH. Six named body slots cover all non-ring equipment; rings are managed separately as a fixed-size array on `Inventory` (see `inventory-system.md`).

**Why a shared file:** Both `Player` and `Equipment` need `Stat` and `Slot`. Placing them on either class creates an awkward ownership dependency. A neutral `Enums` class avoids that. Turn state (`TurnState`) and world-map enums (`NodeType`, `NodeState`) also live here.

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
@export var scene: PackedScene          # Equipment or Weapon scene to instantiate
@export var slot: Enums.Slot = Enums.Slot.WEAPON
@export var is_ring: bool = false
@export var price: int = 0
```

`stat_modifiers` uses `Enums.Stat` keys. An armor piece that grants +15 defense and +5 constitution would be:

```gdscript
{ Enums.Stat.DEFENSE: 15.0, Enums.Stat.CONSTITUTION: 5.0 }
```

Omitted stats contribute zero — no entry needed for unmodified stats.

Added fields:

- `scene` — the `PackedScene` the `Inventory → Player` pipeline instantiates when this item is equipped (see `inventory-system.md` § Equipment Node Lifecycle). Weapons point at `weapon.tscn`; non-weapon gear points at `equipment.tscn`.
- `slot` — which named slot this data targets. Ignored when `is_ring == true`.
- `is_ring` — routes equip calls through `Inventory.equip_ring` rather than a named slot.
- `price` — base value used by `ShopEvent` to compute buy/sell prices (see `event-scene-design.md § ShopEvent`). `0` means "not priced"; shops treat that as a data bug.

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
    _scale_sprite_to_viewport()

func _on_unequipped() -> void:
    pass
```

---

## `weapon.gd`

Reacts to the Player's `attack` signal. Does not own attack logic — only plays animation and sound in response.

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

`animation_finished` (the Weapon signal, not `AnimatedSprite2D`'s) is what the Player listens to for turn gating — it fires only when the attack animation ends. `anim_player` is exposed as a public field so the Player can wire to it if needed for multi-phase sequences; for the current single-phase attack, the AnimatedSprite2D is driven directly and `AnimationPlayer` is unused.

---

## Player Integration

### Storage and equip flow — delegated to Inventory

Storage (named slots, rings, bag) lives on the `Inventory` node under `Player`. The Player reacts to `Inventory`'s `slot_changed` and `ring_changed` signals to instantiate and free `Equipment` node children — see `inventory-system.md` § Equipment Node Lifecycle for the full pattern.

Weapon signal wiring lives in `player._setup_equipment()`: when a `WEAPON`-slot node is created, the Player connects `attack` → `weapon._on_player_attacked` and `weapon.animation_finished` → `_on_weapon_animation_finished`. The mirror disconnects happen in `_teardown_equipment()`.

### Effective stat calculation

`get_effective_stat()` reads `EquipmentData.stat_modifiers` directly via the inventory — it does not iterate Equipment nodes:

```gdscript
func get_effective_stat(stat: Enums.Stat) -> float:
    var base := _get_base_stat(stat)
    var bonus := 0.0
    for data in _inventory.get_all_equipped():
        if data.stat_modifiers.has(stat):
            bonus += data.stat_modifiers[stat]
    return base + bonus
```

`_get_base_stat()` is the single point that reads the Player's raw `@export` floats:

```gdscript
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

`_calculate_damage()` and `_apply_defense()` call `get_effective_stat()` rather than reading the raw floats directly. Reading from `EquipmentData` instead of `Equipment` nodes means stat math works even when an item has no scene (e.g. rings without visuals).

---

## Signal Contract

| Signal | Emitted by | Connected to | Wired by |
|---|---|---|---|
| `attack(damage: float)` | `player.gd` | `weapon._on_player_attacked()` | `player._setup_equipment()` / `_teardown_equipment()` |
| `animation_finished` | `weapon.gd` | `player._on_weapon_animation_finished()` | `player._setup_equipment()` / `_teardown_equipment()` |

`Weapon.animation_finished` was added during implementation to give `player.gd` a stable, parameter-free hook for turn gating. It fires internally when the attack `AnimatedSprite2D` animation ends, decoupling the Player from the sprite wiring details.

---

## Animations

All animations are driven by named states on the `AnimatedSprite2D`, same pattern as the Skeleton. Every `SpriteFrames` resource assigned to an equipment item must define at minimum:

| Animation | Loop | Notes |
|---|---|---|
| `idle` | yes | Default resting state |
| `attack` | no | Weapons only — played on `_on_player_attacked()` |

For the basic single-phase attack, the `AnimatedSprite2D` is driven directly (`_sprite.play("attack")`). The `AnimationPlayer` is present in the scene for future multi-phase sequences (e.g. windup → swing via method call tracks) but is not in the current attack path. When `animation_finished` fires on the sprite, `Weapon` re-emits its own `animation_finished` signal and returns to idle.

---

## Open Questions

- **Armor visuals:** Armor may have no meaningful animation — does it need a `Sprite` and `AnimationPlayer` at all, or should those be optional? For now the base scene includes them; an empty `SpriteFrames` is benign.
- **Ring scenes:** Rings may not need a scene at all (no animation, no equip sound). If `EquipmentData.scene` is null, `player._setup_equipment()` should guard and skip node instantiation — the stat layer still works because it reads from `EquipmentData.stat_modifiers`.

---

## Future Considerations

- **ArmorData / armor.gd:** `Armor extends Equipment` with no additions initially — purely stat modifiers. A block action or damage-reduction hook could be added to `armor.gd` when that mechanic is designed.
- **Active abilities from equipment:** If a piece of gear should register a new action on the Player (e.g. a staff unlocking "Cast"), `_on_equipped()` / `_on_unequipped()` hooks are the right place — the weapon calls `player.register_action()` on equip and deregisters on unequip. The Player is passed in via those hooks when that system is needed.
- **Multiple items of the same slot:** `Inventory.equip()` handles displacement — the old item is sent to the bag before the new one is installed. Swapping is free.
- **Stat system evolution:** `_get_base_stat()` on the Player is the single point that reads raw `@export` floats. When the stat system matures, only that method changes.
