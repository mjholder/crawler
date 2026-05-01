# Event System Design

**Date:** 2026-03-05 (consolidated 2026-04-18)
**Status:** Implemented — except `## BossEvent` (see banner in that section)

Merged from: `event-scene-design.md`, `dialogue-system.md`, `skill-check-system.md`

---

## Overview

All game events extend the base `Event` class and follow a four-phase state machine. This document is the source of truth for every event type — node trees, phase flows, signal contracts, JSON formats, and `game.gd` wiring. Panel node trees and `gui.gd` API live in [[detailed/gui-design.md]].

**Adding a new event type?** See the checklist at the bottom of this document.

---

## Base Event Class

```
Event               Node2D          scripts/event.gd
```

Phase state machine: `SETUP → RUNNING → RESOLUTION → COMPLETE`

```gdscript
func initialize(data: Dictionary) -> void:
    pass  # virtual — subclasses store keys from data dict

func start() -> void:
    # calls _on_setup() then _on_running()

func _on_setup() -> void:
    pass  # virtual

func _on_running() -> void:
    pass  # virtual

func _on_resolution() -> void:
    pass  # virtual
```

`_advance_phase()` walks through the phases in order. `_set_phase(phase)` jumps directly — used by `SkillCheckEvent` to pause at RESOLUTION.

`event_complete` is emitted at the end of COMPLETE. **`game.gd` connects to it one-shot in `start_event()`.**

`rewards: Dictionary` — populated by subclass `initialize()`; read by `game.gd` in `_on_event_complete()` via `_apply_rewards()`.

---

## CombatEvent

### Node Tree

```
CombatEvent         Node2D          scripts/combat_event.gd
└── Enemies         Node            container; enemy scenes instantiated here at runtime
```

`Enemies` is a bare grouping `Node`. Enemy scenes are added as children via `add_enemy()`. `_enemies: Array[Enemy]` holds them for logical iteration.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `player_attacked(damage: float)` | An enemy attacked — re-emitted from `enemy.attack` |
| `player_attack_resolved(enemy: Enemy, damage: float)` | Player's attack landed on a specific enemy |
| `enemy_turns_complete` | All living enemies have finished their turns |
| `event_complete` | Inherited; all enemies dead, combat over |

### Methods game.gd calls on CombatEvent

| Method | When called |
|---|---|
| `add_enemy(enemy: Enemy)` | Before `start()` to register participants |
| `receive_player_attack(enemy: Enemy, damage: float)` | When player attacks; applies damage to the specified enemy |
| `run_enemy_turns()` | Called by game.gd when player turn ends |

### Enemy Connection Pattern

`add_enemy(enemy: Enemy)` does three things:
1. Appends to `_enemies`
2. `$Enemies.add_child(enemy)` — places in scene tree
3. Connects `enemy.died` → `_on_enemy_died()`

`enemy.attack` is connected in `_on_setup()` so the signal is live when the event starts.

`receive_player_attack(enemy, damage)` calls `enemy.take_damage(damage)` and emits `player_attack_resolved(enemy, damage)`. Target selection is `game.gd`'s concern.

### Death Tracking

`_on_enemy_died()` — if all `_enemies` have `is_dead == true`, calls `_advance_phase()` → RESOLUTION → COMPLETE → `event_complete`.

### Turn Loop

`game.gd` calls `(current_event as CombatEvent).run_enemy_turns()`.

Inside `run_enemy_turns()`:
1. Build list of living enemies (skip `is_dead`)
2. Connect to first enemy's `turn_ended` (one-shot)
3. Call `enemy.take_turn()`
4. On `turn_ended`: advance to next living enemy; when none remain, emit `enemy_turns_complete`

`game.gd` connects `enemy_turns_complete` → `_on_enemy_turns_complete()` → `_start_player_turn()`. Sequencing logic stays inside CombatEvent — `game.gd` only knows "enemy turns started / done".

### Changes Required in game.gd

```gdscript
# In start_event(), when event is CombatEvent:
ce.enemy_turns_complete.connect(_on_enemy_turns_complete)

# Disconnect both player_attacked and enemy_turns_complete in _on_event_complete.

func _run_enemy_turns() -> void:
    (current_event as CombatEvent).run_enemy_turns()

func _on_enemy_turns_complete() -> void:
    _start_player_turn()

# Player attack routing:
(current_event as CombatEvent).receive_player_attack(target_enemy, damage)
```

