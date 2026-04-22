class_name CombatEvent
extends Event

const DEFAULT_VICTORY_DIALOGUE := "res://resources/dialogue/post_combat_default.json"

# --- Signals ---

signal enemy_added(enemy: Enemy, total_expected: int)
signal dialogue_trigger_fired(trigger_name: String, data: Dictionary)
signal player_attacked(damage: float)
signal player_attack_resolved(enemy: Enemy, damage: float)
signal enemy_turns_complete

# --- Config ---

var _init_data: Dictionary = {}
var _dialogue_triggers: Dictionary = {}
var _total_expected_enemies: int = 0

# --- Enemies ---

var _enemies: Array[Enemy] = []
var _turn_queue: Array[Enemy] = []

# --- Waves ---

var _waves: Array = []
var _current_wave_index: int = -1


# --- Public API ---

func initialize(data: Dictionary) -> void:
	_init_data = data


# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	enemy_added.connect(game._on_combat_enemy_added)
	dialogue_trigger_fired.connect(game._on_combat_dialogue_trigger)
	player_attacked.connect(game._on_player_attacked)
	enemy_turns_complete.connect(game._on_enemy_turns_complete)
	game.player.attack.connect(game._on_player_attack_action)
	game._gui.show_combat_hud()
	game._gui.set_player_turn(false)
	game._start_combat_music()
	game.player.set_weapon_visible(true)


func _on_exit(game: Node) -> void:
	enemy_added.disconnect(game._on_combat_enemy_added)
	dialogue_trigger_fired.disconnect(game._on_combat_dialogue_trigger)
	player_attacked.disconnect(game._on_player_attacked)
	enemy_turns_complete.disconnect(game._on_enemy_turns_complete)
	game.player.attack.disconnect(game._on_player_attack_action)
	for enemy in _enemies:
		game._gui.remove_enemy_health_bar(enemy)
	game._gui.hide_combat_hud()
	game.player.set_weapon_visible(false)


# --- Setup ---

func _on_setup() -> void:
	if _init_data.is_empty():
		push_warning("CombatEvent: initialize() was not called before start()")
		return
	rewards = _init_data.get("rewards", {})
	_dialogue_triggers = _init_data.get("dialogue_triggers", {})

	var waves_data: Array = _init_data.get("waves", [])
	if not waves_data.is_empty():
		_waves = waves_data
	else:
		# Legacy flat format: spawn all enemies immediately in setup
		var enemy_entries: Array = _init_data.get("enemies", [])
		for entry in enemy_entries:
			_total_expected_enemies += entry.get("count", 1)
		for entry in enemy_entries:
			var scene_path: String = entry.get("scene", "")
			if scene_path == "":
				push_warning("CombatEvent: enemy entry missing 'scene'")
				continue
			var packed := load(scene_path) as PackedScene
			if packed == null:
				push_warning("CombatEvent: could not load scene '%s'" % scene_path)
				continue
			for i in range(entry.get("count", 1)):
				add_enemy(packed.instantiate() as Enemy)


func _on_running() -> void:
	_fire_trigger("on_start")
	if not _waves.is_empty() and not _dialogue_triggers.has("on_start"):
		_start_next_wave()


# --- Wave Control ---

func _start_next_wave() -> void:
	_current_wave_index += 1
	if _current_wave_index >= _waves.size():
		push_warning("CombatEvent: _start_next_wave() called past end of waves array")
		return

	var wave: Dictionary = _waves[_current_wave_index]
	var entries: Array = wave.get("enemies", [])

	# Free dead enemies from the previous wave so they clear from screen
	for e in _enemies:
		if e.is_dead:
			e.queue_free()
	_enemies = _enemies.filter(func(e: Enemy) -> bool: return not e.is_dead)

	_total_expected_enemies = 0
	for entry in entries:
		_total_expected_enemies += entry.get("count", 1)

	for entry in entries:
		var scene_path: String = entry.get("scene", "")
		if scene_path == "":
			push_warning("CombatEvent: wave enemy entry missing 'scene'")
			continue
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_warning("CombatEvent: could not load scene '%s'" % scene_path)
			continue
		for i in range(entry.get("count", 1)):
			add_enemy(packed.instantiate() as Enemy)


