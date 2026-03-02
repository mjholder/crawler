class_name Enemy
extends Node2D

# --- Signals ---
signal damaged(amount: float)
signal died
signal turn_ended
signal attacked(damage: float)

# --- Stats ---
@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
@export var attack_damage: float = 5.0
@export var experience_value: int = 10

# --- State ---
var health: float
var is_dead: bool = false
var _turn_pending: bool = false


func _ready() -> void:
	health = max_health
	_on_ready()


# --- Turn ---

func take_turn() -> void:
	if is_dead:
		return
	_turn_pending = true
	_perform_action()


func _process(_delta: float) -> void:
	if _turn_pending and _is_turn_complete():
		_turn_pending = false
		turn_ended.emit()


func _is_turn_complete() -> bool:
	return true


func _perform_action() -> void:
	attacked.emit(attack_damage)


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	damaged.emit(amount)
	_on_damaged(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	_on_death()
	died.emit()


# --- Extension Hooks ---

func _on_ready() -> void:
	pass


func _on_damaged(_amount: float) -> void:
	pass


func _on_death() -> void:
	pass
