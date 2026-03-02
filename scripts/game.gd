class_name Game
extends Node2D

# --- Turn State ---

enum TurnState { PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, NO_TURN }

var state: TurnState = TurnState.NO_TURN
var round_number: int = 0

# --- Participants ---

var player: Player

# --- Current Event ---

var current_event: Event = null


func _ready() -> void:
	pass


# --- Participant Setup ---

func set_player(p: Player) -> void:
	player = p
	player.turn_ended.connect(_on_player_turn_ended)
	player.died.connect(_on_player_died)


# --- Event Control ---

func start_event(event: Event) -> void:
	current_event = event
	current_event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
	if event is CombatEvent:
		var ce := event as CombatEvent
		ce.player_attacked.connect(_on_player_attacked)
		player.attacked.connect(ce.receive_player_attack)
	current_event.start()


func _on_event_complete() -> void:
	# TODO: receive a result payload once the Event API is finalised
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		ce.player_attacked.disconnect(_on_player_attacked)
		player.attacked.disconnect(ce.receive_player_attack)
	current_event = null
	state = TurnState.NO_TURN


func _on_player_attacked(damage: float) -> void:
	player.take_damage(damage)


# --- Turn Flow ---
# TODO: turn flow will be driven by CombatEvent once implemented;
# these stubs exist to keep the state machine wired up

func _start_player_turn() -> void:
	state = TurnState.PLAYER_TURN
	round_number += 1


func _on_player_turn_ended() -> void:
	if state != TurnState.PLAYER_TURN:
		return
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	# TODO: delegate to CombatEvent; enemy roster lives on the event
	state = TurnState.ENEMY_TURN
	_start_player_turn()


# --- End Conditions ---

func _on_player_died() -> void:
	state = TurnState.GAME_OVER
