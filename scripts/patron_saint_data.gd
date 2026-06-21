class_name PatronSaintData
extends Resource

## "What watches over you" — a character-creation layer alongside class and background.
## A divine contract that evolves across the run's three acts. Each saint is a
## lineage of three BlessingData tiers; act transitions swap the active tier
## (Phase 2 shrine ascension). Triggers are conditional and dramatic, not passive
## stat bumps, and higher tiers carry a steeper tithe.

@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null

## Shared id tying this saint's tiers together. Each entry in `tiers` should
## carry the same lineage_id so the runtime can identify the active saint tier.
@export var lineage_id: StringName = &""

## The three tiers, act-indexed: 0 = Act 1, 1 = Act 2, 2 = Act 3.
## Tier 0 is granted at character creation; later tiers via shrine ascension.
@export var tiers: Array[BlessingData] = []
