class_name GUI
extends CanvasLayer

# --- Signals ---
signal character_created(player_name: String, class_data: PlayerClassData, background: BackgroundData, patron: PatronSaintData)
signal level_up_complete
signal quit_to_main_requested
signal attack_requested(hand: int, attack_name: String)
signal end_turn_requested
signal dialogue_complete(terminal_node_id: String)
signal skill_check_complete(success: bool)
signal rest_requested
signal rest_complete
signal node_selected(node: WorldMapNode)
signal shop_buy_requested(item: EquipmentData)
signal shop_sell_requested(item: EquipmentData)
signal shop_leave_requested
signal shrine_ascend_requested
signal shrine_leave_requested
signal town_temple_requested
signal town_travel_requested
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
@onready var _player_health_label: Label = $PlayerHUD/PlayerHealth/PlayerHealthLabel
@onready var _player_health_bar: ProgressBar = $PlayerHUD/PlayerHealth/PlayerHealthBar
@onready var _player_armor_bar: ProgressBar = get_node_or_null("PlayerHUD/PlayerArmor/PlayerArmorBar")
@onready var _player_armor_label: Label = get_node_or_null("PlayerHUD/PlayerArmor/PlayerArmorLabel")
@onready var _player_gold_label: Label = $PlayerHUD/PlayerGold/PlayerGoldLabel
@onready var _player_xp_bar: ProgressBar = $PlayerHUD/PlayerXP/PlayerXPBar
@onready var _player_xp_label: Label = $PlayerHUD/PlayerXP/PlayerXPLabel
@onready var _combat_hud: Control = $CombatHUD
@onready var _enemy_hud: Control = $CombatHUD/EnemyHUD
## Screen-space overlay (on top of the health bars) that floating damage numbers
## parent to; see _spawn_at.
@onready var _damage_number_layer: Control = $CombatHUD/DamageNumbers
## Hand-placed launch points for the player-facing floating numbers.
@onready var _player_damage_origin: Control = $CombatHUD/PlayerDamageSpawnpoint
@onready var _spell_spend_origin: Control = $CombatHUD/SpellSpendNumber
@onready var _action_menu: Control = $CombatHUD/ActionMenu
# Dual-action bar: one button group per hand plus an explicit End Turn. Built in the
# scene under ActionMenu; if absent (scene not yet updated), _ensure_action_nodes()
# creates a usable fallback so combat still works.
@onready var _mainhand_actions: HBoxContainer = get_node_or_null("CombatHUD/ActionMenu/MainhandActions")
@onready var _offhand_actions: HBoxContainer = get_node_or_null("CombatHUD/ActionMenu/OffhandActions")
@onready var _end_turn_button: Button = get_node_or_null("CombatHUD/ActionMenu/EndTurnButton")
@onready var _consumable_belt: ConsumableBeltUI = $ConsumableBelt
@onready var _combat_log: CombatLog = $CombatHUD/CombatLog
@onready var _player_mana_bar: ProgressBar = $PlayerHUD/PlayerMagic/PlayerMagicBar
@onready var _player_mana_label: Label = $PlayerHUD/PlayerMagic/PlayerMagicLabel
@onready var _status_container: HBoxContainer = $CombatHUD/PlayerStatusEffects/StatusContainer
@onready var _dialogue_panel: DialoguePanel = $DialoguePanel
@onready var _skill_check_panel: SkillCheckPanel = $SkillCheckPanel
@onready var _rest_panel: RestPanel = $RestPanel
@onready var _shrine_panel: ShrinePanel = $ShrinePanel
@onready var _town_panel: TownPanel = $TownPanel
@onready var _world_map: WorldMap = $WorldMap
@onready var _inventory_panel: InventoryPanel = $InventoryPanel
@onready var _stats_label: Label = $InventoryPanel/HBoxContainer/StatsContainer/Label
@onready var _shop_panel: ShopPanel = $ShopPanel
@onready var _game_over_panel: GameOverPanel = $GameOverPanel
@onready var _victory_panel: VictoryPanel = $VictoryPanel

