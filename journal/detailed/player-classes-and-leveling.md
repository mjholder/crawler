# Player Classes & Leveling — Design

**Date:** 2026-04-11 (updated 2026-04-17)
**Status:** Implemented

This document covers the player class system (selection, starting configuration) and the leveling system (XP curve, stat growth, level-up UI). Together these replace the hardcoded starting stats and equipment in `game.gd` with a data-driven class resource and add character progression.

---

## Overview

A **player class** is a preset that determines the player's starting stats, starting equipment/inventory, health bonus, and per-level stat growth rates. Classes are pure data — `PlayerClassData` resources stored as `.tres` files. The player selects a class (and enters a name) on a character creation screen before starting a run.

**Leveling** is driven by XP earned from events. Each level-up auto-applies the class's growth bonuses and grants free stat points for the player to distribute. Level-ups are queued and presented between events via a dedicated stat allocation screen.

---

## PlayerClassData Resource

`scripts/player_class_data.gd`

```gdscript
class_name PlayerClassData
extends Resource

@export var class_name_text: String = ""
@export var description: String = ""

# --- Starting Stats ---
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# --- Health ---
## Flat bonus added on top of CON-derived base max health.
## max_health = (CON * health_modifier) + class_health_bonus
@export var class_health_bonus: float = 0.0

# --- Per-Level Growth ---
## Stat bonuses automatically applied each level-up. Enums.Stat -> float.
## e.g. { 0: 3.0, 2: 2.0 } means +3 STR and +2 CON per level.
@export var growth_rates: Dictionary = {}

# --- Starting Equipment ---
## Equipment to auto-equip on game start. Enums.Slot -> EquipmentData.
@export var starting_equipped: Dictionary = {}

## Rings to auto-equip on game start.
@export var starting_rings: Array[EquipmentData] = []

## Items placed in the bag on game start.
@export var starting_bag: Array[EquipmentData] = []
```

### File Location

Class resources live under `resources/classes/`:

```
resources/classes/
├── warrior.tres
├── rogue.tres
├── mage.tres
└── ...
```

### Example: Warrior

A warrior might look like:

| Field | Value |
|---|---|
| class_name_text | "Warrior" |
| description | "A sturdy frontline fighter. High STR and CON growth. Starts with a battle axe and leather armor." |
| strength | 60.0 |
| defense | 50.0 |
| constitution | 55.0 |
| agility | 40.0 |
| spirit | 30.0 |
| luck | 45.0 |
| class_health_bonus | 20.0 |
| growth_rates | { STR: 3.0, CON: 2.0 } |
| starting_equipped | { WEAPON: battle_axe.tres, HEAD: leather_helm, TORSO: leather_chest, LEGS: leather_pants, FEET: leather_boots, HANDS: leather_gloves } |
| starting_rings | [iron_ring] |
| starting_bag | [] |

---

## Max Health Formula

Max health is derived, not stored as a base stat:

```
base_max_health = effective_CON * health_modifier
max_health = base_max_health + class_health_bonus
```

- `health_modifier` is an exported tuning var on Player (e.g. `2.0`).
- `class_health_bonus` is the flat bonus from `PlayerClassData`.
- `effective_CON` includes equipment bonuses via `get_effective_stat()`.

Max health is recalculated whenever stats change (level-up, equipment change). When max health increases, current health increases by the same delta so the player doesn't lose effective HP.

### Player Changes for Max Health

`max_health` is no longer an `@export`. It becomes a computed property:

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

## base_damage Removal

`base_damage` is removed from Player. Unarmed damage will be handled by an "unarmed" weapon resource that is always equipped when no other weapon is present. This keeps all damage logic in the weapon system.

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

Exponential with slow growth. Both tuning vars are exported on Player:

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
| 3→4 | 132 | 347 |
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
        var bonus: float = _class_data.growth_rates[stat_key]
        _add_to_base_stat(stat_key as Enums.Stat, bonus)
    _recalculate_max_health()
