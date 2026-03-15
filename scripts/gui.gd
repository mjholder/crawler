class_name GUI
extends CanvasLayer

# --- Signals ---
signal start_requested
signal quit_to_main_requested
signal attack_requested

# --- Node References ---
@onready var _main_menu: Control = $MainMenu
@onready var _pause_menu: Control = $PauseMenu
@onready var _combat_hud: Control = $CombatHUD
@onready var _player_health_label: Label = $CombatHUD/PlayerHUD/PlayerHealthLabel
@onready var _player_health_bar: ProgressBar = $CombatHUD/PlayerHUD/PlayerHealthBar
@onready var _enemy_hud: Control = $CombatHUD/EnemyHUD
@onready var _action_menu: Control = $CombatHUD/ActionMenu
@onready var _combat_log: RichTextLabel = $CombatHUD/CombatLog

@export var _health_bar_scene: PackedScene

var _enemy_bars: Dictionary = {}


func _ready() -> void:
	$MainMenu/StartButton.pressed.connect(_on_start_button_pressed)
	$MainMenu/QuitButton.pressed.connect(_on_quit_button_pressed)
	$PauseMenu/ResumeButton.pressed.connect(handle_esc)
	$PauseMenu/QuitToMainButton.pressed.connect(_on_quit_to_main_button_pressed)
	_main_menu.hide()
	_pause_menu.hide()
	_combat_hud.hide()


# --- Navigation ---

func show_main_menu() -> void:
	_main_menu.show()
	_pause_menu.hide()
	_combat_hud.hide()


func start_game() -> void:
	_main_menu.hide()


func handle_esc() -> void:
	_pause_menu.visible = not _pause_menu.visible


func return_to_main_menu() -> void:
	_pause_menu.hide()
	_combat_hud.hide()
	_main_menu.show()


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


func add_enemy_health_bar(enemy: Enemy) -> void:
	if _health_bar_scene == null:
		return
	var bar = _health_bar_scene.instantiate()
	bar.set_max_health(enemy.max_health)
	bar.set_current_health(enemy.health)
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


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_attack_button_pressed() -> void:
	attack_requested.emit()


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _on_quit_to_main_button_pressed() -> void:
	quit_to_main_requested.emit()
