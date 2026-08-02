class_name AttackCoeffBuffEffect
extends Effect

## Buffs the bearer's attack coefficient — the `coeff` in `power * coeff + scale * scaling` — for a
## number of turns, giving the player a lever to boost outgoing damage. ADD feeds the additive pool
## (coeff = base_K + Σ add), MULTIPLY feeds the product (coeff = ... * Π mult); both compose, so an
## additive and a multiplicative buff can be active at once. Author on a SELF action to self-buff.
##
## Mirrors BuffEffect's status construction. The magnitude is fixed per application (stacks drive
## duration, not strength), matching how stat buffs aggregate in Combatant.

enum Mode { ADD, MULTIPLY }

@export var mode: Mode = Mode.ADD
## ADD: how much to add to the coefficient (e.g. 0.3). MULTIPLY: the factor (e.g. 1.3). Expression
## so it can scale off the caster's stats if desired; evaluated against the target (the bearer).
@export var amount_expression: String = "0.3"
@export var duration: int = 3
## Optional per-buff icon; falls back to the shared regen icon so the buff still shows in the strip.
@export var icon: Texture2D = null

var _eval := StatExprEval.new()

const _DEFAULT_ICON := preload("res://resources/effects/statuses/regen.tres")


func apply(source: Node, target: Node, crit_mult: float = 1.0, context: Dictionary = {}) -> void:
	if target == null or not target.has_method("apply_status"):
		return
	var amount := _eval.evaluate(amount_expression, target, context)
	var data := StatusData.new()
	if mode == Mode.MULTIPLY:
		data.tag = &"buff_attack_coeff_mult"
		data.coefficient_mult = amount
		data.display_name = "×%s Power" % _fmt(amount)
	else:
		data.tag = &"buff_attack_coeff_add"
		data.coefficient_add = amount
		data.display_name = "%s Power" % _fmt_signed(amount)
	data.icon = icon if icon != null else _DEFAULT_ICON.icon
	data.duration = duration
	# Buffs live one turn per stack; a crit doubles the stacks, so a crit buff lasts twice as long.
	data.stack_decays = true
	target.apply_status(data, source, int(round(duration * crit_mult)))


func _fmt(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "%d" % int(roundf(amount))
	return "%.2f" % amount


func _fmt_signed(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "%+d" % int(roundf(amount))
	return "%+.2f" % amount
