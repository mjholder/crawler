# GUI Implementation Design

**Date:** 2026-03-13 (consolidated 2026-04-18)
**Status:** Mostly implemented — GameOverPanel and VictoryPanel planned (see banners)

Merged from: `gui-design.md`, panel node trees from `dialogue-system.md`, `skill-check-system.md`, `event-scene-design.md § ShopPanel`, and `player-classes-and-leveling.md § LevelUpPanel`

---

## Overview

Establishes the node structure, `gui.gd` API, and signal wiring for the entire GUI layer. This is the single reference for panel node trees, `gui.gd` method signatures, and the signal connections table.

**Architecture:** `gui.gd` exposes an **intent-based API**. `game.gd` calls methods describing *what happened* (`handle_esc()`, `update_player_health()`). The GUI owns *how* to display it. Signal connections are wired exclusively in `game.gd`. GUI panels are implementation details — `game.gd` never references them directly.

---

## Node Tree

```
GUI  (CanvasLayer, layer 4)  [gui.gd]
├── MainMenu  (Control)
│   ├── Title  (Label)
│   ├── StartButton  (Button)
│   ├── StartDialogueButton  (Button)      # debug entry point
│   ├── StartSkillCheckButton  (Button)    # debug entry point
│   └── QuitButton  (Button)
│
├── WorldMap  (WorldMap)                   [world_map.gd] hidden by default; shown after start
│
├── PlayerHUD  (Control)                   # persistent — visible during all non-menu states
│   ├── PlayerHealthLabel  (Label)         # "80 / 100"
│   ├── PlayerHealthBar  (ProgressBar)
│   ├── PlayerGoldLabel  (Label)           # "Gold: 0"
│   └── PlayerXPLabel  (Label)            # "XP: 0"
│
├── PauseMenu  (Control)
│   ├── Overlay  (ColorRect)
│   ├── ResumeButton  (Button)
│   └── QuitToMainButton  (Button)
│
├── CombatHUD  (Control)                   # shown only during CombatEvent
│   ├── EnemyHUD  (Control)
│   ├── ActionMenu  (Control)
│   │   ├── AttackButton  (Button)
│   │   └── ConsumableBelt  (HBoxContainer)   [consumable_belt_ui.gd]
│   └── CombatLog  (RichTextLabel)
│
├── DialoguePanel  (Control)               [dialogue_panel.gd] hidden by default
├── SkillCheckPanel  (Control)             [skill_check_panel.gd] hidden by default
├── ShopPanel  (Control)                   [shop_panel.gd] hidden by default
├── LevelUpPanel  (Control)                [level_up_panel.gd] hidden by default
├── CharacterCreation  (Control)           [character_creation.gd] hidden by default
│
├── GameOverPanel  (Control)               [game_over_panel.gd] (planned) hidden by default
└── VictoryPanel  (Control)                [victory_panel.gd] (planned) hidden by default
```

> **Planned:** `GameOverPanel` and `VictoryPanel` are not yet built. See `journal/daily/2026-04-17.md`.

**Notes:**
- `PlayerHUD` is a sibling of `CombatHUD`, not a child. It persists across world map, combat, dialogue, skill check — only hidden on the main menu.
- `EnemyHUD` children are spawned/freed at runtime — one `health_bar.tscn` instance per living enemy.
- `CombatLog` lives inside `CombatHUD` and clears when a new combat starts.

---

## MainMenu

Shown at game start. Hidden when the game begins.

| Node | Type | Role |
|---|---|---|
| `Title` | Label | Game title |
| `StartButton` | Button | Shows character creation screen |
| `QuitButton` | Button | `Application.quit()` — wired in `gui.gd` directly |

`StartButton.pressed` → `_on_start_button_pressed()` shows `CharacterCreation` (does **not** emit `start_requested` — that signal is removed).

### PauseMenu

Shown over any game state when ESC is pressed. `game.gd` calls `gui.handle_esc()`.

| Node | Type | Role |
|---|---|---|
| `Overlay` | ColorRect | Semi-transparent black rect |
| `ResumeButton` | Button | Calls `handle_esc()` again — wired in `gui.gd` directly |
| `QuitToMainButton` | Button | Signals `game.gd` to reset and show main menu |

