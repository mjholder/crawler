class_name Skeleton
extends Enemy

# --- Enemy State ---

enum State { IDLE, ATTACKING, HIT, DEAD }

var _state: State = State.IDLE

# --- Node References ---

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer


# --- Extension Hook Overrides ---

func _on_ready() -> void:
	_anim_player.animation_finished.connect(_on_anim_player_finished)
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_transition(State.IDLE)


func _perform_action() -> void:
	super._perform_action()
	_play_sfx(_attack_player)
	_transition(State.ATTACKING)


func _on_damaged(_amount: float) -> void:
	if _state == State.DEAD:
		return
	if _state == State.ATTACKING:
		_anim_player.stop()
	_play_sfx(_hurt_player)
	_transition(State.HIT)


func _on_death() -> void:
	_play_sfx(_death_player)
	_transition(State.DEAD)


# --- Turn Gate ---

func _is_turn_complete() -> bool:
	return _state == State.IDLE or _state == State.DEAD


# --- Internal ---

func _on_anim_player_finished(_anim_name: StringName) -> void:
	_transition(State.IDLE)


func _on_sprite_animation_finished() -> void:
	if _state == State.HIT:
		_transition(State.IDLE)


func _transition(next: State) -> void:
	_state = next
	match _state:
		State.IDLE:      _sprite.play("idle")
		State.ATTACKING: _anim_player.play("attack")
		State.HIT:       _sprite.play("hit")
		State.DEAD:      _sprite.play("death")


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player.stream != null:
		player.play()
