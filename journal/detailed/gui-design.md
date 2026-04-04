# GUI Implementation Design

**Project:** Crawler
**Date:** 2026-03-13 (updated 2026-04-04)
**Scope:** Main Menu, Pause Menu, PlayerHUD (persistent), CombatHUD, WorldMap, DialoguePanel, SkillCheckPanel. Does not specify full menu contents — those will be detailed when the systems they surface (inventory, settings, etc.) are built.

---

## Overview / Goal

Establish the node structure, `gui.gd` API surface, and signal wiring pattern for the GUI layer. This document is the reference for implementing `gui.gd` and the GUI subtree in `game.tscn`. It does not cover game over screens, victory screens, or any menus beyond the three sections listed above.

The established architecture decision applies: `gui.gd` exposes an **intent-based API**. `game.gd` calls methods describing *what happened* (`handle_esc()`, `update_player_health()`). The GUI owns *how* to display it. Signal connections are wired exclusively in `game.gd`.

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
├── PlayerHUD  (Control)                   # persistent — visible during all non-menu game states
│   ├── PlayerHealthLabel  (Label)         # "80 / 100"
│   ├── PlayerHealthBar  (ProgressBar)
│   ├── PlayerGoldLabel  (Label)           # "Gold: 0"
│   └── PlayerXPLabel  (Label)            # "XP: 0"
│
├── PauseMenu  (Control)
│   ├── Overlay  (ColorRect)              # darkens the game world behind the menu
│   ├── ResumeButton  (Button)
│   └── QuitToMainButton  (Button)
│
├── CombatHUD  (Control)                   # shown only during CombatEvent
│   ├── EnemyHUD  (Control)               # health_bar.tscn instances added/removed at runtime
│   ├── ActionMenu  (Control)
│   │   └── AttackButton  (Button)
│   └── CombatLog  (RichTextLabel)
│
├── DialoguePanel  (DialoguePanel)         [dialogue_panel.gd] hidden by default; see dialogue-system.md
│
└── SkillCheckPanel  (SkillCheckPanel)     [skill_check_panel.gd] hidden by default
```

**Notes:**
- `PlayerHUD` is a sibling of `CombatHUD`, not a child of it. It persists across world map, combat, dialogue, and skill check screens — only hidden on the main menu.
- `EnemyHUD` children are spawned and freed at runtime — one `health_bar.tscn` instance per living enemy.
- `CombatLog` lives inside `CombatHUD` and clears when a new combat starts.

---

## Section Breakdown

### MainMenu

Shown at game start before any event is loaded. Hidden when the game begins.

| Node | Type | Role |
|---|---|---|
| `Title` | Label | Game title display |
| `StartButton` | Button | Triggers `game.gd` to load first event; `game.gd` calls `gui.start_game()` in response |
| `QuitButton` | Button | `Application.quit()` — wired in `gui.gd` directly, no game logic involved |

`StartButton.pressed` is the one signal that originates in the GUI and flows *out* to `game.gd`. Wire it in `game.gd` on setup.

### PauseMenu

Shown over any game state when ESC is pressed. `game.gd` calls `gui.handle_esc()` — the GUI decides whether to open, close, or ignore based on its own visible state.

| Node | Type | Role |
|---|---|---|
| `Overlay` | ColorRect | Semi-transparent black rect; fills screen to indicate suspended state |
| `ResumeButton` | Button | Calls `gui.handle_esc()` again (same intent: toggle pause) — wired in `gui.gd` directly |
| `QuitToMainButton` | Button | Signals `game.gd` to reset state and show main menu |

`QuitToMainButton.pressed` is a second outbound signal from GUI to `game.gd`. Wire in `game.gd`.

### PlayerHUD

Visible during all non-menu game states (world map, combat, dialogue, skill check). Hidden on main menu. Driven by `game.gd` method calls.

| Node | Type | Role |
|---|---|---|
| `PlayerHealthLabel` | Label | Text display of current / max health ("80 / 100") |
| `PlayerHealthBar` | ProgressBar | Visual bar; `value` and `max_value` set via `update_player_health()` |
| `PlayerGoldLabel` | Label | Gold total ("Gold: 0"); updated via `update_player_gold()` |
| `PlayerXPLabel` | Label | XP total ("XP: 0"); updated via `update_player_xp()` |

`show()` / `hide()` is called from `start_game()`, `show_main_menu()`, and `return_to_main_menu()`.

### CombatHUD

Shown only during a `CombatEvent`. Driven entirely by `game.gd` method calls.

| Node | Type | Role |
|---|---|---|
| `EnemyHUD` | Control | Container; `health_bar.tscn` instances added/removed at runtime — one per living enemy |
| `ActionMenu` | Control | Player action buttons; enabled on player turn, disabled on enemy turn |
| `AttackButton` | Button | Current sole action; connects to `player.execute_action("attack")` via `game.gd` |
| `CombatLog` | RichTextLabel | Append-only log of combat events; cleared when a new combat starts |

---

## `gui.gd` API

All methods called by `game.gd`. The GUI owns layout and transition logic internally.

```gdscript
# --- Navigation ---

