# GUI Implementation Design

**Date:** 2026-03-13 (consolidated 2026-04-18; audited against code 2026-07-09)
**Status:** Implemented. All panels below exist and are wired (GameOverPanel and VictoryPanel included). RestPanel, ShrinePanel, and TownPanel were added after the original consolidation.

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
│   ├── StartButton  (Button)              # new run (confirms first if a save exists)
│   ├── ContinueButton  (Button)           # loads save; disabled when none exists
│   └── QuitButton  (Button)
│
├── NewRunConfirmDialog  (ConfirmationDialog)   # "overwrite existing save?" gate on StartButton
│
├── PlayerHUD  (Control)                   # persistent — visible during all non-menu states
│   ├── PlayerHealthLabel  (Label)         # "80/100"
│   ├── PlayerHealthBar  (ProgressBar)
│   ├── PlayerArmorLabel  (Label)          # "Armor 12/12" — hidden when max armor is 0
│   ├── PlayerArmorBar  (ProgressBar)
│   ├── PlayerGoldLabel  (Label)           # "Gold: 0"
│   ├── PlayerXPLabel  (Label)             # "XP: 0"
│   ├── InventoryButton  (Button)          # toggles InventoryPanel
│   ├── PlayerManaBar  (ProgressBar)       # created at runtime in gui.gd _ready()
│   ├── PlayerManaLabel  (Label)           # created at runtime
│   └── PlayerStatusLabel  (Label)         # created at runtime; active-status readout + transient messages
│
├── DialoguePanel  (Control)               [dialogue_panel.gd] hidden by default
├── SkillCheckPanel  (Control)             [skill_check_panel.gd] hidden by default
├── RestPanel  (Control)                   [rest_panel.gd] hidden by default
├── ShrinePanel  (Control)                 [shrine_panel.gd] hidden by default — patron-saint ascension
├── TownPanel  (Control)                   [town_panel.gd] hidden by default — end-of-act hub
├── CharacterCreationPanel  (Control)      [character_creation_panel.gd] hidden by default
├── ShopPanel  (Control)                   [shop_panel.gd] hidden by default
│
├── CombatHUD  (Control)                   # shown during any event via show_event_hud()
│   ├── EnemyHUD  (Control)                # health_bar.tscn instance per living enemy
│   ├── ActionMenu  (Control)
│   │   ├── MainhandActions  (HBoxContainer)   # one button per mainhand attack/spell
│   │   ├── OffhandActions   (HBoxContainer)   # one button per offhand attack/spell; hidden when empty
│   │   └── EndTurnButton     (Button)         # explicit turn end
│   └── CombatLog  (RichTextLabel)         # append-only; cleared on show_event_hud()
│
├── ConsumableBelt  (HFlowContainer)       [consumable_belt_ui.gd]  # GUI-level child, NOT under CombatHUD
│   └── ConsumableButton  (Button)         # template button, cloned per belt slot
│
├── WorldMap  (WorldMap)                   [world_map.gd] hidden by default; swapped per act via swap_world_map()
├── InventoryPanel  (Control)              [inventory_panel.gd] hidden by default; toggled by InventoryButton
├── LevelUpPanel  (Control)                [level_up_panel.gd] hidden by default
├── PauseMenu  (Control)
│   ├── Overlay  (ColorRect)
│   ├── ResumeButton  (Button)
│   └── QuitToMainButton  (Button)
│
├── GameOverPanel  (Control)               [game_over_panel.gd] hidden by default
└── VictoryPanel  (Control)                [victory_panel.gd] hidden by default
```

**Notes:**
- `PlayerHUD` is a sibling of `CombatHUD`, not a child. It persists across world map, combat, dialogue, skill check — only hidden on the main menu.
- **Mana bar/label and the status label are created in code** (`gui.gd._ready()`), not authored in `game.tscn`. The armor bar/label *are* in the scene but `gui.gd` fetches them with `get_node_or_null` so an un-updated scene still runs.
- `EnemyHUD` children are spawned/freed at runtime — one `health_bar.tscn` instance per living enemy; each carries its own armor readout and a runtime status `Label`.
- `CombatLog` lives inside `CombatHUD` and clears on `show_event_hud()` (start of every event).
- `ConsumableBelt` is a **direct child of GUI**, not of `CombatHUD` — so it can be shown both during combat and while the InventoryPanel is open (management mode). See the ConsumableBelt section.
- **Action bar is built from the scene when present**, but `gui.gd._ensure_action_nodes()` synthesizes `MainhandActions`/`OffhandActions`/`EndTurnButton` as a fallback if the scene lacks them.

---

## MainMenu

Shown at game start. Hidden when the game begins.

| Node | Type | Role |
|---|---|---|
| `Title` | Label | Game title |
| `StartButton` | Button | Starts a new run |
| `ContinueButton` | Button | Loads the save (`continue_requested`); `disabled` when `SaveManager.has_save()` is false |
| `QuitButton` | Button | `get_tree().quit()` — wired in `gui.gd` directly |

`StartButton.pressed` → `_on_start_button_pressed()`: if a save exists it pops `NewRunConfirmDialog` (whose `confirmed` clears the save and then shows character creation); otherwise it calls `show_character_creation()` directly. It does **not** emit `start_requested` — that signal was removed.

`ContinueButton.pressed` → `_on_continue_button_pressed()` emits `continue_requested`, which `game.gd` handles by loading the save.

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
| `PlayerHealthLabel` | Label | "80/100" |
| `PlayerHealthBar` | ProgressBar | `value` / `max_value` via `update_player_health()` |
| `PlayerArmorLabel` | Label | "Armor 12/12"; hidden when max armor ≤ 0 |
| `PlayerArmorBar` | ProgressBar | per-round armor buffer via `update_player_armor()`; hidden for no-DEF builds |
| `PlayerGoldLabel` | Label | "Gold: 0" |
| `PlayerXPLabel` | Label | "XP: 0" |
| `InventoryButton` | Button | toggles InventoryPanel (`toggle_inventory`) |
| `PlayerManaBar` | ProgressBar | **runtime-created**; "MP" buffer via `update_player_mana()` |
| `PlayerManaLabel` | Label | **runtime-created**; "MP 40/40" |
| `PlayerStatusLabel` | Label | **runtime-created**; active-status readout (`refresh_player_statuses`) and transient messages (`show_status`, e.g. "Not enough mana") |

### CombatHUD

`CombatHUD` is shown by `show_event_hud()` for **every** event type (combat, dialogue, skill check, rest…), not only combat — it's the general in-event HUD. The action bar simply has no buttons outside combat.

| Node | Type | Role |
|---|---|---|
| `EnemyHUD` | Control | Container; `health_bar.tscn` instance per living enemy (health + armor + runtime status `Label`) |
| `ActionMenu` | Control | Container for the dual-hand action bar |
| `MainhandActions` | HBoxContainer | One button per mainhand attack/spell; rebuilt by `rebuild_action_buttons()` |
| `OffhandActions` | HBoxContainer | One button per offhand attack/spell; hidden entirely when the hand offers nothing |
| `EndTurnButton` | Button | Explicit turn end (`end_turn_requested`); an action never ends the turn on its own |
| `CombatLog` | RichTextLabel | Append-only log; cleared on `show_event_hud()` |

#### Dual-hand action bar

Combat is two independently-gated hands (see the Combat UI checklist below and `player.gd`). `game.gd` calls `rebuild_action_buttons(mainhand_attacks, mainhand_spells, offhand_attacks, offhand_spells, current_mana, mainhand_used, offhand_used, offhand_locked)` whenever a hand's repertoire or spent-state changes. Each hand row is repopulated with one `Button` per attack/spell; spell buttons show `"Name (cost)"` and store `hand` / `action` / `cost` as metadata.

- Pressing a button emits `attack_requested(hand: int, action_name: String)`.
- `set_targeting_action(hand, action_name)` highlights the active button and drops focus on the others while the player picks a target; `""` clears targeting.
- `_apply_action_states()` recomputes every button's `disabled` from the gates: player's turn, weapons not sheathed (`set_sheathed`), that hand not spent, and — for spells — affordable against `current_mana`.

#### ConsumableBelt

```
ConsumableBelt      HFlowContainer      scripts/consumable_belt_ui.gd  (class ConsumableBeltUI)
├── ConsumableButton   Button           template button (hidden), cloned per slot
└── [cloned Button nodes at runtime, one per belt slot]
```

`ConsumableBelt` is a **direct child of GUI**, not of `CombatHUD`. Built at runtime from `Inventory.belt_size`; subscribes to the inventory's belt-change and belt-size signals and rebuilds its row as needed.

Each button:
- Indexed by belt position (stored as button metadata).
- Shows the equipped `ConsumableData` icon; empty slots show a placeholder and are disabled.
- `pressed` → emits `consumable_pressed(index: int)` upward.

**Management mode.** The belt has two modes, toggled by `set_management_mode(bool)`:
- **Use mode** (default, in combat) — `gui.gd` routes `consumable_pressed` to `consumable_use_requested(index)` → `game.gd` uses the consumable.
- **Management mode** (while InventoryPanel is open) — `gui.gd` routes the same press to `_inventory_panel.unequip_belt_slot(index)` instead.

`gui.toggle_inventory()` flips the belt into management mode and shows it; closing the inventory outside combat hides it again.

```gdscript
signal consumable_pressed(index: int)

