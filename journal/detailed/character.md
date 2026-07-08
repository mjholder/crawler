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

> **Note:** `TurnState`, `NodeType`, and `NodeState` also live in `enums.gd` — they are documented in [[detailed/game-flow.md]].

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

### ConsumableData extends EquipmentData

```gdscript
class_name ConsumableData
extends EquipmentData    # scripts/consumable_data.gd

enum Effect { HEAL_FLAT, HEAL_PERCENT, DAMAGE_ALL, STAT_BUFF }

@export var effect: Effect = Effect.HEAL_FLAT
@export var effect_value: float = 0.0            # heal amount, damage amount, or buff magnitude
@export var buff_stat: Enums.Stat = Enums.Stat.STRENGTH   # STAT_BUFF only
@export var buff_duration: int = 3               # player turns; STAT_BUFF only
@export var use_sfx: AudioStream
@export var is_consumable: bool = true           # routing flag, mirrors is_ring
```

Single-use by design — the item is destroyed when activated and the belt slot becomes empty until the player re-equips something outside combat. No charge / stack counter exists on the resource.

- `effect` — which branch of the dispatch table (`HEAL_FLAT`, `HEAL_PERCENT`, `DAMAGE_ALL`, `STAT_BUFF`) runs.
- `effect_value` — polymorphic by effect: HP for `HEAL_FLAT`, percent of max health for `HEAL_PERCENT`, damage per enemy for `DAMAGE_ALL`, flat bonus for `STAT_BUFF`.
- `buff_stat` / `buff_duration` — only consulted when `effect == STAT_BUFF`.
- `is_consumable` — mirrors `is_ring`. `InventoryPanel` uses it to route bag clicks through `equip_consumable()` instead of `equip()` / `equip_ring()`.
- `slot` is ignored. Consumables are indexed by belt position like rings.
- `stat_modifiers` is ignored. Consumables grant **only active effects**, never passive bonuses — they are excluded from `Inventory.get_all_equipped()` (see below).
- `scene` is typically unused; consumables don't instantiate an `Equipment` node under the Player. Dispatch is performed entirely from data.

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
@export var belt_size: int = 2                    # initial consumable belt capacity

var _equipped: Dictionary = {}   # Enums.Slot -> EquipmentData
var _rings: Array = []           # Array of EquipmentData or null, length = max_rings
var _consumable_belt: Array = [] # Array of ConsumableData or null, length = belt_size
var _bag: Array[EquipmentData] = []
var _dungeon_locked: bool = false   # true while inside a dungeon; see "Dungeon Lock" below

func _ready() -> void:
    _rings.resize(max_rings)
    _rings.fill(null)
    _consumable_belt.resize(belt_size)
    _consumable_belt.fill(null)
```

### Signals

```gdscript
signal slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData)
signal ring_changed(index: int, new_data: EquipmentData, old_data: EquipmentData)
signal consumable_belt_changed(index: int, new_data: ConsumableData, old_data: ConsumableData)
signal belt_size_changed(new_size: int)
signal bag_changed()
```

Either `new_data` or `old_data` can be `null` (filling from empty or becoming empty). Player uses these to manage Equipment node lifecycle.

### Dungeon Lock

While the player is inside a dungeon, **the bag is sealed**: items can enter but cannot leave. All equipment-swap operations that would pull an item from the bag — or set one aside that the player would need to retrieve — are blocked. Consumable pickups are the sole exception and go directly to the belt without touching the bag (see "Consumable Pickup Flow" below).

```gdscript
func set_dungeon_locked(locked: bool) -> void:
    _dungeon_locked = locked

func is_dungeon_locked() -> bool:
    return _dungeon_locked
