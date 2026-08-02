class_name BraceEffect
extends Effect

## One-round armor bump (Brace's signature). Adds flat armor to the current buffer (clamped to
## a raised max) by touching armor/max_armor directly rather than routing through a stat buff.
## Naturally resets next round when refresh_armor recomputes max_armor from DEFENSE — and claws
## back armor even when Shatter has suppressed that round's refresh. Author on a SELF-target
## attack. `amount_expression` is evaluated against the bracing combatant's stats.
@export var amount_expression: String = "defense * 0.5"

var _eval := StatExprEval.new()


func apply(source: Node, target: Node, _crit_mult: float = 1.0, context: Dictionary = {}) -> void:
	if target == null or target.get("max_armor") == null:
		return
	var amount := _eval.evaluate(amount_expression, source, context)
	if amount <= 0.0:
		return
	var new_max: float = float(target.get("max_armor")) + amount
	var new_armor: float = minf(float(target.get("armor")) + amount, new_max)
	target.set("max_armor", new_max)
	target.set("armor", new_armor)
	if target.has_signal("armor_changed"):
		target.emit_signal("armor_changed", new_armor, new_max)
