class_name DungeonMapNode
extends WorldMapNode

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

@export var rest_scene: PackedScene
@export var rest_json_dir: String
@export var debug_rest_json_path: String

@export var miniboss_scene: PackedScene
@export var miniboss_json_path: String


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []

	for i in range(dungeon_depth - 1):
		var config := _build_random_event_config()
		if not config.is_empty():
			configs.append(config)

		var boss_data := _load_json(miniboss_json_path)
		configs.append({ "scene": miniboss_scene, "data": boss_data })

	return configs


func _build_random_event_config() -> Dictionary:
	var candidates: Array[Dictionary] = []
	if combat_scene:
		candidates.append({ "scene": combat_scene, "dir": combat_json_dir, "debug": debug_combat_json_path })
	if dialogue_scene:
		candidates.append({ "scene": dialogue_scene, "dir": dialogue_json_dir, "debug": debug_dialogue_json_path })
	if skill_check_scene:
		candidates.append({ "scene": skill_check_scene, "dir": skill_check_json_dir, "debug": debug_skill_check_json_path })
	if rest_scene:
		candidates.append({ "scene": rest_scene, "dir": rest_json_dir, "debug": debug_rest_json_path })

	if candidates.is_empty():
		push_warning("[DungeonMapNode] No event types configured on node '%s'" % name)
		return {}

	var pick: Dictionary = candidates[randi() % candidates.size()]
	var files := _get_json_files(pick["dir"])

	var path: String
	if files.is_empty():
		push_warning("[DungeonMapNode] No JSON files found in '%s' — falling back to debug file." % pick["dir"])
		path = pick["debug"]
	else:
		path = files[randi() % files.size()]

	return { "scene": pick["scene"], "data": _load_json(path) }