```

`game.gd` flips this flag at dungeon boundaries — on when the player enters a dungeon node, off when the dungeon completes (or, later, when the player steps into a shrine/safe room). `Inventory` itself does not know the game state; it only enforces the rule.

**Paths that check the lock and no-op when locked:**

| API | Lock check | Notes |
|---|---|---|
| `equip(slot, data)` | blocked when locked | would pull from bag to a named slot |
| `unequip(slot)` | blocked when locked | returns to bag, but player couldn't re-equip |
| `equip_ring(data)` / `equip_ring_at(index, data)` | blocked when locked | bag→ring |
| `unequip_ring(index)` | blocked when locked | ring→bag |
| `equip_consumable(data)` / `equip_consumable_at(index, data)` | blocked when locked | bag→belt |
| `unequip_consumable(index)` | blocked when locked | belt→bag |
| `remove_from_bag(data)` | blocked when locked | the seal rule |
| `place_consumable_on_belt(index, data)` | **bypasses lock** | pickup path only, never reads from bag |
| `consume(index)` | **bypasses lock** | activation, not equipping |
| `add_to_bag(data)` | always allowed | items can enter the bag freely |

No signal fires on a blocked call — the operation is simply a no-op. UI code (InventoryPanel) is responsible for disabling controls up-front via `gui.set_dungeon_locked(true)` rather than relying on silent method failure.

> **Lore pointer:** see [[ideas.md]] entries **Equipment locked in dungeons ("bad air")** and **Consumable handling mid-dungeon ("only the dead remain still")** for the fiction behind this rule.

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

### Consumable Belt API

```gdscript
# Equip into the first empty belt slot from the bag. Returns false if the belt
# is full or the inventory is dungeon-locked.
func equip_consumable(data: ConsumableData) -> bool

# Equip from bag to a specific index, displacing the current occupant to the bag.
# No-op while dungeon-locked.
func equip_consumable_at(index: int, data: ConsumableData) -> void

# Move the item at index back into the bag. No-op while dungeon-locked.
func unequip_consumable(index: int) -> void

# Pickup-path placement. Writes to _consumable_belt[index] directly; the displaced
# occupant (if any) is RETURNED to the caller so game.gd can ask the player whether
# to bag or drop it. Bypasses the dungeon lock — the pickup never touches the bag.
# Emits consumable_belt_changed(index, new_data, displaced).
func place_consumable_on_belt(index: int, data: ConsumableData) -> ConsumableData

# Clear the slot and return the removed data. Used by the dispatcher after an
# effect is applied. Emits consumable_belt_changed(index, null, old). Bypasses the
# dungeon lock — consumable activation is always allowed.
func consume(index: int) -> ConsumableData

func get_consumable_at(index: int) -> ConsumableData
func get_consumable_belt() -> Array  # returns duplicate; may contain nulls

# Resize the belt. When shrinking, overflow items spill into the bag (in reverse
# index order); if the bag is full, they are dropped. Emits belt_size_changed.
func set_belt_size(n: int) -> void
```

The belt mirrors the ring pattern: index-based, may contain `null` entries, separate from the bag. `equip_consumable_at` is what `InventoryPanel` calls when the player drags a consumable from the bag onto a specific belt slot; the auto-fill `equip_consumable(data)` is used for starting loadouts and InventoryPanel bag→belt clicks. `place_consumable_on_belt(index, data)` is a dedicated pickup-path method used by `game.gd._on_consumable_pickup()` — it does not read the bag and is not blocked by the dungeon lock, so fresh pickups can be slotted while dungeon-locked even though bag→belt moves cannot. `consume(index)` is called by `game.gd` immediately after the effect is applied — it is the only path that should clear a belt slot during combat, and is also lock-bypassing so consumable use works inside a dungeon.

### Bag API

```gdscript
func add_to_bag(data: EquipmentData) -> bool   # returns false if full
func remove_from_bag(data: EquipmentData) -> void   # no-op when dungeon-locked
func is_bag_full() -> bool
func get_bag() -> Array[EquipmentData]          # returns duplicate
```

`add_to_bag` is always allowed — items may enter the bag during a dungeon run (bag-routed pickups, displaced consumables from swaps, etc.). `remove_from_bag` is blocked while dungeon-locked: once an item is in the bag during a dungeon, it stays there until the dungeon completes.

### Utility

```gdscript
# Returns all equipped EquipmentData across named slots and rings.
# Used by Player.get_effective_stat(). Excludes consumables — they grant
# only active effects, never passive stat modifiers.
func get_all_equipped() -> Array[EquipmentData]

