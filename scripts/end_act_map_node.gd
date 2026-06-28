class_name EndActMapNode
extends WorldMapNode

# --- End-of-Act Config ---

## Terminal node of an act: an end-of-act town hub (temple ascension + travel onward).
## Hand-placed in the world map; bypasses the floor event pool like ShopMapNode.

## The town/end-act event scene to load when this node is selected.
@export var shrine_scene: PackedScene

## Gold tithe charged at the temple to ascend to the next patron tier.
@export var ascension_cost: int = 100

## The next act's world map. Empty = this is the final act; travelling onward wins the run.
@export var next_act_scene: PackedScene


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	return [{ "scene": shrine_scene, "data": { "ascension_cost": ascension_cost } }]
