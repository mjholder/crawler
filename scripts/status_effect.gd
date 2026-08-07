class_name StatusEffect
extends Effect

@export var status_data: StatusData = null

## How many stacks this application grants. Only meaningful for STACK-policy statuses
## (burn, poison, bleed) — e.g. a 3-stack burn hit that bursts 3/2/1.
@export var stacks: int = 1


func apply(source: Node, target: Node, crit_mult: float = 1.0, _context: Dictionary = {}) -> void:
	if target == null or status_data == null or not target.has_method("apply_status"):
		return
	# Stack-bonus riders add flat stacks via the weapon context (0 when absent). Folded in before the
	# crit multiply so a crit doubles (base + bonus) together — the intended rider/crit interaction.
	var bonus := int(_context.get("bonus_stacks", 0))
	# Potency riders add flat per-stack tick damage. It is a fixed property of the edge, not a stack,
	# so it rides straight onto the instance uncrit — a lucky strike deepens stacks, not potency.
	var potency := int(_context.get("potency_bonus", 0))
	# A crit doubles applied stacks. apply_status ignores the count for non-STACK policies,
	# so duration/control statuses get no free duration — exactly the strict-stacking rule.
	target.apply_status(status_data, source, int((stacks + bonus) * crit_mult), potency)
