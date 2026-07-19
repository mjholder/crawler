class_name ChainDamageEffect
extends Effect

## Chain damage (Lightning's signature). The primary hit lands on the chosen target, then the
## bolt arcs to BOTH immediate array-adjacent enemies in the wave (the flankers) for a fraction
## of the damage. An end enemy has only one flanker; a lone survivor has none.
##
## "Adjacent" = index-adjacent among the target's living siblings under CombatEvent/$Enemies —
## the pragmatic placeholder until a real battlefield-position system exists. Self-contained:
## it reaches the roster through the scene tree (target.get_parent()), needing no combat-context
## plumbing. The player still picks the primary target through the normal single-target flow.
@export var damage_expression: String = "spirit * 0.5"
@export var pierce_expression: String = "0"
## Fraction of the primary damage dealt to the chained neighbor.
@export var chain_multiplier: float = 0.5

var _eval := StatExprEval.new()


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var dmg := _eval.evaluate(damage_expression, source)
	var pierce := _eval.evaluate(pierce_expression, source)
	target.take_damage(dmg, pierce)
	for neighbor in _find_neighbors(target):
		neighbor.take_damage(dmg * chain_multiplier, pierce)


## The living array-adjacent siblings on both sides of the target (left flanker, right flanker).
func _find_neighbors(target: Node) -> Array[Node]:
	var neighbors: Array[Node] = []
	var parent := target.get_parent()
	if parent == null:
		return neighbors
	var siblings := parent.get_children()
	var idx := siblings.find(target)
	if idx == -1:
		return neighbors
	for offset in [-1, 1]:
		var j: int = idx + offset
		if j >= 0 and j < siblings.size():
			var cand: Node = siblings[j]
			if cand != target and cand.has_method("take_damage") and not cand.get("is_dead"):
				neighbors.append(cand)
	return neighbors
