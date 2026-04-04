class_name WorldMap
extends Control

# --- Signals ---

signal node_selected(node: WorldMapNode)

# --- Graph ---

# Set in editor — nodes that become AVAILABLE at game start (first row)
@export var initial_nodes: Array[NodePath]


func _ready() -> void:
	for child in $NodeContainer.get_children():
		if child is WorldMapNode:
			child.set_state(Enums.NodeState.LOCKED)
			child.node_selected.connect(_on_node_selected)

	for path in initial_nodes:
		var node := get_node(path) as WorldMapNode
		if node:
			node.set_state(Enums.NodeState.AVAILABLE)


# --- Public API ---

func on_dungeon_complete(completed_node: WorldMapNode) -> void:
	completed_node.set_state(Enums.NodeState.COMPLETED)
	for path in completed_node.connected_nodes:
		var next := completed_node.get_node(path) as WorldMapNode
		if next and next.state == Enums.NodeState.LOCKED:
			next.set_state(Enums.NodeState.AVAILABLE)


# --- Signal Handlers ---

func _on_node_selected(node: WorldMapNode) -> void:
	node_selected.emit(node)
