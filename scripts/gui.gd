class_name GUI
extends CanvasLayer

# --- Signals ---
signal character_created(player_name: String, class_data: PlayerClassData, background: BackgroundData, patron: PatronSaintData)
signal level_up_complete
signal quit_to_main_requested
signal attack_requested(attack_name: String)
signal dialogue_complete(terminal_node_id: String)
signal skill_check_complete(success: bool)
signal rest_requested
signal rest_complete
signal node_selected(node: WorldMapNode)
signal shop_buy_requested(item: EquipmentData)
signal shop_sell_requested(item: EquipmentData)
signal shop_leave_requested
signal consumable_use_requested(index: int)
signal continue_requested

# --- Node References ---
@onready var _character_creation: CharacterCreationPanel = $CharacterCreationPanel
@onready var _level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var _main_menu: Control = $MainMenu
@onready var _continue_button: Button = $MainMenu/ContinueButton
@onready var _new_run_confirm_dialog: ConfirmationDialog = $NewRunConfirmDialog
@onready var _pause_menu: Control = $PauseMenu
@onready var _player_hud: Control = $PlayerHUD
@onready var _player_health_label: Label = $PlayerHUD/PlayerHealthLabel
@onready var _player_health_bar: ProgressBar = $PlayerHUD/PlayerHealthBar
@onready var _player_gold_label: Label = $PlayerHUD/PlayerGoldLabel
@onready var _player_xp_label: Label = $PlayerHUD/PlayerXPLabel
@onready var _combat_hud: Control = $CombatHUD
@onready var _enemy_hud: Control = $CombatHUD/EnemyHUD
@onready var _action_menu: Control = $CombatHUD/ActionMenu
@onready var _consumable_belt: ConsumableBeltUI = $ConsumableBelt
@onready var _combat_log: RichTextLabel = $CombatHUD/CombatLog
@onready var _dialogue_panel: DialoguePanel = $DialoguePanel
@onready var _skill_check_panel: SkillCheckPanel = $SkillCheckPanel
@onready var _rest_panel: RestPanel = $RestPanel
@onready var _world_map: WorldMap = $WorldMap
@onready var _inventory_panel: InventoryPanel = $InventoryPanel
@onready var _stats_label: Label = $InventoryPanel/HBoxContainer/StatsContainer/Label
@onready var _shop_panel: ShopPanel = $ShopPanel
@onready var _game_over_panel: GameOverPanel = $GameOverPanel
@onready var _victory_panel: VictoryPanel = $VictoryPanel

@export var _health_bar_scene: PackedScene
@export var enemy_health_bar_offset: Vector2 = Vector2(0, -40)

var _enemy_bars: Dictionary = {}
var _player_status_label: Label = null
var _player_mana_label: Label = null
var _player_mana_bar: ProgressBar = null
var _enemy_status_labels: Dictionary = {}

const _BTN_WIDTH := 90
const _BTN_HEIGHT := 35
const _BTN_MARGIN_RIGHT := -83.0
const _BTN_MARGIN_BOTTOM := -73.0
const _BTN_GAP := 5


