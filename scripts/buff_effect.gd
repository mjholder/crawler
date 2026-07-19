class_name BuffEffect
extends Effect

@export var stat: Enums.Stat = Enums.Stat.STRENGTH
@export var amount_expression: String = "5"
@export var duration: int = 3
## Optional per-buff icon. When null, falls back to the regen icon so the runtime-built
## status still shows up in the status strip instead of an invisible slot.
@export var icon: Texture2D = null

var _eval := StatExprEval.new()

# Reused as the default status icon (regen already carves its 32x32 region out of the
# shared status-sheet atlas) so we don't re-declare the atlas region here.
const _DEFAULT_ICON := preload("res://resources/effects/statuses/regen.tres")


func apply(source: Node, target: Node) -> void:
	if target == null or not target.has_method("apply_status"):
		return
	var amount := _eval.evaluate(amount_expression, target)
	var data := StatusData.new()
	data.tag = StringName("buff_" + Enums.Stat.keys()[stat].to_lower())
	data.display_name = "%s %s" % [_format_amount(amount), Enums.Stat.keys()[stat].capitalize()]
	data.icon = icon if icon != null else _DEFAULT_ICON.icon
	data.duration = duration
	data.stat_modifiers = {stat: amount}
	data.stack_policy = StatusData.StackPolicy.REFRESH
	target.apply_status(data, source)


# Signed, whole numbers drop the decimals ("+20"), fractional amounts keep one ("+2.5").
func _format_amount(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "%+d" % int(roundf(amount))
	return "%+.1f" % amount
