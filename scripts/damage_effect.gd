class_name DamageEffect
extends Effect

## Expression evaluated against source stats.
## Available variables: strength, defense, constitution, agility, spirit, luck, max_health, health.
## Examples: "strength * 0.5", "15", "strength + agility * 0.3"
@export var damage_expression: String = "strength * 0.5"

## Armor pierce, as a 0–1 ratio (Frost's signature; also a general damage-shape lever): that
## share of the hit is sent straight to HP, bypassing the armor buffer; the rest hits armor
## normally. Author in quarters — 0.5 is the default for a piercing attack, 1.0 ignores armor
## entirely. Evaluated against source stats and clamped to [0, 1] on use. "0" = none.
@export var pierce_expression: String = "0"

## When true, the TICK variant deals damage straight to health, skipping the armor buffer
## entirely (poison/bleed signature — a DoT in the blood is not soaked by armor, and the
## per-round armor refresh would otherwise erase a small tick before it ever reached HP).
## Only affects apply_tick; direct apply() hits still respect armor.
@export var bypass_armor: bool = false

var _eval := StatExprEval.new()


func apply(source: Node, target: Node, crit_mult: float = 1.0, context: Dictionary = {}) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var dmg := _eval.evaluate(damage_expression, source, context) * crit_mult
	target.take_damage(dmg, _eval.evaluate(pierce_expression, source, context), false, true, crit_mult > 1.0)


## Tick variant: one scaled hit per turn, multiplied by the status's stack count (poison/bleed/
## burn). A 3-damage poison at 3 stacks deals 9 in a single take_damage call — not three ticks.
## A PotencyRider's `potency` adds flat per-stack damage before the stack multiply, so it deepens
## every tick (harder ticks) without touching lifetime (stacks) — the orthogonal DoT lever.
func apply_tick(source: Node, target: Node, instance: StatusInstance) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var stacks: int = instance.stacks if instance != null else 1
	var potency: int = instance.potency if instance != null else 0
	var per_stack := _eval.evaluate(damage_expression, source) + float(potency)
	target.take_damage(per_stack * float(stacks), _eval.evaluate(pierce_expression, source), bypass_armor, false)
