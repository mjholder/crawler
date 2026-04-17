# Dialogue System Design

**Date:** 2026-03-24 (updated 2026-04-17)
**Status:** Implemented

---

## Overview

A modal dialogue system that can be invoked from any game state. Displays speaker text and optional branching choices. Fires consequences when nodes load. Pauses the turn system while active and resumes it when dialogue ends.

Dialogue is a **UI subsystem**, not an Event. It does not go through the event phase state machine. Events (and game.gd) trigger it by passing data and a consequence handler to the GUI layer.

---

## New Files

| File | Role |
|---|---|
| `scripts/dialogue_consequences.gd` | Consequence dispatcher — child node of the game scene; methods are callable by keyword |
| `scripts/dialogue_panel.gd` | Panel logic — node navigation, rendering, consequence dispatch |
| `dialogue/` | Directory for dialogue JSON files (one file per dialogue tree) |

---

## Data Format

Dialogue trees live in `res://dialogue/` as JSON files. Loaded via `FileAccess` and `JSON.parse_string()` at runtime.

### Structure

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
        { "text": "I need supplies.", "next": "0-1" },
        { "text": "Never mind.", "next": "0-2" }
      ]
    },
    "0-0": {
      "speaker": "Merchant",
      "text": "Dangerous place. Lost three adventurers just last week.",
      "consequence": { "action": "set_flag", "value": "heard_dungeon_warning" },
      "choices": []
    },
    "0-1": {
      "speaker": "Merchant",
      "text": "Take this. You'll need it.",
      "consequence": { "action": "give_item", "value": "health_potion" },
      "choices": [
        { "text": "Thank you.", "next": "0-1-0" },
        { "text": "Keep it.", "next": "0-1-1" }
      ]
    },
    "0-1-0": {
      "speaker": "Merchant",
      "text": "Don't mention it. Don't die.",
      "consequence": null,
      "choices": []
    },
    "0-1-1": {
      "speaker": "Merchant",
      "text": "Suit yourself.",
      "consequence": null,
      "choices": []
    },
    "0-2": {
      "speaker": null,
      "text": "You walk away.",
      "consequence": null,
      "choices": []
    }
  }
}
```

### Node naming rules

- Root node is always `"0"`
- Node IDs follow the path of choice indices taken to reach them — e.g. root → choice 1 → choice 0 = `"0-1-0"`
- This is a **developer convention for readability**, not a navigation mechanism
- Navigation is driven entirely by the explicit `"next"` field on each choice
- The naming makes it easy to find a node in the file and understand how the player arrived there

### Node fields

| Field | Type | Notes |
|---|---|---|
| `speaker` | `String \| null` | Displayed in `SpeakerLabel`. Null hides the label |
| `text` | `String` | Main body text |
| `consequence` | `{ action: String, value: Variant } \| null` | Fired on node load, before text renders |
| `choices` | `Array[{ text, next }]` | Each entry has display text and the ID of the next node. Empty array = terminal node |

### Terminal nodes

A node with an empty `choices` array shows a **Continue** button. Pressing it ends the dialogue and emits `dialogue_complete`. The system does not auto-close — the player must confirm.

---

## Node Tree

Added directly to the `GUI` node in `game.tscn`. Hidden by default. No separate scene file.

```
GUI  (CanvasLayer)
├── MainMenu
├── PauseMenu
├── CombatHUD
└── DialoguePanel       Control             [dialogue_panel.gd]
    ├── Background      ColorRect               (placeholder — swap for NinePatchRect when panel art is ready)
    ├── SpeakerLabel    Label               (hidden when speaker is null)
    ├── TextLabel       RichTextLabel
    └── ChoicesContainer    VBoxContainer
        └── [Button nodes instantiated at runtime, one per choice]
```

Choice buttons are created fresh on each node load and freed when the node changes. The Continue button (terminal nodes) replaces them.

---

## `DialogueConsequences`

`scripts/dialogue_consequences.gd`

A child node of the game scene (`extends Node`). Lives in the scene tree as a sibling of `Player`, `GUI`, etc. `game.gd` holds an `@onready` reference to it and passes it to `gui.show_dialogue()`. Methods defined on the class are the consequences. The dialogue system dispatches to them by name using GDScript's `call()`.

New consequence types are new methods — no other file changes.

```gdscript
class_name DialogueConsequences
extends Node

# --- Setup ---

var _game: Game

func _ready() -> void:
    _game = get_parent() as Game

# --- Dispatch ---

# Called by DialoguePanel on each node load.
func execute(action: String, value: Variant) -> void:
    if has_method(action):
        call(action, value)
    else:
        push_warning("DialogueConsequences: unknown action '%s'" % action)