### PlayerHUD

| Node | Type | Role |
|---|---|---|
| `PlayerHealthLabel` | Label | "80 / 100" |
| `PlayerHealthBar` | ProgressBar | `value` and `max_value` set via `update_player_health()` |
| `PlayerGoldLabel` | Label | "Gold: 0" |
| `PlayerXPLabel` | Label | "XP: 0" |

### CombatHUD

| Node | Type | Role |
|---|---|---|
| `EnemyHUD` | Control | Container; `health_bar.tscn` instances per enemy |
| `ActionMenu` | Control | Player action buttons; enabled on player turn |
| `AttackButton` | Button | Turn-ending attack action |
| `ConsumableBelt` | HBoxContainer | Per-slot consumable-use buttons. Icon from equipped `ConsumableData.sprite_frames`; disabled when slot empty or state disallows use. |
| `CombatLog` | RichTextLabel | Append-only log; cleared on new combat |

#### ConsumableBelt

```
ConsumableBelt      HBoxContainer       scripts/consumable_belt_ui.gd
└── [Button nodes instantiated at runtime, one per belt slot]
```

Built at runtime from `Inventory.belt_size`. Subscribes to `Inventory.consumable_belt_changed` and `Inventory.belt_size_changed`; rebuilds its button row when belt size changes.

Each button:
- Indexed by belt position, stored on the button as a metadata key.
- Shows the equipped `ConsumableData.sprite_frames` idle frame as its icon; when the slot is empty, shows an empty-slot placeholder and sets `disabled = true`.
- `pressed` → emits `consumable_use_requested(index: int)` upward.
- Enabled/disabled as a group via `set_can_use(value: bool)`.

```gdscript
signal consumable_use_requested(index: int)

var _inventory: Inventory

func setup(inventory: Inventory) -> void
func set_can_use(value: bool) -> void

func _on_consumable_belt_changed(index: int, new_data: ConsumableData, old_data: ConsumableData) -> void
func _on_belt_size_changed(new_size: int) -> void
```

`ConsumableBelt` receives the `Inventory` reference at setup (passed by `gui.gd` when the player is set) — it does not read `Player` or `game.gd`. That keeps the component's dependencies to just `Inventory` state.

**Enable gate:** `set_player_turn(false)` no longer disables `ConsumableBelt` — usage is allowed during `NO_TURN` and `DIALOGUE` too. `game.gd` flips `gui.set_consumables_enabled(enabled)` based on state: enabled when `state in {PLAYER_TURN, NO_TURN, DIALOGUE}`, disabled otherwise.

**Dungeon lock is independent.** The belt's buttons are for *using* consumables, not for equipping them. `Inventory.consume()` bypasses the dungeon lock, so the belt works normally inside a dungeon. The dungeon lock only affects **equipping/unequipping** flows (InventoryPanel belt row, bag→belt drags), never use.

---

## DialoguePanel

Added directly to GUI in `game.tscn`. Hidden by default. No separate panel scene file.

```
DialoguePanel       Control             scripts/dialogue_panel.gd
├── Background      ColorRect           placeholder; swap for NinePatchRect when art is ready
├── SpeakerLabel    Label               hidden when speaker is null
├── TextLabel       RichTextLabel
└── ChoicesContainer    VBoxContainer
    └── [Button nodes instantiated at runtime, one per choice]
```

Choice buttons are created fresh on each node load and freed when the node changes. The Continue button (terminal nodes) replaces them.

### `dialogue_panel.gd`

```gdscript
signal dialogue_complete

var _data: Dictionary
var _consequences: DialogueConsequences
var _current_node_id: String

func load_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void:
    _data = data
    _consequences = consequences
    _load_node("0")

func _load_node(node_id: String) -> void:
    _current_node_id = node_id
    var node: Dictionary = _data["nodes"][node_id]
    if node["consequence"] != null:
        var c: Dictionary = node["consequence"]
        _consequences.execute(c["action"], c["value"])
    _render_node(node)

func _on_choice_pressed(index: int) -> void:
    var next_id: String = _data["nodes"][_current_node_id]["choices"][index]["next"]
    _load_node(next_id)

func _on_continue_pressed() -> void:
    dialogue_complete.emit()
```

### gui.gd Relay

