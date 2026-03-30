class_name DialogueEvent
extends Event

# --- Signals ---

signal dialogue_requested(data: Dictionary)

# --- Data ---

@export var event_json_path: String = ""

var _data: Dictionary

# --- Phase Hooks ---

func _on_setup() -> void:
	if event_json_path == "":
		push_warning("DialogueEvent: event_json_path not set")
		return
	var event_file := FileAccess.open(event_json_path, FileAccess.READ)
	if event_file == null:
		push_warning("DialogueEvent: could not open '%s'" % event_json_path)
		return
	var event_data: Dictionary = JSON.parse_string(event_file.get_as_text())
	rewards = event_data.get("rewards", {})
	var dialogue_path: String = event_data.get("dialogue", "")
	if dialogue_path == "":
		push_warning("DialogueEvent: event JSON missing 'dialogue' key")
		return
	var dialogue_file := FileAccess.open(dialogue_path, FileAccess.READ)
	if dialogue_file == null:
		push_warning("DialogueEvent: could not open dialogue '%s'" % dialogue_path)
		return
	_data = JSON.parse_string(dialogue_file.get_as_text())


func _on_running() -> void:
	dialogue_requested.emit(_data)


# --- Public API ---

# Called by game.gd when gui.dialogue_complete fires.
func on_dialogue_complete() -> void:
	_advance_phase()
