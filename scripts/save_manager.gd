class_name SaveManager

const SAVE_PATH: String = "user://save.tres"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func write(game: Game) -> Error:
	var data := RunSaveData.new()
	data.version = RunSaveData.VERSION
	data.saved_at_unix = int(Time.get_unix_time_from_system())
	data.player = game.player.to_save_dict()
	data.current_act = game.current_act
	data.active_act_scene_path = game._gui.get_world_map().scene_file_path
	data.world_map_node_states = game._gui.get_world_map().to_state_dict()
	data.game_state = game.game_state
	data.active_world_node_path = _node_to_path(game._active_world_node, game._gui.get_world_map())
	data.event_index = game._event_index
	data.pending_event_configs = _configs_to_save(game._pending_event_configs)
	var err := ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_error("[SaveManager] Failed to save: error %d" % err)
	return err


static func read() -> RunSaveData:
	if not has_save():
		return null
	var data := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as RunSaveData
	if data == null or data.version != RunSaveData.VERSION:
		push_warning("[SaveManager] Save incompatible or corrupt — discarding")
		clear()
		return null
	return data


static func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


static func _node_to_path(node: WorldMapNode, world_map: WorldMap) -> String:
	if node == null or world_map == null:
		return ""
	return String(world_map.get_path_to(node))


static func _configs_to_save(configs: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for config in configs:
		var scene := config.get("scene") as PackedScene
		if scene == null:
			continue
		result.append({"scene_path": scene.resource_path, "data": config.get("data", {})})
	return result
