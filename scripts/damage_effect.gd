class_name DamageEffect
extends Effect

## Expression evaluated against source stats.
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health.
## Examples: "strength * 0.5", "15", "strength + agility * 0.3"
@export var damage_expression: String = "strength * 0.5"

var _eval := StatExprEval.new()


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	target.take_damage(_eval.evaluate(damage_expression, source))
