class_name Player
extends Node2D

# --- Signals ---
signal damaged(amount: float)
signal healed(amount: float)
signal died
signal turn_ended
signal attack_performed(attack_data: AttackData, targets: Array)
signal attack_hit(attack_data: AttackData, targets: Array)
signal weapon_attacks_changed(attacks: Array)
signal gold_changed(new_total: int)
signal experience_changed(new_total: int)
signal stats_changed(stats: Dictionary)
signal leveled_up(new_level: int)
signal consumable_used(data: ConsumableData)
signal buff_applied(stat: Enums.Stat, amount: float, duration: int)
signal buff_expired(stat: Enums.Stat)

# --- Stats ---
@export var player_name: String = "Player"
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# --- Health Tuning ---
## max_health = (effective_CON * health_modifier) + class_health_bonus
@export var health_modifier: float = 2.0

# --- XP Tuning ---
@export var xp_base: float = 100.0
@export var xp_growth_factor: float = 1.15

# --- State Machine ---
enum State { IDLE, DEAD }

var _state: State = State.IDLE
var max_health: float = 0.0
var health: float = 0.0
var gold: int = 0
var experience: int = 0
var level: int = 1
var pending_stat_points: int = 0
var pending_growth_bonuses: Dictionary = {}
var is_dead: bool = false
var _turn_pending: bool = false
var _attack_animation_pending: bool = false
var _weapon_visible: bool = false
var _hurt_overlay: ColorRect = null
var _class_data: PlayerClassData = null
var _active_buffs: Array = []  # Array of {stat, amount, turns_remaining}
var _pending_attack_data: AttackData = null
var _pending_targets: Array = []
var _in_flight_attack_data: AttackData = null
var _in_flight_targets: Array = []

# --- Node References ---
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer
@onready var _inventory: Inventory = $Inventory

# --- Actions ---
# Maps action name -> Callable.
# Register new actions with register_action(); call them via execute_action().
var _actions: Dictionary = {}


func _ready() -> void:
	_register_actions()
	_transition(State.IDLE)
	_inventory.slot_changed.connect(_on_slot_changed)
	_inventory.ring_changed.connect(_on_ring_changed)


func _process(_delta: float) -> void:
	if _turn_pending and _is_turn_complete():
		_turn_pending = false
		_tick_buffs()
		turn_ended.emit()


# --- Initialization ---

func initialize(p_name: String, class_data: PlayerClassData) -> void:
	_class_data = class_data
	player_name = p_name
	strength = class_data.strength
	defense = class_data.defense
	constitution = class_data.constitution
	agility = class_data.agility
	spirit = class_data.spirit
	luck = class_data.luck
	level = 1
	experience = 0
	pending_stat_points = 0
	pending_growth_bonuses = {}
	gold = 0
	_inventory.clear()
	is_dead = false
	_recalculate_max_health()
	health = max_health
	_setup_starting_equipment(class_data)


func _setup_starting_equipment(class_data: PlayerClassData) -> void:
	_inventory.set_belt_size(class_data.starting_consumable_slots)
	for slot_key in class_data.starting_equipped:
		_inventory.equip(slot_key as Enums.Slot, class_data.starting_equipped[slot_key])
	for ring in class_data.starting_rings:
		_inventory.equip_ring(ring)
	for i in class_data.starting_consumables.size():
		_inventory.equip_consumable_at(i, class_data.starting_consumables[i])
	for item in class_data.starting_bag:
		_inventory.add_to_bag(item)


# --- Actions ---

func _register_actions() -> void:
	pass


func register_action(action_name: String, callable: Callable) -> void:
	_actions[action_name] = callable


func unregister_action(action_name: String) -> void:
	_actions.erase(action_name)


func execute_action(action_name: String) -> void:
	if is_dead or _turn_pending or not _actions.has(action_name):
		return
	print("[PLAYER] Action: %s" % action_name)
	_actions[action_name].call()
	_turn_pending = true


func set_pending_attack_payload(attack_data: AttackData, targets: Array) -> void:
	_pending_attack_data = attack_data
	_pending_targets = targets


# --- Action Implementations ---