# --- Phase Control ---

func _advance_phase() -> void:
	match phase:
		Phase.RUNNING:
			if not _waves.is_empty():
				var is_last_wave: bool = _current_wave_index >= _waves.size() - 1
				if is_last_wave:
					_set_phase(Phase.RESOLUTION)
					return
				var trigger_key: String = _waves[_current_wave_index].get("on_clear_trigger", "")
				if trigger_key != "" and _dialogue_triggers.has(trigger_key):
					_fire_trigger(trigger_key)
				else:
					_start_next_wave()
			else:
				_set_phase(Phase.RESOLUTION)
				# Do NOT auto-advance to COMPLETE; _on_resolution decides


func _on_resolution() -> void:
	if _dialogue_triggers.has("on_victory"):
		_fire_trigger("on_victory")
		# game.gd calls on_dialogue_complete() when dialogue is done
		return
	var file := FileAccess.open(DEFAULT_VICTORY_DIALOGUE, FileAccess.READ)
	if file == null:
		push_warning("CombatEvent: default victory dialogue missing at '%s'" % DEFAULT_VICTORY_DIALOGUE)
		_set_phase(Phase.COMPLETE)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	dialogue_trigger_fired.emit("on_victory_default", data)


func on_dialogue_complete() -> void:
	if phase == Phase.RESOLUTION:
		_set_phase(Phase.COMPLETE)
	else:
		_start_next_wave()


# --- Trigger Helper ---

func _fire_trigger(trigger_name: String) -> void:
	if not _dialogue_triggers.has(trigger_name):
		return
	var path: String = _dialogue_triggers[trigger_name]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("CombatEvent: trigger '%s' could not open '%s'" % [trigger_name, path])
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	dialogue_trigger_fired.emit(trigger_name, data)


# --- Enemy Management ---

func add_enemy(enemy: Enemy) -> void:
	enemy.enemy_name = "%s %d" % [enemy.enemy_name, _enemies.size() + 1]
	print("[EVENT] Enemy added: %s (HP: %.0f)" % [enemy.enemy_name, enemy.max_health])
	_enemies.append(enemy)
	$Enemies.add_child(enemy)
	enemy.attack.connect(_on_enemy_attacked)
	enemy.died.connect(_on_enemy_died)
	enemy_added.emit(enemy, _total_expected_enemies)


# --- Player Attack ---

func apply_consumable_damage(amount: float) -> void:
	for enemy in _enemies:
		if not enemy.is_dead:
			enemy.take_damage(amount)


func receive_player_attack(enemy: Enemy, damage: float) -> void:
	enemy.take_damage(damage)
	player_attack_resolved.emit(enemy, damage)


# --- Enemy Turn Loop ---

func run_enemy_turns() -> void:
	_turn_queue = _enemies.filter(func(e: Enemy) -> bool: return not e.is_dead)
	if _turn_queue.is_empty():
		enemy_turns_complete.emit()
		return
	_run_next_enemy_turn()


func _run_next_enemy_turn() -> void:
	if _turn_queue.is_empty():
		enemy_turns_complete.emit()
		return
	var enemy := _turn_queue.pop_front() as Enemy
	print("[ENEMY] %s's turn" % enemy.enemy_name)
	enemy.turn_ended.connect(_on_enemy_turn_ended, CONNECT_ONE_SHOT)
	enemy.take_turn()


func _on_enemy_turn_ended() -> void:
	_run_next_enemy_turn()


# --- Signal Handlers ---

func _on_enemy_attacked(damage: float) -> void:
	player_attacked.emit(damage)


func _on_enemy_died() -> void:
	var all_dead := _enemies.all(func(e: Enemy) -> bool: return e.is_dead)
	if all_dead:
		print("[EVENT] All enemies defeated!")
		_advance_phase()
