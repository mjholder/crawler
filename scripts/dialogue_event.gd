class_name DialogueEvent
extends Event

# --- Signals ---

signal dialogue_requested(data: Dictionary)

# --- Data ---

@export var dialogue_data: DialogueData

var _data: Dictionary

# --- Public API ---

func initialize(data: Dictionary) -> void:
	var dialogue_path: String = ""
	if dialogue_data != null:
		dialogue_path = dialogue_data.dialogue_path
	else:
		dialogue_path = data.get("dialogue", "")
	if dialogue_path == "":
		push_warning("DialogueEvent: no dialogue path — set dialogue_data or data['dialogue']")
		return
	var dialogue_file := FileAccess.open(dialogue_path, FileAccess.READ)
	if dialogue_file == null:
		push_warning("DialogueEvent: could not open dialogue '%s'" % dialogue_path)
		return
	_data = JSON.parse_string(dialogue_file.get_as_text())

# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	dialogue_requested.connect(game._on_dialogue_requested)


func _on_exit(game: Node) -> void:
	dialogue_requested.disconnect(game._on_dialogue_requested)


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
