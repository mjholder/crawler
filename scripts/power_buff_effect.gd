class_name PowerBuffEffect
extends Effect

## Buffs the bearer's outgoing damage on the uniform form `(power + Σ power_add) * coeff + scale *
## scaling`, for a number of turns — the player-facing "buff my damage" lever. Three modes cover
## every knob the term exposes:
##   POWER_ADD  — flat bonus power, independent of weapon power (StatusData.power_add). "+5 Power".
##   COEFF_ADD  — additive on the coefficient, i.e. a share of power (StatusData.coefficient_add).
##                0.3 = +30% of the weapon's power. "+30% Power".
##   COEFF_MULT — multiplicative on the coefficient (StatusData.coefficient_mult). 1.3 = "×1.3 Power".
## The add modes stack additively across active statuses; the mult modes multiply. Author on a SELF
## action to self-buff. Mirrors BuffEffect's status construction; magnitude is fixed per application
## (stacks drive duration, not strength), matching how buffs aggregate in Combatant.

enum Mode { POWER_ADD, COEFF_ADD, COEFF_MULT }

@export var mode: Mode = Mode.POWER_ADD
## The buff magnitude. Expression so it can scale off the caster's stats if desired; evaluated
## against the target (the bearer). POWER_ADD: flat power (e.g. 5). COEFF_ADD: coefficient delta
## (e.g. 0.3 = +30% power). COEFF_MULT: the factor (e.g. 1.3).
@export var amount_expression: String = "5"
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
	match mode:
		Mode.COEFF_MULT:
			data.tag = &"buff_attack_coeff_mult"
			data.coefficient_mult = amount
			data.display_name = "×%s Power" % _fmt(amount)
		Mode.COEFF_ADD:
			data.tag = &"buff_attack_coeff_add"
			data.coefficient_add = amount
			data.display_name = "%s%% Power" % _fmt_signed(amount * 100.0)
		_:
			data.tag = &"buff_power_add"
			data.power_add = amount
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
