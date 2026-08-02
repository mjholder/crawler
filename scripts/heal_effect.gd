class_name HealEffect
extends Effect

## Expression evaluated against target stats (the character being healed).
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health.
## Examples: "50", "max_health * 0.5", "spirit * 3 + 10"
@export var heal_expression: String = "max_health * 0.25"

var _eval := StatExprEval.new()


func apply(_source: Node, target: Node, _crit_mult: float = 1.0, context: Dictionary = {}) -> void:
	if target == null or not target.has_method("heal"):
		return
	target.heal(_eval.evaluate(heal_expression, target, context))