```gdscript
signal dialogue_complete

func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void
    # calls $DialoguePanel.load_dialogue(data, consequences), makes panel visible
    # connects $DialoguePanel.dialogue_complete → _on_dialogue_panel_complete (one-shot)

func _on_dialogue_panel_complete() -> void
    # hides DialoguePanel, emits dialogue_complete
```

`game.gd` connects `_gui.dialogue_complete` → `_on_dialogue_complete` during setup. The panel is an implementation detail — `game.gd` never references it directly.

---

## SkillCheckPanel

Added directly to GUI in `game.tscn`. Hidden by default. No separate panel scene file.

```
SkillCheckPanel     Control             scripts/skill_check_panel.gd
├── Background      ColorRect           dim overlay
└── PanelContainer  PanelContainer      centered card
    └── VBoxContainer
        ├── HBoxContainer
        │   ├── StatNameLabel   Label   e.g. "AGILITY"
        │   └── StatValueLabel  Label   e.g. "65"
        ├── PromptLabel         Label   prompt from JSON "label" field
        ├── RollResultLabel     Label   hidden until rolled — "Rolled: 42 — SUCCESS"
        ├── RollButton          Button  disabled after first press
        └── ContinueButton      Button  hidden until roll resolves
```

### `skill_check_panel.gd`

```gdscript
signal skill_check_complete(success: bool)

var _stat_value: float

func setup(stat_name: String, label: String, stat_value: float) -> void:
    # Populate labels, store _stat_value
    # Reset: re-enable RollButton, hide RollResultLabel and ContinueButton

func _on_roll_button_pressed() -> void:
    var roll: int = randi_range(1, 100)
    var success: bool = roll <= int(_stat_value)
    # Show result text, disable RollButton, show ContinueButton

func _on_continue_pressed() -> void:
    skill_check_complete.emit(_success)
```

`setup()` fully resets panel state — safe to reuse across multiple skill check events per session.

### gui.gd Relay

```gdscript
signal skill_check_complete(success: bool)

func show_skill_check(stat_name: String, label: String, stat_value: float) -> void
    # calls $SkillCheckPanel.setup(...), shows panel

func _on_skill_check_panel_complete(success: bool) -> void
    # hides SkillCheckPanel, emits skill_check_complete(success)
```

---

## ShopPanel

Built in `scenes/ui/shop_panel.tscn`. Two-column list + detail layout.

```
ShopPanel                           Control             scripts/shop_panel.gd
├── Background                      ColorRect           full-rect dim overlay (color 0,0,0,0.5)
└── HBoxContainer                   HBoxContainer       anchored center
    ├── PanelContainer              PanelContainer      left column — shop interior
    │   └── VBoxContainer
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
    └── DetailPanel                 PanelContainer      right column
        └── VBoxContainer
            ├── DetailNameLabel     Label
            ├── DetailPriceLabel    Label               "Price: 45g" (mode-aware)
            ├── DetailStatsLabel    Label               stat modifiers, autowrap on
            └── DetailDescLabel     Label               description, autowrap on
```

**Rendering notes:**
- Set `custom_minimum_size` + `size_flags_vertical = 3` on the list container (per the 2026-04-12 `CharacterCreationPanel` fix).
- Store direct references to runtime row buttons in dicts keyed by item (per 2026-04-14 `LevelUpPanel` fix) — do **not** use `find_child` on just-added nodes.

### Row Button Behavior

`ItemList` rows are `Button` nodes built in code per row:
- `text = "%s — %dg" % [item.item_name, price]`
- `pressed` → emits `buy_requested(item)` or `sell_requested(item)` depending on mode
- `mouse_entered` → updates the right-hand detail panel
- `disabled`: in Buy mode, true when `price > gold` **or** `bag_full`; in Sell mode, never disabled

`game.gd` passes `bag_full: bool` into `refresh_stock` — the panel does not read bag size to infer enablement.

### Panel API

| Method | Purpose |
|---|---|
| `setup(shop_name, stock, bag, gold, buy_mult, sell_mult, bag_full)` | Full init; resets mode to Buy |
| `refresh_stock(stock, bag_full)` | Called after buy/sell mutates shop inventory |
| `refresh_bag(bag, bag_full)` | Called when player bag changes |
| `refresh_gold(gold)` | Called when player gold changes |
| `show_status(msg)` | Shows/clears status line |

