class_name ActionData
extends Resource

## Shared base for the two things the player can DO on a turn: a weapon attack (AttackData) and a
## spell cast (SpellData). Both are a named, targeted bundle of effects with a cooldown, an icon,
## and a sound — the only difference is the anatomy knob each adds on top (AttackData carries the
## per-attack `power_coefficient`; SpellData carries flat `power` + `mana_cost`). Damage for both
## flows through the uniform form `power * coeff + scale * scaling` (see
## journal/ideas/weapon-anatomy-power-and-scaling.md). Keeping the carrier in one place is DRY —
## preview, targeting, and UI read these fields without caring which subclass they hold.

enum TargetMode { SINGLE_ENEMY, ALL_ENEMIES, SELF }

@export var display_name: String = ""
@export var description: String = ""
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY
@export var cooldown: int = 0  # player turns until reusable; 0 = no cooldown
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var sound: AudioStream
