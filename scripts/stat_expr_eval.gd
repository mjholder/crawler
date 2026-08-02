class_name StatExprEval
extends RefCounted

## Evaluates a GDScript Expression string against a character node's stats.
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health,
## plus weapon-anatomy variables power, scaling, scale, coeff (bound from the optional `context`
## dict — the acting weapon's effective power/scaling, its scaling stat's value, and the resolved
## per-attack coefficient). power/scaling/scale default to 0 when absent; `coeff` defaults to 1.0
## since it is a MULTIPLIER (its identity is 1, not 0).

const VARS := [
	"strength", "defense", "constitution", "agility", "spirit", "luck",
	"max_health", "health", "power", "scaling", "scale", "coeff"
]

var _expr: Expression = null
var _compiled_for: String = ""


func evaluate(expression: String, node: Node, context: Dictionary = {}) -> float:
	if _expr == null or _compiled_for != expression:
		_expr = Expression.new()
		var err := _expr.parse(expression, VARS)
		if err != OK:
			push_warning("StatExprEval: parse failed for '%s'" % expression)
			return 0.0
		_compiled_for = expression
	var result = _expr.execute(_build_values(node, context))
	if _expr.has_execute_failed():
		push_warning("StatExprEval: exec failed for '%s'" % expression)
		return 0.0
	return float(result)


func _build_values(node: Node, context: Dictionary = {}) -> Array:
	var values: Array = []
	if node != null and node.has_method("get_effective_stat"):
		values = [
			node.get_effective_stat(Enums.Stat.STRENGTH),
			node.get_effective_stat(Enums.Stat.DEFENSE),
			node.get_effective_stat(Enums.Stat.CONSTITUTION),
			node.get_effective_stat(Enums.Stat.AGILITY),
			node.get_effective_stat(Enums.Stat.SPIRIT),
			node.get_effective_stat(Enums.Stat.LUCK),
		]
	else:
		values = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var mh = node.get("max_health") if node != null else null
	var hp = node.get("health") if node != null else null
	values.append(float(mh) if mh != null else 0.0)
	values.append(float(hp) if hp != null else 0.0)
	# Weapon-anatomy vars — default 0.0 so stat-only expressions and spells are unaffected.
	values.append(float(context.get("power", 0.0)))
	values.append(float(context.get("scaling", 0.0)))
	values.append(float(context.get("scale", 0.0)))
	# `coeff` is a multiplier, so its absent-default is 1.0 (identity), not 0.0.
	values.append(float(context.get("coeff", 1.0)))
	return values
