# GUI Implementation Design

**Project:** Crawler
**Date:** 2026-03-13
**Scope:** Main Menu, Pause Menu, and Combat HUD. Does not specify full menu contents — those will be detailed when the systems they surface (inventory, settings, etc.) are built.

---

## Overview / Goal

Establish the node structure, `gui.gd` API surface, and signal wiring pattern for the GUI layer. This document is the reference for implementing `gui.gd` and the GUI subtree in `game.tscn`. It does not cover game over screens, victory screens, or any menus beyond the three sections listed above.

The established architecture decision applies: `gui.gd` exposes an **intent-based API**. `game.gd` calls methods describing *what happened* (`handle_esc()`, `update_player_health()`). The GUI owns *how* to display it. Signal connections are wired exclusively in `game.gd`.

---

## Mock Node Tree

```
GUI  (CanvasLayer, layer 4)  [gui.gd]
├── MainMenu  (Control)
│   ├── Title  (Label)
│   ├── StartButton  (Button)
│   └── QuitButton  (Button)
│
├── PauseMenu  (Control)
│   ├── Overlay  (ColorRect)          # darkens the game world behind the menu
│   ├── ResumeButton  (Button)
│   └── QuitToMainButton  (Button)
│
└── CombatHUD  (Control)
    ├── PlayerHUD  (Control)
    │   ├── PlayerHealthLabel  (Label)          # "80 / 100" — current stub
    │   └── PlayerHealthBar  (ProgressBar)      # to be added
    ├── EnemyHUD  (Control)                     # stub; enemy health bars added dynamically at runtime
    ├── ActionMenu  (Control)
    │   └── AttackButton  (Button)              # current stub; expands to full action list later
    └── CombatLog  (RichTextLabel)
```

**Notes:**
- `MainMenu` and `PauseMenu` are hidden by default. `CombatHUD` is hidden until a `CombatEvent` starts.
- `EnemyHUD` children are spawned and freed at runtime — one `health_bar.tscn` instance per living enemy, driven by `game.gd` via `gui.gd` API calls.
- `CombatLog` currently lives as a direct child of `GUI` in the scene. It should be moved inside `CombatHUD` — it is combat-scoped and should show/hide with it.
- **Enemy health bars belong to `EnemyHUD`, not to enemy scenes.** The `HealthBar` node currently in `skeleton.tscn` should be removed. `health_bar.tscn` is reused as the instantiated bar inside `EnemyHUD`.

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

### CombatHUD

Shown during a `CombatEvent`, hidden outside of combat. Driven entirely by `game.gd` method calls.

| Node | Type | Role |
|---|---|---|
| `PlayerHealthLabel` | Label | Text display of current / max health ("80 / 100") |
| `PlayerHealthBar` | ProgressBar | Visual bar; `value` and `max_value` set via `update_player_health()` |
| `EnemyHUD` | Control | Container; `health_bar.tscn` instances added/removed at runtime — one per living enemy |
| `ActionMenu` | Control | Player action buttons; enabled on player turn, disabled on enemy turn |
| `AttackButton` | Button | Current sole action; connects to `player.execute_action("attack")` via `game.gd` |
| `CombatLog` | RichTextLabel | Append-only log of combat events; cleared when a new combat starts |

---

## `gui.gd` API

All methods called by `game.gd`. The GUI owns layout and transition logic internally.

```gdscript
# --- Navigation ---

# Called at game start; shows MainMenu.
func show_main_menu() -> void

# Called by game.gd when player confirms start. Hides MainMenu.
func start_game() -> void

# Called by game.gd on ESC input. GUI toggles PauseMenu visibility.
# Also called internally by ResumeButton.
func handle_esc() -> void

# Called by QuitToMainButton (via game.gd). Hides all sections, shows MainMenu.
func return_to_main_menu() -> void

# --- Combat HUD ---

# Called by game.gd in start_event() for CombatEvent. Shows CombatHUD, clears CombatLog.
func show_combat_hud() -> void

# Called by game.gd in _on_event_complete(). Hides CombatHUD.
func hide_combat_hud() -> void

# Called whenever player.damaged fires (wired in game.gd).
func update_player_health(current: float, maximum: float) -> void

# Called once per enemy when a CombatEvent starts. Instantiates a health_bar.tscn in EnemyHUD.
func add_enemy_health_bar(enemy: Enemy) -> void

# Called when enemy.died fires (wired in game.gd). Removes that enemy's bar from EnemyHUD.
func remove_enemy_health_bar(enemy: Enemy) -> void

# Enables or disables ActionMenu buttons. Called at turn transitions.
func set_player_turn(is_player_turn: bool) -> void

# Appends a line to CombatLog.
func log_message(text: String) -> void
```

---

## Signal Connections

All connections wired in `game.gd`. The GUI emits nothing — it receives calls and exposes two outbound button signals for `game.gd` to connect on setup.

| Source | Signal | Wired to | Where connected |
|---|---|---|---|
| `player` | `damaged(amount)` | `gui.update_player_health(player.health, player.max_health)` | `game.gd: set_player()` |
| `enemy` (per instance) | `damaged(amount)` | update that enemy's health bar via `gui` | `game.gd: start_event()` |
| `enemy` (per instance) | `died` | `gui.remove_enemy_health_bar(enemy)` | `game.gd: start_event()` |
| `gui/MainMenu/StartButton` | `pressed` | `game.gd` start logic | `game.gd: _ready()` |
| `gui/PauseMenu/QuitToMainButton` | `pressed` | `game.gd: _on_quit_to_main()` | `game.gd: _ready()` |

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
