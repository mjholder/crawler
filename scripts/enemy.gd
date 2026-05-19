class_name Enemy
extends Combatant

# --- Signals ---
signal damaged(amount: float)
signal died
signal death_finished
signal turn_ended
signal attack(damage: float)

# --- Stats ---
@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
@export var attack_damage: float = 5.0
@export var experience_value: int = 10
@export var defense: float = 0.0

# --- State ---
var health: float
var is_dead: bool = false
var _turn_pending: bool = false
var _death_finished_emitted: bool = false


func _ready() -> void:
	_on_ready()


# --- Turn ---

func take_turn() -> void:
	if is_dead:
		return
	if has_preventing_status():
		print("[ENEMY] %s is stunned! Turn skipped." % enemy_name)
		_turn_pending = true
		return
	_turn_pending = true
	_perform_action()


func _process(_delta: float) -> void:
	if _turn_pending and _is_turn_complete():
		_turn_pending = false
		_tick_statuses()
		turn_ended.emit()


func _is_turn_complete() -> bool:
	return true


func _perform_action() -> void:
	_begin_attack()
	_emit_attack()


func _begin_attack() -> void:
	print("[ENEMY] %s attacks for %.0f damage" % [enemy_name, attack_damage])


func _emit_attack() -> void:
	attack.emit(attack_damage)


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	var net_amount: float = _apply_defense(amount)
	health -= net_amount
	print("  %s HP: %.0f / %.0f" % [enemy_name, health, max_health])
	damaged.emit(net_amount)
	_on_damaged(net_amount)
	if health <= 0.0:
		_die()


func _apply_defense(amount: float) -> float:
	var eff_def := get_effective_stat(Enums.Stat.DEFENSE)
	return maxf(amount * (1.0 - minf(eff_def / 100.0, 1.0)), 0.0)


func _get_base_stat(stat: Enums.Stat) -> float:
	match stat:
		Enums.Stat.DEFENSE: return defense
	return 0.0


func _die() -> void:
	print("  [ENEMY] %s died!" % enemy_name)
	is_dead = true
	_on_death()
	died.emit()
	if _death_is_immediate():
		_emit_death_finished()


func _death_is_immediate() -> bool:
	return true


func _emit_death_finished() -> void:
	if _death_finished_emitted:
		return
	_death_finished_emitted = true
	death_finished.emit()


# --- Extension Hooks ---

func _on_ready() -> void:
	health = max_health



func _on_damaged(_amount: float) -> void:
	pass


func _on_death() -> void:
	pass