`ShopPanel` holds **no** references to `Player`, `Inventory`, or `ShopEvent`. Only plain arrays, ints, floats, and strings cross the panel boundary.

### gui.gd Relay

```gdscript
signal shop_buy_requested(item: EquipmentData)
signal shop_sell_requested(item: EquipmentData)
signal shop_leave_requested

func show_shop(shop_name, stock, bag, gold, buy_mult, sell_mult, bag_full) -> void
func hide_shop() -> void
func refresh_shop_stock(stock: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_bag(bag: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_gold(gold: int) -> void
func show_shop_status(msg: String) -> void
```

`$ShopPanel` signals connected to gui.gd relays in `gui.gd._ready()`.

---

## LevelUpPanel

Shown between events when `player.pending_stat_points > 0`.

```
LevelUpPanel        Control             scripts/level_up_panel.gd
├── Background      ColorRect           dim overlay
└── PanelContainer  PanelContainer      centered card
    └── VBoxContainer
        ├── TitleLabel          Label   "Level Up! — Level N"
        ├── PointsLabel         Label   "Points remaining: N"
        ├── StatsContainer      VBoxContainer
        │   └── [per stat row: StatLabel + MinusButton + ValueLabel + PlusButton]
        └── ConfirmButton       Button  disabled while points remain
```

### Behavior

- `+` next to a stat → calls `player.spend_stat_point(stat)`, decrements counter
- `−` reverses the allocation: calls `_add_to_base_stat(stat, -1.0)` on Player, increments `pending_stat_points`
- Panel tracks allocations made during this session as a local dict for undo support
- `Confirm` button enabled only when `pending_stat_points == 0`
- On confirm → emits `level_up_complete`

### gui.gd Relay

```gdscript
signal level_up_complete

func show_level_up(level: int, stat_points: int, stats: Dictionary) -> void
func hide_level_up() -> void

func _on_level_up_panel_complete() -> void
    # hides LevelUpPanel, emits level_up_complete
```

---

## CharacterCreationPanel

Shown when the player presses Start on MainMenu. Replaced the direct `start_requested` flow.

```
CharacterCreation   Control             scripts/character_creation.gd
├── Background      ColorRect           dim overlay
└── PanelContainer  PanelContainer      centered card
    └── VBoxContainer
        ├── TitleLabel          Label   "Choose Your Class"
        ├── NameInput           LineEdit
        ├── ClassList           VBoxContainer   rows built at runtime, one per PlayerClassData
        │   └── [ClassButton per class — shows name + short description]
        ├── ClassDescription    Label   full description of selected class, autowrap on
        ├── ClassStatsLabel     Label   starting stats and growth rates, autowrap on
        └── ContinueButton      Button  disabled until a class is selected and name entered
```

**Rendering notes:** `custom_minimum_size` + `size_flags_vertical = 3` on ClassList (same fix as ShopPanel). Store direct references to class row buttons.

### gui.gd Relay

```gdscript
signal character_created(player_name: String, class_data: PlayerClassData)

func show_character_creation() -> void
func hide_character_creation() -> void
```

`_on_start_button_pressed()` in `gui.gd` calls `show_character_creation()`. CharacterCreation panel's `Continue` button fires `character_created`. `gui.gd` relays it.

---

## GameOverPanel

**Date:** 2026-04-17

> **Status: Planned — not yet implemented.**

Shown when the player dies. Fullscreen overlay, single action.

```
GameOverPanel           Control             scripts/game_over_panel.gd
                                            visible=false; anchors_preset=15
├── Background          ColorRect           full rect; color=(0.1, 0, 0, 0.7)
└── PanelContainer      PanelContainer      anchors_preset=8; -220,-120 / 220,120
    └── VBoxContainer   VBoxContainer       separation=16
        ├── TitleLabel          Label       "You Died"; font_size=48
        ├── DescriptionLabel    Label       "Your crawl ends here."; font_size=20; autowrap_mode=3
        └── MainMenuButton      Button      "Return to Main Menu"; font_size=20
```

| Signal | Emitted when |
|---|---|
| `main_menu_requested` | `MainMenuButton.pressed` |

