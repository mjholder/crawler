class_name SpellData
extends Resource

@export var spell_name: String = ""
@export var description: String = ""
@export var mana_cost: float = 0.0
@export var target_mode: AttackData.TargetMode = AttackData.TargetMode.SINGLE_ENEMY
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var cast_sfx: AudioStream
