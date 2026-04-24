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

# --- Game / Turn State ---

var game_state: Enums.GameState = Enums.GameState.MAIN_MENU
var state: Enums.TurnState = Enums.TurnState.NO_TURN
var game_started: bool = false
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

	_gui.character_created.connect(_on_character_created)
	_gui.level_up_complete.connect(_on_level_up_complete)
	_gui.start_dialogue_requested.connect(start_dialogue_game)
	_gui.start_skill_check_requested.connect(start_skill_check_game)
	_gui.quit_to_main_requested.connect(quit_to_main)
	_gui.attack_requested.connect(attack_action)
	_gui.consumable_use_requested.connect(_on_consumable_use_requested)
	_gui.dialogue_complete.connect(_on_gui_dialogue_complete)
	_gui.skill_check_complete.connect(_on_gui_skill_check_complete)
	_gui.rest_requested.connect(_on_gui_rest_requested)
	_gui.rest_complete.connect(_on_gui_rest_complete)
	_gui.node_selected.connect(_on_world_node_selected)
	_gui.shop_buy_requested.connect(_on_gui_shop_buy_requested)
	_gui.shop_sell_requested.connect(_on_gui_shop_sell_requested)
	_gui.shop_leave_requested.connect(_on_gui_shop_leave_requested)

	_enter_main_menu()


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if game_started and state not in [Enums.TurnState.GAME_OVER, Enums.TurnState.VICTORY]:
			_gui.handle_esc()
		return
	if event.is_action_pressed("inventory"):
		if game_started and state not in [Enums.TurnState.ENEMY_TURN, Enums.TurnState.DIALOGUE, Enums.TurnState.GAME_OVER, Enums.TurnState.VICTORY]:
			_gui.toggle_inventory(state == Enums.TurnState.NO_TURN)
		return
	if state in [Enums.TurnState.GAME_OVER, Enums.TurnState.VICTORY]:
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
	if debug_dialogue_scene == null:
		return
	game_started = true
	game_state = Enums.GameState.DUNGEON
	_gui.start_game()
	var event_instance := debug_dialogue_scene.instantiate() as DialogueEvent
	_enter_event(event_instance)


func start_skill_check_game() -> void:
	if debug_skill_check_scene == null:
		return
	game_started = true
	game_state = Enums.GameState.DUNGEON
	_gui.start_game()
	var event_instance := debug_skill_check_scene.instantiate() as SkillCheckEvent
	_enter_event(event_instance)


func _on_character_created(p_name: String, class_data: PlayerClassData) -> void:
	player.initialize(p_name, class_data)
	game_started = true
	_gui.start_game()
	_enter_world_map()


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
	_gui.setup_consumable_belt(player.get_node("Inventory") as Inventory)
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


# --- State Enter / Exit ---

func _enter_main_menu() -> void:
	game_state = Enums.GameState.MAIN_MENU
	state = Enums.TurnState.NO_TURN
	game_started = false
	player.set_weapon_visible(false)
	_start_exploration_music()
	_gui.return_to_main_menu()


func _exit_main_menu() -> void:
	pass


func _enter_world_map(completed_node: WorldMapNode = null) -> void:
	game_state = Enums.GameState.WORLD_MAP
	state = Enums.TurnState.NO_TURN
	_start_exploration_music()
	player.set_weapon_visible(false)
	_gui.hide_event_hud()
	if completed_node != null:
		_gui.world_map_on_dungeon_complete(completed_node)
	else:
		_gui.show_world_map()
	_gui.update_player_health(player.health, player.max_health)
	_gui.update_player_stats(player.build_stats_dict())
	_gui.update_player_gold(player.gold)
	_gui.update_player_xp(player.experience)


func _exit_world_map() -> void:
	_gui.hide_world_map()


func _enter_dungeon(configs: Array[Dictionary], event_index: int, world_node: WorldMapNode) -> void:
	game_state = Enums.GameState.DUNGEON
	_active_world_node = world_node
	_pending_event_configs = configs
	_event_index = event_index
	player.get_inventory().set_dungeon_locked(true)
	_gui.set_dungeon_locked(true)
	_start_next_dungeon_event()


func _exit_dungeon() -> void:
	_exit_event()
	_pending_event_configs = []
	_event_index = 0
	_active_world_node = null
	player.get_inventory().set_dungeon_locked(false)
	_gui.set_dungeon_locked(false)


func _enter_game_over() -> void:
	game_state = Enums.GameState.GAME_OVER
	state = Enums.TurnState.GAME_OVER
	_pending_event_configs = []
	_event_index = 0
	_active_world_node = null
	_gui.set_consumables_enabled(false)
	_gui.show_game_over()


func _exit_game_over() -> void:
	_gui.hide_game_over()


func _enter_victory() -> void:
	game_state = Enums.GameState.VICTORY
	state = Enums.TurnState.VICTORY
	_pending_event_configs = []
	_event_index = 0
	_active_world_node = null
	_gui.set_consumables_enabled(false)
	_gui.show_victory()


func _exit_victory() -> void:
	_gui.hide_victory()


# --- Event Control ---

func _enter_event(event: Event) -> void:
	_gui.show_event_hud()
	$EventContainer.add_child(event)
	current_event = event
	current_event.event_complete.connect(_on_event_complete, CONNECT_ONE_SHOT)
	event._on_enter(self)
	if game_state == Enums.GameState.DUNGEON and event.allows_inventory:
		player.get_inventory().set_dungeon_locked(false)
		_gui.set_dungeon_locked(false)
	current_event.start()
	if event is CombatEvent and state != Enums.TurnState.DIALOGUE:
		_start_player_turn()


