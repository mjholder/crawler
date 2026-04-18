class_name BossMapNode
extends WorldMapNode

# --- Boss Config ---

@export var boss_scene: PackedScene
@export var boss_data_json_path: String


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	var boss_data := _load_json(boss_data_json_path)
	return [{ "scene": boss_scene, "data": boss_data }]