func setup(inventory: Inventory) -> void
func set_can_use(value: bool) -> void
func set_management_mode(value: bool) -> void
func is_management_mode() -> bool
```

`ConsumableBelt` receives the `Inventory` reference at `setup()` (from `gui.setup_consumable_belt()`, called in `game.gd` when the player is set) — it does not read `Player` or `game.gd`.

**Enable gate:** `game.gd` flips `gui.set_consumables_enabled(enabled)` (→ `set_can_use`) by state — enabled during player turn / `NO_TURN` / dialogue, disabled otherwise. This is independent of the management-mode toggle.

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
signal dialogue_complete(terminal_node_id: String)

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
signal dialogue_complete(terminal_node_id: String)

func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void
    # calls _dialogue_panel.load_dialogue(data, consequences), shows the panel

func _on_dialogue_complete(terminal_node_id: String) -> void
    # hides DialoguePanel, re-emits dialogue_complete(terminal_node_id)
```

The panel's `dialogue_complete` is connected to `gui._on_dialogue_complete` once in `gui.gd._ready()` (not one-shot). `game.gd` connects `_gui.dialogue_complete` → `_on_gui_dialogue_complete`. The terminal node id is carried through so `game.gd` can branch on which ending the player reached. The panel is an implementation detail — `game.gd` never references it directly.

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

