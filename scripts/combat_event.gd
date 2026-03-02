class_name CombatEvent
extends Event

# --- Signals ---

signal player_attacked(damage: float)

# --- Enemies ---

var _enemies: Array[Enemy] = []


func add_enemy(enemy: Enemy) -> void:
	_enemies.append(enemy)
	enemy.attacked.connect(_on_enemy_attacked)


func _on_enemy_attacked(damage: float) -> void:
	player_attacked.emit(damage)


func receive_player_attack(damage: float) -> void:
	for enemy in _enemies:
		if not enemy.is_dead:
			enemy.take_damage(damage)
			break


# --- Event Hooks ---

func _on_setup() -> void:
	for enemy in _enemies:
		enemy.attacked.connect(_on_enemy_attacked)


func _on_running() -> void:
	pass  # TODO: drive enemy turn loop here