`gui.show_game_over()` hides combat HUD, dialogue, skill check, rest, shop, level-up, and world map. PlayerHUD stays visible (0 HP is meaningful feedback). `main_menu_requested` feeds `gui.quit_to_main_requested` → `game.quit_to_main()`.

### gui.gd Relay

```gdscript
func show_game_over() -> void
func hide_game_over() -> void
```

---

## VictoryPanel

**Date:** 2026-04-17

> **Status: Planned — not yet implemented.**

Shown when a `BossEvent` is defeated. Same shape as `GameOverPanel`.

```
VictoryPanel            Control             scripts/victory_panel.gd
                                            visible=false; anchors_preset=15
├── Background          ColorRect           full rect; color=(0.05, 0.05, 0.15, 0.7)
└── PanelContainer      PanelContainer      anchors_preset=8; -240,-140 / 240,140
    └── VBoxContainer   VBoxContainer       separation=16
        ├── TitleLabel          Label       "Victory"; font_size=48
        ├── DescriptionLabel    Label       "The depths are quiet. For now."; font_size=20; autowrap_mode=3
        └── MainMenuButton      Button      "Return to Main Menu"; font_size=20
```

| Signal | Emitted when |
|---|---|
| `main_menu_requested` | `MainMenuButton.pressed` |

If `player.pending_stat_points > 0`, `show_level_up()` is called first; `_on_level_up_complete()` checks `state == VICTORY` and routes to `show_victory()` instead of `_finish_event()`. World map is NOT re-shown — `_on_dungeon_complete()` is not called.

### gui.gd Relay

```gdscript
func show_victory() -> void
func hide_victory() -> void
```

Both `GameOverPanel.main_menu_requested` and `VictoryPanel.main_menu_requested` feed the unified `gui.quit_to_main_requested` relay — one destination, `game.quit_to_main()`.

---

## `gui.gd` Full API

```gdscript
# --- Navigation ---
func show_main_menu() -> void
func start_game() -> void
func handle_esc() -> void
func return_to_main_menu() -> void

# --- Character Creation ---
func show_character_creation() -> void
func hide_character_creation() -> void

# --- World Map ---
func show_world_map() -> void
func hide_world_map() -> void
func world_map_on_dungeon_complete(completed_node: WorldMapNode) -> void

# --- Player HUD ---
func update_player_health(current: float, maximum: float) -> void
func update_player_gold(new_total: int) -> void
func update_player_xp(new_total: int) -> void

# --- Combat HUD ---
func show_combat_hud() -> void
func hide_combat_hud() -> void
func add_enemy_health_bar(enemy: Enemy) -> void
func remove_enemy_health_bar(enemy: Enemy) -> void
func set_player_turn(is_player_turn: bool) -> void
func log_message(text: String) -> void

# --- Consumables ---
signal consumable_use_requested(index: int)
func set_consumables_enabled(enabled: bool) -> void   # flips ConsumableBelt.set_can_use
func setup_consumable_belt(inventory: Inventory) -> void   # called from game.gd on set_player

# --- Inventory lock (bag sealed during dungeons) ---
func set_dungeon_locked(locked: bool) -> void   # disables all equip/unequip/swap in InventoryPanel

# --- Dialogue ---
func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void

# --- Skill Check ---
func show_skill_check(stat_name: String, label: String, stat_value: float) -> void

# --- Shop Panel ---
func show_shop(shop_name: String, stock: Array[EquipmentData], bag: Array[EquipmentData], gold: int, buy_mult: float, sell_mult: float, bag_full: bool) -> void
func hide_shop() -> void
func refresh_shop_stock(stock: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_bag(bag: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_gold(gold: int) -> void
func show_shop_status(msg: String) -> void

# --- Level Up ---
func show_level_up(level: int, stat_points: int, stats: Dictionary) -> void
func hide_level_up() -> void

# --- Game End (planned) ---
func show_game_over() -> void
func hide_game_over() -> void
func show_victory() -> void
func hide_victory() -> void
```

---

## Signal Connections

All connections wired in `game.gd`. GUI emits nothing outbound except through its relay signals below.

