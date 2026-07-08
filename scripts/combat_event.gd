class_name CombatEvent
extends Event

const DEFAULT_VICTORY_DIALOGUE := "res://resources/dialogue/post_combat_default.tres"

# --- Signals ---

signal enemy_added(enemy: Enemy, total_expected: int)
signal dialogue_trigger_fired(trigger_name: String, data: Dictionary)
signal player_attacked(damage: float)
signal enemy_turns_complete
signal enemy_turn_started(enemy: Enemy)
signal enemy_turn_ended(enemy: Enemy)
signal enemy_move_performed(enemy: Enemy, move: EnemyMoveData)
signal wave_started
signal wave_completed

# --- Config ---

var _init_data: Dictionary = {}
var _dialogue_triggers: Dictionary = {}
var _total_expected_enemies: int = 0

# --- Enemies ---

var _enemies: Array[Enemy] = []
var _turn_queue: Array[Enemy] = []
var _current_turn_enemy: Enemy = null

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
	enemy_turn_started.connect(game._on_combat_enemy_turn_started)
	enemy_turn_ended.connect(game._on_combat_enemy_turn_ended)
	enemy_move_performed.connect(game._on_enemy_move_performed)
	wave_started.connect(game._on_combat_wave_started)
	wave_completed.connect(game._on_combat_wave_completed)
	game.player_turn_started.connect(_on_round_started)
	game._gui.set_sheathed(false)
	game._gui.set_player_turn(false)
	game._start_combat_music()
	game.player.set_weapon_visible(true)


func _on_exit(game: Node) -> void:
	enemy_added.disconnect(game._on_combat_enemy_added)
	dialogue_trigger_fired.disconnect(game._on_combat_dialogue_trigger)
	player_attacked.disconnect(game._on_player_attacked)
	enemy_turns_complete.disconnect(game._on_enemy_turns_complete)
	enemy_turn_started.disconnect(game._on_combat_enemy_turn_started)
	enemy_turn_ended.disconnect(game._on_combat_enemy_turn_ended)
	enemy_move_performed.disconnect(game._on_enemy_move_performed)
	wave_started.disconnect(game._on_combat_wave_started)
	wave_completed.disconnect(game._on_combat_wave_completed)
	game.player_turn_started.disconnect(_on_round_started)
	for enemy in _enemies:
		game._gui.remove_enemy_health_bar(enemy)
	game._gui.set_sheathed(true)
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

	wave_started.emit()
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
			wave_completed.emit()
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
	var data: Dictionary = DialogueLoader.load_dict(DEFAULT_VICTORY_DIALOGUE)
	if data.is_empty():
		push_warning("CombatEvent: default victory dialogue missing at '%s'" % DEFAULT_VICTORY_DIALOGUE)
		_set_phase(Phase.COMPLETE)
		return
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
	var data: Dictionary = DialogueLoader.load_dict(path)
	if data.is_empty():
		push_warning("CombatEvent: trigger '%s' could not load '%s'" % [trigger_name, path])
		return
	dialogue_trigger_fired.emit(trigger_name, data)


# --- Enemy Management ---

func add_enemy(enemy: Enemy) -> void:
	enemy.enemy_name = "%s %d" % [enemy.enemy_name, _enemies.size() + 1]
	print("[EVENT] Enemy added: %s (HP: %.0f)" % [enemy.enemy_name, enemy.max_health])
	_enemies.append(enemy)
	$Enemies.add_child(enemy)
	enemy.attack.connect(_on_enemy_attacked)
	enemy.move_performed.connect(_on_enemy_move_performed.bind(enemy))
	enemy.died.connect(_on_enemy_died)
	enemy_added.emit(enemy, _total_expected_enemies)


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
	_current_turn_enemy = _turn_queue.pop_front() as Enemy
	print("[ENEMY] %s's turn" % _current_turn_enemy.enemy_name)
	enemy_turn_started.emit(_current_turn_enemy)
	_current_turn_enemy.turn_ended.connect(_on_enemy_turn_ended, CONNECT_ONE_SHOT)
	_current_turn_enemy.take_turn()


func _on_enemy_turn_ended() -> void:
	enemy_turn_ended.emit(_current_turn_enemy)
	_current_turn_enemy = null
	_run_next_enemy_turn()


# --- Signal Handlers ---

## Each round starts with the player's turn; refresh every living enemy's armor buffer so it
## is full going into the phase where the player attacks (mirrors player.begin_turn).
func _on_round_started() -> void:
	for e in _enemies:
		if not e.is_dead:
			e.refresh_armor()


func _on_enemy_attacked(damage: float) -> void:
	player_attacked.emit(damage)


func _on_enemy_move_performed(move: EnemyMoveData, enemy: Enemy) -> void:
	enemy_move_performed.emit(enemy, move)


func _on_enemy_died() -> void:
	var all_dead := _enemies.all(func(e: Enemy) -> bool: return e.is_dead)
	if all_dead:
		print("[EVENT] All enemies defeated!")
		for e in _enemies:
			if not e._death_finished_emitted:
				await e.death_finished
		_advance_phase()
