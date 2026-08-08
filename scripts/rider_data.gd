class_name RiderData
extends Resource

## A binary behavior composed onto an ItemInstance at read time — the non-numeric counterpart to
## TagData (journal/ideas/equipment-tags-and-riders). Where a tag rolls numbers
## (power/scaling/stat_modifiers), a rider grants a discrete capability that a smithed common can
## never match, because commons simply don't carry riders. Keeping riders off commons is what keeps
## "smithing moves power, rarity moves scaling" intact.
##
## `rarity` here is METADATA, not a runtime gate: it classifies which rarity pool this rider belongs
## to. Generation grabs a rider from the pool matching the item's rolled rarity and attaches it (see
## RiderPool); once attached, a rider always applies — ItemInstance.effective_riders() no longer
## re-checks rarity. This lets an item draw richer behavior as its rarity climbs without any rider
## silently sitting inert on the instance.
##
## Riders are a polymorphic family (like the Effect family): this base carries only the identity and
## the pool tag; concrete subclasses (StackBonusRider, InnateSpellRider) carry the behavior.

@export var rider_name: String = ""
@export var description: String = ""

## Which rarity pool this rider belongs to — metadata used at generation time to draw riders from a
## pool matching the item's rolled rarity (RiderPool). Not a runtime activation gate. Riders never
## belong to the COMMON pool; RARE is the conventional floor.
@export var rarity: Enums.Rarity = Enums.Rarity.RARE
