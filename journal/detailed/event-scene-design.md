# Event Scene Design

**Date:** 2026-03-05 (updated 2026-04-17)
**Status:** Implemented — except `## BossEvent` (see banner in that section)

---

## Overview

Captures the node tree and signal contract for every event subclass: base `Event`, `CombatEvent`, `DialogueEvent`, `SkillCheckEvent`, `RestEvent`, `ShopEvent`, and the planned `BossEvent`. All except `BossEvent` are built and in use. This document is the source of truth for scene structure and signal flow across event types.

---

## Node Trees

### Base Event

```
Event               Node2D          scripts/event.gd
```

Just the root node. `event.gd` already has the phase state machine (SETUP → RUNNING → RESOLUTION → COMPLETE). No child nodes at the base level — subclasses add their own structure.

In Godot 4, CombatEvent's scene inherits the base Event scene and extends it.

### CombatEvent

```
CombatEvent         Node2D          scripts/combat_event.gd
└── Enemies         Node            container; enemy scenes instantiated here at runtime
```

`Enemies` is a bare grouping `Node` with no script. Enemy scenes are added as children at runtime via `add_enemy()`. `_enemies: Array[Enemy]` on the script holds them for logical iteration; the node gives a clean editor grouping.

Music and ambient audio live on `Game`, not on events.

---

## Signal Contract

### Signals CombatEvent emits

| Signal | Emitted when |
|---|---|
| `player_attacked(damage: float)` | An enemy attacked — re-emitted from `enemy.attacked` |
| `player_attack_resolved(enemy: Enemy, damage: float)` | Player's attack landed on a specific enemy — for UI/combat log |
| `enemy_turns_complete` | All living enemies have finished their turns |
| `event_complete` | Inherited from Event; all enemies dead, combat over |

### Methods game.gd calls on CombatEvent

| Method | When called |
|---|---|
| `add_enemy(enemy: Enemy)` | Before `start()` to register participants |
| `receive_player_attack(enemy: Enemy, damage: float)` | When player attacks; applies damage to the specified enemy |
| `run_enemy_turns()` | Called by game.gd when player turn ends |

---

## Enemy Connection Pattern

### `add_enemy(enemy: Enemy)` does three things

1. Appends to `_enemies: Array[Enemy]`
2. Calls `$Enemies.add_child(enemy)` to place the enemy in the scene tree
3. Connects `enemy.died` → `_on_enemy_died()`

`enemy.attack` is connected in `_on_setup()` so the signal is live when the event starts.

### `receive_player_attack(enemy: Enemy, damage: float)`

- Applies damage directly to the specified enemy via `enemy.take_damage(damage)`
- Emits `player_attack_resolved(enemy, damage)` for UI/combat log

Target selection (which enemy the player is attacking) is the concern of game.gd or a future targeting system — CombatEvent just applies damage to whichever enemy is passed.

### Death tracking in `_on_enemy_died()`

- Skip or optionally clean up the reference (dead enemies are skipped via `is_dead` during turn loops)
- If all `_enemies` have `is_dead == true`, call `_advance_phase()` → RESOLUTION → COMPLETE → `event_complete`

`enemy.died` is connected per-enemy in `add_enemy()`, not in `_on_setup()`, so it survives across phases.

---

## Turn Loop

game.gd calls `(current_event as CombatEvent).run_enemy_turns()` in `_run_enemy_turns()`.

### Inside `run_enemy_turns()` on CombatEvent

1. Build a list of living enemies from `_enemies` (skip `is_dead`)
2. Connect to the first enemy's `turn_ended` signal (one-shot)
3. Call `enemy.take_turn()`
4. On `turn_ended`: advance to next living enemy; if none remain, emit `enemy_turns_complete`

game.gd connects `enemy_turns_complete` → `_on_enemy_turns_complete()` → `_start_player_turn()`.

Sequencing logic lives inside CombatEvent. game.gd only knows "enemy turns started / enemy turns done".

**Why not game.gd driving the loop directly?** game.gd would need to know how many enemies exist and which ones are alive — that is CombatEvent's concern. Routing through CombatEvent keeps game.gd enemy-type-agnostic.

---

## Changes Required in game.gd

In `start_event()`, when `event is CombatEvent`, also connect:

