class_name TagData
extends Resource

## A rolled bonus payload composed onto an ItemInstance at read time (rare tier and above; loot
## roll odds are deferred — see journal/ideas/luck-crit-loot-quality). A tag reuses the existing
## equipment vocabulary wholesale (stat_modifiers / proc_effects / conditional_modifiers) and adds
## the two weapon-anatomy axes on top. Tags are the only mutation path that may move BOTH power
## and scaling; smithing moves power alone, rarity scaling alone (see item_instance.gd, THE LAW).
##
## Riders (binary, rarity-gated behavior like "+1 status stack" or an innate spell on a focus) are
## a separate, deliberately non-numeric concept — parked, not modeled here
## (journal/ideas/equipment-tags-and-riders).

@export var tag_name: String = ""
@export var description: String = ""

## Weapon-anatomy deltas. power_delta shifts flat damage, scaling_delta the stat coefficient —
## e.g. "Fine Balance" raises scaling so every attack moves from X + STR*0.5 to X + STR.
@export var power_delta: float = 0.0
@export var scaling_delta: float = 0.0

## Summed onto the base's stat_modifiers (Enums.Stat -> float).
@export var stat_modifiers: Dictionary = {}
## Concatenated onto the base's proc_effects (Array[ProcDef]).
@export var proc_effects: Array[Resource] = []
## Concatenated onto the base's conditional_modifiers (Array[ConditionalModifier]).
@export var conditional_modifiers: Array[Resource] = []
