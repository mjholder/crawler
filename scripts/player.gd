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

# --- Actions ---
# Maps action name -> Callable(target: Node).
# Register new actions with register_action(); call them via execute_action().
var _actions: Dictionary = {}


func _ready() -> void:
	health = max_health
	_register_actions()


func _register_actions() -> void:
	register_action("attack", _do_attack)


func register_action(action_name: String, callable: Callable) -> void:
	_actions[action_name] = callable


func execute_action(action_name: String, target: Node = null) -> void:
	if is_dead or not _actions.has(action_name):
		return
	_actions[action_name].call(target)
	turn_ended.emit()


# --- Action Implementations ---

func _do_attack(target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)


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
