class_name DialogueEvent
extends Event

# --- Signals ---

signal dialogue_requested(data: Dictionary)

# --- Data ---

@export var dialogue_data: DialogueData

var _data: Dictionary

# --- Public API ---

func initialize(data: Dictionary) -> void:
	var path: String = ""
	if dialogue_data != null:
		path = dialogue_data.dialogue_path
	else:
		path = data.get("dialogue", "")
	if path == "":
		push_warning("DialogueEvent: no dialogue path — set dialogue_data or data['dialogue']")
		return
	_data = DialogueLoader.load_dict(path)
	if _data.is_empty():
		push_warning("DialogueEvent: could not load dialogue at '%s'" % path)

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