func _ready() -> void:
	$MainMenu/StartButton.pressed.connect(_on_start_button_pressed)
	$MainMenu/ContinueButton.pressed.connect(_on_continue_button_pressed)
	$MainMenu/QuitButton.pressed.connect(_on_quit_button_pressed)
	$NewRunConfirmDialog.confirmed.connect(_on_new_run_confirmed)
	$PauseMenu/ResumeButton.pressed.connect(handle_esc)
	$PauseMenu/QuitToMainButton.pressed.connect(_on_quit_to_main_button_pressed)
	_main_menu.hide()
	_pause_menu.hide()
	_combat_hud.hide()
	_dialogue_panel.hide()
	_dialogue_panel.dialogue_complete.connect(_on_dialogue_complete)
	_skill_check_panel.hide()
	_skill_check_panel.skill_check_complete.connect(_on_skill_check_complete)
	_rest_panel.hide()
	_rest_panel.rest_requested.connect(_on_rest_requested)
	_rest_panel.rest_complete.connect(_on_rest_complete)
	_world_map.hide()
	_world_map.node_selected.connect(_on_world_map_node_selected)
	_player_hud.hide()
	_inventory_panel.hide()
	_character_creation.hide()
	_character_creation.character_confirmed.connect(_on_character_confirmed)
	_level_up_panel.hide()
	_level_up_panel.level_up_confirmed.connect(_on_level_up_confirmed)
	_shop_panel.hide()
	_shop_panel.buy_requested.connect(func(item: EquipmentData) -> void: shop_buy_requested.emit(item))
	_shop_panel.sell_requested.connect(func(item: EquipmentData) -> void: shop_sell_requested.emit(item))
	_shop_panel.leave_requested.connect(func() -> void: shop_leave_requested.emit())
	_consumable_belt.consumable_pressed.connect(_on_consumable_belt_pressed)
	_game_over_panel.hide()
	_game_over_panel.main_menu_requested.connect(func() -> void: quit_to_main_requested.emit())
	_victory_panel.hide()
	_victory_panel.main_menu_requested.connect(func() -> void: quit_to_main_requested.emit())
	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.layout_mode = 1
	_player_status_label.offset_left = 38.0
	_player_status_label.offset_top = 175.0
	_player_status_label.offset_right = 400.0
	_player_status_label.offset_bottom = 210.0
	_player_hud.add_child(_player_status_label)
	_player_mana_bar = ProgressBar.new()
	_player_mana_bar.name = "PlayerManaBar"
	_player_mana_bar.layout_mode = 1
	_player_mana_bar.offset_left = 38.0
	_player_mana_bar.offset_top = 50.0
	_player_mana_bar.offset_right = 190.0
	_player_mana_bar.offset_bottom = 68.0
	_player_mana_bar.modulate = Color(0.3, 0.5, 1.0)
	_player_hud.add_child(_player_mana_bar)
	_player_mana_label = Label.new()
	_player_mana_label.name = "PlayerManaLabel"
	_player_mana_label.layout_mode = 1
	_player_mana_label.offset_left = 38.0
	_player_mana_label.offset_top = 68.0
	_player_mana_label.offset_right = 190.0
	_player_mana_label.offset_bottom = 86.0
	_player_hud.add_child(_player_mana_label)


# --- Inventory ---

func setup_inventory(inventory: Inventory) -> void:
	_inventory_panel.setup(inventory)


func setup_spell_prep(player: Player) -> void:
	_inventory_panel.setup_spell_prep(player)


func setup_tomes(player: Player) -> void:
	_inventory_panel.setup_tomes(player)


func toggle_inventory(can_equip: bool = true) -> void:
	_inventory_panel.set_can_equip(can_equip)
	_inventory_panel.visible = not _inventory_panel.visible
	_consumable_belt.set_management_mode(_inventory_panel.visible)
	if _inventory_panel.visible:
		_consumable_belt.show()
	elif not _combat_hud.visible:
		_consumable_belt.hide()


func is_inventory_open() -> bool:
	return _inventory_panel.visible


func set_dungeon_locked(locked: bool) -> void:
	_inventory_panel.set_dungeon_locked(locked)


# --- Consumables ---

func setup_consumable_belt(inventory: Inventory) -> void:
	_consumable_belt.setup(inventory)


func set_consumables_enabled(enabled: bool) -> void:
	_consumable_belt.set_can_use(enabled)


# --- Navigation ---

func show_main_menu() -> void:
	_continue_button.disabled = not SaveManager.has_save()
	_main_menu.show()
	_pause_menu.hide()
	_combat_hud.hide()
	_player_hud.hide()


func start_game() -> void:
	_main_menu.hide()
	_player_hud.show()
	_world_map.reset()


func handle_esc() -> void:
	_pause_menu.visible = not _pause_menu.visible


func return_to_main_menu() -> void:
	_pause_menu.hide()
	_combat_hud.hide()
	_world_map.hide()
	_dialogue_panel.hide()
	_skill_check_panel.hide()
	_rest_panel.hide()
	_shop_panel.hide()
	_inventory_panel.hide()
	_consumable_belt.set_management_mode(false)
	_consumable_belt.hide()
	_game_over_panel.hide()
	_victory_panel.hide()
	_player_hud.hide()
	_continue_button.disabled = not SaveManager.has_save()
	_main_menu.show()


# --- Event HUD ---

func show_event_hud() -> void:
	set_sheathed(true)
	_combat_log.text = ""
	_combat_hud.show()
	_consumable_belt.show()


func hide_event_hud() -> void:
	for child in _enemy_hud.get_children():
		child.queue_free()
	_enemy_bars.clear()
	_enemy_status_labels.clear()
	_combat_hud.hide()
	if not _inventory_panel.visible:
		_consumable_belt.hide()


func set_sheathed(sheathed: bool) -> void:
	for child in _action_menu.get_children():
		if child is Button:
			child.disabled = sheathed


func _on_consumable_belt_pressed(index: int) -> void:
	if _consumable_belt.is_management_mode():
		_inventory_panel.unequip_belt_slot(index)
	else:
		consumable_use_requested.emit(index)