func _do_attack() -> void:
	var attack_data := _pending_attack_data
	var targets := _pending_targets.duplicate()
	_pending_attack_data = null
	_pending_targets = []
	if attack_data == null:
		push_warning("[PLAYER] _do_attack() called with no pending payload")
		return
	var weapon_data := _inventory.get_equipped(Enums.Slot.WEAPON)
	if weapon_data != null and weapon_data.scene != null and attack_data.target_mode != AttackData.TargetMode.SELF:
		_attack_animation_pending = true
		_in_flight_attack_data = attack_data
		_in_flight_targets = targets
	print("  Player performs: %s" % attack_data.attack_name)
	attack_performed.emit(attack_data, targets)
	if not _attack_animation_pending:
		attack_hit.emit(attack_data, targets)


# --- Rewards ---

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_experience(amount: int) -> void:
	experience += amount
	while experience >= xp_to_next_level():
		experience -= xp_to_next_level()
		_level_up()
	experience_changed.emit(experience)


# --- Leveling ---

func xp_to_next_level() -> int:
	return int(xp_base * pow(xp_growth_factor, level - 1))


func _level_up() -> void:
	level += 1
	_apply_growth_rates()
	pending_stat_points += 3
	leveled_up.emit(level)


func _apply_growth_rates() -> void:
	if _class_data == null:
		return
	for stat_key in _class_data.growth_rates:
		var amount: float = _class_data.growth_rates[stat_key]
		_add_to_base_stat(stat_key as Enums.Stat, amount)
		pending_growth_bonuses[stat_key] = pending_growth_bonuses.get(stat_key, 0.0) + amount
	_recalculate_max_health()
	stats_changed.emit(build_stats_dict())


func clear_pending_growth_bonuses() -> void:
	pending_growth_bonuses = {}


func spend_stat_point(stat: Enums.Stat) -> void:
	if pending_stat_points <= 0:
		return
	_add_to_base_stat(stat, 1.0)
	pending_stat_points -= 1
	_recalculate_max_health()
	stats_changed.emit(build_stats_dict())


func unspend_stat_point(stat: Enums.Stat) -> void:
	_add_to_base_stat(stat, -1.0)
	pending_stat_points += 1
	_recalculate_max_health()
	stats_changed.emit(build_stats_dict())


func _add_to_base_stat(stat: Enums.Stat, amount: float) -> void:
	match stat:
		Enums.Stat.STRENGTH:     strength += amount
		Enums.Stat.DEFENSE:      defense += amount
		Enums.Stat.CONSTITUTION: constitution += amount
		Enums.Stat.AGILITY:      agility += amount
		Enums.Stat.SPIRIT:       spirit += amount
		Enums.Stat.LUCK:         luck += amount


# --- Combat ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	var net_amount: float = _apply_defense(amount)
	health -= net_amount
	print("  Player HP: %.0f / %.0f" % [health, max_health])
	damaged.emit(net_amount)
	_flash_hurt_overlay()
	if health <= 0.0:
		_die()
	else:
		_play_sfx(_hurt_player)


func heal(amount: float) -> void:
	if is_dead:
		return
	var actual := minf(amount, max_health - health)
	health += actual
	healed.emit(actual)


func _die() -> void:
	print("  [PLAYER] Died!")
	is_dead = true
	_play_sfx(_death_player)
	_transition(State.DEAD)
	died.emit()


func _apply_defense(amount: float) -> float:
	return maxf(amount - get_effective_stat(Enums.Stat.DEFENSE), 0.0)


# --- Equipment ---

func _recalculate_max_health() -> void:
	if _class_data == null:
		return
	var old_max := max_health
	var effective_con := get_effective_stat(Enums.Stat.CONSTITUTION)
	max_health = (effective_con * health_modifier) + _class_data.class_health_bonus
	var delta := max_health - old_max
	if delta > 0.0:
		health += delta
	else:
		health = minf(health, max_health)


func _on_slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData) -> void:
	if old_data != null:
		_teardown_equipment(slot, old_data)
	if new_data != null:
		_setup_equipment(slot, new_data)
	_recalculate_max_health()
	stats_changed.emit(build_stats_dict())


func _on_ring_changed(_index: int, new_data: EquipmentData, old_data: EquipmentData) -> void:
	if old_data != null:
		_teardown_equipment(null, old_data)
	if new_data != null:
		_setup_equipment(null, new_data)
	_recalculate_max_health()
	stats_changed.emit(build_stats_dict())


