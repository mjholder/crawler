class_name Player
extends Node2D

# --- Signals ---
signal damaged(amount: float)
signal died
signal turn_ended
signal attack(damage: float)

# --- Stats ---
@export var player_name: String = "Player"
@export var max_health: float = 100.0
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

@export var base_damage: float = 10.0

# --- State Machine ---
enum State { IDLE, DEAD }

var _state: State = State.IDLE
var health: float
var gold: int = 0
var experience: int = 0
var is_dead: bool = false
var _turn_pending: bool = false
var _attack_animation_pending: bool = false
var _hurt_overlay: ColorRect = null

# --- Node References ---
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer

# --- Actions ---
# Maps action name -> Callable.
# Register new actions with register_action(); call them via execute_action().
var _actions: Dictionary = {}
var _equipped: Dictionary = {}  # Enums.Slot → Equipment


func _ready() -> void:
	health = max_health
	_register_actions()
	_transition(State.IDLE)


func _process(_delta: float) -> void:
	if _turn_pending and _is_turn_complete():
		_turn_pending = false
		turn_ended.emit()


# --- Actions ---

func _register_actions() -> void:
	register_action("attack", _do_attack)


func register_action(action_name: String, callable: Callable) -> void:
	_actions[action_name] = callable


func execute_action(action_name: String) -> void:
	if is_dead or _turn_pending or not _actions.has(action_name):
		return
	print("[PLAYER] Action: %s" % action_name)
	_actions[action_name].call()
	_turn_pending = true


# --- Action Implementations ---

func _do_attack() -> void:
	if _equipped.has(Enums.Slot.WEAPON):
		_attack_animation_pending = true
	print("  Player attacks for %.1f damage!" % _calculate_damage())
	attack.emit(_calculate_damage())


# --- Rewards ---

func add_gold(amount: int) -> void:
	gold += amount


func add_experience(amount: int) -> void:
	experience += amount


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	var net_amount: float = _apply_defense(amount)
	health -= net_amount
	print("  Player HP: %.0f / %.0f" % [health, max_health])
	damaged.emit(net_amount)
	_flash_hurt_overlay()
	if health <= 0.0:
		_die()
	else:
		_play_sfx(_hurt_player)


func _die() -> void:
	print("  [PLAYER] Died!")
	is_dead = true
	_play_sfx(_death_player)
	_transition(State.DEAD)
	died.emit()


func _apply_defense(amount: float) -> float:
	return maxf(amount - get_effective_stat(Enums.Stat.DEFENSE), 0.0)


func _calculate_damage() -> float:
	return base_damage + (get_effective_stat(Enums.Stat.STRENGTH) * 0.5)


# --- Equipment ---

func equip(slot: Enums.Slot, item: Equipment) -> void:
	if _equipped.has(slot):
		var old: Equipment = _equipped[slot]
		old.play_unequip()
		old._on_unequipped()
		if slot == Enums.Slot.WEAPON:
			attack.disconnect((old as Weapon)._on_player_attacked)
			(old as Weapon).animation_finished.disconnect(_on_weapon_animation_finished)
		remove_child(old)
	_equipped[slot] = item
	add_child(item)
	item.play_equip()
	item._on_equipped()
	if slot == Enums.Slot.WEAPON:
		print("[PLAYER] Equipped weapon: %s" % item.data.item_name)
		attack.connect((item as Weapon)._on_player_attacked)
		(item as Weapon).animation_finished.connect(_on_weapon_animation_finished)


func get_effective_stat(stat: Enums.Stat) -> float:
	var base: float = _get_base_stat(stat)
	var bonus: float = 0.0
	for item in _equipped.values():
		bonus += item.get_modifier(stat)
	return base + bonus


func _get_base_stat(stat: Enums.Stat) -> float:
	match stat:
		Enums.Stat.STRENGTH:     return strength
		Enums.Stat.DEFENSE:      return defense
		Enums.Stat.CONSTITUTION: return constitution
		Enums.Stat.AGILITY:      return agility
		Enums.Stat.SPIRIT:       return spirit
		Enums.Stat.LUCK:         return luck
	return 0.0


func set_hurt_overlay(overlay: ColorRect) -> void:
	_hurt_overlay = overlay


# --- Internal ---

func _is_turn_complete() -> bool:
	return not _attack_animation_pending and (_state == State.IDLE or _state == State.DEAD)


func _transition(next: State) -> void:
	_state = next


func _on_weapon_animation_finished() -> void:
	_attack_animation_pending = false


func _flash_hurt_overlay() -> void:
	if _hurt_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_hurt_overlay, "modulate:a", 0.5, 0.05)
	tween.tween_property(_hurt_overlay, "modulate:a", 0.0, 0.2)


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player != null and player.stream != null:
		player.play()
