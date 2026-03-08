class_name Game
extends Node2D

# --- Debug ---
@export var debug_start_combat: bool = false
@export var debug_combat_event: PackedScene
@export var debug_enemy_scene: PackedScene
@export var debug_enemy_count: int = 1

# --- Turn State ---

enum TurnState { PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, NO_TURN }

var state: TurnState = TurnState.NO_TURN
var round_number: int = 0

# --- Music ---

@export var _combat_music: AudioStream
@export var _exploration_music: AudioStream

# --- Participants ---

var player: Player

# --- Current Event ---

var current_event: Event = null


func _ready() -> void:
	set_player($Player)
	$Player.set_hurt_overlay($HurtOverlay/HurtRect)
	if _exploration_music:
		$Music/BGM.stream = _exploration_music
		$Music/BGM.play()

	if debug_start_combat and debug_combat_event != null:
		var event_instance = debug_combat_event.instantiate() as CombatEvent
		start_event(event_instance)


# --- Participant Setup ---

func set_player(p: Player) -> void:
	player = p
	player.turn_ended.connect(_on_player_turn_ended)
	player.died.connect(_on_player_died)


# --- Event Control ---

func start_event(event: Event) -> void:
	$EventContainer.add_child(event)
	current_event = event
	current_event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
	if event is CombatEvent:
		var ce := event as CombatEvent

		if debug_start_combat and debug_enemy_scene != null:
			for i in range(debug_enemy_count):
				var enemy_instance = debug_enemy_scene.instantiate() as Skeleton
				ce.add_enemy(enemy_instance)

		ce.player_attacked.connect(_on_player_attacked)
		ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
		player.attack.connect(_on_player_attack_action)
		$GUI/CombatHUD.show()
		_start_combat_music()
	current_event.start()
	if event is CombatEvent:
		_start_player_turn()


func _on_event_complete() -> void:
	# TODO: receive a result payload once the Event API is finalised
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		ce.player_attacked.disconnect(_on_player_attacked)
		ce.enemy_turns_complete.disconnect(_on_enemy_turns_complete)
		player.attack.disconnect(_on_player_attack_action)
		$GUI/CombatHUD.hide()
	current_event.queue_free()
	current_event = null
	state = TurnState.NO_TURN
	_start_exploration_music()


func _on_player_attacked(damage: float) -> void:
	player.take_damage(damage)


# --- Turn Flow ---

func _start_player_turn() -> void:
	state = TurnState.PLAYER_TURN
	round_number += 1


func _on_player_turn_ended() -> void:
	if state != TurnState.PLAYER_TURN:
		return
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	state = TurnState.ENEMY_TURN
	(current_event as CombatEvent).run_enemy_turns()


func _on_enemy_turns_complete() -> void:
	_start_player_turn()


func _on_player_attack_action(damage: float) -> void:
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		# Target selection: first living enemy for now
		for enemy in ce._enemies:
			if not enemy.is_dead:
				ce.receive_player_attack(enemy, damage)
				break


# --- Music ---

func _start_combat_music() -> void:
	if _combat_music == null:
		return
	$Music/BGM.stream = _combat_music
	$Music/BGM.play()


func _start_exploration_music() -> void:
	if _exploration_music == null:
		return
	$Music/BGM.stream = _exploration_music
	$Music/BGM.play()


# --- End Conditions ---

func _on_player_died() -> void:
	state = TurnState.GAME_OVER
