class_name DialogueEvent
extends Event

# --- Signals ---

signal dialogue_requested(data: Dictionary)

# --- Data ---

@export var dialogue_json_path: String = ""

var _data: Dictionary

# --- Phase Hooks ---

func _on_setup() -> void:
	if dialogue_json_path == "":
		push_warning("DialogueEvent: dialogue_json_path not set")
		return
	var file := FileAccess.open(dialogue_json_path, FileAccess.READ)
	if file == null:
		push_warning("DialogueEvent: could not open '%s'" % dialogue_json_path)
		return
	_data = JSON.parse_string(file.get_as_text())


func _on_running() -> void:
	dialogue_requested.emit(_data)


# --- Public API ---

# Called by game.gd when gui.dialogue_complete fires.
func on_dialogue_complete() -> void:
	_advance_phase()