const ACTION_SCENE := preload("res://scenes/action.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/damage_number.tscn")

@export var _health_bar_scene: PackedScene
@export var enemy_health_bar_offset: Vector2 = Vector2(0, -40)

var _enemy_bars: Dictionary = {}
# Action-bar gating. A button is enabled iff it's the player's turn, weapons aren't
# sheathed, that hand isn't spent, and (for spells) it's affordable.
var _sheathed: bool = true
var _is_player_turn: bool = false
var _mh_used: bool = false
var _oh_used: bool = false
var _oh_locked: bool = false
var _action_mana: float = 0.0
var _player_status_label: Label = null
# Source combatant (the player) for evaluating action-button damage/status preview tooltips.
# Read-only stat queries only — the GUI never mutates it.
var _preview_source: Node = null


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
	_shrine_panel.hide()
	_shrine_panel.ascend_requested.connect(func() -> void: shrine_ascend_requested.emit())
	_shrine_panel.leave_requested.connect(func() -> void: shrine_leave_requested.emit())
	_town_panel.hide()
	_town_panel.temple_requested.connect(func() -> void: town_temple_requested.emit())
	_town_panel.travel_requested.connect(func() -> void: town_travel_requested.emit())
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
	# Transient message toast (e.g. "Not enough mana"). Positioned below the HUD's
	# left column, which now runs down to ~y208 (health/armor/magic + Bag/Gold row).
	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.layout_mode = 1
	_player_status_label.offset_left = 38.0
	_player_status_label.offset_top = 220.0
	_player_status_label.offset_right = 400.0
	_player_status_label.offset_bottom = 255.0
	_player_hud.add_child(_player_status_label)
	_ensure_action_nodes()
	if _end_turn_button != null:
		_end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())


# --- Action Bar (dual-action) ---

## Creates fallback action-bar nodes if the scene doesn't provide them yet. Once the
## CombatHUD scene defines MainhandActions / OffhandActions / EndTurnButton under
## ActionMenu, these are used instead and this is a no-op.
func _ensure_action_nodes() -> void:
	if _mainhand_actions == null:
		_mainhand_actions = _make_action_row("MainhandActions", -120.0)
	if _offhand_actions == null:
		_offhand_actions = _make_action_row("OffhandActions", -82.0)
	if _end_turn_button == null:
		var btn := Button.new()
		btn.name = "EndTurnButton"
		btn.text = "End Turn"
		btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		btn.offset_left = -110.0
		btn.offset_right = -20.0
		btn.offset_top = -44.0
		btn.offset_bottom = -14.0
		_action_menu.add_child(btn)
		_end_turn_button = btn


func _make_action_row(node_name: String, bottom: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 5)
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left = -640.0
	row.offset_right = -20.0
	row.offset_top = bottom - 35.0
	row.offset_bottom = bottom
	_action_menu.add_child(row)
	return row


# --- Inventory ---

func setup_inventory(inventory: Inventory) -> void:
	_inventory_panel.setup(inventory)


func setup_spell_prep(player: Player) -> void:
	_inventory_panel.setup_spell_prep(player)


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
	_shrine_panel.hide()
	_town_panel.hide()
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
	_combat_log.clear()
	_combat_hud.show()
	_consumable_belt.show()


func hide_event_hud() -> void:
	for child in _enemy_hud.get_children():
		child.queue_free()
	_enemy_bars.clear()
	if _damage_number_layer != null:
		for child in _damage_number_layer.get_children():
			child.queue_free()
	_combat_hud.hide()
	if not _inventory_panel.visible:
		_consumable_belt.hide()


func set_sheathed(sheathed: bool) -> void:
	_sheathed = sheathed
	_apply_action_states()


func _on_consumable_belt_pressed(index: int) -> void:
	if _consumable_belt.is_management_mode():
		_inventory_panel.unequip_belt_slot(index)
	else:
		consumable_use_requested.emit(index)


func update_player_health(current: float, maximum: float) -> void:
	_player_health_label.text = "%d/%d" % [int(current), int(maximum)]
	_player_health_bar.max_value = maximum
	_player_health_bar.value = current


