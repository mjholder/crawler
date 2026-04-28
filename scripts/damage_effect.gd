class_name DamageEffect
extends Effect

## Expression evaluated against source stats.
## Available variables: strength, defense, constitution, agility, spirit, luck.
## Examples: "strength * 0.5", "5", "strength + agility * 0.3"
@export var damage_expression: String = "strength * 0.5"

const _STAT_VARS := ["strength", "defense", "constitution", "agility", "spirit", "luck"]

var _expr: Expression = null
var _expr_compiled_for: String = ""


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	target.take_damage(_evaluate(source))


func _evaluate(source: Node) -> float:
	if _expr == null or _expr_compiled_for != damage_expression:
		_expr = Expression.new()
		var err := _expr.parse(damage_expression, _STAT_VARS)
		if err != OK:
			push_warning("DamageEffect: parse failed for '%s'" % damage_expression)
			return 0.0
		_expr_compiled_for = damage_expression
	var values: Array = []
	if source != null and source.has_method("get_effective_stat"):
		for stat_name in _STAT_VARS:
			values.append(source.get_effective_stat(Enums.Stat[stat_name.to_upper()]))
	else:
		values = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var result = _expr.execute(values)
	if _expr.has_execute_failed():
		push_warning("DamageEffect: exec failed for '%s'" % damage_expression)
		return 0.0
	return float(result)
