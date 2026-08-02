class_name AttackData
extends ActionData

## Per-attack shape multiplier on the weapon's `power` term — the `coeff` var in damage expressions
## (`power * coeff + scale * scaling`). 1.0 = the weapon's flat power as-is. Authored here so a heavy
## move can hit harder than a jab without a bespoke effect. Buffs raise it at runtime, additively
## and/or multiplicatively (see Combatant.get_attack_coeff_add / _mult, PowerBuffEffect), which
## is the player-facing "buff my damage" lever. Defaults to 1.0 — most attacks never override it.
@export var power_coefficient: float = 1.0
