class_name WeaponData
extends EquipmentData

@export var attack_sfx: AudioStream
@export var innate_spells: Array[Resource] = []
@export var is_two_handed: bool = false
## Which hand(s) this weapon may be equipped into. Default MAINHAND_ONLY preserves every
## existing weapon. EITHER lets the player pick a hand at equip time; OFFHAND_ONLY forces
## the offhand.
@export var hand_restriction: Enums.HandRestriction = Enums.HandRestriction.MAINHAND_ONLY
## Supporting offhand action(s) a two-handed weapon grants to the hand it *locks*. When this
## weapon locks the OFFHAND slot, these populate the locked offhand's action group (e.g. a
## SELF buff or a bonus attack). Empty means the offhand is idle while a two-hander is equipped.
## NOTE: this is what the *locked* offhand does while THIS weapon sits in the mainhand — not
## what this weapon does when it is itself placed in the offhand (that is as_offhand_attacks).
@export var locked_offhand_attacks: Array[Resource] = []  # Array[AttackData]
## The hand's moveset when THIS weapon is equipped into the OFFHAND slot. Empty falls back to
## the weapon's normal `attacks`. Only meaningful for weapons flagged EITHER / OFFHAND_ONLY.
@export var as_offhand_attacks: Array[Resource] = []  # Array[AttackData]
