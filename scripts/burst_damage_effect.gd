class_name BurstDamageEffect
extends DamageEffect

## Burst damage-over-time (Fire's signature). Damage scales with the status's remaining
## duration, so an authored `duration: 3` burn hits 3 → 2 → 1 as it decays, then expires.
##
## Used as a status's `on_tick`. Combatant._tick_statuses calls apply_tick BEFORE decrementing
## turns_remaining, so the first tick correctly sees the full duration (3, not 2).
##
## `damage_expression` is the per-remaining-turn amount (evaluated against source stats): author
## a flat "1" for a clean 3/2/1 curve, or "spirit * 0.1" to scale the whole burst by a stat.
## Inherits `pierce_expression` from DamageEffect. The whole burst also scales by stack count.


func apply_tick(source: Node, target: Node, instance: StatusInstance) -> void:
	if instance == null or target == null or not target.has_method("take_damage"):
		return
	# Potency deepens each per-turn bite (harder ticks), same as the poison/bleed tick — added before
	# the turn/stack multiplies so a PotencyRider raises the whole burst without extending it.
	var per_turn := _eval.evaluate(damage_expression, source) + float(instance.potency)
	var pierce := _eval.evaluate(pierce_expression, source)
	target.take_damage(per_turn * float(instance.turns_remaining) * float(instance.stacks), pierce, false, false)