func setup(stat_name: String, label: String, stat_value: float, threshold: float) -> void:
    # stat_value is displayed only; the roll is compared against threshold
    # Reset: re-enable RollButton, hide RollResultLabel and ContinueButton

func _on_roll_button_pressed() -> void:
    var roll: int = randi_range(1, 100)
    var success: bool = roll <= int(_threshold)
    # Show result text, disable RollButton, show ContinueButton

func _on_continue_pressed() -> void:
    skill_check_complete.emit(_success)
```

`setup()` fully resets panel state — safe to reuse across multiple skill check events per session.

### gui.gd Relay

```gdscript
signal skill_check_complete(success: bool)

func show_skill_check(stat_name: String, label: String, stat_value: float, threshold: float) -> void
    # calls _skill_check_panel.setup(...), shows panel

func _on_skill_check_complete(success: bool) -> void
    # hides SkillCheckPanel, emits skill_check_complete(success)
```

`game.gd` supplies the threshold when it calls `show_skill_check(...)` (`gui.show_skill_check(Enums.Stat.keys()[stat], label, stat_value, threshold)`).

---

## RestPanel

Node `RestPanel`, script `rest_panel.gd`. Shown for a rest event; offers to heal.

```gdscript
signal rest_requested     # player chose to rest — game.gd applies the heal
signal rest_complete      # player leaves the rest node

func setup(heal_amount: float) -> void
```

`gui.show_rest_panel(heal_amount)` / `hide_rest_panel()`. Both signals relay through `gui.gd` under the same names to `game.gd` (`_on_gui_rest_requested` / `_on_gui_rest_complete`).

---

## ShrinePanel

Node `ShrinePanel`, script `shrine_panel.gd`. Patron-saint ascension hub (spend gold to advance the active saint to its next tier). Shown from the end-of-act flow.

```gdscript
signal ascend_requested    # relayed as gui.shrine_ascend_requested
signal leave_requested     # relayed as gui.shrine_leave_requested

func setup(saint_name: String, has_next: bool, next_tier_name: String,
           next_tier_desc: String, next_stat_mods: Dictionary,
           cost: int, player_gold: int) -> void
