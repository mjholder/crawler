class_name WeightedEntry
extends Resource

@export var event: Resource
@export_enum("combat", "boss", "dialogue", "skill_check", "rest") var event_type: int = 0
@export var weight: int = 1
