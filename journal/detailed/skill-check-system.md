# Skill Check System Design

**Date:** 2026-03-31
**Status:** Implemented

---

## Overview

A modal skill check system that can be invoked from any event. Presents a stat-based d100 roll-under challenge — the player rolls a virtual die, and succeeds if the result is at or below their effective stat value. After the roll, the event optionally fires success or failure dialogue before completing.

The skill check is an **Event subclass**, not a standalone UI subsystem. It goes through the full event phase state machine. Dialogue during resolution reuses the existing dialogue system unchanged.

---

## New Files

| File | Role |
|---|---|
| `scripts/skill_check_event.gd` | Event subclass — loads JSON, emits signals, routes phases |
| `scripts/skill_check_panel.gd` | Roll UI — displays stat, prompt, roll button, result |
| `scenes/skill_check_event.tscn` | Scene file; inherits `event.tscn`, sets default JSON path |
| `resources/events/skill_check/example.json` | Example event definition |

---

## Roll Mechanic

**d100 roll-under.** `randi_range(1, 100) <= int(effective_stat)`.

A stat of 50 gives a 50% success chance. Stats default to 50.0, so a fresh character is balanced. Equipment can push the stat up or down.

The roll happens in `SkillCheckPanel`, not in the event. The event receives only the boolean outcome via `on_skill_check_complete(success)`. This keeps the event agnostic to how the roll is presented — the UI could animate a die, add visual flair, etc., without touching the event logic.

`game.gd` is the only place `player.get_effective_stat()` is called. When `skill_check_requested` fires, `_on_skill_check_requested()` reads the value and passes it to the GUI as a plain `float`. The event never holds a player reference.

---

## Data Format

Event definitions live in `res://resources/events/skill_check/`. Loaded via `FileAccess` and `JSON.parse_string()` at runtime.

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

### Fields

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Identifier for debugging |
| `label` | `String` | Prompt text shown to the player above the roll button |
| `stat` | `String` | Must match an `Enums.Stat` key exactly (`"STRENGTH"`, `"AGILITY"`, etc.) |
| `rewards` | `Dictionary` | Applied on event completion regardless of outcome — same format as other events |
| `on_success` | `String` | Path to a dialogue content JSON. Empty string skips dialogue on success |
| `on_failure` | `String` | Path to a dialogue content JSON. Empty string skips dialogue on failure |

`on_success` and `on_failure` point directly to dialogue node trees (the same format used by `DialogueEvent`) — not to event definition files.

---

## Node Tree

`SkillCheckPanel` is added directly to the `GUI` node in `game.tscn`. Hidden by default. No separate scene file for the panel.

```
GUI  (CanvasLayer)
├── MainMenu
├── PauseMenu
├── CombatHUD
├── DialoguePanel
└── SkillCheckPanel     Control             [skill_check_panel.gd]
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

`SkillCheckEvent` has no children — it is a root-only scene like `DialogueEvent`.

---

## `skill_check_event.gd`

```gdscript
class_name SkillCheckEvent
extends Event

signal skill_check_requested(stat: Enums.Stat, label: String)
signal dialogue_requested(data: Dictionary)

@export var event_json_path: String = ""

# Loaded in _on_setup()
var _stat: Enums.Stat
var _label: String
var _on_success_path: String
var _on_failure_path: String
# Stored in on_skill_check_complete()
var _success: bool
```

### Phase flow

`_on_setup()` opens `event_json_path`, parses the JSON, and populates all private vars. `stat` is converted via `Enums.Stat[stat_key]` — an unknown key logs a warning and defaults to `LUCK`.

`_on_running()` emits `skill_check_requested(_stat, _label)`. The event stays in RUNNING until `on_skill_check_complete()` is called externally.

`on_skill_check_complete(success)` stores `_success` and calls `_set_phase(Phase.RESOLUTION)` directly — **not** `_advance_phase()`. The base `_advance_phase()` goes RUNNING → RESOLUTION → COMPLETE atomically; calling `_set_phase` one step at a time lets `_on_resolution()` pause for dialogue before COMPLETE.

`_on_resolution()` picks the path based on `_success`. If empty, calls `_set_phase(Phase.COMPLETE)`. If non-empty, loads the dialogue JSON and emits `dialogue_requested`.

`on_dialogue_complete()` calls `_set_phase(Phase.COMPLETE)` — invoked by `game.gd` when optional result dialogue is dismissed.

---

## `skill_check_panel.gd`

Owns roll logic, display, and the `skill_check_complete` signal. `gui.gd` initialises it via `setup()` and listens for its signal.

```gdscript
signal skill_check_complete(success: bool)

var _stat_value: float
var _success: bool

func setup(stat_name: String, label: String, stat_value: float) -> void:
    # Populate labels, store _stat_value
    # Reset: re-enable RollButton, hide RollResultLabel and ContinueButton

func _on_roll_button_pressed() -> void:
    var roll: int = randi_range(1, 100)
    _success = roll <= int(_stat_value)
    # Show result text, disable RollButton, show ContinueButton

func _on_continue_pressed() -> void:
    skill_check_complete.emit(_success)