## Draws the per-round armor buffer below the health bar. Stays visible even for a
## no-DEF build (shows 0/0) so the HUD layout is stable across classes.
func update_player_armor(current: float, maximum: float) -> void:
	if _player_armor_bar != null:
		_player_armor_bar.max_value = maxf(maximum, 1.0)
		_player_armor_bar.value = current
	if _player_armor_label != null:
		_player_armor_label.text = "%d/%d" % [int(current), int(maximum)]


func update_player_mana(current: float, maximum: float) -> void:
	if _player_mana_label == null or _player_mana_bar == null:
		return
	_player_mana_label.text = "%d/%d" % [int(current), int(maximum)]
	_player_mana_bar.max_value = maxf(maximum, 1.0)
	_player_mana_bar.value = current


func show_status(message: String) -> void:
	if _player_status_label != null:
		_player_status_label.text = message


func update_player_gold(new_total: int) -> void:
	_player_gold_label.text = "Gold: %d" % new_total


func update_player_xp(current: int, to_next: int) -> void:
	_player_xp_bar.max_value = maxf(float(to_next), 1.0)
	_player_xp_bar.value = current
	_player_xp_label.text = "%d/%d" % [current, to_next]


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
	# Add first so the bar's @onready node refs resolve before we feed it data.
	_enemy_hud.add_child(bar)
	bar.set_max_health(enemy.max_health)
	bar.set_current_health(enemy.health)
	bar.set_armor(enemy.armor, enemy.max_armor)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * enemy.global_position
	# Control positions by top-left, so center the bar horizontally over the enemy.
	bar.position = screen_pos + enemy_health_bar_offset - Vector2(bar.size.x * 0.5, 0.0)
	_enemy_bars[enemy] = bar


func remove_enemy_health_bar(enemy: Enemy) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].queue_free()
	_enemy_bars.erase(enemy)


func update_enemy_health_bar(enemy: Enemy, current: float) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].set_current_health(current)


func update_enemy_armor(enemy: Enemy, current: float, maximum: float) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].set_armor(current, maximum)


# --- Floating damage numbers ---

## Spawn a self-freeing DamageNumber centered on a global `origin` point, in the
## overlay layer. The layer and every source node share this CanvasLayer's screen-space
## frame. Parenting to the layer (not a bar) lets the number keep animating even if its
## source is freed mid-flight (e.g. the enemy dies).
func _spawn_at(origin: Vector2, amount: float, kind: int) -> void:
	if _damage_number_layer == null:
		return
	var dn: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	_damage_number_layer.add_child(dn)
	dn.global_position = origin - dn.size * 0.5  # center on origin
	dn.setup(amount, kind)


