class_name GatedBleedEffect
extends Effect

## Gated composite (Bleed's signature). Deals damage, then applies `status_data` ONLY if the
## hit actually reduced the target's HP. Fully-absorbed hits don't bleed; overflow past armor —
## or an explicit `pierce` — does. Pairing pierce with bleed reliably bleeds a fully-armored
## target a normal hit couldn't touch.
##
## Self-contained: it observes target.health before/after its own take_damage call, so no shared
## awareness with sibling attack effects is needed. Author `status_data` as a duration:-1,
## persistence:COMBAT status (never ticks down, cleared at combat end).
@export var damage_expression: String = "strength * 0.5"
## Armor pierce as a 0–1 ratio (share of the hit sent straight to HP). See DamageEffect. "0" = none.
@export var pierce_expression: String = "0"
@export var status_data: StatusData = null

var _eval := StatExprEval.new()


func apply(source: Node, target: Node, crit_mult: float = 1.0) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var hp_before := _health_of(target)
	var dmg := _eval.evaluate(damage_expression, source) * crit_mult
	var pierce := _eval.evaluate(pierce_expression, source)
	target.take_damage(dmg, pierce, false, true, crit_mult > 1.0)
	var hp_after := _health_of(target)
	# A crit doubles the applied bleed stacks too (the Saint of Ambush synergy).
	if status_data != null and hp_after < hp_before and target.has_method("apply_status"):
		target.apply_status(status_data, source, int(crit_mult))


func _health_of(target: Node) -> float:
	var hp = target.get("health")
	return float(hp) if hp != null else 0.0