```gdscript
ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
```

Disconnect both `player_attacked` and `enemy_turns_complete` in `_on_event_complete`.

In `_run_enemy_turns()`, replace the current stub:

```gdscript
func _run_enemy_turns() -> void:
    (current_event as CombatEvent).run_enemy_turns()
```

Add handler:

```gdscript
func _on_enemy_turns_complete() -> void:
    _start_player_turn()
```

Player attack routing:

```gdscript
# Target selection lives here or in a future targeting system
(current_event as CombatEvent).receive_player_attack(target_enemy, damage)
```

---

## Waves — Future Flexibility

Waves are out of scope for the initial implementation. When added, CombatEvent refills `_enemies` internally and loops through the turn sequence again without changes to game.gd. `enemy_turns_complete` fires between waves only if game.gd needs a beat — otherwise CombatEvent suppresses it and starts the next wave directly. The `_on_enemy_died()` all-dead check becomes wave-aware (don't advance phase if more waves remain), but that logic stays entirely inside CombatEvent.

---

---

## DialogueEvent

**Date:** 2026-03-29

### Node Tree

```
DialogueEvent       Node2D          scripts/dialogue_event.gd
```

Root node only — no children. Dialogue rendering lives entirely in GUI (`DialoguePanel`). `DialogueEvent` is a thin event wrapper that loads data and hands it off.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `dialogue_requested(data: Dictionary)` | Event enters RUNNING — carries the loaded dialogue tree |
| `event_complete` | Inherited from Event; emitted when dialogue is confirmed complete |

### Methods game.gd calls on DialogueEvent

| Method | When called |
|---|---|
| `on_dialogue_complete()` | Called from `_on_gui_dialogue_complete()` when the player dismisses the final dialogue node |

### Phase Flow

`start()` calls `_on_setup()` (load JSON from `dialogue_json_path`) then immediately `_on_running()` (emit `dialogue_requested`). The event stays in RUNNING while the player navigates dialogue. When the panel emits `dialogue_complete`, `game.gd` restores the turn state and calls `on_dialogue_complete()`, which calls `_advance_phase()` — this transitions RUNNING → RESOLUTION → COMPLETE atomically, emitting `event_complete`.

`_on_resolution()` is not overridden. Nothing to do between dialogue ending and event completing at this stage.

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is DialogueEvent:
    var de := event as DialogueEvent
    de.dialogue_requested.connect(_on_dialogue_requested)
```

`_on_dialogue_requested(data)` saves the current turn state to `_pre_dialogue_state`, sets state to `DIALOGUE`, and calls `_gui.show_dialogue(data, _dialogue_consequences)`.

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
  → game._on_dialogue_requested(data) → start_dialogue(data)
    → save state, set DIALOGUE, gui.show_dialogue()
  → [player navigates dialogue tree]
  → gui.dialogue_complete → game._on_gui_dialogue_complete()
    → restore state
    → de.on_dialogue_complete() → _advance_phase()
      → RESOLUTION → COMPLETE → event_complete.emit()
  → game._on_event_complete() → disconnect, _finish_event()
```

---

## SkillCheckEvent

**Date:** 2026-03-31

### Node Tree

```
SkillCheckEvent     Node2D          scripts/skill_check_event.gd
```

Root node only — no children. The roll UI lives entirely in GUI (`SkillCheckPanel`). `SkillCheckEvent` loads event data and coordinates the phase flow; it never touches the player or the UI directly.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `skill_check_requested(stat: Enums.Stat, label: String)` | Event enters RUNNING — carries the stat to roll against and the prompt text |
| `dialogue_requested(data: Dictionary)` | RESOLUTION fires optional success/failure dialogue |
| `event_complete` | Inherited from Event; emitted at end of COMPLETE phase |

### Methods game.gd calls on SkillCheckEvent

| Method | When called |
|---|---|
| `on_skill_check_complete(success: bool)` | Called from `_on_gui_skill_check_complete()` after the player rolls and presses Continue |
| `on_dialogue_complete()` | Called from `_on_gui_dialogue_complete()` when RESOLUTION dialogue is dismissed |

### Phase Flow

`start()` runs `_on_setup()` (load JSON, parse `_stat`, `_label`, `_on_success_path`, `_on_failure_path`, `rewards`) then `_on_running()` (emit `skill_check_requested`). The event stays in RUNNING while the player rolls.

When game.gd calls `on_skill_check_complete(success)`, the result is stored and `_set_phase(Phase.RESOLUTION)` is called directly — **not** `_advance_phase()`. The base `_advance_phase()` jumps RUNNING → RESOLUTION → COMPLETE atomically; calling `_set_phase` one step at a time lets `_on_resolution()` pause and fire dialogue before COMPLETE.

`_on_resolution()` picks `_on_success_path` or `_on_failure_path` based on the stored result. If the path is non-empty, it loads the dialogue JSON and emits `dialogue_requested`. If the path is empty, it calls `_set_phase(Phase.COMPLETE)` directly.

After optional dialogue is dismissed, game.gd calls `on_dialogue_complete()` → `_set_phase(Phase.COMPLETE)` → `event_complete` emits.

### JSON Format

```json
{
  "name": "sneak_past_guard",
  "label": "Sneak past the guard",
  "stat": "AGILITY",
  "rewards": { "experience": 15, "gold": 0 },
  "on_success": "res://resources/dialogue/sneak_success.json",
  "on_failure": "res://resources/dialogue/sneak_failure.json"
}
```

`stat` maps to an `Enums.Stat` key via `Enums.Stat[stat_key]`. `on_success` and `on_failure` are optional — leave empty to skip result dialogue.

### Roll Mechanic

d100 roll-under: `randi_range(1, 100) <= int(effective_stat)`. A stat of 50 gives a 50% chance. The roll happens in `SkillCheckPanel`, not in the event — the event only receives the boolean result.

`game.gd` is the only place `player.get_effective_stat()` is called. `_on_skill_check_requested()` reads the value and passes it to `gui.show_skill_check()` as a plain float. The event never holds a player reference.

### SkillCheckPanel Node Tree

```
SkillCheckPanel     Control             scripts/skill_check_panel.gd
└── Background      ColorRect           dim overlay
└── PanelContainer  PanelContainer      centered card
    └── VBoxContainer
        ├── HBoxContainer
        │   ├── StatNameLabel   Label   e.g. "AGILITY"
        │   └── StatValueLabel  Label   e.g. "65"
        ├── PromptLabel         Label   e.g. "Sneak past the guard"
        ├── RollResultLabel     Label   hidden until rolled; "Rolled: 42 — SUCCESS"
        ├── RollButton          Button  disabled after first press
        └── ContinueButton      Button  hidden until roll resolves
```

`setup(stat_name, label, stat_value)` fully resets the panel state (re-enables Roll, hides result/continue) so it is safe to reuse across multiple skill check events in a session.

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

`dialogue_requested` reuses the existing `_on_dialogue_requested` handler unchanged. The `_on_gui_dialogue_complete()` handler adds an `elif current_event is SkillCheckEvent` branch to call `on_dialogue_complete()`.

### Signal Flow

```
game.start_event(skill_check_event)
  → sce.skill_check_requested.connect(_on_skill_check_requested)
  → sce.dialogue_requested.connect(_on_dialogue_requested)
  → sce.start()
    → _on_setup(): load JSON, parse stat/label/paths/rewards
    → _on_running(): emit skill_check_requested(_stat, _label)
  → game._on_skill_check_requested(stat, label)
    → player.get_effective_stat(stat) → stat_value
    → gui.show_skill_check("AGILITY", label, stat_value)
  → [player rolls, panel shows result]
  → gui.skill_check_complete(success) → game._on_gui_skill_check_complete(success)
    → sce.on_skill_check_complete(success)
      → store _success, _set_phase(RESOLUTION)
      → _on_resolution(): load and emit dialogue_requested OR _set_phase(COMPLETE)

  [if dialogue fires:]
  → game._on_dialogue_requested(data) → gui.show_dialogue()
  → [player dismisses dialogue]
  → gui.dialogue_complete → game._on_gui_dialogue_complete()
    → sce.on_dialogue_complete() → _set_phase(COMPLETE) → event_complete.emit()

  → game._on_event_complete() → disconnect signals, _apply_rewards(), _finish_event()
```

---

## ShopEvent

**Date:** 2026-04-14

### Node Tree

```
ShopEvent           Node2D          scripts/shop_event.gd
```

Root node only — no children. The shop UI lives entirely in GUI (`ShopPanel`). `ShopEvent` owns its transient stock and coordinates phase flow; it never touches the player, inventory, or the UI directly.

### Signal Contract

| Signal | Emitted when |
|---|---|
| `shop_requested(shop_name: String, stock: Array[EquipmentData], buy_mult: float, sell_mult: float)` | Enters RUNNING — hands shop identity, stock snapshot, and pricing multipliers to `game.gd` |
| `stock_changed(stock: Array[EquipmentData])` | After `on_buy()` / `on_sell()` mutates `_stock` |
| `event_complete` | Inherited from Event; emitted after COMPLETE |

### Methods game.gd calls on ShopEvent

| Method | When called |
|---|---|
| `initialize(data: Dictionary)` | Before `start()`. `data["shop"]` is a `ShopData` resource. |
| `on_buy(item: EquipmentData)` | After `game.gd` has validated and applied gold+inventory changes. Removes item from `_stock`, emits `stock_changed`. |
| `on_sell(item: EquipmentData)` | After `game.gd` has applied gold+inventory changes. Appends item to `_stock`, emits `stock_changed`. Buy-back is supported by default. |
| `on_leave()` | Called from `_on_gui_shop_leave_requested()`. Calls `_advance_phase()` → RESOLUTION → COMPLETE. |
| `get_buy_price(item) -> int` | Returns `round(item.price * _buy_mult)`. Used by `game.gd` for validation. |
| `get_sell_price(item) -> int` | Returns `round(item.price * _sell_mult)`. |

### Phase Flow

`start()` runs `_on_setup()` (shallow-copy `shop_data.stock` into `_stock`; store `_shop_name`, `_buy_mult`, `_sell_mult`) then `_on_running()` (emit `shop_requested`). The event stays in RUNNING through any number of buy/sell transactions.

`on_leave()` calls `_advance_phase()` — `RUNNING → RESOLUTION → COMPLETE` transitions atomically; `_on_resolution()` is not overridden. `rewards` stays empty — gold and items are debited/credited **inline during transactions**, not at completion.

Follows the same "stay in RUNNING, advance via user-action callback" pattern as `RestEvent`.

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

Three subsequent signal emissions drive UI refreshes in `game.gd`:

- `player.gold_changed` → `_on_player_gold_changed` branches: if `current_event is ShopEvent`, call `_gui.refresh_shop_gold(new_total)`.
- `current_event.stock_changed` → `_on_shop_stock_changed(stock)` → `_gui.refresh_shop_stock(stock)`.
- `inventory.bag_changed` → connected in `start_event()` only while a shop is active; calls `_gui.refresh_shop_bag(inventory.get_bag())`.

**Sell flow:** mirrors in reverse — validate `item in inventory.get_bag()`, `player.add_gold(price)`, `current_event.on_sell(item)`, `inventory.remove_from_bag(item)`.

`spend_gold(amount: int) -> bool` is a new method on `Player` co-located with `add_gold`; returns `false` without side effects if `gold < amount`.

### Pricing

`EquipmentData` gains a new field: `@export var price: int = 0` — the item's intrinsic base value. `ShopData` scales it per shop via `buy_price_multiplier` (default `1.0`) and `sell_price_multiplier` (default `0.5`). Shops compute prices on demand via `get_buy_price` / `get_sell_price`.

### ShopData resource

```
scripts/shop_data.gd            # extends Resource
    @export var shop_name: String = ""
    @export var stock: Array[EquipmentData] = []
    @export var buy_price_multiplier: float = 1.0
    @export var sell_price_multiplier: float = 0.5
```

Mirrors `PlayerClassData` — one `.tres` per shop, lives under `resources/shops/`.

### ShopPanel Node Tree

```
ShopPanel                           Control             scripts/shop_panel.gd
├── Background                      ColorRect           full-rect dim overlay (color 0,0,0,0.5)
└── HBoxContainer                   HBoxContainer       anchored center
    ├── PanelContainer              PanelContainer      left column — the shop interior
    │   └── VBoxContainer           VBoxContainer
    │       ├── ShopNameLabel       Label               e.g. "Old Pete's Wares"
    │       ├── GoldLabel           Label               e.g. "Gold: 120"
    │       ├── ModeButtons         HBoxContainer
    │       │   ├── BuyTabButton    Button              "Buy" (pressed by default)
    │       │   └── SellTabButton   Button              "Sell"
    │       ├── ItemList            VBoxContainer       rows built at runtime as Buttons
    │       │                                           custom_minimum_size = Vector2(0, 240)
    │       │                                           size_flags_vertical = 3 (FILL+EXPAND)
    │       ├── StatusLabel         Label               "Bag full" / "Not enough gold" — hidden by default
    │       └── LeaveButton         Button              "Leave"
    └── DetailPanel                 PanelContainer      right column — mirrors InventoryPanel
        └── VBoxContainer           VBoxContainer
            ├── DetailNameLabel     Label
            ├── DetailPriceLabel    Label               "Price: 45g" (mode-aware)
            ├── DetailStatsLabel    Label               stat modifiers, autowrap on
            └── DetailDescLabel     Label               description text, autowrap on
```

Build in `scenes/ui/shop_panel.tscn` and attach `scripts/shop_panel.gd`. Layout follows the two-column list + detail idiom established by `InventoryPanel`. A Buy/Sell mode toggle swaps what populates `ItemList` — no `TabContainer` (novel pattern in this codebase).

Rendering notes — lessons from prior panels:

- Set `custom_minimum_size` + `size_flags_vertical = 3` on the list container, per the 2026-04-12 `CharacterCreationPanel` fix.
- Store direct references to runtime-created row buttons in dictionaries keyed by item, per the 2026-04-14 `LevelUpPanel` fix — do **not** use `find_child` on just-added nodes.

### Row Button Behavior

`ItemList` rows are `Button`s built in code (matches `InventoryPanel._refresh_bag`). Per row:

- `text = "%s — %dg" % [item.item_name, price]`
- `pressed` → emits `buy_requested(item)` or `sell_requested(item)` depending on current mode
- `mouse_entered` → updates the right-hand detail panel
- `disabled`: in Buy mode, true when `price > gold` **or** `bag_full == true`; in Sell mode, never disabled.

`game.gd` passes a `bag_full: bool` into `refresh_stock` so the panel stays free of policy — it does not read bag size to infer enablement.

### Panel API (methods — no signal connections into the panel)

| Method | Purpose |
|---|---|
| `setup(shop_name, stock, bag, gold, buy_mult, sell_mult, bag_full)` | Full initialization; resets mode to Buy. |
| `refresh_stock(stock, bag_full)` | Called after a buy/sell mutates shop inventory. |
| `refresh_bag(bag, bag_full)` | Called when player bag changes. |
| `refresh_gold(gold)` | Called when player gold changes. |
| `show_status(msg)` | Shows/clears status line. |

**Critical compliance point:** `ShopPanel` holds **no** references to `Player`, `Inventory`, or `ShopEvent`. Only plain arrays, ints, floats, and strings cross the panel boundary — matches `SkillCheckPanel` precedent (see "The event never holds a player reference" above).

### How game.gd wires it (in `start_event()`)

```gdscript
elif event is ShopEvent:
    var se := event as ShopEvent
    se.shop_requested.connect(_on_shop_requested)
    se.stock_changed.connect(_on_shop_stock_changed)
    player.inventory.bag_changed.connect(_on_shop_bag_changed)
```

`_on_shop_requested(name, stock, buy_mult, sell_mult)` builds a bag snapshot via `player.inventory.get_bag()`, reads `player.gold` and `player.inventory.is_bag_full()`, and calls `_gui.show_shop(name, stock, bag, gold, buy_mult, sell_mult, bag_full)`.

Cleanup in `_on_event_complete()`:

```gdscript
elif current_event is ShopEvent:
    var se := current_event as ShopEvent
    se.shop_requested.disconnect(_on_shop_requested)
    se.stock_changed.disconnect(_on_shop_stock_changed)
    player.inventory.bag_changed.disconnect(_on_shop_bag_changed)
```

`_gui.shop_buy_requested`, `shop_sell_requested`, `shop_leave_requested` are connected to `game.gd` handlers in `_ready()` alongside the existing rest/dialogue hookups. The leave handler calls `_gui.hide_shop()` then `(current_event as ShopEvent).on_leave()`.

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
  → se.shop_requested.connect(_on_shop_requested)
  → se.stock_changed.connect(_on_shop_stock_changed)
  → player.inventory.bag_changed.connect(_on_shop_bag_changed)
  → se.start()
    → _on_setup(): copy stock, buy/sell multipliers, shop_name from ShopData
    → _on_running(): emit shop_requested(name, stock, buy_mult, sell_mult)
  → game._on_shop_requested(...)
    → gui.show_shop(name, stock, player.inventory.get_bag(), player.gold,
                    buy_mult, sell_mult, player.inventory.is_bag_full())

  [player clicks a buy row]
  → panel.buy_requested(item) → gui.shop_buy_requested → game._on_gui_shop_buy_requested(item)
    → price = se.get_buy_price(item)
    → validate: price <= player.gold AND not inventory.is_bag_full()
       → on fail: gui.show_shop_status("..."); return
       → on pass:
           player.spend_gold(price)            → gold_changed → gui.refresh_shop_gold
           se.on_buy(item)                     → stock_changed → gui.refresh_shop_stock
           player.inventory.add_to_bag(item)   → bag_changed → gui.refresh_shop_bag

  [player clicks a sell row]
  → panel.sell_requested(item) → gui.shop_sell_requested → game._on_gui_shop_sell_requested(item)
    → price = se.get_sell_price(item)
    → player.add_gold(price)                   → gold_changed → gui.refresh_shop_gold
    → se.on_sell(item)                         → stock_changed → gui.refresh_shop_stock
    → player.inventory.remove_from_bag(item)   → bag_changed → gui.refresh_shop_bag

  [player clicks Leave]
  → panel.leave_requested → gui.shop_leave_requested → game._on_gui_shop_leave_requested()
    → gui.hide_shop()
    → se.on_leave() → _advance_phase() → RESOLUTION → COMPLETE → event_complete
  → game._on_event_complete(): disconnect all three shop signals, _apply_rewards({}), _finish_event()
```

### Open Questions

- **Stock persistence across revisits.** Stock is copied into `ShopEvent` at setup and freed with the event. Future persistence would live on `WorldMapNode` and be passed through `initialize(data)` — no event-API changes needed.
- **`price == 0` semantics.** Treat as a data bug: error-log in `_on_setup` rather than offering a free item or a silent "not for sale" state. Revisit if "quest rewards only" items become a thing.
- **Sold items re-entering stock.** Default: yes, `on_sell` appends to `_stock` so the player can buy back. Trivial to change if it causes unwanted UX.
- **Do shops have rewards?** Not in initial design — `rewards` dict stays empty. Gold/items are trades, not rewards.

---

## BossEvent

**Date:** 2026-04-17

> **Status: Planned — not yet implemented.** See `journal/daily/2026-04-17.md` for the implementation punch list (`scripts/boss_event.gd`, `scenes/boss_event.tscn`, `resources/events/boss/debug_boss.json`, game.gd wiring).

### Node Tree

```
BossEvent           Node2D (inherits combat_event.tscn)     scripts/boss_event.gd
└── Enemies         Node (inherited)
```

Scene-inherits from `combat_event.tscn`. No new children. All enemy spawning, turn loops, dialogue-trigger handling, and per-enemy connections are reused from `CombatEvent` unchanged.

### Signal Contract

Adds one signal on top of CombatEvent's existing contract:

| Signal | Emitted when |
|---|---|
| `boss_defeated` | All enemies dead — BossEvent's override of `_advance_phase()` intercepts the RUNNING → RESOLUTION transition, emits this signal, and stops. **`event_complete` is intentionally not emitted on victory.** |

BossEvent still inherits and emits `enemy_added`, `player_attacked`, `player_attack_resolved`, `enemy_turns_complete`, and `dialogue_trigger_fired` — these wire automatically through the `event is CombatEvent` branch in `start_event()`. No per-signal wiring changes are needed for inherited signals.

### Methods game.gd calls on BossEvent

Identical to CombatEvent: `initialize`, `add_enemy`, `receive_player_attack`, `run_enemy_turns`. No new method surface.

### Phase Flow

`start()` runs `_on_setup()` and `_on_running()` inherited from CombatEvent. The event stays in RUNNING throughout the fight. When `_on_enemy_died()` detects all enemies dead, it calls `_advance_phase()`. BossEvent's override:

```gdscript
signal boss_defeated

func _advance_phase() -> void:
    match phase:
        Phase.RUNNING:
            boss_defeated.emit()
        _:
            super._advance_phase()
```

The event stays in RUNNING. No RESOLUTION, no COMPLETE, no `event_complete`. game.gd is responsible for reading `rewards` off the event, tearing it down, and driving the victory UI — because the boss terminates the run, the normal reward-→-next-event pipeline does not apply.

### How game.gd wires it (in `start_event()`)

`BossEvent is CombatEvent` evaluates to true via inheritance, so the existing CombatEvent branch runs unchanged. Add one additional connection after it:

```gdscript
if event is BossEvent:
    (event as BossEvent).boss_defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
```

No cleanup branch is needed in `_on_event_complete()` — BossEvent never reaches COMPLETE on victory. CONNECT_ONE_SHOT handles disconnection automatically.

Player death during a boss fight follows the same path as any other combat death: `player.died` → `_on_player_died` → `_teardown_current_event()` frees the BossEvent using the existing CombatEvent disconnect chain. Inheriting from CombatEvent means no extra teardown code is needed.

### Signal Flow

```
[player attacks the final living boss enemy]
  → current_event.receive_player_attack(enemy, damage)
  → enemy.take_damage → enemy._die → died.emit()
  → BossEvent._on_enemy_died() (inherited)
    → all dead → _advance_phase()
  → override: boss_defeated.emit()   [phase stays RUNNING]

  → game._on_boss_defeated()
    → state = VICTORY
    → _apply_rewards(current_event.rewards)     # must run BEFORE teardown
    → _teardown_current_event()                 # reuse shared helper
    → null out _active_world_node / _pending_event_configs / _event_index
    → if player.pending_stat_points > 0: gui.show_level_up(player); return
    → gui.show_victory()
```

If level-up is shown first, `_on_level_up_complete()` branches on `state == VICTORY` to call `gui.show_victory()` instead of `_finish_event()`.

### Boss JSON

Mirrors the existing combat JSON shape — `{"enemies": [...], "rewards": {...}, "dialogue_triggers": {...}}`. Lives under `resources/events/boss/`. `CombatEvent.initialize()` and `_on_setup()` consume it unchanged.

### Why intercept at the event layer, not at `_finish_event`

Routing victory through `event_complete` → `_on_event_complete` → `_finish_event` would eventually call `_start_next_dungeon_event` on an empty queue → `_on_dungeon_complete` → `gui.world_map_on_dungeon_complete(_active_world_node)`, which marks the boss node COMPLETED and re-shows the world map. Wrong semantics for a run-ender. A dedicated `boss_defeated` signal with a matching handler keeps victory logic in one place and skips the dungeon-completion plumbing entirely.

---

## Signal Flow Summary

**Enemy attacks player:**
`enemy.attack(damage)` → CombatEvent re-emits `player_attacked(damage)` → game.gd → `player.take_damage(damage)`

**Player attacks enemy:**
game.gd calls `receive_player_attack(target_enemy, damage)` → `target_enemy.take_damage(damage)` + CombatEvent emits `player_attack_resolved(enemy, damage)`

**Combat ends:**
`enemy.died` → `_on_enemy_died()` → all dead check → `_advance_phase()` → `event_complete` → game.gd

**Boss defeated (planned):**
`enemy.died` → `_on_enemy_died()` (inherited) → all dead check → `_advance_phase()` (overridden) → `boss_defeated` → game.gd `_on_boss_defeated` → VICTORY state + rewards + teardown + (optional level-up) → `gui.show_victory()`. `event_complete` is never emitted.

**Player dies (planned full flow — today `GAME_OVER` is set but no UI responds):**
`player.died` → game.gd `_on_player_died` → GAME_OVER state → `_teardown_current_event()` (shared helper) → `gui.show_game_over()`. Until the 2026-04-17 game-end work ships, `_on_player_died()` only sets the state; no teardown helper exists and the GUI does not show anything.
