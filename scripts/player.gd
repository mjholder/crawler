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
@export var attack_damage: float = 10.0

# --- State Machine ---
enum State { IDLE, ATTACKING, HIT, DEAD }

var _state: State = State.IDLE
var health: float
var is_dead: bool = false
var _turn_pending: bool = false
var _hurt_overlay: ColorRect = null

# --- Node References ---
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer

# --- Actions ---
# Maps action name -> Callable.
# Register new actions with register_action(); call them via execute_action().
var _actions: Dictionary = {}


func _ready() -> void:
	health = max_health
	_anim_player.animation_finished.connect(_on_anim_player_finished)
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
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
	if is_dead or not _actions.has(action_name):
		return
	print("[PLAYER] Action: %s" % action_name)
	_actions[action_name].call()
	_turn_pending = true


# --- Action Implementations ---

func _do_attack() -> void:
	_play_sfx(_attack_player)
	_transition(State.ATTACKING)
	attack.emit(attack_damage)


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	print("  Player HP: %.0f / %.0f" % [health, max_health])
	damaged.emit(amount)
	_flash_hurt_overlay()
	if health <= 0.0:
		_die()
	else:
		_play_sfx(_hurt_player)
		_transition(State.HIT)


func _die() -> void:
	print("  [PLAYER] Died!")
	is_dead = true
	_play_sfx(_death_player)
	_transition(State.DEAD)
	died.emit()


# --- Equipment ---

func equip_weapon(frames: SpriteFrames) -> void:
	_sprite.sprite_frames = frames
	_transition(State.IDLE)


func set_hurt_overlay(overlay: ColorRect) -> void:
	_hurt_overlay = overlay


# --- Internal ---

func _is_turn_complete() -> bool:
	return _state == State.IDLE or _state == State.DEAD


func _transition(next: State) -> void:
	_state = next
	match _state:
		State.IDLE:      _sprite.play("idle")
		State.ATTACKING: _anim_player.play("attack")
		State.HIT:       _sprite.play("hurt")
		State.DEAD:      _sprite.play("death")


func _on_anim_player_finished(_anim_name: StringName) -> void:
	_transition(State.IDLE)


func _on_sprite_animation_finished() -> void:
	if _state == State.HIT:
		_transition(State.IDLE)


func _flash_hurt_overlay() -> void:
	if _hurt_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_hurt_overlay, "modulate:a", 0.5, 0.05)
	tween.tween_property(_hurt_overlay, "modulate:a", 0.0, 0.2)


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player.stream != null:
		player.play()
