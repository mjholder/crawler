class_name WorldMapNode
extends Control

# --- Signals ---

signal node_selected(node: WorldMapNode)

# --- State ---

var state: Enums.NodeState = Enums.NodeState.LOCKED

# --- Visuals ---

@export var texture_available: Texture2D
@export var texture_locked: Texture2D
@export var texture_completed: Texture2D

# --- Graph ---

@export var connected_nodes: Array[NodePath]


# --- State Management ---

func set_state(new_state: Enums.NodeState) -> void:
	state = new_state
	_update_visuals()
	$NodeButton.disabled = state != Enums.NodeState.AVAILABLE


func _update_visuals() -> void:
	match state:
		Enums.NodeState.AVAILABLE:  $NodeButton.texture_normal = texture_available
		Enums.NodeState.LOCKED:     $NodeButton.texture_normal = texture_locked
		Enums.NodeState.COMPLETED:  $NodeButton.texture_normal = texture_completed


# --- Input ---

func _on_node_button_pressed() -> void:
	if state == Enums.NodeState.AVAILABLE:
		node_selected.emit(self)


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	return []


# --- Helpers ---

func _get_json_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	if dir_path == "":
		return files
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".json"):
			files.append(dir_path.path_join(file))
		file = dir.get_next()
	return files


func _load_json(path: String) -> Dictionary:
	if path == "":
		push_warning("[WorldMapNode] _load_json called with empty path")
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("[WorldMapNode] Could not read file '%s'" % path)
		return {}
	return JSON.parse_string(text)