### Waves — Future Flexibility

Waves are out of scope. When added, CombatEvent refills `_enemies` internally and loops the turn sequence again without changes to `game.gd`. The `_on_enemy_died()` all-dead check becomes wave-aware (don't advance phase if more waves remain) — logic stays entirely inside CombatEvent.

---

## BossEvent

**Date:** 2026-04-17

> **Status: Planned — not yet implemented.** See [[daily/2026-04-17]] for the implementation punch list (`scripts/boss_event.gd`, `scenes/boss_event.tscn`, `resources/events/boss/debug_boss.json`, game.gd wiring).

### Node Tree

```
BossEvent           Node2D (inherits combat_event.tscn)     scripts/boss_event.gd
└── Enemies         Node (inherited)
```

No new children. All enemy spawning, turn loops, and per-enemy connections are reused from `CombatEvent` unchanged.

### Signal Contract

Adds one signal on top of CombatEvent's:

| Signal | Emitted when |
|---|---|
| `boss_defeated` | All enemies dead — BossEvent's `_advance_phase()` override intercepts RUNNING → RESOLUTION, emits this, and stops. **`event_complete` is intentionally not emitted on victory.** |

All inherited CombatEvent signals wire automatically through the `event is CombatEvent` branch. No per-signal wiring changes needed for inherited signals.

### Phase Flow

`_advance_phase()` override:

```gdscript
signal boss_defeated

func _advance_phase() -> void:
    match phase:
        Phase.RUNNING:
            boss_defeated.emit()
        _:
            super._advance_phase()
```

The event stays in RUNNING. `game.gd` reads `rewards` off the event, tears it down, and drives the victory UI.

### How game.gd wires it (in `start_event()`)

`BossEvent is CombatEvent` evaluates true via inheritance, so the existing CombatEvent branch runs unchanged. Add one connection after:

```gdscript
if event is BossEvent:
    (event as BossEvent).boss_defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
```

No cleanup branch needed — BossEvent never reaches COMPLETE on victory. `CONNECT_ONE_SHOT` handles disconnection.

Player death during a boss fight follows the normal combat death path: `player.died` → `_on_player_died` → `_teardown_current_event()`. Inheriting from CombatEvent means no extra teardown code is needed.

### Signal Flow

```
[player kills final boss enemy]
  → receive_player_attack(enemy, damage)
  → enemy.take_damage → enemy._die → died.emit()
  → BossEvent._on_enemy_died() (inherited)
    → all dead → _advance_phase()
  → override: boss_defeated.emit()  [phase stays RUNNING]

  → game._on_boss_defeated()
    → state = VICTORY
    → _apply_rewards(current_event.rewards)     # must run BEFORE teardown
    → _teardown_current_event()
    → null out _active_world_node / _pending_event_configs / _event_index
    → if player.pending_stat_points > 0: gui.show_level_up(player); return
    → gui.show_victory()
```

If level-up is shown first, `_on_level_up_complete()` branches on `state == VICTORY` to call `gui.show_victory()`.

### Boss JSON

Mirrors combat JSON shape — `{"enemies": [...], "rewards": {...}, "dialogue_triggers": {...}}`. Lives under `resources/events/boss/`. `CombatEvent.initialize()` and `_on_setup()` consume it unchanged.

### Why intercept at the event layer, not at `_finish_event`

Routing through `event_complete` → `_on_event_complete` → `_finish_event` would call `_start_next_dungeon_event` on an empty queue → `_on_dungeon_complete` → re-show the world map. Wrong semantics for a run-ender.

---

## DialogueEvent

**Date:** 2026-03-29

### Node Tree

```
DialogueEvent       Node2D          scripts/dialogue_event.gd
```

Root node only. Dialogue rendering lives entirely in GUI (`DialoguePanel`). `DialogueEvent` is a thin wrapper that loads data and hands it off.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `dialogue_requested(data: Dictionary)` | Enters RUNNING — carries the loaded dialogue tree |
| `event_complete` | Inherited; emitted when dialogue is confirmed complete |

### Methods game.gd calls on DialogueEvent

| Method | When called |
|---|---|
| `on_dialogue_complete(terminal_node_id: String)` | Called from `_on_gui_dialogue_complete()` when the player dismisses the final dialogue node. `terminal_node_id` is the id of the node they stopped on. |

### Phase Flow

`start()` runs `_on_setup()` (load JSON from `dialogue_json_path`) then `_on_running()` (emit `dialogue_requested`). Event stays in RUNNING while the player navigates. When the panel emits `dialogue_complete(terminal_node_id)`, `game.gd` restores turn state and calls `on_dialogue_complete(terminal_node_id)`. The event then reads the terminal node's optional `rewards` dict off `_data["nodes"][terminal_node_id]` into the inherited `rewards` field, and calls `_advance_phase()` → RESOLUTION → COMPLETE → `event_complete`. `_on_resolution()` is not overridden. Event-level `rewards` no longer exists for dialogue — every rewarding path declares its own, or grants nothing.

### Dialogue Data Format

Dialogue trees live in `res://dialogue/` as JSON. Each file is one dialogue tree.

```json
{
  "name": "merchant_greeting",
  "nodes": {
    "0": {
      "speaker": "Merchant",
      "text": "What brings you here, traveler?",
      "consequence": null,
      "choices": [
        { "text": "Tell me about the dungeon.", "next": "0-0" },
        { "text": "Never mind.", "next": "0-1" }
      ]
    },
    "0-0": {
      "speaker": "Merchant",
      "text": "Dangerous place.",
      "consequence": { "action": "set_flag", "value": "heard_dungeon_warning" },
      "choices": [],
      "rewards": { "experience": 10, "gold": 2 }
    },
    "0-1": {
      "speaker": null,
      "text": "You walk away.",
      "consequence": null,
      "choices": []
    }
  }
}
```

**Node fields:**

| Field | Type | Notes |
|---|---|---|
| `speaker` | `String \| null` | Displayed in SpeakerLabel. Null hides it. |
| `text` | `String` | Main body text |
| `consequence` | `{ action: String, value: Variant } \| null` | Fired on node load, before text renders |
| `choices` | `Array[{ text, next }]` | Empty array = terminal node; shows Continue button |
| `rewards` | `{ experience: int, gold: int } \| omitted` | **Only on terminal nodes** (empty `choices`). Read by `DialogueEvent` after the player dismisses the node; fed into `game._apply_rewards()` at event completion. Omit to grant nothing. |

Node IDs follow the path of choice indices taken to reach them (developer convention for readability). Navigation is driven by the explicit `"next"` field. Root is always `"0"`.

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is DialogueEvent:
    var de := event as DialogueEvent
    de.dialogue_requested.connect(_on_dialogue_requested)
```

`_on_dialogue_requested(data)` saves current turn state to `_pre_dialogue_state`, sets state to `DIALOGUE`, calls `_gui.show_dialogue(data, _dialogue_consequences)`.

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
  → game._on_dialogue_requested(data)
    → save state, set DIALOGUE, gui.show_dialogue(data, _dialogue_consequences)
  → [player navigates dialogue tree]
  → gui.dialogue_complete(terminal_node_id) → game._on_gui_dialogue_complete(id)
    → restore state
    → de.on_dialogue_complete(id)
      → rewards = _data["nodes"][id].get("rewards", {})
      → _advance_phase() → RESOLUTION → COMPLETE → event_complete.emit()
  → game._on_event_complete() → _apply_rewards(current_event.rewards), disconnect, _finish_event()
```

---

## SkillCheckEvent

**Date:** 2026-03-31

### Node Tree

```
SkillCheckEvent     Node2D          scripts/skill_check_event.gd
```

Root node only. Roll UI lives in `SkillCheckPanel`. Event loads data and coordinates phase flow; never touches the player or UI directly.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `skill_check_requested(stat: Enums.Stat, label: String)` | Enters RUNNING |
| `dialogue_requested(data: Dictionary)` | RESOLUTION fires optional success/failure dialogue |
| `event_complete` | Inherited; emitted at end of COMPLETE |

### Methods game.gd calls on SkillCheckEvent

| Method | When called |
|---|---|
| `on_skill_check_complete(success: bool)` | After the player rolls and presses Continue |
| `on_dialogue_complete()` | When RESOLUTION dialogue is dismissed |

### Phase Flow

`start()` runs `_on_setup()` (load JSON, parse `_stat`, `_label`, `_on_success_path`, `_on_failure_path`, `_rewards_on_success`, `_rewards_on_failure`) then `_on_running()` (emit `skill_check_requested`). Stays in RUNNING until `on_skill_check_complete(success)` is called.

`on_skill_check_complete(success)` stores `_success` and calls `_set_phase(Phase.RESOLUTION)` directly — not `_advance_phase()`. This lets `_on_resolution()` pause for dialogue before COMPLETE.

`_on_resolution()` sets `rewards = _rewards_on_success if _success else _rewards_on_failure` at its first line, so rewards are populated even if no result dialogue fires. Then picks the success or failure dialogue path. If empty, calls `_set_phase(Phase.COMPLETE)` directly. If non-empty, loads dialogue JSON and emits `dialogue_requested`.

`on_dialogue_complete()` → `_set_phase(Phase.COMPLETE)` → `event_complete` emits. Note: this ignores the `terminal_node_id` that `game.gd` passes to `DialogueEvent.on_dialogue_complete()` — skill-check flavor dialogues are *not* reward-bearing, and any terminal-node `rewards` declared on them are ignored. The skill check's own `rewards_on_success` / `rewards_on_failure` are authoritative.

### JSON Format

```json
{
  "name": "sneak_past_guard",
  "label": "Sneak past the guard",
  "stat": "AGILITY",
  "rewards_on_success": { "experience": 15, "gold": 0 },
  "rewards_on_failure": {},
  "on_success": "res://resources/dialogue/sneak_success.json",
  "on_failure": "res://resources/dialogue/sneak_failure.json"
}
```

`stat` maps to `Enums.Stat` via `Enums.Stat[stat_key]`. `on_success` and `on_failure` point directly to dialogue node tree JSONs. Leave empty to skip result dialogue. `rewards_on_success` and `rewards_on_failure` are each optional — omit to grant nothing on that outcome. No shared fallback; each outcome declares its own.

### Roll Mechanic

d100 roll-under: `randi_range(1, 100) <= int(effective_stat)`. A stat of 50 = 50% success. Roll happens in `SkillCheckPanel`, not the event — the event receives only the boolean result.

`game.gd` is the only place `player.get_effective_stat()` is called. The event never holds a player reference.

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is SkillCheckEvent:
    var sce := event as SkillCheckEvent
    sce.skill_check_requested.connect(_on_skill_check_requested)
    sce.dialogue_requested.connect(_on_dialogue_requested)
```

`_on_skill_check_requested(stat, label)` calls `player.get_effective_stat(stat)` and passes the value to `_gui.show_skill_check(Enums.Stat.keys()[stat], label, stat_value)`.

Cleanup in `_on_event_complete()`:
```gdscript
elif current_event is SkillCheckEvent:
    var sce := current_event as SkillCheckEvent
    sce.skill_check_requested.disconnect(_on_skill_check_requested)
    sce.dialogue_requested.disconnect(_on_dialogue_requested)
```

`dialogue_requested` reuses the existing `_on_dialogue_requested` handler. `_on_gui_dialogue_complete()` adds:
```gdscript
elif current_event is SkillCheckEvent:
    (current_event as SkillCheckEvent).on_dialogue_complete()
```

### Signal Flow

```
game.start_event(skill_check_event)
  → sce.skill_check_requested.connect / sce.dialogue_requested.connect
  → sce.start()
    → _on_setup(): load JSON
    → _on_running(): emit skill_check_requested(_stat, _label)
  → game._on_skill_check_requested(stat, label)
    → player.get_effective_stat(stat) → stat_value
    → gui.show_skill_check("AGILITY", label, stat_value)
  → [player rolls]
  → gui.skill_check_complete(success) → game._on_gui_skill_check_complete(success)
    → sce.on_skill_check_complete(success)
      → store _success, _set_phase(RESOLUTION)
      → _on_resolution(): rewards = outcome-specific dict; then load dialogue + emit dialogue_requested OR _set_phase(COMPLETE)

  [if dialogue fires:]
  → game._on_dialogue_requested(data) → gui.show_dialogue()
  → [player dismisses]
  → gui.dialogue_complete → game._on_gui_dialogue_complete()
    → sce.on_dialogue_complete() → _set_phase(COMPLETE) → event_complete.emit()

  → game._on_event_complete() → disconnect, _apply_rewards(), _finish_event()
```

### Open Questions

- Roll animation — panel shows result instantly; a tween would add game feel.
- Stat display — showing the raw stat number reveals exact odds; consider hiding until after roll.

---

## ShopEvent

**Date:** 2026-04-14

### Node Tree

```
ShopEvent           Node2D          scripts/shop_event.gd
```

Root node only. Shop UI lives in `ShopPanel` (see [[detailed/gui-design.md]]). `ShopEvent` owns transient stock and phase flow; never touches the player, inventory, or UI directly.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `shop_requested(shop_name: String, stock: Array[EquipmentData], buy_mult: float, sell_mult: float)` | Enters RUNNING |
| `stock_changed(stock: Array[EquipmentData])` | After `on_buy()` / `on_sell()` mutates `_stock` |
| `event_complete` | Inherited; emitted after COMPLETE |

### Methods game.gd calls on ShopEvent

| Method | When called |
|---|---|
| `initialize(data: Dictionary)` | Before `start()`. `data["shop"]` is a `ShopData` resource. |
| `on_buy(item: EquipmentData)` | After game.gd validates and applies gold+inventory changes. Removes from `_stock`, emits `stock_changed`. |
| `on_sell(item: EquipmentData)` | After game.gd applies changes. Appends to `_stock`, emits `stock_changed`. |
| `on_leave()` | From `_on_gui_shop_leave_requested()`. Calls `_advance_phase()` → RESOLUTION → COMPLETE. |
| `get_buy_price(item) -> int` | Returns `round(item.price * _buy_mult)`. |
| `get_sell_price(item) -> int` | Returns `round(item.price * _sell_mult)`. |

### Phase Flow

`start()` runs `_on_setup()` (shallow-copy `shop_data.stock` into `_stock`; store name, buy/sell multipliers) then `_on_running()` (emit `shop_requested`). Event stays in RUNNING through any number of buy/sell transactions.

`on_leave()` calls `_advance_phase()` — RUNNING → RESOLUTION → COMPLETE atomically. `_on_resolution()` is not overridden. `rewards` stays empty — gold and items are traded inline, not rewarded at completion.

Follows the same "stay in RUNNING, advance via user-action callback" pattern as `RestEvent`.

### ShopData Resource

```gdscript
class_name ShopData
extends Resource         # scripts/shop_data.gd

@export var shop_name: String = ""
@export var stock: Array[EquipmentData] = []
@export var buy_price_multiplier: float = 1.0
@export var sell_price_multiplier: float = 0.5
```

One `.tres` per shop, lives under `resources/shops/`. Mirrors `PlayerClassData`.

### Pricing

`EquipmentData.price: int` is the item's intrinsic base value. `ShopData` scales it per shop. Shops compute on demand via `get_buy_price` / `get_sell_price`. `price == 0` is treated as a data bug — error-log in `_on_setup`.

### Transaction Routing — the critical policy point

All validation and state mutation lives in `game.gd`. The event never touches the player. The panel never touches the event. The panel never touches the player.

**Buy flow:**
```
panel row pressed → panel.buy_requested(item)
  → gui.shop_buy_requested(item)
  → game._on_gui_shop_buy_requested(item):
      price = current_event.get_buy_price(item)
      if player.gold < price:             gui.show_shop_status("Not enough gold"); return
      if player.inventory.is_bag_full():  gui.show_shop_status("Bag full"); return
      player.spend_gold(price)                     # emits gold_changed
      current_event.on_buy(item)                   # emits stock_changed
      player.inventory.add_to_bag(item)            # emits bag_changed
```

Three signal emissions drive UI refreshes:
- `player.gold_changed` → `_on_player_gold_changed` → if ShopEvent active, `_gui.refresh_shop_gold`
- `current_event.stock_changed` → `_on_shop_stock_changed` → `_gui.refresh_shop_stock`
- `inventory.bag_changed` → connected in `start_event()` only while shop is active → `_gui.refresh_shop_bag`

**Sell flow:** mirrors in reverse — validate `item in inventory.get_bag()`, `player.add_gold(price)`, `current_event.on_sell(item)`, `inventory.remove_from_bag(item)`.

`spend_gold(amount: int) -> bool` — new method on Player co-located with `add_gold`; returns `false` without side effects if `gold < amount`.

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is ShopEvent:
    var se := event as ShopEvent
    se.shop_requested.connect(_on_shop_requested)
    se.stock_changed.connect(_on_shop_stock_changed)
    player.inventory.bag_changed.connect(_on_shop_bag_changed)
```

`_on_shop_requested(name, stock, buy_mult, sell_mult)` builds a bag snapshot and calls `_gui.show_shop(name, stock, player.inventory.get_bag(), player.gold, buy_mult, sell_mult, player.inventory.is_bag_full())`.

Cleanup in `_on_event_complete()`:
```gdscript
elif current_event is ShopEvent:
    var se := current_event as ShopEvent
    se.shop_requested.disconnect(_on_shop_requested)
    se.stock_changed.disconnect(_on_shop_stock_changed)
    player.inventory.bag_changed.disconnect(_on_shop_bag_changed)
```

`gui.shop_buy_requested`, `shop_sell_requested`, `shop_leave_requested` connected in `_ready()`. Leave handler calls `_gui.hide_shop()` then `(current_event as ShopEvent).on_leave()`.

### WorldMapNode integration

```gdscript
@export var shop_scene: PackedScene
@export var shop_data: ShopData

func _build_shop_config() -> Array[Dictionary]:
    return [{ "scene": shop_scene, "data": { "shop": shop_data } }]
```

New case in `generate_event_configs()`:
```gdscript
if node_type == Enums.NodeType.SHOP:
    return _build_shop_config()
```

### Signal Flow

```
game.start_event(shop_event)
  → se.shop_requested.connect / stock_changed.connect / bag_changed.connect
  → se.start()
    → _on_setup(): copy stock + multipliers from ShopData
    → _on_running(): emit shop_requested(...)
  → game._on_shop_requested(...) → gui.show_shop(...)

  [buy]
  → panel.buy_requested(item) → gui.shop_buy_requested → game._on_gui_shop_buy_requested(item)
    → validate → player.spend_gold → se.on_buy → inventory.add_to_bag
    → each emits → gui.refresh_shop_gold / refresh_shop_stock / refresh_shop_bag

  [sell]
  → panel.sell_requested(item) → gui.shop_sell_requested → game._on_gui_shop_sell_requested(item)
    → player.add_gold → se.on_sell → inventory.remove_from_bag

  [leave]
  → panel.leave_requested → gui.shop_leave_requested → game._on_gui_shop_leave_requested()
    → gui.hide_shop()
    → se.on_leave() → _advance_phase() → RESOLUTION → COMPLETE → event_complete
  → game._on_event_complete(): disconnect all three shop signals, _apply_rewards({}), _finish_event()
```

### Open Questions

- Stock persistence across revisits — future: live on `WorldMapNode`, passed through `initialize(data)`.
- Sold items re-entering stock — default yes (buy-back supported). Easy to change.
- Do shops have rewards? Not in initial design.

---

## RestEvent

RestEvent follows the same "stay in RUNNING, advance via user-action callback" pattern as `ShopEvent`. When designed, it will live here. Current placeholder:

- Phase flow: SETUP (load data) → RUNNING (show rest panel, emit rest options) → RESOLUTION → COMPLETE
- User presses "Rest" or "Leave" → `on_rest()` / `on_leave()` → `_advance_phase()`
- No panel node tree yet — add to `gui-design.md` when built.

---

## Checklist: Adding a New Event Type

1. **Create `scripts/<name>_event.gd`** — extends `Event`; override `initialize()`, `_on_setup()`, `_on_running()`, signals, phase methods
2. **Create `scenes/<name>_event.tscn`** — inherit `event.tscn` (or `combat_event.tscn` for combat variants); add child nodes if needed
3. **Create JSON resources** — under `resources/events/<type>/`; document format in this file
4. **Add WorldMapNode config builder** — add `@export` vars to `world_map_node.gd`, implement `_build_<type>_config()`, add case to `generate_event_configs()` — document in `game-flow.md`
5. **Wire in `game.gd start_event()`** — add `elif event is <Name>Event:` branch; connect signals; document the branch in `game-flow.md`
6. **Disconnect in `game.gd _on_event_complete()`** — add matching cleanup branch
7. **Add GUI panel** — implement panel script + scene; add to GUI node tree in `game.tscn`; add panel section to `gui-design.md`
8. **Add `gui.gd` relay methods** — `show_<type>()` / `hide_<type>()` and any refresh methods; add to `gui-design.md` API table
9. **Add this event's section to this file**
