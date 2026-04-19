class_name DialogueEvent
extends Event

# --- Signals ---

signal dialogue_requested(data: Dictionary)

# --- Data ---

var _data: Dictionary

# --- Public API ---

func initialize(data: Dictionary) -> void:
	var dialogue_path: String = data.get("dialogue", "")
	if dialogue_path == "":
		push_warning("DialogueEvent: data missing 'dialogue' key")
		return
	var dialogue_file := FileAccess.open(dialogue_path, FileAccess.READ)
	if dialogue_file == null:
		push_warning("DialogueEvent: could not open dialogue '%s'" % dialogue_path)
		return
	_data = JSON.parse_string(dialogue_file.get_as_text())

# --- Phase Hooks ---

func _on_setup() -> void:
	pass


func _on_running() -> void:
	dialogue_requested.emit(_data)


# --- Public API ---

# Called by game.gd when gui.dialogue_complete fires.
func on_dialogue_complete(terminal_node_id: String) -> void:
	var node: Dictionary = _data["nodes"][terminal_node_id]
	rewards = node.get("rewards", {})
	_advance_phase()
