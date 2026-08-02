class_name StatusEffect
extends Effect

@export var status_data: StatusData = null

## How many stacks this application grants. Only meaningful for STACK-policy statuses
## (burn, poison, bleed) — e.g. a 3-stack burn hit that bursts 3/2/1.
@export var stacks: int = 1


func apply(source: Node, target: Node, crit_mult: float = 1.0, _context: Dictionary = {}) -> void:
	if target == null or status_data == null or not target.has_method("apply_status"):
		return
	# A crit doubles applied stacks. apply_status ignores the count for non-STACK policies,
	# so duration/control statuses get no free duration — exactly the strict-stacking rule.
	target.apply_status(status_data, source, int(stacks * crit_mult))