# Resets all slots, rings, belt, and bag. Called by player.initialize() on new game.
func clear() -> void
```

### Expanding Ring Slots

```gdscript
player._inventory.max_rings += 1
player._inventory._rings.append(null)
```

No signal needed — UI reads `get_rings()`.

### Expanding Belt Slots

```gdscript
player._inventory.set_belt_size(player._inventory.belt_size + 1)
```

`set_belt_size()` emits `belt_size_changed(new_size)`; `ConsumableBelt` rebuilds its button row in response. Shrinking spills overflow items into the bag (or drops them if the bag is full).

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
        _tick_buffs()
        turn_ended.emit()

func _is_turn_complete() -> bool:
    return not _attack_animation_pending and (_state == State.IDLE or _state == State.DEAD)

func _on_weapon_animation_finished() -> void:
    _attack_animation_pending = false
```

`_attack_animation_pending` is set in `_do_attack()` when a weapon is equipped, cleared when `Weapon.animation_finished` fires. `game.gd` is unchanged — it connects to `turn_ended` and doesn't care when it fires.

### Buff Tracking

```gdscript
var _active_buffs: Array = []   # [{stat: Enums.Stat, amount: float, turns_remaining: int}]

func apply_buff(stat: Enums.Stat, amount: float, duration: int) -> void:
    _active_buffs.append({"stat": stat, "amount": amount, "turns_remaining": duration})
    buff_applied.emit(stat, amount, duration)
    stats_changed.emit(build_stats_dict())

func _tick_buffs() -> void:
    var expired_stats: Array = []
    for buff in _active_buffs:
        buff.turns_remaining -= 1
    var kept: Array = []
    for buff in _active_buffs:
        if buff.turns_remaining <= 0:
            expired_stats.append(buff.stat)
        else:
            kept.append(buff)
    _active_buffs = kept
    if not expired_stats.is_empty():
        for stat in expired_stats:
            buff_expired.emit(stat)
        stats_changed.emit(build_stats_dict())
```

`_tick_buffs()` is called once per player turn, **immediately before `turn_ended.emit()` in `_process()`**, so a `duration` of `N` means "active for N player turns starting with the turn on which it was applied." Enemy turns do not tick buffs.

Buffs are additive and independent — applying `+5 STR` twice stacks to `+10` until each entry expires. There are no diminishing returns, no caps, and no stat-grouped merging for MVP.

> **Note (2026-05-02):** The v1 buff system above is superseded by the Effect System v2 design. The `_active_buffs` schema, `apply_buff`, `_tick_buffs`, and `buff_applied`/`buff_expired` signals will migrate to a shared `Combatant` base alongside a new `StatusData`-driven status system covering named statuses (Poison, Bleed, Stun, Regen), `prevents_action`, per-turn tick Effects, and stack policy. Enemy will gain full parity. The v1 code remains in place until implementation phases 2–3 land. See [[design.md]] — "Effect System v2" (2026-05-02).

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
| `consumable_used(data: ConsumableData)` | `game.gd._on_consumable_use_requested()` after effect + `Inventory.consume()` | `game.gd` → `gui.log_message()` / optional SFX |
| `buff_applied(stat, amount, duration)` | `apply_buff()` | `game.gd` → `gui.log_message()` (optional HUD indicator later) |
| `buff_expired(stat)` | `_tick_buffs()` when a buff reaches zero duration | `game.gd` → `gui.log_message()` |

---

## Effective Stat Calculation

