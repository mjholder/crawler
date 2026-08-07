class_name StackBonusRider
extends RiderData

## Adds flat stacks to the STACK-policy statuses this item's attacks apply (poison, bleed, burn).
## Threaded to StatusEffect via the weapon-anatomy context dict (ItemInstance.stack_bonus() ->
## ctx["bonus_stacks"]), it is folded in before the crit multiply, so a crit doubles (base + bonus)
## together — the interaction the design doc calls out (journal/ideas/equipment-tags-and-riders).
## On a STACK-policy DoT this compounds over a fight, so it is worth more on poison than on refreshing
## statuses; that asymmetry is intended, not a bug.

@export var bonus_stacks: int = 1
