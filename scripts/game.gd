class_name Game
extends Node2D

# --- Debug ---

@export var debug_start_combat: bool = false
@export var debug_combat_event: PackedScene
@export var debug_enemy_scene: PackedScene
@export var debug_enemy_count: int = 1
@export var debug_weapon_scene: PackedScene
@export var debug_dialogue_json: String = ""
@export var debug_dialogue_scene: PackedScene
@export var debug_skill_check_scene: PackedScene

# --- Screen Transform ---
var screen_size: Vector2
var screen_center: Vector2

# --- Turn State ---

var state: Enums.TurnState = Enums.TurnState.NO_TURN
var round_number: int = 0
var _pre_dialogue_state: Enums.TurnState = Enums.TurnState.NO_TURN

# --- Music ---

@export var _combat_music: AudioStream
@export var _exploration_music: AudioStream

# --- Participants ---

var player: Player

# --- Current Event ---

var current_event: Event = null

# --- World Map ---

var _pending_event_configs: Array[Dictionary] = []
var _event_index: int = 0
var _active_world_node: WorldMapNode = null

# --- GUI ---

@onready var _gui: GUI = $GUI
@onready var _dialogue_consequences: DialogueConsequences = $DialogueCondsequences


func _ready() -> void:
	screen_size = get_viewport_rect().size
	screen_center = screen_size / 2
	set_player($Player)
	$Player.position = screen_center
	$Player.set_hurt_overlay($HurtOverlay/HurtRect)
	_gui.setup_inventory($Player.get_node("Inventory") as Inventory)
	if _exploration_music:
		$Music/BGM.stream = _exploration_music
		$Music/BGM.play()

	_gui.character_created.connect(_on_character_created)
	_gui.level_up_complete.connect(_on_level_up_complete)
	_gui.start_dialogue_requested.connect(start_dialogue_game)
	_gui.start_skill_check_requested.connect(start_skill_check_game)
	_gui.quit_to_main_requested.connect(quit_to_main)
	_gui.attack_requested.connect(attack_action)
	_gui.dialogue_complete.connect(_on_gui_dialogue_complete)
	_gui.skill_check_complete.connect(_on_gui_skill_check_complete)
	_gui.rest_requested.connect(_on_gui_rest_requested)
	_gui.rest_complete.connect(_on_gui_rest_complete)
	_gui.node_selected.connect(_on_world_node_selected)
	_gui.shop_buy_requested.connect(_on_gui_shop_buy_requested)
	_gui.shop_sell_requested.connect(_on_gui_shop_sell_requested)
	_gui.shop_leave_requested.connect(_on_gui_shop_leave_requested)
	_gui.show_main_menu()


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_gui.handle_esc()
		return
	if state != Enums.TurnState.PLAYER_TURN:
		return


# --- GUI Callbacks ---

func attack_action() -> void:
	if state != Enums.TurnState.PLAYER_TURN:
		return
	_gui.set_player_turn(false)
	player.execute_action("attack")


func start_dialogue_game() -> void:
	_gui.start_game()
	if debug_dialogue_scene != null:
		var event_instance := debug_dialogue_scene.instantiate() as DialogueEvent
		start_event(event_instance)


func start_skill_check_game() -> void:
	_gui.start_game()
	if debug_skill_check_scene != null:
		var event_instance := debug_skill_check_scene.instantiate() as SkillCheckEvent
		start_event(event_instance)


func _on_character_created(p_name: String, class_data: PlayerClassData) -> void:
	player.initialize(p_name, class_data)
	_gui.start_game()
	_gui.show_world_map()
	_gui.update_player_health(player.health, player.max_health)
	_gui.update_player_stats(player.build_stats_dict())


func start_game() -> void:
	_gui.start_game()
	_gui.show_world_map()


# --- Participant Setup ---

