class_name DamageEffect
extends Effect

## Expression evaluated against source stats.
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health.
## Examples: "strength * 0.5", "15", "strength + agility * 0.3"
@export var damage_expression: String = "strength * 0.5"

## Armor pierce: reduces how much of the target's armor buffer can absorb THIS hit (Frost's
## signature; also a general damage-shape lever). Evaluated against source stats. "0" = none.
@export var pierce_expression: String = "0"

var _eval := StatExprEval.new()


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	target.take_damage(_eval.evaluate(damage_expression, source), _eval.evaluate(pierce_expression, source))
