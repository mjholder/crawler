class_name HealthBar
extends Node2D

@export var base_health_sprite: Sprite2D
@export var current_health_sprite: Sprite2D

@export var max_health: float = 100
@export var current_health: float = 100

@export var default_dimensions: Vector2 = Vector2(64, 16)

func set_max_health(value: float) -> void:
	max_health = value
	set_current_health(current_health)  # Re-clamp current health to new max

func set_current_health(value: float) -> void:
	current_health = clamp(value, 0, max_health)
	var health_ratio: float = 0.0 if max_health <= 0 else current_health / max_health
	current_health_sprite.scale.x = health_ratio * default_dimensions.x

func subtract_health(amount: float) -> void:
	set_current_health(current_health - amount)

func add_health(amount: float) -> void:
	set_current_health(current_health + amount)