func _setup_equipment(slot, data: EquipmentData) -> void:
	if data.scene != null:
		var node := data.scene.instantiate() as Equipment
		node.data = data
		add_child(node)
		node.play_equip()
		node._on_equipped()
		if slot == Enums.Slot.WEAPON:
			print("[PLAYER] Equipped weapon scene: %s" % data.item_name)
			node.visible = _weapon_visible
			attack_performed.connect((node as Weapon)._on_player_attacked)
			(node as Weapon).animation_finished.connect(_on_weapon_animation_finished)
			(node as Weapon).hit_landed.connect(_on_weapon_hit_landed)
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		print("[PLAYER] Equipped weapon: %s" % data.item_name)
		var wdata := data as WeaponData
		for atk_res in wdata.attacks:
			var atk := atk_res as AttackData
			if atk == null:
				continue
			if _actions.has(atk.attack_name):
				push_warning("[PLAYER] Duplicate attack name: %s" % atk.attack_name)
			register_action(atk.attack_name, _do_attack)
		weapon_attacks_changed.emit(wdata.attacks)


func _teardown_equipment(slot, data: EquipmentData) -> void:
	if data.scene != null:
		for child in get_children():
			if child is Equipment and child.data == data:
				child.play_unequip()
				child._on_unequipped()
				if slot == Enums.Slot.WEAPON:
					attack_performed.disconnect((child as Weapon)._on_player_attacked)
					(child as Weapon).animation_finished.disconnect(_on_weapon_animation_finished)
					(child as Weapon).hit_landed.disconnect(_on_weapon_hit_landed)
				child.queue_free()
				break
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		var wdata := data as WeaponData
		for atk_res in wdata.attacks:
			var atk := atk_res as AttackData
			if atk == null:
				continue
			unregister_action(atk.attack_name)
		weapon_attacks_changed.emit([])


func get_equipped_node(slot: Enums.Slot) -> Equipment:
	var data := _inventory.get_equipped(slot)
	if data == null:
		return null
	for child in get_children():
		if child is Equipment and child.data == data:
			return child
	return null


func set_weapon_visible(show: bool) -> void:
	_weapon_visible = show
	var weapon := get_equipped_node(Enums.Slot.WEAPON)
	if weapon != null:
		weapon.visible = show


func get_base_stat(stat: Enums.Stat) -> float:
	return _get_base_stat(stat)


func get_inventory() -> Inventory:
	return _inventory


func get_effective_stat(stat: Enums.Stat) -> float:
	var base: float = _get_base_stat(stat)
	var bonus: float = 0.0
	for data in _inventory.get_all_equipped():
		if data.stat_modifiers.has(stat):
			bonus += data.stat_modifiers[stat]
	for buff in _active_buffs:
		if buff.stat == stat:
			bonus += buff.amount
	return base + bonus


func apply_buff(stat: Enums.Stat, amount: float, duration: int) -> void:
	_active_buffs.append({stat = stat, amount = amount, turns_remaining = duration})
	buff_applied.emit(stat, amount, duration)


func _tick_buffs() -> void:
	var expired: Array = []
	for buff in _active_buffs:
		buff.turns_remaining -= 1
		if buff.turns_remaining <= 0:
			expired.append(buff)
	for buff in expired:
		_active_buffs.erase(buff)
		buff_expired.emit(buff.stat)


func build_stats_dict() -> Dictionary:
	var stats := {}
	for stat_key in Enums.Stat.values():
		stats[stat_key] = get_effective_stat(stat_key as Enums.Stat)
	return stats


func _get_base_stat(stat: Enums.Stat) -> float:
	match stat:
		Enums.Stat.STRENGTH:     return strength
		Enums.Stat.DEFENSE:      return defense
		Enums.Stat.CONSTITUTION: return constitution
		Enums.Stat.AGILITY:      return agility
		Enums.Stat.SPIRIT:       return spirit
		Enums.Stat.LUCK:         return luck
	return 0.0


func set_hurt_overlay(overlay: ColorRect) -> void:
	_hurt_overlay = overlay


# --- Internal ---

func _is_turn_complete() -> bool:
	return not _attack_animation_pending and (_state == State.IDLE or _state == State.DEAD)


func _transition(next: State) -> void:
	_state = next


func _on_weapon_animation_finished() -> void:
	_attack_animation_pending = false


func _on_weapon_hit_landed() -> void:
	if _in_flight_attack_data == null:
		return
	var attack_data := _in_flight_attack_data
	var targets := _in_flight_targets
	_in_flight_attack_data = null
	_in_flight_targets = []
	attack_hit.emit(attack_data, targets)


func _flash_hurt_overlay() -> void:
	if _hurt_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_hurt_overlay, "modulate:a", 0.5, 0.05)
	tween.tween_property(_hurt_overlay, "modulate:a", 0.0, 0.2)


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player != null and player.stream != null:
		player.play()