```

`setup()` fully resets panel state so it is safe to reuse across multiple skill check events in a single session.

---

## `gui.gd` Additions

```gdscript
signal skill_check_complete(success: bool)

# Called by game.gd to open the skill check panel.
func show_skill_check(stat_name: String, label: String, stat_value: float) -> void

# Called internally when SkillCheckPanel signals completion.
func _on_skill_check_complete(success: bool) -> void
    # hides SkillCheckPanel
    # emits skill_check_complete(success)
```

`show_skill_check()` calls `_skill_check_panel.setup(...)` then shows the panel.

`game.gd` connects `_gui.skill_check_complete` → `_on_gui_skill_check_complete` during setup. The panel is an implementation detail — `game.gd` never references it directly.

---

## `game.gd` Changes

### Event wiring in `start_event()`

```gdscript
elif event is SkillCheckEvent:
    var sce := event as SkillCheckEvent
    sce.skill_check_requested.connect(_on_skill_check_requested)
    sce.dialogue_requested.connect(_on_dialogue_requested)
```

`dialogue_requested` reuses the existing `_on_dialogue_requested` handler — no changes needed there.

### Cleanup in `_on_event_complete()`

```gdscript
elif current_event is SkillCheckEvent:
    var sce := current_event as SkillCheckEvent
    sce.skill_check_requested.disconnect(_on_skill_check_requested)
    sce.dialogue_requested.disconnect(_on_dialogue_requested)
```

### New handlers

```gdscript
func _on_skill_check_requested(stat: Enums.Stat, label: String) -> void:
    var stat_value: float = player.get_effective_stat(stat)
    _gui.show_skill_check(Enums.Stat.keys()[stat], label, stat_value)

func _on_gui_skill_check_complete(success: bool) -> void:
    if current_event is SkillCheckEvent:
        (current_event as SkillCheckEvent).on_skill_check_complete(success)
```

### Dialogue complete routing

`_on_gui_dialogue_complete()` adds a branch for skill check resolution dialogue:

```gdscript
elif current_event is SkillCheckEvent:
    (current_event as SkillCheckEvent).on_dialogue_complete()
```

This only fires when `_on_resolution()` emitted `dialogue_requested` — i.e. a success or failure dialogue path was set. If no dialogue fired, `_on_resolution()` called `_set_phase(COMPLETE)` directly and this branch is never reached.

### Setup

Wire in `_ready()`:

```gdscript
_gui.skill_check_complete.connect(_on_gui_skill_check_complete)
_gui.start_skill_check_requested.connect(start_skill_check_game)
```

Debug export for in-editor testing (parallels `debug_dialogue_scene`):

```gdscript
@export var debug_skill_check_scene: PackedScene
```

---

## Signal Flow

**Roll (no result dialogue):**
```
game.start_event(skill_check_event)
  → sce.skill_check_requested.connect(_on_skill_check_requested)
  → sce.dialogue_requested.connect(_on_dialogue_requested)
  → sce.start()
    → _on_setup(): load JSON, parse all fields
    → _on_running(): emit skill_check_requested(_stat, _label)
  → game._on_skill_check_requested(stat, label)
    → player.get_effective_stat(stat) → stat_value
    → gui.show_skill_check("AGILITY", label, stat_value)
  → [player rolls]
  → gui.skill_check_complete(success) → game._on_gui_skill_check_complete(success)
    → sce.on_skill_check_complete(success)
      → _set_phase(RESOLUTION) → _on_resolution()
        → path is empty → _set_phase(COMPLETE) → event_complete.emit()
  → game._on_event_complete() → disconnect, _apply_rewards(), _finish_event()
```

**Roll (with result dialogue):**
```
  ... [same up to _on_resolution()] ...
      → _on_resolution(): load dialogue JSON, emit dialogue_requested(data)
  → game._on_dialogue_requested(data) → start_dialogue(data)
    → save state, set DIALOGUE, gui.show_dialogue()
  → [player dismisses dialogue]
  → gui.dialogue_complete → game._on_gui_dialogue_complete()
    → sce.on_dialogue_complete() → _set_phase(COMPLETE) → event_complete.emit()
  → game._on_event_complete() → disconnect, _apply_rewards(), _finish_event()
```

---

## Open Questions

- **Rewards split by outcome** — Current rewards dict applies regardless of pass/fail. A future extension could support `"rewards_on_success"` and `"rewards_on_failure"` keys in the JSON if asymmetric rewards are needed.
- **Roll animation** — The panel currently shows the result instantly. A tween or short animation before revealing the number would add game feel; the panel script is the only place to change.
- **Stat display** — Showing the raw stat number tells the player their exact odds. Consider hiding the value or showing it only after rolling, depending on the feel we want.
- **Multiple rolls / retry** — Not supported. One roll per event. If a retry mechanic is needed (spend a resource to reroll), that logic would live in the panel and emit an updated result without re-entering the event phase.
- **Skill check as dialogue consequence** — Currently skill checks only fire as standalone events. If a dialogue node needs to branch based on a skill check, that pathway doesn't exist yet. It would require a blocking consequence mechanism in `DialogueConsequences` — design that when the use case arrives.