# --- Consequence Methods ---
# Add new methods here as new consequence types are needed.

func give_item(value: Variant) -> void:
    pass

func give_gold(value: Variant) -> void:
    pass

func set_flag(value: Variant) -> void:
    pass

func trigger_event(value: Variant) -> void:
    pass
```

---

## `dialogue_panel.gd`

Owns node navigation, consequence dispatch, and rendering. `gui.gd` initialises it via `load_dialogue()` and listens for its `dialogue_complete` signal.

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

func _render_node(node: Dictionary) -> void:
    # Update SpeakerLabel, TextLabel
    # Clear ChoicesContainer
    # If choices is empty: add Continue button
    # Else: add one Button per choice string
    pass

func _on_choice_pressed(index: int) -> void:
    var next_id: String = _data["nodes"][_current_node_id]["choices"][index]["next"]
    _load_node(next_id)

func _on_continue_pressed() -> void:
    dialogue_complete.emit()
```

---

## `gui.gd` Additions

```gdscript
signal dialogue_complete

# Called by game.gd to open dialogue.
func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void

# Called internally when DialoguePanel signals completion.
func _on_dialogue_panel_complete() -> void
    # hides DialoguePanel
    # emits dialogue_complete
```

`show_dialogue()` passes data and consequences to `$DialoguePanel.load_dialogue()`, makes the panel visible, and connects `$DialoguePanel.dialogue_complete` → `_on_dialogue_panel_complete` (one-shot).

`game.gd` connects `_gui.dialogue_complete` → `_on_dialogue_complete` during setup. The DialoguePanel is an implementation detail — `game.gd` never references it directly.

---

## `game.gd` Changes

### New TurnState

Add `DIALOGUE` to `Enums.TurnState`:

```gdscript
enum TurnState { NO_TURN, PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, DIALOGUE }
```

### Dialogue entry and exit

```gdscript
@onready var _dialogue_consequences: DialogueConsequences = $DialogueConsequences

var _pre_dialogue_state: Enums.TurnState

func start_dialogue(data: Dictionary) -> void:
    _pre_dialogue_state = state
    state = Enums.TurnState.DIALOGUE
    _gui.show_dialogue(data, _dialogue_consequences)

func _on_dialogue_complete() -> void:
    state = _pre_dialogue_state
```

`_unhandled_input` already gates on `state != PLAYER_TURN`, so no additional input blocking is needed.

### Setup

Wire in `_ready()`:

```gdscript
_gui.dialogue_complete.connect(_on_dialogue_complete)
```

### Triggered by events

Events do not call `gui.gd` directly. An event that wants to trigger dialogue emits a signal:

```gdscript
signal dialogue_requested(data: Dictionary)
```

`game.gd` connects `event.dialogue_requested` → a handler that calls `start_dialogue(data)`. This keeps events GUI-agnostic and player-mutation in `game.gd`.

---

## Signal Flow

**Dialogue starts (from event):**
`event.dialogue_requested(data)` → `game.gd._on_dialogue_requested()` → `game.gd.start_dialogue(data)` → `_gui.show_dialogue(data, _dialogue_consequences)`

**Node loads with consequence:**
`_load_node()` → `consequences.execute(action, value)` → consequence method runs → node renders

**Player picks a choice:**
`ChoiceButton.pressed` → `_on_choice_pressed(index)` → read `choices[index]["next"]` → `_load_node(next_id)`

**Dialogue ends:**
`DialoguePanel.dialogue_complete` → `gui._on_dialogue_panel_complete()` → hide panel → `gui.dialogue_complete.emit()` → `game.gd._on_dialogue_complete()` → restore `state`

---

## Open Questions

- **Terminal node UX** — Continue button that closes, or does a short delay auto-advance? Keep it a button for now; revisit during UI polish.
- **Speaker portraits** — SpeakerLabel is text-only. Reserve a `PortraitTexture` node in the panel tree when building the scene so there's a slot for it later without rearchitecting.
- **DialogueConsequences references** — `_ready()` casts the parent to `Game`, giving access to the player and current event. If a consequence needs the active event reference at dispatch time, read `_game.current_event` directly rather than passing it separately.
- **Dialogue file location** — `res://dialogue/` flat, or organised by area/NPC? Flat is fine until the count grows.
- **Blocking consequences** — Not needed now. If a future consequence needs to pause and await a result (e.g. a skill check), add a `consequence_resolved` signal to `DialogueConsequences` and have `_load_node` await it before rendering. Design that when the use case arrives.
