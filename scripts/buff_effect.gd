class_name BuffEffect
extends Effect

@export var stat: Enums.Stat = Enums.Stat.STRENGTH
@export var amount_expression: String = "5"
@export var duration: int = 3

var _eval := StatExprEval.new()


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("apply_status"):
		return
	var data := StatusData.new()
	data.tag = StringName("buff_" + Enums.Stat.keys()[stat].to_lower())
	data.display_name = "Buff"
	data.duration = duration
	data.stat_modifiers = {stat: _eval.evaluate(amount_expression, target)}
	data.stack_policy = StatusData.StackPolicy.REFRESH
	target.apply_status(data, source)
