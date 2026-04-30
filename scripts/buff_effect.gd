class_name BuffEffect
extends Effect

@export var stat: Enums.Stat = Enums.Stat.STRENGTH
@export var amount_expression: String = "5"
@export var duration: int = 3

const _EXPR_VARS := [
	"strength", "defense", "constitution", "agility", "spirit", "luck",
	"max_health", "health"
]

var _expr: Expression = null
var _expr_compiled_for: String = ""


func apply(_source: Node, target: Node) -> void:
	if target == null or not target.has_method("apply_buff"):
		return
	target.apply_buff(stat, _evaluate(target), duration)


func _evaluate(target: Node) -> float:
	if _expr == null or _expr_compiled_for != amount_expression:
		_expr = Expression.new()
		var err := _expr.parse(amount_expression, _EXPR_VARS)
		if err != OK:
			push_warning("BuffEffect: parse failed for '%s'" % amount_expression)
			return 0.0
		_expr_compiled_for = amount_expression
	var values: Array = _build_values(target)
	var result = _expr.execute(values)
	if _expr.has_execute_failed():
		push_warning("BuffEffect: exec failed for '%s'" % amount_expression)
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
