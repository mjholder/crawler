class_name SpellData
extends ActionData

@export var mana_cost: float = 0.0
## Flat authored spell power — the caster-side counterpart to WeaponData.power. Spells flow through
## the same uniform damage form as weapons (`power * coeff + scale * scaling`), but with no stat term
## (scale/scaling resolve to 0), so a spell's damage is this flat number, carried by the spell itself.
## SPI gates mana, not spell damage — see journal/ideas/mana-as-capacity.md.
@export var power: float = 0.0