func set_player(p: Player) -> void:
	player = p
	player.turn_ended.connect(_on_player_turn_ended)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.healed.connect(_on_player_healed)
	player.gold_changed.connect(_on_player_gold_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.stats_changed.connect(_on_player_stats_changed)
	_gui.update_player_health(player.max_health, player.max_health)
	_gui.update_player_stats(player.build_stats_dict())


func _on_player_damaged(_amount: float) -> void:
	_gui.update_player_health(player.health, player.max_health)


func _on_player_healed(_amount: float) -> void:
	_gui.update_player_health(player.health, player.max_health)


func _on_player_gold_changed(new_total: int) -> void:
	_gui.update_player_gold(new_total)
	if current_event is ShopEvent:
		_gui.refresh_shop_gold(new_total)


func _on_player_experience_changed(new_total: int) -> void:
	_gui.update_player_xp(new_total)


func _on_player_stats_changed(stats: Dictionary) -> void:
	_gui.update_player_stats(stats)
	_gui.update_player_health(player.health, player.max_health)


# --- Event Control ---

func start_event(event: Event) -> void:
	$EventContainer.add_child(event)
	current_event = event
	current_event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
	if event is CombatEvent:
		print("[GAME] Starting Combat Event")
		var ce := event as CombatEvent
		ce.enemy_added.connect(_on_combat_enemy_added)
		ce.dialogue_trigger_fired.connect(_on_combat_dialogue_trigger)
		ce.player_attacked.connect(_on_player_attacked)
		ce.enemy_turns_complete.connect(_on_enemy_turns_complete)
		player.attack.connect(_on_player_attack_action)
		_gui.show_combat_hud()
		_gui.set_player_turn(false)
		_start_combat_music()
		player.set_weapon_visible(true)
	elif event is DialogueEvent:
		var de := event as DialogueEvent
		de.dialogue_requested.connect(_on_dialogue_requested)
	elif event is SkillCheckEvent:
		var sce := event as SkillCheckEvent
		sce.skill_check_requested.connect(_on_skill_check_requested)
		sce.dialogue_requested.connect(_on_dialogue_requested)
	elif event is RestEvent:
		var re := event as RestEvent
		re.rest_requested.connect(_on_rest_requested)
	elif event is ShopEvent:
		var se := event as ShopEvent
		se.shop_requested.connect(_on_shop_requested)
		se.stock_changed.connect(_on_shop_stock_changed)
		player.get_node("Inventory").bag_changed.connect(_on_shop_bag_changed)
	current_event.start()
	if event is CombatEvent and state != Enums.TurnState.DIALOGUE:
		_start_player_turn()


func _on_event_complete() -> void:
	print("[GAME] Event complete")
	if current_event is CombatEvent:
		var ce := current_event as CombatEvent
		ce.player_attacked.disconnect(_on_player_attacked)
		ce.enemy_turns_complete.disconnect(_on_enemy_turns_complete)
		ce.enemy_added.disconnect(_on_combat_enemy_added)
		ce.dialogue_trigger_fired.disconnect(_on_combat_dialogue_trigger)
		player.attack.disconnect(_on_player_attack_action)
		for enemy in ce._enemies:
			_gui.remove_enemy_health_bar(enemy)
		_gui.hide_combat_hud()
		player.set_weapon_visible(false)
	elif current_event is DialogueEvent:
		var de := current_event as DialogueEvent
		de.dialogue_requested.disconnect(_on_dialogue_requested)
	elif current_event is SkillCheckEvent:
		var sce := current_event as SkillCheckEvent
		sce.skill_check_requested.disconnect(_on_skill_check_requested)
		sce.dialogue_requested.disconnect(_on_dialogue_requested)
	elif current_event is RestEvent:
		var re := current_event as RestEvent
		re.rest_requested.disconnect(_on_rest_requested)
	elif current_event is ShopEvent:
		var se := current_event as ShopEvent
		se.shop_requested.disconnect(_on_shop_requested)
		se.stock_changed.disconnect(_on_shop_stock_changed)
		player.get_node("Inventory").bag_changed.disconnect(_on_shop_bag_changed)
	_apply_rewards(current_event.rewards)
	if player.pending_stat_points > 0:
		_gui.show_level_up(player)
		return
	_finish_event()


func _on_level_up_complete() -> void:
	_finish_event()


func _finish_event() -> void:
	current_event.queue_free()
	current_event = null
	state = Enums.TurnState.NO_TURN
	if _active_world_node != null:
		_start_next_dungeon_event()
	else:
		_start_exploration_music()
		_gui.return_to_main_menu()


# --- World Map ---

func _on_world_node_selected(node: WorldMapNode) -> void:
	_active_world_node = node
	_pending_event_configs = node.generate_event_configs()
	_event_index = 0
	_start_next_dungeon_event()


func _start_next_dungeon_event() -> void:
	if _event_index >= _pending_event_configs.size():
		_on_dungeon_complete()
		return
	var config: Dictionary = _pending_event_configs[_event_index]
	_event_index += 1
	var event := (config["scene"] as PackedScene).instantiate() as Event
	event.initialize(config["data"])
	start_event(event)


func _on_dungeon_complete() -> void:
	_start_exploration_music()
	_gui.world_map_on_dungeon_complete(_active_world_node)
	_pending_event_configs = []
	_event_index = 0
	_active_world_node = null


func _on_player_attacked(damage: float) -> void:
	print("[PLAYER] Takes %.0f damage" % damage)
	player.take_damage(damage)


# --- Dialogue ---

func start_dialogue(data: Dictionary) -> void:
	_pre_dialogue_state = state
	state = Enums.TurnState.DIALOGUE
	_gui.show_dialogue(data, _dialogue_consequences)


func _on_dialogue_requested(data: Dictionary) -> void:
	start_dialogue(data)


func _on_skill_check_requested(stat: Enums.Stat, label: String) -> void:
	var stat_value: float = player.get_effective_stat(stat)
	_gui.show_skill_check(Enums.Stat.keys()[stat], label, stat_value)


func _on_gui_skill_check_complete(success: bool) -> void:
	if current_event is SkillCheckEvent:
		(current_event as SkillCheckEvent).on_skill_check_complete(success)


# --- Rest ---

func _on_rest_requested() -> void:
	var heal_amount: float = (current_event as RestEvent).get_heal_amount(player.max_health)
	_gui.show_rest_panel(heal_amount)


func _on_gui_rest_requested() -> void:
	var heal_amount: float = (current_event as RestEvent).get_heal_amount(player.max_health)
	player.heal(heal_amount)


func _on_gui_rest_complete() -> void:
	_gui.hide_rest_panel()
	(current_event as RestEvent).on_rest_complete()


# --- Shop ---

func _on_shop_requested(shop_name: String, stock: Array[EquipmentData], buy_mult: float, sell_mult: float) -> void:
	var inventory: Inventory = player.get_node("Inventory")
	_gui.show_shop(shop_name, stock, inventory.get_bag(), player.gold, buy_mult, sell_mult, inventory.is_bag_full())


func _on_shop_stock_changed(stock: Array[EquipmentData]) -> void:
	var inventory: Inventory = player.get_node("Inventory")
	_gui.refresh_shop_stock(stock, inventory.is_bag_full())


func _on_shop_bag_changed() -> void:
	var inventory: Inventory = player.get_node("Inventory")
	_gui.refresh_shop_bag(inventory.get_bag(), inventory.is_bag_full())


func _on_gui_shop_buy_requested(item: EquipmentData) -> void:
	if not current_event is ShopEvent:
		return
	var se := current_event as ShopEvent
	var inventory: Inventory = player.get_node("Inventory")
	var price := se.get_buy_price(item)
	if player.gold < price:
		_gui.show_shop_status("Not enough gold")
		return
	if inventory.is_bag_full():
		_gui.show_shop_status("Bag full")
		return
	_gui.show_shop_status("")
	player.spend_gold(price)
	se.on_buy(item)
	inventory.add_to_bag(item)


func _on_gui_shop_sell_requested(item: EquipmentData) -> void:
	if not current_event is ShopEvent:
		return
	var se := current_event as ShopEvent
	var inventory: Inventory = player.get_node("Inventory")
	var price := se.get_sell_price(item)
	player.add_gold(price)
	se.on_sell(item)
	inventory.remove_from_bag(item)


func _on_gui_shop_leave_requested() -> void:
	_gui.hide_shop()
	if current_event is ShopEvent:
		(current_event as ShopEvent).on_leave()


func _on_combat_enemy_added(enemy: Enemy, total_expected: int) -> void:
	var index := (current_event as CombatEvent)._enemies.size() - 1
	enemy.position = _calculate_enemy_position(index, total_expected)
	_scale_sprite_to_viewport(enemy.get_node("Sprite"))
	_gui.add_enemy_health_bar(enemy)
	enemy.damaged.connect(func(_amt: float) -> void:
		_gui.update_enemy_health_bar(enemy, enemy.health))
	enemy.died.connect(func() -> void:
		_gui.remove_enemy_health_bar(enemy))


func _on_combat_dialogue_trigger(_trigger_name: String, data: Dictionary) -> void:
	start_dialogue(data)


func _on_gui_dialogue_complete() -> void:
	state = _pre_dialogue_state
	if current_event is DialogueEvent:
		(current_event as DialogueEvent).on_dialogue_complete()
	elif current_event is SkillCheckEvent:
		(current_event as SkillCheckEvent).on_dialogue_complete()
	elif current_event is CombatEvent:
		var ce := current_event as CombatEvent
		if ce.phase == Event.Phase.RESOLUTION:
			ce.on_dialogue_complete()
		elif state == Enums.TurnState.NO_TURN:
			_start_player_turn()
	else:
		_finish_event()


# --- Turn Flow ---

func _start_player_turn() -> void:
	state = Enums.TurnState.PLAYER_TURN
	round_number += 1
	print("[ROUND %d] === Player Turn ===" % round_number)
	_gui.set_player_turn(true)
	_gui.log_message("[Round %d] Your turn." % round_number)


func _on_player_turn_ended() -> void:
	if state != Enums.TurnState.PLAYER_TURN:
		return
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	state = Enums.TurnState.ENEMY_TURN
	print("[ROUND %d] === Enemy Turn ===" % round_number)
	(current_event as CombatEvent).run_enemy_turns()


func _on_enemy_turns_complete() -> void:
	if state == Enums.TurnState.DIALOGUE:
		return
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
	state = Enums.TurnState.GAME_OVER


func quit_to_main() -> void:
	if current_event != null:
		current_event.queue_free()
		current_event = null
	_pending_event_configs = []
	_event_index = 0
	_active_world_node = null
	_start_exploration_music()
	player.set_weapon_visible(false)
	_gui.return_to_main_menu()
	state = Enums.TurnState.NO_TURN


# --- Helper Functions ---

func _apply_rewards(r: Dictionary) -> void:
	var xp: int = r.get("experience", 0)
	var gold: int = r.get("gold", 0)
	if xp > 0:
		player.add_experience(xp)
	if gold > 0:
		player.add_gold(gold)
	print("[GAME] Rewards applied: %d XP, %d gold" % [xp, gold])


func _scale_sprite_to_viewport(sprite: AnimatedSprite2D) -> void:
	var texture := sprite.sprite_frames.get_frame_texture("idle", 0)
	var sprite_size := texture.get_size()
	var scale_factor: float = min(screen_size.x / sprite_size.x, screen_size.y / sprite_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)


func _calculate_enemy_position(index: int, total: int) -> Vector2:
	var spacing: int = int(screen_size.x * 0.15)
	var start_x := -spacing * (total - 1) / 2
	return Vector2(start_x + index * spacing, 0) + screen_center