```

`gui.show_shrine_panel(saint_name, has_next, next_tier_name, next_tier_desc, next_stat_mods, cost, player_gold)` / `hide_shrine_panel()`. `game.gd` reads the next tier off `player.get_next_tier()` and passes cost/gold in; when the player has no further tier it calls `setup(..., has_next=false, ...)`.

---

## TownPanel

Node `TownPanel`, script `town_panel.gd`. End-of-act hub with two exits.

```gdscript
signal temple_requested    # relayed as gui.town_temple_requested → opens ShrinePanel
signal travel_requested    # relayed as gui.town_travel_requested → advances the act
```

`gui.show_town_panel()` / `hide_town_panel()`. The temple button routes to the ShrinePanel; travel advances to the next act (which triggers `swap_world_map`).

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

func show_level_up(player: Player) -> void   # panel reads pending points/stats off the player
func hide_level_up() -> void

func _on_level_up_confirmed() -> void
    # hides LevelUpPanel, emits level_up_complete
```

The panel is handed the `Player` directly (`_level_up_panel.setup(player)`) and reads `pending_stat_points` / current stats off it, rather than receiving them as loose args. Its internal `level_up_confirmed` signal is relayed by `gui.gd` as `level_up_complete`.

---

## CharacterCreationPanel

Node `CharacterCreationPanel`, script `character_creation_panel.gd`. Shown when the player starts a new run (from `StartButton`, after the `NewRunConfirmDialog` gate if a save exists). Replaced the direct `start_requested` flow.

It is a **hand-built multi-step wizard**, not a single class picker: **Class → Background → Patron Saint → Confirm** (see [[CLAUDE.md]] and the character-creation data resources). Each step selects one resource — `PlayerClassData`, then `BackgroundData` ("who you were"), then `PatronSaintData` ("what watches over you") — with description/stat panels per step. The panel's node tree is intentionally not mirrored here in full; it is built and rewired frequently. `gui.gd` treats it as a black box behind `show_character_creation()` and the confirm signal.

**Rendering note:** list containers use `custom_minimum_size` + `size_flags_vertical = 3` (same fix as ShopPanel); runtime row buttons are stored by direct reference.

### gui.gd Relay

The panel emits `character_confirmed(player_name, class_data, background, patron)` on Confirm; `gui.gd` relays it as `character_created` with the same four args.

```gdscript
signal character_created(player_name: String, class_data: PlayerClassData, background: BackgroundData, patron: PatronSaintData)

func show_character_creation() -> void      # hides MainMenu, resets and shows the wizard
func _on_character_confirmed(p_name, class_data, background, patron) -> void
    # hides the panel, re-emits character_created(...)
```

`game.gd` connects `_gui.character_created` → `_on_character_created`, which builds the player from all four layers.

---

## GameOverPanel

**Date:** 2026-04-17 (implemented since)

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

**Date:** 2026-04-17 (implemented since)

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
# --- Outbound signals (all connected in game.gd unless noted) ---
signal character_created(player_name: String, class_data: PlayerClassData, background: BackgroundData, patron: PatronSaintData)
signal level_up_complete
signal quit_to_main_requested
signal attack_requested(hand: int, attack_name: String)
signal end_turn_requested
signal dialogue_complete(terminal_node_id: String)
signal skill_check_complete(success: bool)
signal rest_requested
signal rest_complete
signal node_selected(node: WorldMapNode)
signal shop_buy_requested(item: EquipmentData)
signal shop_sell_requested(item: EquipmentData)
signal shop_leave_requested
signal shrine_ascend_requested
signal shrine_leave_requested
signal town_temple_requested
signal town_travel_requested
signal consumable_use_requested(index: int)
signal continue_requested

# --- Navigation ---
func show_main_menu() -> void
func start_game() -> void
func handle_esc() -> void            # toggles PauseMenu
func return_to_main_menu() -> void

# --- Character Creation ---
func show_character_creation() -> void

# --- Player HUD ---
func update_player_health(current: float, maximum: float) -> void
func update_player_armor(current: float, maximum: float) -> void   # hidden when maximum <= 0
func update_player_mana(current: float, maximum: float) -> void
func update_player_stats(stats: Dictionary) -> void
func update_player_gold(new_total: int) -> void
func update_player_xp(new_total: int) -> void
func show_status(message: String) -> void                          # PlayerStatusLabel transient text
func refresh_player_statuses(statuses: Array) -> void