# Called at game start; shows MainMenu, hides PlayerHUD.
func show_main_menu() -> void

# Called by game.gd when player confirms start. Hides MainMenu, shows PlayerHUD.
func start_game() -> void

# Called by game.gd on ESC input. GUI toggles PauseMenu visibility.
# Also called internally by ResumeButton.
func handle_esc() -> void

# Called by QuitToMainButton (via game.gd). Hides all sections, shows MainMenu, hides PlayerHUD.
func return_to_main_menu() -> void

# --- World Map ---

# Shows the WorldMap panel.
func show_world_map() -> void

# Hides the WorldMap panel.
func hide_world_map() -> void

# Called when a dungeon run completes. Marks the node complete on the map and re-shows it.
func world_map_on_dungeon_complete(completed_node: WorldMapNode) -> void

# --- Player HUD ---

# Called whenever player.damaged fires (wired in game.gd). Updates label and bar.
func update_player_health(current: float, maximum: float) -> void

# Called whenever player.gold_changed fires. Updates gold label.
func update_player_gold(new_total: int) -> void

# Called whenever player.experience_changed fires. Updates XP label.
func update_player_xp(new_total: int) -> void

# --- Combat HUD ---

# Called by game.gd in start_event() for CombatEvent. Shows CombatHUD, clears CombatLog.
func show_combat_hud() -> void

# Called by game.gd in _on_event_complete(). Hides CombatHUD.
func hide_combat_hud() -> void

# Called once per enemy when a CombatEvent starts. Instantiates a health_bar.tscn in EnemyHUD.
func add_enemy_health_bar(enemy: Enemy) -> void

# Called when enemy.died fires (wired in game.gd). Removes that enemy's bar from EnemyHUD.
func remove_enemy_health_bar(enemy: Enemy) -> void

# Enables or disables ActionMenu buttons. Called at turn transitions.
func set_player_turn(is_player_turn: bool) -> void

# Appends a line to CombatLog.
func log_message(text: String) -> void

# --- Dialogue ---

# Shows DialoguePanel and loads the given dialogue data.
func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void

# --- Skill Check ---

# Shows SkillCheckPanel configured for the given stat and difficulty label.
func show_skill_check(stat_name: String, label: String, stat_value: float) -> void
```

---

## Signal Connections

All connections wired in `game.gd`. The GUI emits nothing — it receives calls and exposes two outbound button signals for `game.gd` to connect on setup.

| Source | Signal | Wired to | Where connected |
|---|---|---|---|
| `player` | `damaged(amount)` | `gui.update_player_health()` | `game.gd: set_player()` |
| `player` | `gold_changed(new_total)` | `gui.update_player_gold()` | `game.gd: set_player()` |
| `player` | `experience_changed(new_total)` | `gui.update_player_xp()` | `game.gd: set_player()` |
| `enemy` (per instance) | `damaged(amount)` | update that enemy's health bar via `gui` | `game.gd: start_event()` |
| `enemy` (per instance) | `died` | `gui.remove_enemy_health_bar(enemy)` | `game.gd: start_event()` |
| `WorldMap` | `node_selected(node)` | `game.gd: _on_world_node_selected()` | `gui.gd: _ready()` → relayed via `node_selected` signal |
| `DialoguePanel` | `dialogue_complete` | `game.gd: _on_gui_dialogue_complete()` | `gui.gd: _ready()` → relayed via `dialogue_complete` signal |
| `SkillCheckPanel` | `skill_check_complete(success)` | `game.gd: _on_gui_skill_check_complete()` | `gui.gd: _ready()` → relayed via `skill_check_complete` signal |
| `gui/MainMenu/StartButton` | `pressed` | `game.gd` start logic | `game.gd: _ready()` |
| `gui/PauseMenu/QuitToMainButton` | `pressed` | `game.gd: quit_to_main()` | `game.gd: _ready()` |

**Not wired to GUI directly:**
- `player.attack` — routed through `CombatEvent`, not a display concern
- `CombatEvent.player_attacked` — `game.gd` handles damage application; GUI sees result via `player.damaged`
- `player.turn_ended` / `CombatEvent.enemy_turns_complete` — `game.gd` calls `gui.set_player_turn()` at each transition

---

## Open Questions

- **ActionMenu shape** — Single attack button now. Will it grow to a vertical list (Attack / Spell / Item / Flee), a grid, or something else? This affects the layout of `ActionMenu` and how `set_player_turn()` enables/disables children.
- **Enemy health bar layout** — Stacked vertically in `EnemyHUD`? Positioned near each enemy sprite? Max enemy count affects this significantly.
- **Enemy health bar identity** — Should bars show enemy names? If enemies can share a type (e.g. two skeletons), how are they distinguished?
- **CombatLog persistence** — Clear on each new combat, or accumulate across the whole run?
- **Game over / victory screens** — Out of scope here, but `gui.gd` will need `show_game_over()` and `show_victory()` methods eventually. Reserve space in the section enum.
- **PauseMenu contents** — Resume and quit are the minimum. Settings, controls reference, and save/load may be added later.
