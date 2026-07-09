class_name ChainDamageEffect
extends Effect

## Chain damage (Lightning's signature). The primary hit lands on the chosen target, then the
## bolt arcs to one array-adjacent enemy in the wave for a fraction of the damage.
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
	var neighbor := _find_neighbor(target)
	if neighbor != null:
		neighbor.take_damage(dmg * chain_multiplier, pierce)


## The nearest living array-adjacent sibling (next preferred, then previous).
func _find_neighbor(target: Node) -> Node:
	var parent := target.get_parent()
	if parent == null:
		return null
	var siblings := parent.get_children()
	var idx := siblings.find(target)
	if idx == -1:
		return null
	for offset in [1, -1]:
		var j: int = idx + offset
		if j >= 0 and j < siblings.size():
			var cand: Node = siblings[j]
			if cand != target and cand.has_method("take_damage") and not cand.get("is_dead"):
				return cand
	return null
