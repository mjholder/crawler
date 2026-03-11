class_name HealthBar
extends Node2D

@export var base_health_sprite: Sprite2D
@export var current_health_sprite: Sprite2D

@export var max_health: float = 100
@export var current_health: float = 100

@export var default_dimensions: Vector2 = Vector2(64, 16)

func set_max_health(value: float) -> void:
	max_health = value
	current_health = min(current_health, max_health)

func set_current_health(value: float) -> void:
	current_health = clamp(value, 0, max_health)

func subtract_health(amount: float) -> void:
	set_current_health(current_health - amount)

func add_health(amount: float) -> void:
	set_current_health(current_health + amount)