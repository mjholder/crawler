class_name PotencyRider
extends RiderData

## Deepens the STACK-policy statuses this item's attacks apply (poison, bleed, burn): each tick bites
## harder without the affliction lasting any longer. Where StackBonusRider adds stacks (more turns,
## higher ramp), a PotencyRider adds a flat per-stack bonus to the DoT's tick damage — the orthogonal
## lever (journal/ideas/equipment-tags-and-riders): potency = harder ticks, same duration.
##
## Threaded to StatusEffect via the weapon context (ItemInstance.potency_bonus() -> ctx["potency_bonus"])
## and stored on the StatusInstance so it persists across the DoT's remaining ticks (the weapon context
## is gone by tick time). Unlike stacks it is NOT crit-scaled — potency is a fixed property of the edge,
## not something a lucky strike deepens (that is stacks' job).

@export var potency_bonus: int = 1
