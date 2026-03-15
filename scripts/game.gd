class_name Game
extends Node2D

# --- Debug ---

@export var debug_start_combat: bool = false
@export var debug_combat_event: PackedScene
@export var debug_enemy_scene: PackedScene
@export var debug_enemy_count: int = 1

# --- Screen Transform ---
var screen_size: Vector2
var screen_center: Vector2


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

# --- GUI ---

@onready var _gui: GUI = $GUI


func _ready() -> void:
	screen_size = get_viewport_rect().size
	screen_center = screen_size / 2
	set_player($Player)
	$Player.position = screen_center
	_scale_sprite_to_viewport($Player.get_node("Sprite"))
	$Player.set_hurt_overlay($HurtOverlay/HurtRect)
	if _exploration_music:
		$Music/BGM.stream = _exploration_music
		$Music/BGM.play()

	_gui.start_requested.connect(start_game)
	_gui.quit_to_main_requested.connect(quit_to_main)
	_gui.attack_requested.connect(attack_action)
	_gui.show_main_menu()


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_gui.handle_esc()
		return
	if state != TurnState.PLAYER_TURN:
		return


# --- GUI Callbacks ---

func attack_action() -> void:
	if state != TurnState.PLAYER_TURN:
		return
	_gui.set_player_turn(false)
	player.execute_action("attack")


func start_game() -> void:
	_gui.start_game()
	if debug_start_combat and debug_combat_event != null:
		var event_instance = debug_combat_event.instantiate() as CombatEvent
		start_event(event_instance)


# --- Participant Setup ---

func set_player(p: Player) -> void:
	player = p
	player.turn_ended.connect(_on_player_turn_ended)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	_gui.update_player_health(player.max_health, player.max_health)


func _on_player_damaged(_amount: float) -> void:
	_gui.update_player_health(player.health, player.max_health)


# --- Event Control ---

func start_event(event: Event) -> void:
	$EventContainer.add_child(event)
	current_event = event
	current_event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
	if event is CombatEvent:
		print("[GAME] Starting Combat Event")
		var ce := event as CombatEvent

		if debug_start_combat and debug_enemy_scene != null:
			for i in range(debug_enemy_count):
				var enemy_instance = debug_enemy_scene.instantiate() as Skeleton
				enemy_instance.position = _calculate_enemy_position(i, debug_enemy_count)
				_scale_sprite_to_viewport(enemy_instance.get_node("Sprite"))
				ce.add_enemy(enemy_instance)
				_gui.add_enemy_health_bar(enemy_instance)
				enemy_instance.damaged.connect(func(_amt: float) -> void:
					_gui.update_enemy_health_bar(enemy_instance, enemy_instance.health))
				enemy_instance.died.connect(func() -> void:
					_gui.remove_enemy_health_bar(enemy_instance))

		ce.player_attacked.connect(_on_player_attacked)
		ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
		player.attack.connect(_on_player_attack_action)
		_gui.show_combat_hud()
		_gui.set_player_turn(false)
		_start_combat_music()
	current_event.start()
	if event is CombatEvent:
		_start_player_turn()


func _on_event_complete() -> void:
	print("[GAME] Event complete")
	# TODO: receive a result payload once the Event API is finalised
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		ce.player_attacked.disconnect(_on_player_attacked)
		ce.enemy_turns_complete.disconnect(_on_enemy_turns_complete)
		player.attack.disconnect(_on_player_attack_action)
		for enemy in ce._enemies:
			_gui.remove_enemy_health_bar(enemy)
		_gui.hide_combat_hud()
	current_event.queue_free()
	current_event = null
	state = TurnState.NO_TURN
	_start_exploration_music()


func _on_player_attacked(damage: float) -> void:
	print("[PLAYER] Takes %.0f damage" % damage)
	player.take_damage(damage)


# --- Turn Flow ---

func _start_player_turn() -> void:
	state = TurnState.PLAYER_TURN
	round_number += 1
	print("[ROUND %d] === Player Turn ===" % round_number)
	_gui.set_player_turn(true)
	_gui.log_message("[Round %d] Your turn." % round_number)


func _on_player_turn_ended() -> void:
	if state != TurnState.PLAYER_TURN:
		return
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	state = TurnState.ENEMY_TURN
	print("[ROUND %d] === Enemy Turn ===" % round_number)
	(current_event as CombatEvent).run_enemy_turns()


func _on_enemy_turns_complete() -> void:
	_start_player_turn()


func _on_player_attack_action(damage: float) -> void:
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		# Target selection: first living enemy for now
		for enemy in ce._enemies:
			if not enemy.is_dead:
				print("[PLAYER] Attacks %s for %.0f damage" % [enemy.enemy_name, damage])
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
	print("[GAME] Player died — GAME OVER")
	state = TurnState.GAME_OVER


func quit_to_main() -> void:
	_gui.return_to_main_menu()
	state = TurnState.NO_TURN


# --- Helper Functions ---

func _scale_sprite_to_viewport(sprite: AnimatedSprite2D) -> void:
	var texture := sprite.sprite_frames.get_frame_texture("idle", 0)
	var sprite_size := texture.get_size()
	var scale_factor: float = min(screen_size.x / sprite_size.x, screen_size.y / sprite_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)


func _calculate_enemy_position(index: int, total: int) -> Vector2:
	var spacing: int = int(screen_size.x * 0.15)
	var start_x := -spacing * (total - 1) / 2
	return Vector2(start_x + index * spacing, 0) + screen_center
