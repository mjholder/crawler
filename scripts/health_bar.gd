class_name HealthBar
extends Node2D

@export var base_health_sprite: Sprite2D
@export var current_health_sprite: Sprite2D
## Optional overlay for the per-round armor buffer, drawn just above the health strip.
## Hidden whenever max_armor <= 0 (enemy has no DEF).
@export var armor_sprite: Sprite2D

@export var max_health: float = 100
@export var current_health: float = 100

@export var max_armor: float = 0
@export var current_armor: float = 0

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

func set_armor(value: float, maximum: float) -> void:
	max_armor = maximum
	current_armor = clamp(value, 0, max_armor)
	if armor_sprite == null:
		return
	armor_sprite.visible = max_armor > 0
	var armor_ratio: float = 0.0 if max_armor <= 0 else current_armor / max_armor
	armor_sprite.scale.x = armor_ratio * default_dimensions.x
