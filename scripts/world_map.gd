class_name WorldMap
extends Control

# --- Signals ---

signal node_selected(node: WorldMapNode)

# --- Graph ---

# Set in editor — nodes that become AVAILABLE at game start (first row)
@export var initial_nodes: Array[NodePath]

# Set to a non-zero value to produce a deterministic floor assignment for this run.
@export var run_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _floor_pool: FloorEventPool


func _ready() -> void:
	if run_seed != 0:
		_rng.seed = run_seed
	else:
		_rng.randomize()

	_floor_pool = FloorEventPool.new()
	_floor_pool.build()

	for child in $NodeContainer.get_children():
		if child is WorldMapNode:
			child.node_selected.connect(_on_node_selected)
		if child is DungeonMapNode:
			child.resolve_floor(_rng, _floor_pool)

	reset()


func reset() -> void:
	for child in $NodeContainer.get_children():
		if child is WorldMapNode:
			child.set_state(Enums.NodeState.LOCKED)
	for path in initial_nodes:
		var node := get_node(path) as WorldMapNode
		if node:
			node.set_state(Enums.NodeState.AVAILABLE)


# --- Public API ---

func to_state_dict() -> Dictionary:
	var result: Dictionary = {}
	for child in $NodeContainer.get_children():
		if child is WorldMapNode:
			result[String(get_path_to(child))] = child.state as int
	return result


func apply_state_dict(d: Dictionary) -> void:
	for path_str in d:
		var node := get_node_or_null(NodePath(path_str)) as WorldMapNode
		if node == null:
			push_warning("[WorldMap] Saved node path not found: %s — save may be stale" % path_str)
			continue
		node.set_state(d[path_str])


func get_world_map_node(path_str: String) -> WorldMapNode:
	return get_node_or_null(NodePath(path_str)) as WorldMapNode


func on_dungeon_complete(completed_node: WorldMapNode) -> void:
	completed_node.set_state(Enums.NodeState.COMPLETED)
	for path in completed_node.connected_nodes:
		var next := completed_node.get_node(path) as WorldMapNode
		if next and next.state == Enums.NodeState.LOCKED:
			next.set_state(Enums.NodeState.AVAILABLE)


# --- Signal Handlers ---

func _on_node_selected(node: WorldMapNode) -> void:
	for child in $NodeContainer.get_children():
		if child is WorldMapNode and child != node and child.state == Enums.NodeState.AVAILABLE:
			child.set_state(Enums.NodeState.LOCKED)
	node_selected.emit(node)
