class_name StatExprEval
extends RefCounted

## Evaluates a GDScript Expression string against a character node's stats.
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health.

const VARS := [
	"strength", "defense", "constitution", "agility", "spirit", "luck",
	"max_health", "health"
]

var _expr: Expression = null
var _compiled_for: String = ""


func evaluate(expression: String, node: Node) -> float:
	if _expr == null or _compiled_for != expression:
		_expr = Expression.new()
		var err := _expr.parse(expression, VARS)
		if err != OK:
			push_warning("StatExprEval: parse failed for '%s'" % expression)
			return 0.0
		_compiled_for = expression
	var result = _expr.execute(_build_values(node))
	if _expr.has_execute_failed():
		push_warning("StatExprEval: exec failed for '%s'" % expression)
		return 0.0
	return float(result)


func _build_values(node: Node) -> Array:
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
	return values