func update_player_health(current: float, maximum: float) -> void:
	_player_health_label.text = "%d/%d" % [int(current), int(maximum)]
	_player_health_bar.max_value = maximum
	_player_health_bar.value = current


func update_player_mana(current: float, maximum: float) -> void:
	if _player_mana_label == null or _player_mana_bar == null:
		return
	_player_mana_label.text = "MP %d/%d" % [int(current), int(maximum)]
	_player_mana_bar.max_value = maximum
	_player_mana_bar.value = current


func show_status(message: String) -> void:
	if _player_status_label != null:
		_player_status_label.text = message


func update_player_gold(new_total: int) -> void:
	_player_gold_label.text = "Gold: %d" % new_total


func update_player_xp(new_total: int) -> void:
	_player_xp_label.text = "XP: %d" % new_total


func update_player_stats(stats: Dictionary) -> void:
	var stat_names := Enums.Stat.keys()
	var lines: Array[String] = []
	for stat_key in Enums.Stat.values():
		var value: float = stats.get(stat_key, 0.0)
		var name: String = stat_names[stat_key] if stat_key < stat_names.size() else str(stat_key)
		lines.append("%s: %d" % [name, int(value)])
	_stats_label.text = "\n".join(lines)


func add_enemy_health_bar(enemy: Enemy) -> void:
	if _health_bar_scene == null:
		return
	var bar = _health_bar_scene.instantiate()
	bar.set_max_health(enemy.max_health)
	bar.set_current_health(enemy.health)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * enemy.global_position
	bar.position = screen_pos + enemy_health_bar_offset
	_enemy_hud.add_child(bar)
	_enemy_bars[enemy] = bar


func remove_enemy_health_bar(enemy: Enemy) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].queue_free()
	_enemy_bars.erase(enemy)
	_enemy_status_labels.erase(enemy)


func update_enemy_health_bar(enemy: Enemy, current: float) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].set_current_health(current)


func add_enemy_status_label(enemy: Enemy) -> void:
	if not _enemy_bars.has(enemy):
		return
	var lbl := Label.new()
	lbl.name = "StatusLabel"
	lbl.position = Vector2(-32.0, -18.0)
	_enemy_bars[enemy].add_child(lbl)
	_enemy_status_labels[enemy] = lbl


func refresh_enemy_statuses(enemy: Enemy, statuses: Array) -> void:
	if not _enemy_status_labels.has(enemy):
		return
	var parts: PackedStringArray = []
	for s in statuses:
		if s.data.duration == -1:
			parts.append(s.data.display_name)
		else:
			parts.append("%s(%d)" % [s.data.display_name, s.turns_remaining])
	_enemy_status_labels[enemy].text = " ".join(parts)


func refresh_player_statuses(statuses: Array) -> void:
	var parts: PackedStringArray = []
	for s in statuses:
		if s.data.duration == -1:
			parts.append(s.data.display_name)
		else:
			parts.append("%s(%d)" % [s.data.display_name, s.turns_remaining])
	_player_status_label.text = " ".join(parts)


func rebuild_action_buttons(attacks: Array, spells: Array[SpellData] = [], current_mana: float = 0.0) -> void:
	for child in _action_menu.get_children():
		child.queue_free()
	var items: Array = []
	for atk_res in attacks:
		if atk_res is AttackData:
			items.append(atk_res)
	for spell in spells:
		if spell != null:
			items.append(spell)
	for i in items.size():
		var item = items[i]
		var btn := Button.new()
		var action_name: String
		if item is AttackData:
			action_name = (item as AttackData).attack_name
			btn.text = action_name
		elif item is SpellData:
			var spell := item as SpellData
			action_name = spell.spell_name
			var cost := spell.mana_cost
			btn.text = "%s (%d)" % [action_name, int(cost)] if cost > 0.0 else action_name
			btn.disabled = current_mana < cost
		var offset_right := _BTN_MARGIN_RIGHT - i * (_BTN_WIDTH + _BTN_GAP)
		var offset_left := offset_right - _BTN_WIDTH
		btn.set_anchor(SIDE_LEFT, 1.0)
		btn.set_anchor(SIDE_TOP, 1.0)
		btn.set_anchor(SIDE_RIGHT, 1.0)
		btn.set_anchor(SIDE_BOTTOM, 1.0)
		btn.set_offset(SIDE_LEFT, offset_left)
		btn.set_offset(SIDE_TOP, _BTN_MARGIN_BOTTOM - _BTN_HEIGHT)
		btn.set_offset(SIDE_RIGHT, offset_right)
		btn.set_offset(SIDE_BOTTOM, _BTN_MARGIN_BOTTOM)
		var captured_name := action_name
		btn.pressed.connect(func() -> void: attack_requested.emit(captured_name))
		_action_menu.add_child(btn)