func _marker_center(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5


## Global launch point for an enemy's numbers: the center of its "DamageNumberSpawnpoint"
## marker child (hand-placed in the health-bar scene) if present, else the bar's top-center.
func _bar_origin(bar: Control) -> Vector2:
	var marker := bar.get_node_or_null("DamageNumberSpawnpoint")
	if marker is Control:
		return _marker_center(marker)
	return bar.global_position + Vector2(bar.size.x * 0.5, 0.0)


func spawn_enemy_damage(enemy: Enemy, amount: float, is_crit: bool = false) -> void:
	if _enemy_bars.has(enemy):
		var kind := DamageNumber.Kind.CRIT if is_crit else DamageNumber.Kind.DAMAGE
		_spawn_at(_bar_origin(_enemy_bars[enemy]), amount, kind)


func spawn_player_damage(amount: float, is_crit: bool = false) -> void:
	if _player_damage_origin != null:
		var kind := DamageNumber.Kind.CRIT if is_crit else DamageNumber.Kind.DAMAGE
		_spawn_at(_marker_center(_player_damage_origin), amount, kind)


func spawn_player_heal(amount: float) -> void:
	if _player_damage_origin != null:
		_spawn_at(_marker_center(_player_damage_origin), amount, DamageNumber.Kind.HEAL)


func spawn_player_armor_damage(amount: float) -> void:
	if _player_damage_origin != null:
		_spawn_at(_marker_center(_player_damage_origin), amount, DamageNumber.Kind.ARMOR)


func spawn_player_mana_cost(amount: float) -> void:
	if _spell_spend_origin != null:
		_spawn_at(_marker_center(_spell_spend_origin), amount, DamageNumber.Kind.MANA)


## Rebuilds an enemy's status-icon strip in its health bar's Statuses HBox,
## mirroring the player's status strip (atlas icon + stack-count overlay + tooltip).
func refresh_enemy_statuses(enemy: Enemy, statuses: Array) -> void:
	if not _enemy_bars.has(enemy):
		return
	var strip: HBoxContainer = _enemy_bars[enemy].statuses
	for child in strip.get_children():
		child.queue_free()
	for s in statuses:
		strip.add_child(_make_status_icon(s))


## Rebuilds the player's active-status icon strip from the current status list.
## Each active status is one atlas icon (its StatusData.icon). Stacking statuses show
## their stack count as a small corner number; single stacks show none. Full detail
## (name, stacks, remaining turns) is in the hover tooltip.
func refresh_player_statuses(statuses: Array) -> void:
	for child in _status_container.get_children():
		child.queue_free()
	for s in statuses:
		_status_container.add_child(_make_status_icon(s))


func _make_status_icon(s: StatusInstance) -> Control:
	var icon := TextureRect.new()
	icon.texture = s.data.icon
	icon.custom_minimum_size = Vector2(32.0, 32.0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = _status_tooltip(s)
	if s.stacks > 1:
		var count := Label.new()
		count.name = "StackCount"
		count.text = str(s.stacks)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(count)
	return icon


func _status_tooltip(s: StatusInstance) -> String:
	var text := s.data.display_name
	if s.stacks > 1:
		text += " x%d" % s.stacks
	if s.data.duration != -1:
		text += " (%d)" % s.turns_remaining
	return text


func rebuild_action_buttons(
	mainhand_attacks: Array, mainhand_spells: Array,
	offhand_attacks: Array, offhand_spells: Array,
	current_mana: float,
	mainhand_used: bool, offhand_used: bool, offhand_locked: bool,
	mainhand_cooldowns: Dictionary = {}, offhand_cooldowns: Dictionary = {}
) -> void:
	_action_mana = current_mana
	_mh_used = mainhand_used
	_oh_used = offhand_used
	_oh_locked = offhand_locked
	_populate_hand_group(_mainhand_actions, Player.Hand.MAINHAND, mainhand_attacks, mainhand_spells, mainhand_cooldowns)
	_populate_hand_group(_offhand_actions, Player.Hand.OFFHAND, offhand_attacks, offhand_spells, offhand_cooldowns)
	# The offhand row hides entirely when the hand offers nothing (e.g. a two-hander that
	# locks the offhand and grants no supporting action).
	_offhand_actions.visible = _offhand_actions.get_child_count() > 0
	_apply_action_states()


func _populate_hand_group(group: HBoxContainer, hand: int, attacks: Array, spells: Array, cooldowns: Dictionary = {}) -> void:
	if group == null:
		return
	for child in group.get_children():
		child.queue_free()
	for atk_res in attacks:
		var atk := atk_res as AttackData
		if atk != null:
			_add_action_button(group, hand, atk.attack_name, 0.0, cooldowns.get(atk.attack_name, 0), _build_action_tooltip(atk, atk.attack_name, atk.target_mode, atk.description))
	for spell_res in spells:
		var spell := spell_res as SpellData
		if spell != null:
			_add_action_button(group, hand, spell.spell_name, spell.mana_cost, cooldowns.get(spell.spell_name, 0), _build_action_tooltip(spell, spell.spell_name, spell.target_mode, spell.description))


func _add_action_button(group: HBoxContainer, hand: int, action_name: String, cost: float, cooldown_remaining: int = 0, tooltip: String = "") -> void:
	var action := ACTION_SCENE.instantiate() as ActionButtonUI
	group.add_child(action)
	action.configure(hand, action_name, cost, cooldown_remaining, tooltip)
	action.pressed.connect(func() -> void: attack_requested.emit(hand, action_name))


## Sets the combatant whose stats feed action-button damage/status preview tooltips.
func set_preview_source(node: Node) -> void:
	_preview_source = node


const _TARGET_MODE_LABEL := {
	AttackData.TargetMode.SINGLE_ENEMY: "Single enemy",
	AttackData.TargetMode.ALL_ENEMIES: "All enemies",
	AttackData.TargetMode.SELF: "Self",
}


## Multi-line hover tooltip for an action: name, target mode, then the per-effect breakdown
## (humanized scaling expression + computed value) from the shared AttackPreview.
func _build_action_tooltip(action_data: Object, action_name: String, target_mode: int, description: String) -> String:
	var text := action_name
	text += "\nTarget: %s" % _TARGET_MODE_LABEL.get(target_mode, "?")
	if description != "":
		text += "\n%s" % description
	if _preview_source != null:
		var body := AttackPreview.compute(action_data, _preview_source).tooltip_body()
		if body != "":
			text += "\n————\n%s" % body
	return text


## Recomputes every action button's disabled/focus state from the current gates.
func _apply_action_states() -> void:
	_apply_group_states(_mainhand_actions, _mh_used)
	_apply_group_states(_offhand_actions, _oh_used)
	if _end_turn_button != null:
		_end_turn_button.disabled = not (_is_player_turn and not _sheathed)


func _apply_group_states(group: HBoxContainer, hand_used: bool) -> void:
	if group == null:
		return
	var base := _is_player_turn and not _sheathed and not hand_used
	for child in group.get_children():
		var action := child as ActionButtonUI
		if action == null:
			continue
		action.set_disabled(not base or (action.cost > 0.0 and _action_mana < action.cost) or action.cooldown_remaining > 0)


func set_targeting_action(hand: int, action_name: String) -> void:
	var targeting := action_name != ""
	for group in [_mainhand_actions, _offhand_actions]:
		if group == null:
			continue
		for child in group.get_children():
			var action := child as ActionButtonUI
			if action == null:
				continue
			action.set_focus_enabled(not targeting)
			action.set_highlighted(targeting and action.hand == hand and action.action_name == action_name)


func set_player_turn(is_player_turn: bool) -> void:
	_is_player_turn = is_player_turn
	_apply_action_states()


func log_message(text: String) -> void:
	_combat_log.push(text)


# --- World Map ---

func get_world_map() -> WorldMap:
	return _world_map


## Replaces the live world map with a new act's scene. The new instance is named
## "WorldMap" so saved node paths (relative to the WorldMap root) stay valid, and its
## own _ready() rebuilds the floor pool, wires child nodes, and resets node states.
func swap_world_map(scene: PackedScene) -> void:
	var parent := _world_map.get_parent()
	var old_index := _world_map.get_index()
	# Detach synchronously so the "WorldMap" name is free before the new node is added
	# (otherwise add_child would auto-rename it and saved node paths would break).
	parent.remove_child(_world_map)
	_world_map.queue_free()
	var new_map := scene.instantiate() as WorldMap
	new_map.name = "WorldMap"
	new_map.hide()
	parent.add_child(new_map)
	parent.move_child(new_map, old_index)
	_world_map = new_map
	_world_map.node_selected.connect(_on_world_map_node_selected)


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


# --- Shrine Panel ---

func show_shrine_panel(
	saint_name: String,
	has_next: bool,
	next_tier_name: String,
	next_tier_desc: String,
	next_stat_mods: Dictionary,
	cost: int,
	player_gold: int
) -> void:
	_shrine_panel.setup(saint_name, has_next, next_tier_name, next_tier_desc, next_stat_mods, cost, player_gold)
	_shrine_panel.show()


func hide_shrine_panel() -> void:
	_shrine_panel.hide()


# --- Town Panel (end-of-act hub) ---

func show_town_panel() -> void:
	_town_panel.show()


func hide_town_panel() -> void:
	_town_panel.hide()


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
