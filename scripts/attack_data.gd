class_name AttackData
extends Resource

enum TargetMode { SINGLE_ENEMY, ALL_ENEMIES, SELF }

@export var attack_name: String = ""
@export var description: String = ""
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var sound: AudioStream
