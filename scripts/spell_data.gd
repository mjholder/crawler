class_name SpellData
extends Resource

@export var spell_name: String = ""
@export var description: String = ""
@export var mana_cost: float = 0.0
## Flat authored spell power — the caster-side counterpart to WeaponData.power. Spells flow through
## the same uniform damage form as weapons (`power * coeff + scale * scaling`), but with no stat term
## (scale/scaling resolve to 0), so a spell's damage is this flat number, carried by the spell itself.
## SPI gates mana, not spell damage — see journal/ideas/mana-as-capacity.md.
@export var power: float = 0.0
@export var target_mode: AttackData.TargetMode = AttackData.TargetMode.SINGLE_ENEMY
@export var cooldown: int = 0  # player turns until reusable; 0 = no cooldown
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var cast_sfx: AudioStream