# --- Event / Combat HUD ---
func show_event_hud() -> void        # shows CombatHUD + belt, clears CombatLog, sheathes
func hide_event_hud() -> void        # frees enemy bars, hides CombatHUD (+ belt if inventory closed)
func set_sheathed(sheathed: bool) -> void
func set_player_turn(is_player_turn: bool) -> void
func log_message(text: String) -> void
func rebuild_action_buttons(mainhand_attacks, mainhand_spells, offhand_attacks, offhand_spells, current_mana: float, mainhand_used: bool, offhand_used: bool, offhand_locked: bool) -> void
func set_targeting_action(hand: int, action_name: String) -> void

# --- Enemy bars ---
func add_enemy_health_bar(enemy: Enemy) -> void
func remove_enemy_health_bar(enemy: Enemy) -> void
func update_enemy_health_bar(enemy: Enemy, current: float) -> void
func update_enemy_armor(enemy: Enemy, current: float, maximum: float) -> void
func add_enemy_status_label(enemy: Enemy) -> void
func refresh_enemy_statuses(enemy: Enemy, statuses: Array) -> void

# --- Inventory ---
func setup_inventory(inventory: Inventory) -> void
func setup_spell_prep(player: Player) -> void
func toggle_inventory(can_equip: bool = true) -> void
func is_inventory_open() -> bool
func set_dungeon_locked(locked: bool) -> void   # disables all equip/unequip/swap in InventoryPanel

# --- Consumables ---
func setup_consumable_belt(inventory: Inventory) -> void
func set_consumables_enabled(enabled: bool) -> void

# --- World Map ---
func get_world_map() -> WorldMap
func swap_world_map(scene: PackedScene) -> void   # per-act; keeps the "WorldMap" node name
func show_world_map() -> void
func hide_world_map() -> void
func world_map_on_dungeon_complete(completed_node: WorldMapNode) -> void

# --- Dialogue / Skill Check ---
func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void
func show_skill_check(stat_name: String, label: String, stat_value: float, threshold: float) -> void

# --- Rest / Shrine / Town ---
func show_rest_panel(heal_amount: float) -> void
func hide_rest_panel() -> void
func show_shrine_panel(saint_name: String, has_next: bool, next_tier_name: String, next_tier_desc: String, next_stat_mods: Dictionary, cost: int, player_gold: int) -> void
func hide_shrine_panel() -> void
func show_town_panel() -> void
func hide_town_panel() -> void

