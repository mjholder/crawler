extends Node2D

# --- Turn State ---

enum TurnState { PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, NO_TURN }

var state: TurnState = TurnState.NO_TURN
var round_number: int = 0

# --- Combat Participants ---

var player: Player
var enemies: Array[Enemy] = []


func _ready() -> void:
	pass


# --- Participant Setup ---

func set_player(p: Player) -> void:
	player = p
	player.turn_ended.connect(_on_player_turn_ended)
	player.died.connect(_on_player_died)


# --- Event Loading ---
# Each load_*_event function will be called by its corresponding Event class
# when an encounter begins. Mocked here until the Event class is implemented.

func load_combat_event(enemy_list: Array[Enemy]) -> void:
	# TODO: called by CombatEvent; receives the enemy roster and kicks off combat
	enemies = enemy_list
	for enemy in enemies:
		enemy.died.connect(_on_enemy_died.bind(enemy))
	_start_player_turn()


func load_skill_check_event() -> void:
	# TODO: called by SkillCheckEvent; suspends turn flow, resolves the check, then resumes
	pass


func load_loot_event() -> void:
	# TODO: called by LootEvent; pauses the combat loop and presents loot to the player
	pass


func load_roleplay_event() -> void:
	# TODO: called by RoleplaysEvent; presents a decision node and applies the outcome
	pass


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
	for enemy in enemies:
		if not enemy.is_dead:
			enemy.take_turn(player)
	if not player.is_dead:
		_start_player_turn()


# --- End Conditions ---

func _on_player_died() -> void:
	state = TurnState.GAME_OVER


func _on_enemy_died(_enemy: Enemy) -> void:
	if _all_enemies_dead():
		state = TurnState.ENEMY_CLEARED


func _all_enemies_dead() -> bool:
	for enemy in enemies:
		if not enemy.is_dead:
			return false
	return true
