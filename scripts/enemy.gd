class_name Enemy
extends Combatant

# --- Signals ---
signal damaged(amount: float)
signal died
signal death_finished
signal turn_ended
signal attack(damage: float)
signal move_performed(move: EnemyMoveData)
## Per-round armor buffer (DEF-derived) changed — current/maximum. UI listens to draw it.
signal armor_changed(current: float, maximum: float)

# --- Stats ---
@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
@export var attack_damage: float = 5.0
@export var experience_value: int = 10
@export var defense: float = 0.0

# --- Behavior ---
@export var pattern: EnemyPatternData = null

# --- State ---
var health: float
# Per-round armor buffer: absorbs incoming damage before HP. Refreshed to effective DEF each
# round by CombatEvent (enemies take damage during the player's turn, so refresh at round start).
var armor: float = 0.0
var max_armor: float = 0.0
var is_dead: bool = false
var _turn_pending: bool = false
var _death_finished_emitted: bool = false
var _pattern_index: int = 0


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


## The move this enemy will perform on its current turn, or null when it has no
## pattern. Peeking does not advance the cursor — the move is consumed by
## _emit_attack(). Used for telegraphing the upcoming move on the HUD.
func peek_next_move() -> EnemyMoveData:
	if pattern == null or pattern.moves.is_empty():
		return null
	return pattern.moves[_pattern_index] as EnemyMoveData


func _emit_attack() -> void:
	var move := peek_next_move()
	if move == null:
		attack.emit(attack_damage)
		return
	move_performed.emit(move)
	_pattern_index = (_pattern_index + 1) % pattern.moves.size()


# --- Combat ---

func take_damage(amount: float, pierce: float = 0.0) -> void:
	if is_dead:
		return
	var net_amount: float = _apply_defense(amount, pierce)
	health -= net_amount
	print("  %s HP: %.0f / %.0f" % [enemy_name, health, max_health])
	damaged.emit(net_amount)
	_on_damaged(net_amount)
	if health <= 0.0:
		_die()


## The armor buffer soaks incoming damage before HP; only the overflow bleeds through.
## `pierce` reduces how much of the buffer can absorb THIS hit (leaves the rest intact).
func _apply_defense(amount: float, pierce: float = 0.0) -> float:
	var effective_armor := maxf(armor - pierce, 0.0)
	var absorbed := minf(effective_armor, amount)
	armor -= absorbed
	if absorbed > 0.0:
		armor_changed.emit(armor, max_armor)
	return amount - absorbed


## Refills the armor buffer to the current effective DEF. Called at each round start.
## Shatter: skipped while a suppressing status is active, so the buffer stays depleted.
func refresh_armor() -> void:
	if has_armor_refresh_suppressed():
		return
	max_armor = get_effective_stat(Enums.Stat.DEFENSE)
	armor = max_armor
	armor_changed.emit(armor, max_armor)


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
	refresh_armor()  # full armor before the player can hit it on the spawn turn



func _on_damaged(_amount: float) -> void:
	pass


func _on_death() -> void:
	pass
