class_name ConditionalModifier
extends Resource

@export var stat: Enums.Stat = Enums.Stat.STRENGTH
@export var amount_expression: String = "10"
# Evaluated via StatExprEval against the holder; truthy (> 0) enables the modifier.
# Available vars: strength, defense, constitution, agility, spirit, luck, max_health, health.
@export var guard_expression: String = "1"
