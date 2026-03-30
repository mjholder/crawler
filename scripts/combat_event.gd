class_name CombatEvent
extends Event

# --- Signals ---

signal enemy_added(enemy: Enemy, total_expected: int)
signal dialogue_trigger_fired(trigger_name: String, data: Dictionary)
signal player_attacked(damage: float)
signal player_attack_resolved(enemy: Enemy, damage: float)
signal enemy_turns_complete

# --- Config ---

@export var combat_json_path: String = ""

var _dialogue_triggers: Dictionary = {}
var _total_expected_enemies: int = 0

# --- Enemies ---

var _enemies: Array[Enemy] = []
var _turn_queue: Array[Enemy] = []


# --- Setup ---

func _on_setup() -> void:
	if combat_json_path == "":
		return
	var file := FileAccess.open(combat_json_path, FileAccess.READ)
	if file == null:
		push_warning("CombatEvent: could not open '%s'" % combat_json_path)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	rewards = data.get("rewards", {})
	_dialogue_triggers = data.get("dialogue_triggers", {})
	var enemy_entries: Array = data.get("enemies", [])
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


# --- Phase Control ---

func _advance_phase() -> void:
	match phase:
		Phase.RUNNING:
			_set_phase(Phase.RESOLUTION)
			# Do NOT auto-advance to COMPLETE; _on_resolution decides


func _on_resolution() -> void:
	if _dialogue_triggers.has("on_victory"):
		_fire_trigger("on_victory")
		# game.gd calls on_dialogue_complete() when dialogue is done
	else:
		_set_phase(Phase.COMPLETE)


func on_dialogue_complete() -> void:
	_set_phase(Phase.COMPLETE)


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