```gdscript
func get_effective_stat(stat: Enums.Stat) -> float:
    var base := _get_base_stat(stat)
    var bonus := 0.0
    for data in _inventory.get_all_equipped():
        if data.stat_modifiers.has(stat):
            bonus += data.stat_modifiers[stat]
    for buff in _active_buffs:
        if buff.stat == stat:
            bonus += buff.amount
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

Reads from `EquipmentData.stat_modifiers` directly — not from Equipment nodes. Stat math works even when an item has no scene (e.g. rings without visuals). Active buffs (from `STAT_BUFF` consumables) are layered on top of the equipment bonuses.

`_calculate_damage()` and `_apply_defense()` call `get_effective_stat()` rather than reading raw floats directly — so buffs automatically flow into attack/defense math without extra wiring.

**Defense — armor buffer (not percentage).** `DEF` no longer scales damage by a percentage.
Each combatant carries an `armor` buffer whose maximum (`max_armor`) is the effective DEF;
`_apply_defense()` subtracts incoming damage from the buffer and only the overflow reaches
HP. The buffer refreshes to full at the **start of each round** — `player.begin_turn()` for
the player, `CombatEvent._on_round_started()` (off `game.player_turn_started`) for enemies,
which take damage during the player's turn. A hit larger than the remaining buffer pierces
straight to HP, so DEF can't reach immunity. A fully-absorbed hit deals 0 (no 1-damage
floor) and emits `armor_absorbed` for a combat-log line rather than a hurt flash.

**Agility — decaying dodge.** `_roll_dodge()` reads dodge chance as `AGI/100`, halved once
per successful dodge already made this round (`_dodge_streak`, reset in `begin_turn()`).
Only a *successful* dodge decays the chance. See [[design.md]] "DEF is a refreshing per-round
armor buffer; AGI dodge decays within a round" (2026-07-07). `armor`, `max_armor`, and
`_dodge_streak` are transient combat state and are not saved.

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

# Starting Consumables
@export var starting_consumable_slots: int = 2
@export var starting_consumables: Array[ConsumableData] = []
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
| starting_consumable_slots | 2 |
| starting_consumables | `[minor_healing_potion.tres, throwing_bomb.tres]` |

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
    _inventory.set_belt_size(class_data.starting_consumable_slots)
    for consumable in class_data.starting_consumables:
        _inventory.equip_consumable(consumable)
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

## BackgroundData Resource

`scripts/background_data.gd` — the *who you were* character-creation layer (alongside class and patron
saint). Theme: civilians forced to adventure. Fields:

| Field | Type | Role |
|---|---|---|
| `display_name` / `description` / `icon` | String / String / Texture2D | presentation |
| `stat_modifiers` | Dictionary (Enums.Stat int → float) | flat run-long stat shift, **signed** (negative = gothic drawback) |
| `starting_gold` | int | gold the character begins the run with |
| `gold_reward_multiplier` | float | scales event gold rewards; read in `game.gd._apply_rewards` |
| `shop_buy_multiplier` | float | stacks onto `ShopData.buy_price_multiplier` (<1 = cheaper) |
| `shop_sell_multiplier` | float | stacks onto `ShopData.sell_price_multiplier` (>1 = better) |
| `passive` | BlessingData | optional unique passive; granted via `add_blessing` at run start |

The stat shift is summed in `Player.get_effective_stat` (its own modifier layer); the optional `passive`
reuses the full `BlessingData` machinery (its own `stat_modifiers` + lifecycle `subscriptions`). The
economy floats are plain values read at specific call sites, not signal-bus effects. Stored in
`resources/backgrounds/` (passive blessings in `resources/backgrounds/passives/`).

## PatronSaintData Resource

`scripts/patron_saint_data.gd` — the *what watches over you* layer. A divine contract that evolves
across the run's three acts.

| Field | Type | Role |
|---|---|---|
| `display_name` / `description` / `icon` | | presentation |
| `lineage_id` | StringName | shared id tying the saint's tiers together |
| `tiers` | Array[BlessingData] | the three act tiers (index 0 = Act 1 … 2 = Act 3) |

A saint is a thin wrapper: each tier is an ordinary `BlessingData` carrying the same `lineage_id` (a new
field on `BlessingData`). Tier 0 is granted at character creation via `Player._setup_patron`. Tiers 2
and 3 are applied by `Player.ascend_patron()` — it `remove_blessing`s the current tier and
`add_blessing`s the next, reusing the verified tier-swap path — driven by the **Phase 2 shrine
ascension event** (not yet built). `_patron` and `_patron_tier_index` persist across save/load so the
next tier is known. Triggers should be conditional/dramatic (reuse `subscriptions`), and the tithe
scales with tier (larger negative `stat_modifiers`). Stored in `resources/patron_saints/` (tiers in
`resources/patron_saints/tiers/`, kept out of the general blessing pool so unique saint shapes never
leak into random rewards).

## Player Integration

`Player.initialize(p_name, class_data, background := null, patron := null)` — the two new params default
to `null` (back-compatible). After the existing class setup it calls `_setup_background(background)`
(sets the three economy multipliers, adds `starting_gold`, grants the `passive`) and
`_setup_patron(patron)` (adds `tiers[0]`, sets `_patron_tier_index = 0`). The health/mana recalc was
moved to *after* these calls so a background/saint CON shift counts toward starting max HP.
`reset_run_state` clears the layers and resets the multipliers to `1.0`. `to_save_dict` /
`apply_save_dict` persist `background_path`, `patron_path`, `patron_tier_index`, and the three
multipliers (the active tier blessing + background passive round-trip via the existing `blessings`
array).

## Character Creation Flow

### Sequence (4-step wizard)

```
MainMenu
  └── [Start Button pressed]
       └── CharacterCreationPanel shown (hand-built wizard, resizes with viewport)
            ├── Step 1: Name (LineEdit) + Class picker (PlayerClassData)
            ├── Step 2: Background picker (BackgroundData)
            ├── Step 3: Patron Saint picker (PatronSaintData)
            ├── Step 4: Confirm (summary) — Next button reads "Begin"
            │     (Back/Next gate: each step requires its selection before advancing)
            └── [Begin pressed]
                 └── character_confirmed(name, class, background, patron)
                      └── GUI.character_created → game._on_character_created
                           ├── player.initialize(name, class, background, patron)
                           └── start_game() → show world map