```

Multiple level-ups in a single XP grant are handled by the `while` loop — `pending_stat_points` accumulates.

### Free Point Distribution

```gdscript
## Called by the level-up UI when the player assigns a point.
func spend_stat_point(stat: Enums.Stat) -> void:
    if pending_stat_points <= 0:
        return
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

## Player Initialization

Player gains a setup method that replaces the current `@export` stat defaults and `_setup_starting_equipment()`:

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

This moves `_setup_starting_equipment()` from `game.gd` onto `Player`, where it belongs — Player owns its own state initialization.

---

## Character Creation Flow

### Sequence

```
MainMenu
  └── [Start Button pressed]
       └── Character Creation Screen shown
            ├── Name input (LineEdit)
            ├── Class picker (list of PlayerClassData)
            │   └── Shows: class name, description, starting stats, growth rates
            └── [Continue pressed]
                 └── game.gd receives (name, class_data)
                      ├── player.initialize(name, class_data)
                      └── start_game() → show world map
```

### GUI Changes

`gui.gd` gains:

```gdscript
signal character_created(player_name: String, class_data: PlayerClassData)

@onready var _character_creation: Control = $CharacterCreation
```

- `_on_start_button_pressed()` now shows the character creation screen instead of emitting `start_requested`.
- The character creation screen emits `character_created` when the player confirms.
- `start_requested` signal is removed — `character_created` replaces it as the trigger for game start.

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

At the end of `_on_event_complete()` in `game.gd`, after rewards are applied:

```gdscript
func _on_event_complete() -> void:
    # ... existing cleanup ...
    _apply_rewards(current_event.rewards)
    if player.pending_stat_points > 0:
        _show_level_up_screen()
        return  # Don't proceed to _finish_event yet
    _finish_event()

func _show_level_up_screen() -> void:
    _gui.show_level_up(player.level, player.pending_stat_points, player.build_stats_dict())

func _on_level_up_complete() -> void:
    _finish_event()
```

### Level-Up Panel

A dedicated `LevelUpPanel` (Control node under GUI):

- Displays current level
- Shows all 6 stats with current values
- **+** button next to each stat (disabled when `pending_stat_points == 0`)
- **−** button to undo an allocation before confirming
- Counter: "Points remaining: N"
- **Confirm** button (disabled while points remain)

When the player clicks **+** on a stat, it calls `player.spend_stat_point(stat)` and decrements the displayed counter. When all points are spent and confirmed, emits `level_up_complete`.

#### Undo Behavior

To support the − button, the panel tracks allocations made during this session as a local dictionary. On −, it reverses the point: calls `_add_to_base_stat(stat, -1.0)` on Player, increments `pending_stat_points`, and updates the display. On confirm, allocations are finalized. This keeps Player as the source of truth for stats while allowing the UI to offer undo.

### Signal Chain

```
Player.leveled_up(level) → game.gd stores info
Event completes → game.gd checks pending_stat_points
  → gui.show_level_up(...)
    → LevelUpPanel shown
      → player.spend_stat_point() on each +
      → Confirm pressed → level_up_complete signal
        → game.gd._on_level_up_complete() → _finish_event()
```

---

## Open Questions

- **Class-specific actions:** Should classes unlock unique actions (e.g. a rogue's "backstab")? Not in scope for this design — can be layered on later via action registration in `initialize()`.
- **Respec:** Can the player undo stat allocations from previous levels? Not planned for now.
- **Level cap:** Is there a max level? Not defined yet — can be added as an export var when content scope is clearer.
- **XP display:** The HUD currently shows raw XP. It should show XP progress toward next level (e.g. "XP: 45/115") once leveling is implemented.
- **Unarmed weapon:** Needs its own `.tres` resource and logic to auto-equip when no weapon is present. Separate from this design — just noting the dependency since `base_damage` is being removed.
