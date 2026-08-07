class_name RiderData
extends Resource

## A binary, rarity-gated behavior composed onto an ItemInstance at read time — the non-numeric
## counterpart to TagData (journal/ideas/equipment-tags-and-riders). Where a tag rolls numbers
## (power/scaling/stat_modifiers), a rider grants a discrete capability that a smithed common can
## never match, because commons simply don't carry riders. That gate is what keeps "smithing moves
## power, rarity moves scaling" intact.
##
## Riders are a polymorphic family (like the Effect family): this base carries only the identity and
## the gate; concrete subclasses (StackBonusRider, InnateSpellRider) carry the behavior. The gate is
## enforced in one place — ItemInstance.effective_riders() — so a rider whose min_rarity exceeds the
## instance's rarity simply does not apply.

@export var rider_name: String = ""
@export var description: String = ""

## Minimum instance rarity for this rider to apply. Riders never roll on commons; RARE is the floor.
@export var min_rarity: Enums.Rarity = Enums.Rarity.RARE
