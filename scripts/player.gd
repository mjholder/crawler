class_name Player
extends Node2D

# --- Signals ---
signal damaged(amount: float)
signal died
signal turn_ended

# --- Stats ---
@export var player_name: String = "Player"
@export var max_health: float = 100.0
@export var attack_damage: float = 10.0

# --- State ---
var health: float
var is_dead: bool = false


func _ready() -> void:
	health = max_health


# --- Turn ---

func attack(target: Node) -> void:
	if is_dead:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	turn_ended.emit()


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	damaged.emit(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	died.emit()
