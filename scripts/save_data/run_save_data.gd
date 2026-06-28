class_name RunSaveData extends Resource

const VERSION: int = 2

@export var version: int = VERSION
@export var saved_at_unix: int = 0

# Player + Inventory snapshot (Player.to_save_dict embeds inventory under "inventory" key)
@export var player: Dictionary = {}

# Current act number (1-based) and the world map scene currently loaded for it.
# active_act_scene_path lets Continue rebuild the correct map before applying node states.
@export var current_act: int = 1
@export var active_act_scene_path: String = "res://scenes/world_map.tscn"

# WorldMap node states keyed by path string relative to the WorldMap node
@export var world_map_node_states: Dictionary = {}

# Run flow
@export var game_state: int = 0               # Enums.GameState value
@export var active_world_node_path: String = ""  # empty = not in dungeon
@export var event_index: int = 0              # post-increment; passed directly to _enter_dungeon
@export var pending_event_configs: Array[Dictionary] = []  # [{scene_path, data}, ...]