| Source | Signal | Wired to | Where connected |
|---|---|---|---|
| `player` | `damaged(amount)` | `gui.update_player_health()` | `game.gd: set_player()` |
| `player` | `gold_changed` | `gui.update_player_gold()` | `game.gd: set_player()` |
| `player` | `experience_changed` | `gui.update_player_xp()` | `game.gd: set_player()` |
| `enemy` (per instance) | `damaged` | update health bar | `game.gd: start_event()` |
| `enemy` (per instance) | `died` | `gui.remove_enemy_health_bar()` | `game.gd: start_event()` |
| `WorldMap` | `node_selected(node)` | `game.gd: _on_world_node_selected()` | `gui.gd: _ready()` → relayed |
| `DialoguePanel` | `dialogue_complete` | `game.gd: _on_gui_dialogue_complete()` | `gui.gd: _ready()` → relayed |
| `SkillCheckPanel` | `skill_check_complete(success)` | `game.gd: _on_gui_skill_check_complete()` | `gui.gd: _ready()` → relayed |
| `ShopPanel` | `buy_requested(item)` | `game.gd: _on_gui_shop_buy_requested()` | `gui.gd: _ready()` → relayed |
| `ShopPanel` | `sell_requested(item)` | `game.gd: _on_gui_shop_sell_requested()` | `gui.gd: _ready()` → relayed |
| `ShopPanel` | `leave_requested` | `game.gd: _on_gui_shop_leave_requested()` | `gui.gd: _ready()` → relayed |
| `LevelUpPanel` | `level_up_complete` | `game.gd: _on_level_up_complete()` | `gui.gd: _ready()` → relayed |
| `CharacterCreation` | `character_created(name, class_data)` | `game.gd: _on_character_created()` | `gui.gd: _ready()` → relayed |
| `ConsumableBelt` | `consumable_use_requested(index)` | `game.gd: _on_consumable_use_requested()` | `gui.gd: _ready()` → relayed |
| `Inventory` | `consumable_belt_changed` | `ConsumableBelt._on_consumable_belt_changed()` | `gui.setup_consumable_belt()` (direct, no relay) |
| `Inventory` | `belt_size_changed` | `ConsumableBelt._on_belt_size_changed()` | `gui.setup_consumable_belt()` (direct, no relay) |
| `MainMenu/StartButton` | `pressed` | show character creation | `game.gd: _ready()` |
| `PauseMenu/QuitToMainButton` | `pressed` | `game.gd: quit_to_main()` | `game.gd: _ready()` |
| `GameOverPanel` *(planned)* | `main_menu_requested` | `gui.quit_to_main_requested` → `game.gd: quit_to_main()` | `gui.gd: _ready()` |
| `VictoryPanel` *(planned)* | `main_menu_requested` | `gui.quit_to_main_requested` → `game.gd: quit_to_main()` | `gui.gd: _ready()` |
| `BossEvent` *(planned)* | `boss_defeated` | `game.gd: _on_boss_defeated()` | `game.gd: start_event()` (one-shot) |
| `Player` | `died` | `game.gd: _on_player_died()` | `game.gd: set_player()` |

**Not wired to GUI directly:**
- `player.attack` — routed through `CombatEvent`
- `CombatEvent.player_attacked` — `game.gd` applies damage; GUI sees result via `player.damaged`
- `player.turn_ended` / `CombatEvent.enemy_turns_complete` — `game.gd` calls `gui.set_player_turn()` at each transition
- `player.consumable_used` / `player.buff_applied` / `player.buff_expired` — `game.gd` observes and pushes to `gui.log_message()`; the belt UI itself rebuilds from `Inventory` signals, not from `Player`

---

## InventoryPanel — Consumable Belt Row

`InventoryPanel` is not documented in depth here (it pre-dates this doc). The consumables system adds one visual addition, and the dungeon-lock rule changes how the whole panel behaves mid-dungeon.

- A horizontal row of **belt-slot buttons** beneath the existing Rings row. Each button shows the equipped `ConsumableData` icon or an empty placeholder. Click to unequip (returns the item to the bag).
- Bag entries with `is_consumable == true` route through `Inventory.equip_consumable(data)` (auto-fill) or `Inventory.equip_consumable_at(index, data)` (when dragged onto a specific belt slot) — the same branching `is_ring` uses today.
- All belt-row and bag-routing buttons respect the existing `set_can_equip()` gate, so they are disabled during combat turns for free.