```

The panel auto-loads pickable resources from `res://resources/classes/`, `…/backgrounds/`, and
`…/patron_saints/` when its exported arrays are empty. Each step shows an info panel (class stats,
background effects, saint tier preview) in a `ScrollContainer` so tall content never overflows.

### Signal chain (all extended with optional `background`/`patron`)

```gdscript
# character_creation_panel.gd
signal character_confirmed(player_name, class_data, background, patron)
# gui.gd
signal character_created(player_name, class_data, background, patron)
func _on_character_confirmed(p_name, class_data, background := null, patron := null):
    character_created.emit(p_name, class_data, background, patron)
# game.gd
func _on_character_created(p_name, class_data, background := null, patron := null):
    player.initialize(p_name, class_data, background, patron)
    ...
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

## Consumable Use Dispatch

Consumable activation **never flows through the action registry**. Doing so would set `_turn_pending = true` and eventually emit `turn_ended`, which is the explicit contract of every registered action. Consumables must not end the player's turn.

### Flow

```
ConsumableBelt button pressed (index)
  → gui.consumable_use_requested(index)     # gui.gd re-emits from ConsumableBelt
  → game.gd._on_consumable_use_requested(index)
      1. Validate state ∉ {ENEMY_TURN, GAME_OVER, VICTORY}
      2. data := player._inventory.get_consumable_at(index)
      3. if data == null: return
      4. _apply_consumable_effect(data)
      5. player._inventory.consume(index)    # clears slot, emits consumable_belt_changed
      6. player.consumable_used.emit(data)   # for combat log, SFX
```

### Effect dispatch

```gdscript
func _apply_consumable_effect(data: ConsumableData) -> void:
    match data.effect:
        ConsumableData.Effect.HEAL_FLAT:
            player.heal(data.effect_value)
        ConsumableData.Effect.HEAL_PERCENT:
            player.heal(player.max_health * data.effect_value * 0.01)
        ConsumableData.Effect.DAMAGE_ALL:
            if current_event is CombatEvent:
                (current_event as CombatEvent).apply_consumable_damage(data.effect_value)
            # no-op outside combat
        ConsumableData.Effect.STAT_BUFF:
            player.apply_buff(data.buff_stat, data.effect_value, data.buff_duration)
