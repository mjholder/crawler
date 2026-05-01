class_name RestMapNode
extends WorldMapNode

# --- Rest Config ---

@export var rest_scene: PackedScene


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	return [{ "scene": rest_scene, "data": { "heal_expression": "max_health" } }]