# --- Shop Panel ---
func show_shop(shop_name: String, stock: Array[EquipmentData], bag: Array[EquipmentData], gold: int, buy_mult: float, sell_mult: float, bag_full: bool) -> void
func hide_shop() -> void
func refresh_shop_stock(stock: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_bag(bag: Array[EquipmentData], bag_full: bool) -> void
func refresh_shop_gold(gold: int) -> void
func show_shop_status(msg: String) -> void

# --- Level Up ---
func show_level_up(player: Player) -> void
func hide_level_up() -> void

# --- Game End ---
func show_game_over() -> void
func hide_game_over() -> void
func show_victory() -> void
func hide_victory() -> void
```

---

## Signal Connections

Two layers of wiring:
- **Panel/WorldMap → `gui.gd`** relays are connected inside `gui.gd._ready()`. Each inbound panel signal is re-emitted as a `gui.gd` signal (or handled internally).
- **`gui.gd` outbound + Player/Enemy → `game.gd`** handlers are connected in `game.gd` (`_ready()` for GUI, `set_player()` for the player, per-enemy in the combat-add helper).

The GUI emits nothing outbound except through its relay signals; `game.gd` never references panels directly.

### `gui.gd` outbound → `game.gd` (wired in `game.gd._ready()`)

| gui.gd signal | game.gd handler |
|---|---|
| `character_created(name, class, background, patron)` | `_on_character_created()` |
| `continue_requested` | `_on_continue_requested()` |
| `level_up_complete` | `_on_level_up_complete()` |
| `quit_to_main_requested` | `quit_to_main()` |
| `attack_requested(hand, action_name)` | `_on_action_requested()` |
| `end_turn_requested` | `_on_end_turn_requested()` |
| `consumable_use_requested(index)` | `_on_consumable_use_requested()` |
| `dialogue_complete(terminal_node_id)` | `_on_gui_dialogue_complete()` |
| `skill_check_complete(success)` | `_on_gui_skill_check_complete()` |
| `rest_requested` / `rest_complete` | `_on_gui_rest_requested()` / `_on_gui_rest_complete()` |
| `node_selected(node)` | `_on_world_node_selected()` |
| `shop_buy_requested` / `shop_sell_requested` / `shop_leave_requested` | `_on_gui_shop_*()` |
| `shrine_ascend_requested` / `shrine_leave_requested` | `_on_gui_shrine_*()` |
| `town_temple_requested` / `town_travel_requested` | `_on_gui_town_*()` |

### Player → `game.gd` → GUI (wired in `game.gd.set_player()`)

| Player signal | Drives |
|---|---|
| `damaged` / `healed` | `gui.update_player_health()` |
| `armor_changed` | `gui.update_player_armor()` |
| `armor_absorbed` | `gui.log_message("Your armor absorbs …")` |
| `mana_spent` / `mana_restored` | `gui.update_player_mana()` |
| `dodged` | `gui.log_message("You dodged…")` |
| `stats_changed` | `gui.update_player_stats()` (+ health) |
| `gold_changed` / `experience_changed` | `gui.update_player_gold()` / `update_player_xp()` |
| `status_applied` / `status_ticked` / `status_expired` | `gui.refresh_player_statuses()` |
| `hand_actions_changed` | `gui.rebuild_action_buttons(...)` |
| `action_resolved` / `turn_ended` | turn/action-bar bookkeeping in `game.gd` |
| `died` | `_on_player_died()` → `gui.show_game_over()` |

### Enemy (per instance) → `game.gd` → GUI (wired when the enemy is added to combat)

| Enemy signal | Drives |
|---|---|
| `damaged` | `gui.update_enemy_health_bar()` |
| `armor_changed` | `gui.update_enemy_armor()` |
| `status_applied` / `ticked` / `expired` | `gui.refresh_enemy_statuses()` |
| `died` | `gui.remove_enemy_health_bar()` |
| `attack(damage)` | `game.gd` applies damage to the player |

### Panel / WorldMap → `gui.gd` (wired in `gui.gd._ready()`)

| Source | Signal | Relayed as / handled by |
|---|---|---|
| `MainMenu/StartButton` | `pressed` | `_on_start_button_pressed()` (save-gate → creation) |
| `MainMenu/ContinueButton` | `pressed` | `continue_requested` |
| `MainMenu/QuitButton` | `pressed` | `get_tree().quit()` |
| `NewRunConfirmDialog` | `confirmed` | clears save, shows creation |
| `PauseMenu/ResumeButton` | `pressed` | `handle_esc()` |
| `PauseMenu/QuitToMainButton` | `pressed` | `quit_to_main_requested` |
| `CharacterCreationPanel` | `character_confirmed(...)` | `character_created(...)` |
| `DialoguePanel` | `dialogue_complete(id)` | `dialogue_complete(id)` |
| `SkillCheckPanel` | `skill_check_complete(ok)` | `skill_check_complete(ok)` |
| `RestPanel` | `rest_requested` / `rest_complete` | same names |
| `ShrinePanel` | `ascend_requested` / `leave_requested` | `shrine_ascend_requested` / `shrine_leave_requested` |
| `TownPanel` | `temple_requested` / `travel_requested` | `town_temple_requested` / `town_travel_requested` |
| `ShopPanel` | `buy_requested` / `sell_requested` / `leave_requested` | `shop_*_requested` |
| `LevelUpPanel` | `level_up_confirmed` | `level_up_complete` |
| `ConsumableBelt` | `consumable_pressed(index)` | use-or-manage split (see ConsumableBelt) |
| `GameOverPanel` / `VictoryPanel` | `main_menu_requested` | `quit_to_main_requested` |
| `WorldMap` | `node_selected(node)` | `node_selected(node)` (map hidden first) |

**Direct, no relay:** `Inventory.consumable_belt_changed` / `belt_size_changed` → `ConsumableBelt` internals (wired in `gui.setup_consumable_belt()`); the belt rebuilds from `Inventory`, never from `Player`.

**Not wired to GUI directly:** `player.attack_hit` / `cast_hit` resolve in `game.gd`/`CombatEvent`; GUI sees only the resulting `damaged` / `armor_changed` / health updates.

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

Wiring signal (planned): `PickupChoicePanel.choice_made(choice, target_index, displaced_action)` → `game.gd._on_consumable_pickup()` / `_on_equipment_pickup()`. See [[detailed/character.md]] for the handler contract.

---

## Open Questions

- ~~**ActionMenu shape**~~ — Resolved: dual-hand rows (`MainhandActions` / `OffhandActions`) plus an explicit `EndTurnButton`, built by `rebuild_action_buttons()`. See the dual-hand action bar section.
- **Enemy health bar layout** — Positioned near each enemy sprite (screen-projected from `enemy.global_position + enemy_health_bar_offset`). Open: behavior when enemies overlap or crowd.
- **Enemy health bar identity** — Still open. Bars now carry an armor readout and a status `Label`, but no name/label to distinguish two identical enemies (e.g. two skeletons).
- ~~**CombatLog persistence**~~ — Resolved: cleared per event in `show_event_hud()`, not accumulated across the run.
- **PauseMenu contents** — Resume and quit are the minimum. Settings, controls, save/load may follow.
- ~~**ConsumableBelt scope**~~ — Resolved: the belt is a **GUI-level child**, shown during combat *and* while the InventoryPanel is open (management mode). It is no longer trapped inside `CombatHUD`.
- **PickupChoicePanel shape** — Listed inline in `game.gd._on_consumable_pickup()` flow, but the panel scene and layout are not yet designed. Open questions: modal vs inline, single-screen with all choices vs two-step (choice → displaced-item destination for swaps), how the displaced-item choice is surfaced visually (two extra buttons or a secondary prompt).
- **Dungeon-lock feedback** — InventoryPanel needs to communicate *why* controls are disabled when locked ("Bag sealed — the bad air keeps you moving", or a padlock icon, or the whole panel shaded). MVP probably a single status label; revisit when lore copy is being written.
- **Equipment pickup UX outside dungeons** — When the player is on the world map / rest / shop and picks up an item, the pickup flow has more options than the two-choice dungeon prompt. Need to decide whether to route those to the same `PickupChoicePanel` with an expanded choice set, or let the InventoryPanel be the primary handling path and skip the pickup prompt entirely in safe contexts.

---

## Combat UI — Information Inventory (design-sketch checklist)

**Date:** 2026-07-09
**Status:** Design sketch — pre-implementation. Enumerates everything combat must surface so a layout can be drawn against it. Grounded in the systems as they exist in `player.gd`, `enemy.gd`, `combatant.gd`, and the status/verb work of [[daily/2026-07-08]] / [[daily/2026-07-09]]. Items marked **(invisible today)** are the player-legibility gaps this pass targets.

Several existing [Open Questions](#open-questions) overlap here — ActionMenu shape (→ §2), enemy health bar layout/identity (→ §4), CombatLog persistence (→ §7).

### 1. Player vitals

- **Health** — current / max; damage-taken and heal feedback (`damaged`, `healed`).
- **Armor buffer** — *distinct from HP*, per-round, DEF-derived, refills at round start, soaks damage before HP (`armor_changed`, `armor_absorbed`). Needs its own bar/pip layer, not folded into the health bar. Show depletion mid-round.
- **Mana** — current / max; spend + restore feedback (`mana_spent`, `mana_restored`).
- **Dodge** — AGI-driven; chance *halves per successful dodge this round* (`_dodge_streak`). Dodge event (`dodged`) must read clearly; the decaying chance should be legible so a dodge build understands why later hits land. **(partly invisible today)**
- **Level / XP / Gold** — already in PlayerHUD; decide whether they stay visible or collapse during combat.

### 2. Dual-hand action model

Combat is two independently-gated hands, not one attack button.

- **Mainhand + offhand as separate action slots**, each with its own attack list and spell list.
- **Per-hand spent/unspent state** this turn (`_mainhand_used` / `_offhand_used`) — UI must show which hands remain available.
- **Two-handed weapons lock the offhand** (`is_offhand_locked`), sometimes granting `locked_offhand_attacks` — offhand slot needs distinct locked / empty-punch / has-actions appearances.
- **Action-in-flight state** (`_action_resolving`) — one action animates before the second is allowed; buttons need a disabled/pending look during resolution.
- **End Turn is explicit and separate** — never fired by an attack; its own prominent control, and the thing to press when you don't want to spend a hand.
- Offhand actions animate the offhand weapon separately (mirrored) — leave stage room for two acting sources.

### 3. Per-action information (per button)

Decide what shows on the button face vs. on hover:

- Name, and **which hand** it belongs to.
- **Spell mana cost — effective, not raw.** `compute_spell_cost()` multiplies by equipment; show the computed cost and grey out when unaffordable.
- **Target mode** — SELF vs single vs (planned) AOE/multi; shown before committing.
- **Elemental signature / martial verb** (Fire/Frost/Lightning/Poison, Bleed/Shatter/Brace). **(invisible today)**
- **Self-cost & procs** — self-damage, HP costs, proc chances (`proc_def.gd`). **(invisible today)**
- **Consumable belt** — per-slot icons, disabled when empty or state disallows (spec'd in `consumable_belt_ui`).

### 4. Enemies

- **Per-enemy health bar** (spawned per living enemy) + the same **armor buffer** the player has (`enemy.armor` / `max_armor`).
- **Identity** — the "two skeletons" problem: names or numbering.
- **Enemy statuses** — same status-row treatment as the player.
- **Move telegraph** — `peek_next_move()` exists for this; show the enemy's *upcoming* move (`EnemyMoveData`) so the player can react. Already code-supported.
- **Positioning / array order** — enemies are an ordered array and *adjacency matters* (chain lightning jumps to the array-adjacent enemy). Layout should reflect adjacency or chain effects feel random.
- **Death** — removal timing (`death_finished`) and bar clear.

### 5. Targeting

- **Target selection** — `target_indicator` exists. Click enemy, or select-action-then-target?
- **Hit preview for multi-target** — AOE and chain must show which enemies will be hit before confirming (given adjacency rules).
- **Self-targeted actions** (Brace, buffs, heals) — visually distinct from offensive ones.

### 6. Status effects (display layer)

- **Status row** per combatant — icon, **turns remaining** (`status_ticked`), stacking (`stack_policy`: STACK / REFRESH / MAX_DURATION).
- **Persistence marker** — COMBAT statuses clear at fight end; PERSISTENT (gear/background) ones don't. Distinguish so players don't expect a buff to linger.
- **Rule-changing statuses that need explicit signposting:**
  - **Shatter** — suppresses armor refresh, so the armor bar *stays empty* next round; without an indicator this looks like a bug.
  - **Brace** — bumps max armor / armor.
  - **Stun / `prevents_action`** — combatant skips its turn; needs a clear "stunned, turn skipped" read.
  - **Regen / poison / burn / bleed** — ticking each turn.
- **Application feedback** — status landing vs. resisted/gated. Bleed only applies on real HP loss (`GatedBleedEffect`); the gated no-op needs feedback so it doesn't look broken. **(invisible today)**

### 7. Combat log

Fallback for everything bars can't show (`CombatLog` RichTextLabel):

- Damage dealt/taken **with source** (which attack, which enemy).
- **Armor absorbed** vs. HP lost (`armor_absorbed`) — answers "why did that big hit do nothing."
- Dodges, misses.
- Status applied / ticked / expired.
- Proc fired / crit / elemental-verb triggers (burst tick, chain jump, pierce, shatter).
- Open question: clear per-combat vs. accumulate across the run.

### 8. Turn & round flow

- **Whose turn** (`set_player_turn`) — clear player-turn vs enemy-turn state; lock controls during enemy turn.
- **Round boundary** — armor refreshes and dodge streak resets *per round*; without a round indicator those mechanics are opaque.
- **Resolution pacing** — weapon attack / cast / hit-landed / hurt-overlay / enemy death animations gate the next input; UI must reflect "busy, wait."

### 9. Combat scene composition (the stage)

- **Player paper-doll** (body/armor/arms) + weapon scene with attack/cast animations — reserve stage space.
- **Enemy sprites** laid out to reflect targeting/adjacency.
- **Hurt overlay** flash, hit VFX, floating damage numbers (decide yes/no — they'd offload the combat log).
- **Backdrop / framing** relative to the persistent PlayerHUD and CombatHUD.

### 10. Combat entry / exit

- **Victory** and **Game Over** panels (both implemented) + the level-up flow that interposes when `pending_stat_points > 0`.
- **Rewards** surfaced on win (XP / gold / stock mutations).
- **Combat-status cleanup** — COMBAT statuses vanish on exit; the disappearance should feel intended.

### Cross-cutting decisions to make first

1. **Effective vs. base stats.** Everything the player sees in combat (DEF→armor, AGI→dodge, SPI→mana, damage) is computed by stacking equipment + blessings + background + statuses on base. The UI should show *effective* values, with the breakdown on hover — this is the core of the legibility pass.
2. **Space budget** for two hands + N enemies + status rows + a log. The dual-hand model fights a single action bar; decide early whether hands are side-by-side, stacked, or context-switched.
