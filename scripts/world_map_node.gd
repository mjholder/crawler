class_name WorldMapNode
extends Control

# --- Signals ---

signal node_selected(node: WorldMapNode)

# --- State ---

@export var node_type: Enums.NodeType = Enums.NodeType.DUNGEON
var state: Enums.NodeState = Enums.NodeState.LOCKED

# --- Visuals ---

@export var texture_available: Texture2D
@export var texture_locked: Texture2D
@export var texture_completed: Texture2D

# --- Graph ---

@export var connected_nodes: Array[NodePath]

# --- Dungeon Config ---

@export var dungeon_depth: int = 4

@export var combat_scene: PackedScene
@export var combat_json_dir: String
@export var debug_combat_json_path: String

@export var dialogue_scene: PackedScene
@export var dialogue_json_dir: String
@export var debug_dialogue_json_path: String

@export var skill_check_scene: PackedScene
@export var skill_check_json_dir: String
@export var debug_skill_check_json_path: String

@export var miniboss_scene: PackedScene
@export var miniboss_json_path: String

# --- Rest Config ---

@export var rest_scene: PackedScene


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
	if node_type == Enums.NodeType.REST:
		return _build_rest_config()

	var configs: Array[Dictionary] = []

	for i in range(dungeon_depth - 1):
		var config := _build_random_event_config()
		if not config.is_empty():
			configs.append(config)

		var boss_data := _load_json(miniboss_json_path)
		configs.append({ "scene": miniboss_scene, "data": boss_data })

	return configs


func _build_rest_config() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	configs.append({ "scene": rest_scene, "data": { "heal_percent": 1.0 } })
	return configs


func _build_random_event_config() -> Dictionary:
	var candidates: Array[Dictionary] = []
	if combat_scene:
		candidates.append({ "scene": combat_scene, "dir": combat_json_dir, "debug": debug_combat_json_path })
	if dialogue_scene:
		candidates.append({ "scene": dialogue_scene, "dir": dialogue_json_dir, "debug": debug_dialogue_json_path })
	if skill_check_scene:
		candidates.append({ "scene": skill_check_scene, "dir": skill_check_json_dir, "debug": debug_skill_check_json_path })

	if candidates.is_empty():
		push_warning("[WorldMapNode] No event types configured on node '%s'" % name)
		return {}

	var pick: Dictionary = candidates[randi() % candidates.size()]
	var files := _get_json_files(pick["dir"])

	var path: String
	if files.is_empty():
		push_warning("[WorldMapNode] No JSON files found in '%s' — falling back to debug file." % pick["dir"])
		path = pick["debug"]
	else:
		path = files[randi() % files.size()]

	return { "scene": pick["scene"], "data": _load_json(path) }


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