### Dungeon-locked behavior

While the player is inside a dungeon, **the entire InventoryPanel is read-only**. `gui.set_dungeon_locked(true)` disables every equip/unequip/swap interaction:

| Control | Dungeon-unlocked | Dungeon-locked |
|---|---|---|
| Equipped-slot click (weapon / armor / ring / belt) | unequip to bag | disabled |
| Bag-item click on equipment | route to `equip*` | disabled |
| Bag-item click on consumable | route to `equip_consumable*` | disabled |
| Drag from bag → equipped/ring/belt slot | perform swap | drag rejected |
| View item details | full details | full details (unchanged) |

Viewing stats, reading item descriptions, and browsing the bag all remain available — the panel becomes an info surface rather than an edit surface. A status line or banner ("Bag sealed — the bad air keeps you moving") surfaces the rule so the player understands why controls are disabled rather than assuming a bug.

Implementation note: `set_dungeon_locked()` should be a **stronger** gate than `set_can_equip()`. When locked, ignore `set_can_equip()` entirely — the combat-turn gate is a finer-grained variant that only matters in the unlocked (safe-node) context.

---

## Pickup Choice (during dungeon)

**Status:** Planned — UI details deferred until the loot system is designed.

When the player picks up an item mid-dungeon, the InventoryPanel cannot be used to equip it (the panel is locked). Instead, a dedicated pickup prompt surfaces the choices in-flow. The prompt is driven by `game.gd` and rendered by a new `PickupChoicePanel` (TBD). The exact choice set depends on item type:

**Consumable pickup** (four possible choices, gated by availability):
- **Equip to slot N** — shown once per empty belt slot.
- **Swap with slot N** — shown once per occupied belt slot. Player then chooses *where the displaced item goes*: bag or drop.
- **Put in bag** — disabled if bag is full.
- **Drop** — always available.

**Equipment pickup** (two choices during dungeon):
- **Put in bag** — disabled if bag is full.
- **Drop** — always available.

The "Equip" choice for non-consumable equipment is simply not offered inside a dungeon. Outside a dungeon (world map, rest, shop contexts), standard InventoryPanel flows handle equip instead.

Wiring signal (planned): `PickupChoicePanel.choice_made(choice, target_index, displaced_action)` → `game.gd._on_consumable_pickup()` / `_on_equipment_pickup()`. See `journal/detailed/character.md § Consumable Pickup Flow` for the handler contract.

---

## Open Questions

- **ActionMenu shape** — Single attack button now. May grow to vertical list (Attack / Spell / Item / Flee) or grid.
- **Enemy health bar layout** — Stacked vertically in `EnemyHUD` or positioned near each enemy sprite?
- **Enemy health bar identity** — Show enemy names? Distinguish two skeletons?
- **CombatLog persistence** — Clear on each new combat, or accumulate across the run?
- **PauseMenu contents** — Resume and quit are the minimum. Settings, controls, save/load may follow.
- **ConsumableBelt scope** — Belt buttons live inside `CombatHUD` today, so they're only visible while fighting. Since usage is permitted during `NO_TURN` and `DIALOGUE`, a later pass may surface the belt outside combat (world-map overlay or persistent HUD element). MVP keeps it combat-only.
- **PickupChoicePanel shape** — Listed inline in `game.gd._on_consumable_pickup()` flow, but the panel scene and layout are not yet designed. Open questions: modal vs inline, single-screen with all choices vs two-step (choice → displaced-item destination for swaps), how the displaced-item choice is surfaced visually (two extra buttons or a secondary prompt).
- **Dungeon-lock feedback** — InventoryPanel needs to communicate *why* controls are disabled when locked ("Bag sealed — the bad air keeps you moving", or a padlock icon, or the whole panel shaded). MVP probably a single status label; revisit when lore copy is being written.
- **Equipment pickup UX outside dungeons** — When the player is on the world map / rest / shop and picks up an item, the pickup flow has more options than the two-choice dungeon prompt. Need to decide whether to route those to the same `PickupChoicePanel` with an expanded choice set, or let the InventoryPanel be the primary handling path and skip the pickup prompt entirely in safe contexts.