func _exit_event() -> void:
	if current_event == null:
		return
	current_event._on_exit(self)
	current_event.queue_free()
	current_event = null
	if game_state == Enums.GameState.DUNGEON:
		player.get_inventory().set_dungeon_locked(true)
		_gui.set_dungeon_locked(true)


func _on_event_complete() -> void:
	print("[GAME] Event complete")
	_apply_rewards(current_event.rewards)
	_exit_event()
	if player.pending_stat_points > 0:
		_gui.show_level_up(player)
		return
	if state == Enums.TurnState.VICTORY:
		_enter_victory()
		return
	_finish_event()


func _on_level_up_complete() -> void:
	if state == Enums.TurnState.VICTORY:
		_enter_victory()
		return
	if state == Enums.TurnState.GAME_OVER:
		_enter_game_over()
		return
	_finish_event()


func _finish_event() -> void:
	state = Enums.TurnState.NO_TURN
	_gui.set_consumables_enabled(true)
	if _active_world_node != null:
		_start_next_dungeon_event()
	else:
		_enter_main_menu()


# --- World Map ---

func _on_world_node_selected(node: WorldMapNode) -> void:
	_exit_world_map()
	_enter_dungeon(node.generate_event_configs(), 0, node)


func _start_next_dungeon_event() -> void:
	if _event_index >= _pending_event_configs.size():
		_on_dungeon_complete()
		return
	var config: Dictionary = _pending_event_configs[_event_index]
	_event_index += 1
	var event := (config["scene"] as PackedScene).instantiate() as Event
	event.initialize(config["data"])
	_enter_event(event)


func _on_dungeon_complete() -> void:
	var completed_node := _active_world_node
	_exit_dungeon()
	_enter_world_map(completed_node)


func _on_player_attacked(damage: float) -> void:
	print("[PLAYER] Takes %.0f damage" % damage)
	player.take_damage(damage)


# --- Dialogue ---

func start_dialogue(data: Dictionary) -> void:
	_pre_dialogue_state = state
	state = Enums.TurnState.DIALOGUE
	_gui.set_consumables_enabled(true)
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


func _on_gui_dialogue_complete(terminal_node_id: String) -> void:
	state = _pre_dialogue_state
	if current_event is DialogueEvent:
		(current_event as DialogueEvent).on_dialogue_complete(terminal_node_id)
	elif current_event is SkillCheckEvent:
		(current_event as SkillCheckEvent).on_dialogue_complete()
	elif current_event is CombatEvent:
		var ce := current_event as CombatEvent
		var was_resolution := ce.phase == Event.Phase.RESOLUTION
		ce.on_dialogue_complete()
		if not was_resolution:
			_start_player_turn()
	else:
		_finish_event()


# --- Consumable Dispatch ---
# This path never calls execute_action() and never touches _turn_pending — turn does not end.

func _on_consumable_use_requested(index: int) -> void:
	if state in [Enums.TurnState.ENEMY_TURN, Enums.TurnState.GAME_OVER, Enums.TurnState.VICTORY]:
		return
	var inventory := player.get_node("Inventory") as Inventory
	var data: ConsumableData = inventory.get_consumable_at(index)
	if data == null:
		return
	inventory.consume(index)
	_apply_consumable_effect(data)
	player.consumable_used.emit(data)


func _apply_consumable_effect(data: ConsumableData) -> void:
	match data.effect:
		ConsumableData.Effect.HEAL_FLAT:
			player.heal(data.effect_value)
		ConsumableData.Effect.HEAL_PERCENT:
			player.heal(player.max_health * data.effect_value * 0.01)
		ConsumableData.Effect.DAMAGE_ALL:
			if current_event is CombatEvent:
				(current_event as CombatEvent).apply_consumable_damage(data.effect_value)
		ConsumableData.Effect.STAT_BUFF:
			player.apply_buff(data.buff_stat, data.effect_value, data.buff_duration)


# --- Turn Flow ---

func _start_player_turn() -> void:
	state = Enums.TurnState.PLAYER_TURN
	round_number += 1
	print("[ROUND %d] === Player Turn ===" % round_number)
	_gui.set_player_turn(true)
	_gui.set_consumables_enabled(true)
	_gui.log_message("[Round %d] Your turn." % round_number)


func _on_player_turn_ended() -> void:
	if state != Enums.TurnState.PLAYER_TURN:
		return
	if not current_event is CombatEvent:
		return
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	state = Enums.TurnState.ENEMY_TURN
	_gui.set_consumables_enabled(false)
	print("[ROUND %d] === Enemy Turn ===" % round_number)
	(current_event as CombatEvent).run_enemy_turns()


func _on_enemy_turns_complete() -> void:
	if state in [Enums.TurnState.DIALOGUE, Enums.TurnState.GAME_OVER, Enums.TurnState.VICTORY]:
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
	if $Music/BGM.stream == _exploration_music and $Music/BGM.playing:
		return
	$Music/BGM.stream = _exploration_music
	$Music/BGM.play()


# --- End Conditions ---

func _on_player_died() -> void:
	print("[GAME] Player died — GAME OVER")
	_exit_event()
	_enter_game_over()


func _on_boss_defeated() -> void:
	print("[GAME] Boss defeated — VICTORY")
	state = Enums.TurnState.VICTORY
	_gui.set_consumables_enabled(false)
	# Victory panel is shown via _on_event_complete() after the on_victory dialogue.


func quit_to_main() -> void:
	match game_state:
		Enums.GameState.DUNGEON:
			_exit_dungeon()
		Enums.GameState.WORLD_MAP:
			_exit_world_map()
		Enums.GameState.GAME_OVER:
			_exit_game_over()
		Enums.GameState.VICTORY:
			_exit_victory()
	_enter_main_menu()


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
