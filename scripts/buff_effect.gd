class_name BuffEffect
extends Effect

@export var stat: Enums.Stat = Enums.Stat.STRENGTH
@export var amount_expression: String = "5"
@export var duration: int = 3

var _eval := StatExprEval.new()


func apply(_source: Node, target: Node) -> void:
	if target == null or not target.has_method("apply_buff"):
		return
	target.apply_buff(stat, _eval.evaluate(amount_expression, target), duration)