```

`CombatEvent.apply_consumable_damage(amount)` iterates living enemies and calls `enemy.take_damage(amount)` on each — the same path `player.attack` reaches through. `DAMAGE_ALL` effects outside combat silently do nothing; there is no error state (they just don't apply).

### Invariant — do not break

**This path must not touch `_turn_pending` and must not emit `turn_ended`.** `execute_action()` remains the single source of turn-ending. Any future consumable effect that *should* end the turn belongs in the action registry as a distinct `register_action("…")` entry, not in this dispatch table.

---

## Consumable Pickup Flow

The pickup flow is the one path that can move consumables onto the belt while the inventory is dungeon-locked. It is driven by `game.gd` in response to a loot interaction (the Loot UI itself is not yet designed — see [[detailed/gui-design.md]]). The rule set is symmetric for bag-locked and unlocked states; the dungeon lock only changes which choices the UI offers.

### Player choices at pickup (consumable)

1. **Equip to empty slot** — only available if at least one belt slot is empty. Writes directly to the empty slot, no bag involvement.
2. **Swap with an equipped consumable** — available when the belt is occupied. Player picks which slot; the displaced occupant then needs a destination:
   - **Send displaced to bag** — standard case; `add_to_bag(displaced)` is always allowed.
   - **Drop displaced** — the displaced item is discarded (lost).
3. **Put in bag** — consumable goes into the bag. During a dungeon this is a one-way commitment: the item cannot be pulled back to the belt until the dungeon ends.
4. **Drop** — the new item is discarded.

Equipment (non-consumable `EquipmentData`) has a reduced choice set during a dungeon: only **Put in bag** or **Drop**. Outside a dungeon, equipment pickups can use the normal InventoryPanel flow to equip immediately.

### Flow

```
Loot interaction selects item (data)
  → gui shows pickup choice (three-choice prompt for consumables, two for equipment)
  → game.gd._on_consumable_pickup(data, choice, target_index, displaced_action)
      match choice:
          EQUIP_EMPTY:
              place_consumable_on_belt(target_index, data)
              # displaced return value is null; belt was empty
          SWAP:
              displaced := place_consumable_on_belt(target_index, data)
              match displaced_action:
                  TO_BAG:  _inventory.add_to_bag(displaced)
                  DROP:    pass   # discard
          BAG:
              _inventory.add_to_bag(data)
          DROP:
              pass   # discard
```

`place_consumable_on_belt` is the only method that writes to `_consumable_belt` without checking the dungeon lock; it is therefore the pickup-only primitive. The high-level pickup handler lives in `game.gd` because it spans multiple systems (Inventory + loot UI + possibly CombatEvent for drop-on-floor visuals later).

### Invariant — do not break

**Pickups never read from the bag.** The pickup flow is strictly item-in-hand → destination. If a flow ever needs to move a bag item to the belt, that is a bag→belt operation and is subject to the dungeon lock like any other equip call. Keeping the pickup path bag-isolated is what makes the "bag is sealed during a dungeon" rule enforceable.

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
- **Consumable belt growth:** MVP ships with a fixed `starting_consumable_slots` per class and the `set_belt_size()` helper. No equipment-driven or level-driven growth mechanic exists yet — see [[ideas.md]].
- **Combat-only consumables:** No flag distinguishes combat-only from universal items. `DAMAGE_ALL` no-ops outside combat; other effects work anywhere allowed by the state gate. A future `combat_only: bool` on `ConsumableData` could disable buttons when out of scope rather than silently failing.
- **Buff stacking:** Additive with independent decrements; no caps, no diminishing returns, no per-stat merging. Two `+5 STR, 3 turns` buffs stack to `+10 STR` and both tick down separately.
- **`use_sfx` playback channel:** Unresolved whether to reuse `SFX/AttackPlayer`, add a dedicated `SFX/ConsumePlayer` on the Player, or let the dispatcher play it on a one-shot node. Flag at implementation time.
- **Dungeon lock boundaries:** `game.gd` drives `Inventory.set_dungeon_locked()`. The exact world-map → dungeon transition hook is not yet defined — current turn-state machine has no `IN_DUNGEON` phase. May derive from `current_event` type (e.g. `CombatEvent` / `LootEvent` / `RoleplaysEvent` imply dungeon) vs `ShopEvent` / `RestEvent` (imply safe node). Revisit when dungeon-run structure ([[ideas.md]] § Roguelike Run Structure) is formalized.
- **Shrine / safe room unlock:** Planned longer-dungeon feature that temporarily unlocks the inventory mid-dungeon. Not yet in scope. When built, it toggles `set_dungeon_locked(false)` on entry and `true` on exit.
- **Full-belt-plus-full-bag pickup:** If the belt is full AND the bag is full, the player's only remaining choices are Swap+Drop (displaced item lost) or Drop (new item lost). Acceptable but harsh; may want to surface this clearly in the pickup UI.
- **Pre-dungeon preparation UX:** Leaving belt slots empty before descending is a valid strategy (room for pickups). The UI may want to signal this as a deliberate choice rather than an oversight, e.g. a subtle "Empty — ready for pickup" label rather than a warning indicator.
