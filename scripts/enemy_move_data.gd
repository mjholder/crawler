class_name EnemyMoveData
extends Resource

enum Target { PLAYER, SELF }

@export var move_name: String = ""
@export var description: String = ""
@export var target: Target = Target.PLAYER
@export var effects: Array[Resource] = []
@export var icon: Texture2D
@export var sound: AudioStream
