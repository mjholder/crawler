class_name ShopMapNode
extends WorldMapNode

# --- Shop Config ---

@export var shop_scene: PackedScene
@export var shop_data: ShopData


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	return [{ "scene": shop_scene, "data": { "shop": shop_data } }]
