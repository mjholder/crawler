class_name AttackData
extends Resource

enum TargetMode { SINGLE_ENEMY, ALL_ENEMIES, SELF }

@export var attack_name: String = ""
@export var description: String = ""
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY
@export var cooldown: int = 0  # player turns until reusable; 0 = no cooldown
## Per-attack shape multiplier on the weapon's `power` term — the `coeff` var in damage expressions
## (`power * coeff + scale * scaling`). 1.0 = the weapon's flat power as-is. Authored here so a heavy
## move can hit harder than a jab without a bespoke effect. Buffs raise it at runtime, additively
## and/or multiplicatively (see Combatant.get_attack_coeff_add / _mult, AttackCoeffBuffEffect), which
## is the player-facing "buff my damage" lever. Defaults to 1.0 — most attacks never override it.
@export var power_coefficient: float = 1.0
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var sound: AudioStream
