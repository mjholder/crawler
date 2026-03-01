class_name Skeleton
extends Enemy

# --- Enemy State ---

enum State { IDLE, ATTACKING, HIT, DEAD }

var _state: State = State.IDLE

# --- Animation Timing ---

const HIT_DURATION: float = 0.20

# --- Node References ---

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sequencer: Timer = $AnimationSequencer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer


# --- Extension Hook Overrides ---

func _on_ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)
	_sequencer.timeout.connect(_on_sequencer_timeout)
	_transition(State.IDLE)


func _perform_action(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	_play_sfx(_attack_player)
	_transition(State.ATTACKING)


func _on_damaged(_amount: float) -> void:
	if _state == State.DEAD:
		return
	_sequencer.stop()
	_play_sfx(_hurt_player)
	_transition(State.HIT)
	_sequencer.start(HIT_DURATION)


func _on_death() -> void:
	_sequencer.stop()
	_play_sfx(_death_player)
	_transition(State.DEAD)


# --- Turn Gate ---

func _is_turn_complete() -> bool:
	return _state == State.IDLE or _state == State.DEAD


# --- Internal ---

func _on_animation_finished() -> void:
	if _state == State.ATTACKING:
		_transition(State.IDLE)


func _on_sequencer_timeout() -> void:
	if _state == State.HIT:
		_transition(State.IDLE)


func _transition(next: State) -> void:
	_state = next
	match _state:
		State.IDLE:      _sprite.play("idle")
		State.ATTACKING: _sprite.play("attack")
		State.HIT:       _sprite.play("hurt")
		State.DEAD:      _sprite.play("death")


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player.stream != null:
		player.play()
