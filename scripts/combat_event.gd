class_name CombatEvent
extends Event

# --- Signals ---

signal player_attacked(damage: float)
signal player_attack_resolved(enemy: Enemy, damage: float)
signal enemy_turns_complete

# --- Enemies ---

var _enemies: Array[Enemy] = []
var _turn_queue: Array[Enemy] = []


func add_enemy(enemy: Enemy) -> void:
	enemy.enemy_name = "%s %d" % [enemy.enemy_name, _enemies.size() + 1]
	print("[EVENT] Enemy added: %s (HP: %.0f)" % [enemy.enemy_name, enemy.max_health])
	_enemies.append(enemy)
	$Enemies.add_child(enemy)
	enemy.attack.connect(_on_enemy_attacked)
	enemy.died.connect(_on_enemy_died)


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