func set_targeting_action(action_name: String) -> void:
	var targeting := action_name != ""
	for child in _action_menu.get_children():
		if not child is Button:
			continue
		var btn := child as Button
		btn.focus_mode = Control.FOCUS_NONE if targeting else Control.FOCUS_ALL
		if targeting and btn.text == action_name:
			btn.modulate = Color(1.4, 1.4, 0.6)
		else:
			btn.modulate = Color.WHITE


func set_player_turn(is_player_turn: bool) -> void:
	for child in _action_menu.get_children():
		if child is Button:
			child.disabled = not is_player_turn


func log_message(text: String) -> void:
	_combat_log.append_text(text + "\n")


# --- World Map ---

func get_world_map() -> WorldMap:
	return _world_map


func show_world_map() -> void:
	_world_map.show()


func hide_world_map() -> void:
	_world_map.hide()


func world_map_on_dungeon_complete(completed_node: WorldMapNode) -> void:
	_world_map.on_dungeon_complete(completed_node)
	_world_map.show()


func _on_world_map_node_selected(node: WorldMapNode) -> void:
	_world_map.hide()
	node_selected.emit(node)


# --- Dialogue ---

func show_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void:
	_dialogue_panel.load_dialogue(data, consequences)
	_dialogue_panel.show()


func _on_dialogue_complete(terminal_node_id: String) -> void:
	_dialogue_panel.hide()
	dialogue_complete.emit(terminal_node_id)


# --- Skill Check ---

func show_skill_check(stat_name: String, label: String, stat_value: float, threshold: float) -> void:
	_skill_check_panel.setup(stat_name, label, stat_value, threshold)
	_skill_check_panel.show()


func _on_skill_check_complete(success: bool) -> void:
	_skill_check_panel.hide()
	skill_check_complete.emit(success)


# --- Rest Panel ---

func show_rest_panel(heal_amount: float) -> void:
	_rest_panel.setup(heal_amount)
	_rest_panel.show()


func hide_rest_panel() -> void:
	_rest_panel.hide()


func _on_rest_requested() -> void:
	rest_requested.emit()


func _on_rest_complete() -> void:
	_rest_panel.hide()
	rest_complete.emit()


# --- Character Creation ---

## Shows the character creation panel. Wired once the scene is built.
func show_character_creation() -> void:
	_main_menu.hide()
	_character_creation.reset()
	_character_creation.show()


func _on_character_confirmed(p_name: String, class_data: PlayerClassData, background: BackgroundData = null, patron: PatronSaintData = null) -> void:
	_character_creation.hide()
	character_created.emit(p_name, class_data, background, patron)


# --- Level-Up Panel ---

## Called by game.gd when the player has pending stat points to distribute.
func show_level_up(player: Player) -> void:
	_level_up_panel.setup(player)
	_level_up_panel.show()


func hide_level_up() -> void:
	_level_up_panel.hide()


func _on_level_up_confirmed() -> void:
	hide_level_up()
	level_up_complete.emit()


# --- Shop Panel ---

func show_shop(
	shop_name: String,
	stock: Array[EquipmentData],
	bag: Array[EquipmentData],
	gold: int,
	buy_mult: float,
	sell_mult: float,
	bag_full: bool
) -> void:
	_shop_panel.setup(shop_name, stock, bag, gold, buy_mult, sell_mult, bag_full)
	_shop_panel.show()


func hide_shop() -> void:
	_shop_panel.hide()


func refresh_shop_stock(stock: Array[EquipmentData], bag_full: bool) -> void:
	_shop_panel.refresh_stock(stock, bag_full)


func refresh_shop_bag(bag: Array[EquipmentData], bag_full: bool) -> void:
	_shop_panel.refresh_bag(bag, bag_full)


func refresh_shop_gold(gold: int) -> void:
	_shop_panel.refresh_gold(gold)


func show_shop_status(msg: String) -> void:
	_shop_panel.show_status(msg)


# --- Game Over / Victory ---

func show_game_over() -> void:
	_game_over_panel.show()


func hide_game_over() -> void:
	_game_over_panel.hide()


func show_victory() -> void:
	_victory_panel.show()


func hide_victory() -> void:
	_victory_panel.hide()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_start_button_pressed() -> void:
	if SaveManager.has_save():
		_new_run_confirm_dialog.popup_centered()
	else:
		show_character_creation()


func _on_continue_button_pressed() -> void:
	continue_requested.emit()


func _on_new_run_confirmed() -> void:
	SaveManager.clear()
	show_character_creation()


func _on_quit_to_main_button_pressed() -> void:
	quit_to_main_requested.emit()
