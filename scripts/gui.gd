class_name GUI
extends CanvasLayer

# --- Signals ---
signal start_requested
signal start_dialogue_requested
signal start_skill_check_requested
signal quit_to_main_requested
signal attack_requested
signal dialogue_complete
signal skill_check_complete(success: bool)
signal node_selected(node: WorldMapNode)

# --- Node References ---
@onready var _main_menu: Control = $MainMenu
@onready var _pause_menu: Control = $PauseMenu
@onready var _player_hud: Control = $PlayerHUD
@onready var _player_health_label: Label = $PlayerHUD/PlayerHealthLabel
@onready var _player_health_bar: ProgressBar = $PlayerHUD/PlayerHealthBar
@onready var _player_gold_label: Label = $PlayerHUD/PlayerGoldLabel
@onready var _player_xp_label: Label = $PlayerHUD/PlayerXPLabel
@onready var _combat_hud: Control = $CombatHUD
@onready var _enemy_hud: Control = $CombatHUD/EnemyHUD
@onready var _action_menu: Control = $CombatHUD/ActionMenu
@onready var _combat_log: RichTextLabel = $CombatHUD/CombatLog
@onready var _dialogue_panel: DialoguePanel = $DialoguePanel
@onready var _skill_check_panel: SkillCheckPanel = $SkillCheckPanel
@onready var _world_map: WorldMap = $WorldMap
@onready var _inventory_panel: InventoryPanel = $InventoryPanel

@export var _health_bar_scene: PackedScene
@export var enemy_health_bar_offset: Vector2 = Vector2(0, -40)

var _enemy_bars: Dictionary = {}


func _ready() -> void:
	$MainMenu/StartButton.pressed.connect(_on_start_button_pressed)
	$MainMenu/StartDialogueButton.pressed.connect(_on_start_dialogue_button_pressed)
	$MainMenu/StartSkillCheckButton.pressed.connect(_on_start_skill_check_button_pressed)
	$MainMenu/QuitButton.pressed.connect(_on_quit_button_pressed)
	$PauseMenu/ResumeButton.pressed.connect(handle_esc)
	$PauseMenu/QuitToMainButton.pressed.connect(_on_quit_to_main_button_pressed)
	_main_menu.hide()
	_pause_menu.hide()
	_combat_hud.hide()
	_dialogue_panel.hide()
	_dialogue_panel.dialogue_complete.connect(_on_dialogue_complete)
	_skill_check_panel.hide()
	_skill_check_panel.skill_check_complete.connect(_on_skill_check_complete)
	_world_map.hide()
	_world_map.node_selected.connect(_on_world_map_node_selected)
	_player_hud.hide()
	_inventory_panel.hide()


# --- Inventory ---

func setup_inventory(inventory: Inventory) -> void:
	_inventory_panel.setup(inventory)


func toggle_inventory() -> void:
	_inventory_panel.visible = not _inventory_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()


# --- Navigation ---

func show_main_menu() -> void:
	_main_menu.show()
	_pause_menu.hide()
	_combat_hud.hide()
	_player_hud.hide()


func start_game() -> void:
	_main_menu.hide()
	_player_hud.show()


func handle_esc() -> void:
	_pause_menu.visible = not _pause_menu.visible


func return_to_main_menu() -> void:
	_pause_menu.hide()
	_combat_hud.hide()
	_main_menu.show()
	_player_hud.hide()


# --- Combat HUD ---

func show_combat_hud() -> void:
	_combat_log.text = ""
	_combat_hud.show()


func hide_combat_hud() -> void:
	_combat_hud.hide()


func update_player_health(current: float, maximum: float) -> void:
	_player_health_label.text = "%d/%d" % [int(current), int(maximum)]
	_player_health_bar.max_value = maximum
	_player_health_bar.value = current


func update_player_gold(new_total: int) -> void:
	_player_gold_label.text = "Gold: %d" % new_total


func update_player_xp(new_total: int) -> void:
	_player_xp_label.text = "XP: %d" % new_total


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


func update_enemy_health_bar(enemy: Enemy, current: float) -> void:
	if not _enemy_bars.has(enemy):
		return
	_enemy_bars[enemy].set_current_health(current)


func set_player_turn(is_player_turn: bool) -> void:
	for child in _action_menu.get_children():
		if child is Button:
			child.disabled = not is_player_turn


func log_message(text: String) -> void:
	_combat_log.append_text(text + "\n")


# --- World Map ---

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


func _on_dialogue_complete() -> void:
	_dialogue_panel.hide()
	dialogue_complete.emit()


# --- Skill Check ---

func show_skill_check(stat_name: String, label: String, stat_value: float) -> void:
	_skill_check_panel.setup(stat_name, label, stat_value)
	_skill_check_panel.show()


func _on_skill_check_complete(success: bool) -> void:
	_skill_check_panel.hide()
	skill_check_complete.emit(success)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_attack_button_pressed() -> void:
	attack_requested.emit()


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _on_start_dialogue_button_pressed() -> void:
	start_dialogue_requested.emit()


func _on_start_skill_check_button_pressed() -> void:
	start_skill_check_requested.emit()


func _on_quit_to_main_button_pressed() -> void:
	quit_to_main_requested.emit()
