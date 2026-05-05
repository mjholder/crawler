class_name RunSaveData extends Resource

const VERSION: int = 1

@export var version: int = VERSION
@export var saved_at_unix: int = 0

# Player + Inventory snapshot (Player.to_save_dict embeds inventory under "inventory" key)
@export var player: Dictionary = {}

# WorldMap node states keyed by path string relative to the WorldMap node
@export var world_map_node_states: Dictionary = {}

# Run flow
@export var game_state: int = 0               # Enums.GameState value
@export var active_world_node_path: String = ""  # empty = not in dungeon
@export var event_index: int = 0              # post-increment; passed directly to _enter_dungeon
@export var pending_event_configs: Array[Dictionary] = []  # [{scene_path, data}, ...]
