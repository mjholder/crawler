class_name Player
extends Combatant

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
signal mana_spent(amount: float)
signal mana_restored(amount: float)
signal cast_performed(spell: SpellData, targets: Array)
signal cast_hit(spell: SpellData, targets: Array)
signal learned_spells_changed(spells: Array)
signal prepared_spells_changed(spells: Array)
signal prep_slots_changed(new_size: int)

# --- Stats ---
@export var player_name: String = "Player"
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# --- Health / Mana Tuning ---
## max_health = (effective_CON * health_modifier) + class_health_bonus
@export var health_modifier: float = 2.0
## max_mana = (effective_SPI * mana_modifier) + class_mana_bonus
@export var mana_modifier: float = 2.0

# --- XP Tuning ---
@export var xp_base: float = 100.0
@export var xp_growth_factor: float = 1.15

# --- State Machine ---
enum State { IDLE, DEAD }

var _state: State = State.IDLE
var max_health: float = 0.0
var health: float = 0.0
var max_mana: float = 0.0
var mana: float = 0.0
var prep_slots: int = 0
var gold: int = 0
var experience: int = 0
var level: int = 1
var pending_stat_points: int = 0
var pending_growth_bonuses: Dictionary = {}
var is_dead: bool = false
var mana_regen: float = 0.0
var mana_on_kill: float = 0.0
var _turn_pending: bool = false
var _attack_animation_pending: bool = false
var _cast_animation_pending: bool = false
var _evaluating_conditionals: bool = false
var _weapon_visible: bool = false
var _hurt_overlay: ColorRect = null
var _class_data: PlayerClassData = null
var _pending_attack_data: AttackData = null
var _pending_targets: Array = []
var _in_flight_attack_data: AttackData = null
var _in_flight_targets: Array = []
var _in_flight_spell: SpellData = null
var _in_flight_spell_targets: Array = []
var _learned_spells: Array[SpellData] = []
var _prepared_spells: Array[SpellData] = []
var _innate_spell_names: Array[String] = []
var _pending_spell: SpellData = null
var _pending_spell_targets: Array = []
var _game: Game = null
var _blessings: Array[BlessingData] = []
var _blessing_subs: Dictionary = {}  # BlessingData -> Subscription

# --- Node References ---
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer
@onready var _inventory: Inventory = $Inventory

var _cond_eval: StatExprEval = StatExprEval.new()

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
		_tick_statuses()
		turn_ended.emit()


# --- Initialization ---

func initialize(p_name: String, class_data: PlayerClassData) -> void:
	reset_run_state()
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
	_recalculate_max_health()
	_recalculate_max_mana()
	health = max_health
	_setup_starting_equipment(class_data)
	_setup_starting_blessings(class_data)
	_recalculate_prep_slots()
	_setup_starting_spells(class_data)
	restore_mana_to_full()


func reset_run_state() -> void:
	_clear_equipment_nodes()
	for bd in _blessings.duplicate():
		remove_blessing(bd)
	_active_statuses.clear()
	for spell in _prepared_spells:
		if spell != null:
			unregister_action(spell.spell_name)
	_learned_spells.clear()
	_prepared_spells.clear()
	_innate_spell_names.clear()
	prep_slots = 0
	_pending_attack_data = null
	_pending_targets = []
	_in_flight_attack_data = null
	_in_flight_targets = []
	_in_flight_spell = null
	_in_flight_spell_targets = []
	_pending_spell = null
	_pending_spell_targets = []
	_turn_pending = false
	_attack_animation_pending = false
	_cast_animation_pending = false
	is_dead = false
	_transition(State.IDLE)
	_inventory.set_dungeon_locked(false)


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
	for tome_res in class_data.starting_tomes:
		if tome_res is TomeData:
			_inventory.add_tome(tome_res as TomeData)


func _setup_starting_blessings(class_data: PlayerClassData) -> void:
	for data in class_data.starting_blessings:
		add_blessing(data)


# --- Blessings ---

func add_blessing(data: BlessingData) -> void:
	_blessings.append(data)
	if _game == null or data.subscriptions.is_empty():
		return
	var sub := Subscription.new()
	var owner := self
	for trigger in data.subscriptions:
		var effect := data.subscriptions[trigger] as Effect
		if effect == null:
			continue
		sub.add(Signal(_game, trigger), func() -> void: effect.apply(owner, owner))
	_blessing_subs[data] = sub


func remove_blessing(data: BlessingData) -> void:
	_blessings.erase(data)
	if _blessing_subs.has(data):
		(_blessing_subs[data] as Subscription).clear_all()
		_blessing_subs.erase(data)


func get_blessings() -> Array[BlessingData]:
	return _blessings


# --- Actions ---

func _register_actions() -> void:
	pass


func register_action(action_name: String, callable: Callable) -> void:
	_actions[action_name] = callable


func unregister_action(action_name: String) -> void:
	_actions.erase(action_name)


func pass_turn() -> void:
	if is_dead or _turn_pending:
		return
	_turn_pending = true


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
	_recalculate_max_mana()
	stats_changed.emit(build_stats_dict())


func clear_pending_growth_bonuses() -> void:
	pending_growth_bonuses = {}


func spend_stat_point(stat: Enums.Stat) -> void:
	if pending_stat_points <= 0:
		return
	_add_to_base_stat(stat, 1.0)
	pending_stat_points -= 1
	_recalculate_max_health()
	_recalculate_max_mana()
	stats_changed.emit(build_stats_dict())


func unspend_stat_point(stat: Enums.Stat) -> void:
	_add_to_base_stat(stat, -1.0)
	pending_stat_points += 1
	_recalculate_max_health()
	_recalculate_max_mana()
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
	health = maxf(health - net_amount, 0.0)
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


# --- Mana ---

func _recalculate_max_mana() -> void:
	if _class_data == null:
		return
	var old_max := max_mana
	var effective_spi := get_effective_stat(Enums.Stat.SPIRIT)
	max_mana = (effective_spi * mana_modifier) + _class_data.class_mana_bonus
	var delta := max_mana - old_max
	if delta > 0.0:
		mana += delta
	else:
		mana = minf(mana, max_mana)
	_recalculate_mana_regen()


func _recalculate_mana_regen() -> void:
	if _class_data == null:
		return
	mana_regen = _class_data.mana_regen_per_turn
	mana_on_kill = _class_data.mana_on_kill
	for equip_data in _inventory.get_all_equipped():
		mana_regen += equip_data.bonus_mana_regen


func restore_mana(amount: float) -> void:
	if is_dead:
		return
	var actual := minf(amount, max_mana - mana)
	if actual <= 0.0:
		return
	mana += actual
	mana_restored.emit(actual)


func restore_mana_to_full() -> void:
	var delta := max_mana - mana
	mana = max_mana
	if delta > 0.0:
		mana_restored.emit(delta)


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	mana_spent.emit(amount)
	return true


func compute_spell_cost(spell: SpellData) -> float:
	var multiplier := 1.0
	for equip_data in _inventory.get_all_equipped():
		multiplier *= equip_data.spell_cost_multiplier
	return spell.mana_cost * multiplier


# --- Spells ---

func _recalculate_prep_slots() -> void:
	var new_size := _class_data.starting_prep_slots if _class_data != null else 0
	for equip_data in _inventory.get_all_equipped():
		new_size += equip_data.bonus_prep_slots
	if new_size == prep_slots:
		return
	if new_size < prep_slots:
		for i in range(new_size, prep_slots):
			if i < _prepared_spells.size() and _prepared_spells[i] != null:
				unregister_action(_prepared_spells[i].spell_name)
		_prepared_spells.resize(new_size)
	else:
		_prepared_spells.resize(new_size)
		for i in range(prep_slots, new_size):
			_prepared_spells[i] = null
	prep_slots = new_size
	prep_slots_changed.emit(prep_slots)
	prepared_spells_changed.emit(get_castable_spells())


func learn_spell(spell: SpellData) -> void:
	if _learned_spells.has(spell):
		return
	_learned_spells.append(spell)
	learned_spells_changed.emit(_learned_spells.duplicate())


func forget_spell(spell: SpellData) -> void:
	if not _learned_spells.has(spell):
		return
	for i in _prepared_spells.size():
		if _prepared_spells[i] == spell:
			unprepare_spell(i)
	_learned_spells.erase(spell)
	learned_spells_changed.emit(_learned_spells.duplicate())


func prepare_spell(spell: SpellData, index: int) -> void:
	if _inventory.is_dungeon_locked():
		return
	if index < 0 or index >= _prepared_spells.size():
		return
	if not _learned_spells.has(spell):
		return
	var displaced := _prepared_spells[index]
	if displaced != null:
		unregister_action(displaced.spell_name)
	_prepared_spells[index] = spell
	register_action(spell.spell_name, _do_cast)
	prepared_spells_changed.emit(get_castable_spells())


func unprepare_spell(index: int) -> void:
	if index < 0 or index >= _prepared_spells.size():
		return
	var spell := _prepared_spells[index]
	if spell == null:
		return
	unregister_action(spell.spell_name)
	_prepared_spells[index] = null
	prepared_spells_changed.emit(get_castable_spells())


func get_castable_spells() -> Array[SpellData]:
	var result: Array[SpellData] = []
	for name in _innate_spell_names:
		var found := _find_spell_by_name(name)
		if found != null and not result.has(found):
			result.append(found)
	for spell in _prepared_spells:
		if spell != null and not result.has(spell):
			result.append(spell)
	return result


func _find_spell_by_name(name: String) -> SpellData:
	var weapon_data := _inventory.get_equipped(Enums.Slot.WEAPON)
	if weapon_data is WeaponData:
		for spell_res in (weapon_data as WeaponData).innate_spells:
			var spell := spell_res as SpellData
			if spell != null and spell.spell_name == name:
				return spell
	return null


func get_learned_spells() -> Array[SpellData]:
	return _learned_spells.duplicate()


func get_prepared_spells() -> Array[SpellData]:
	return _prepared_spells.duplicate()


func _setup_starting_spells(class_data: PlayerClassData) -> void:
	for spell_res in class_data.starting_learned_spells:
		var spell := spell_res as SpellData
		if spell != null:
			learn_spell(spell)
	var slot_index := 0
	for spell_res in class_data.starting_prepared_spells:
		var spell := spell_res as SpellData
		if spell != null and slot_index < prep_slots:
			prepare_spell(spell, slot_index)
			slot_index += 1


func set_pending_spell_payload(spell: SpellData, targets: Array) -> void:
	_pending_spell = spell
	_pending_spell_targets = targets


func _do_cast() -> void:
	var spell := _pending_spell
	var targets := _pending_spell_targets.duplicate()
	_pending_spell = null
	_pending_spell_targets = []
	if spell == null:
		push_warning("[PLAYER] _do_cast() called with no pending payload")
		return
	var cost := compute_spell_cost(spell)
	if not spend_mana(cost):
		push_warning("[PLAYER] _do_cast() insufficient mana for: %s" % spell.spell_name)
		return
	var weapon_data := _inventory.get_equipped(Enums.Slot.WEAPON)
	if weapon_data != null and weapon_data.scene != null and spell.target_mode != AttackData.TargetMode.SELF:
		_cast_animation_pending = true
		_in_flight_spell = spell
		_in_flight_spell_targets = targets
	print("  Player casts: %s" % spell.spell_name)
	cast_performed.emit(spell, targets)
	if not _cast_animation_pending:
		cast_hit.emit(spell, targets)


func _on_stat_modifiers_changed() -> void:
	_recalculate_max_health()
	_recalculate_max_mana()
	stats_changed.emit(build_stats_dict())


func _on_slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData) -> void:
	if old_data != null:
		_teardown_equipment(slot, old_data)
	if new_data != null:
		_setup_equipment(slot, new_data)
	_recalculate_max_health()
	_recalculate_max_mana()
	_recalculate_prep_slots()
	stats_changed.emit(build_stats_dict())


func _on_ring_changed(_index: int, new_data: EquipmentData, old_data: EquipmentData) -> void:
	if old_data != null:
		_teardown_equipment(null, old_data)
	if new_data != null:
		_setup_equipment(null, new_data)
	_recalculate_max_health()
	_recalculate_max_mana()
	_recalculate_prep_slots()
	stats_changed.emit(build_stats_dict())


func _setup_equipment(slot, data: EquipmentData) -> void:
	for effect_res in data.on_equip_effects:
		if effect_res is Effect:
			(effect_res as Effect).apply(self, self)
	if data.scene != null:
		var node := data.scene.instantiate() as Equipment
		node.data = data
		node._game = get_parent() as Game
		add_child(node)
		node.play_equip()
		node._on_equipped()
		if slot == Enums.Slot.WEAPON:
			print("[PLAYER] Equipped weapon scene: %s" % data.item_name)
			node.visible = _weapon_visible
			attack_performed.connect((node as Weapon)._on_player_attacked)
			(node as Weapon).animation_finished.connect(_on_weapon_animation_finished)
			(node as Weapon).hit_landed.connect(_on_weapon_hit_landed)
			cast_performed.connect((node as Weapon)._on_player_cast)
			(node as Weapon).cast_animation_finished.connect(_on_weapon_cast_animation_finished)
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		print("[PLAYER] Equipped weapon: %s" % data.item_name)
		var wdata := data as WeaponData
		if wdata.is_two_handed:
			if _inventory.get_equipped(Enums.Slot.OFFHAND) != null:
				_inventory.unequip(Enums.Slot.OFFHAND)
			_inventory.lock_slot(Enums.Slot.OFFHAND)
		for atk_res in wdata.attacks:
			var atk := atk_res as AttackData
			if atk == null:
				continue
			if _actions.has(atk.attack_name):
				push_warning("[PLAYER] Duplicate attack name: %s" % atk.attack_name)
			register_action(atk.attack_name, _do_attack)
		for spell_res in wdata.innate_spells:
			var spell := spell_res as SpellData
			if spell == null:
				continue
			if _actions.has(spell.spell_name):
				push_warning("[PLAYER] Duplicate action name from innate spell: %s" % spell.spell_name)
			_innate_spell_names.append(spell.spell_name)
			register_action(spell.spell_name, _do_cast)
		weapon_attacks_changed.emit(wdata.attacks)
		prepared_spells_changed.emit(get_castable_spells())


func _teardown_equipment(slot, data: EquipmentData) -> void:
	for effect_res in data.on_unequip_effects:
		if effect_res is Effect:
			(effect_res as Effect).apply(self, self)
	if data.scene != null:
		for child in get_children():
			if child is Equipment and child.data == data:
				child.play_unequip()
				child._on_unequipped()
				if slot == Enums.Slot.WEAPON:
					attack_performed.disconnect((child as Weapon)._on_player_attacked)
					(child as Weapon).animation_finished.disconnect(_on_weapon_animation_finished)
					(child as Weapon).hit_landed.disconnect(_on_weapon_hit_landed)
					cast_performed.disconnect((child as Weapon)._on_player_cast)
					(child as Weapon).cast_animation_finished.disconnect(_on_weapon_cast_animation_finished)
				child.queue_free()
				break
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		var wdata := data as WeaponData
		if wdata.is_two_handed:
			_inventory.unlock_slot(Enums.Slot.OFFHAND)
		for atk_res in wdata.attacks:
			var atk := atk_res as AttackData
			if atk == null:
				continue
			unregister_action(atk.attack_name)
		for name in _innate_spell_names:
			unregister_action(name)
		_innate_spell_names.clear()
		weapon_attacks_changed.emit([])
		prepared_spells_changed.emit(get_castable_spells())


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


# --- Save / Load ---

func to_save_dict() -> Dictionary:
	var blessings: Array[String] = []
	for bd in _blessings:
		if bd != null and not bd.resource_path.is_empty():
			blessings.append(bd.resource_path)
	return {
		"name": player_name,
		"class_data_path": _class_data.resource_path if _class_data != null else "",
		"strength": strength,
		"defense": defense,
		"constitution": constitution,
		"agility": agility,
		"spirit": spirit,
		"luck": luck,
		"level": level,
		"experience": experience,
		"gold": gold,
		"pending_stat_points": pending_stat_points,
		"pending_growth_bonuses": pending_growth_bonuses.duplicate(),
		"max_health": max_health,
		"health": health,
		"mana": mana,
		"is_dead": is_dead,
		"blessings": blessings,
		"learned_spells": _spell_paths(_learned_spells),
		"prepared_spells": _prepared_spell_paths(),
		"active_statuses": to_status_save_array(),
		"inventory": _inventory.to_save_dict(),
	}


func apply_save_dict(d: Dictionary) -> void:
	reset_run_state()
	_class_data = load(d["class_data_path"]) as PlayerClassData
	player_name = d["name"]
	strength = d["strength"]
	defense = d["defense"]
	constitution = d["constitution"]
	agility = d["agility"]
	spirit = d["spirit"]
	luck = d["luck"]
	level = d["level"]
	experience = d["experience"]
	gold = d["gold"]
	pending_stat_points = d["pending_stat_points"]
	pending_growth_bonuses = d["pending_growth_bonuses"].duplicate()
	is_dead = d["is_dead"]
	_transition(State.DEAD if is_dead else State.IDLE)
	_recalculate_max_health()
	_recalculate_max_mana()
	health = max_health
	_inventory.apply_save_dict(d["inventory"])
	for path in d["blessings"]:
		var bd := load(path) as BlessingData
		if bd != null:
			add_blessing(bd)
	apply_status_save_array(d["active_statuses"])
	# Final recalc picks up any blessing/status CON modifiers, then pin health and mana.
	_recalculate_max_health()
	_recalculate_max_mana()
	_recalculate_prep_slots()
	health = minf(d["health"], max_health)
	for path in d.get("learned_spells", []):
		var spell := load(path) as SpellData
		if spell != null:
			learn_spell(spell)
	var saved_prepared: Array = d.get("prepared_spells", [])
	for i in saved_prepared.size():
		if i >= prep_slots:
			break
		var path = saved_prepared[i]
		if path == null or path == "":
			continue
		var spell := load(path) as SpellData
		if spell != null:
			prepare_spell(spell, i)
	mana = minf(d.get("mana", max_mana), max_mana)
	stats_changed.emit(build_stats_dict())
	gold_changed.emit(gold)
	experience_changed.emit(experience)


func _spell_paths(spells: Array[SpellData]) -> Array[String]:
	var paths: Array[String] = []
	for spell in spells:
		if spell != null and not spell.resource_path.is_empty():
			paths.append(spell.resource_path)
	return paths


func _prepared_spell_paths() -> Array:
	var paths := []
	for spell in _prepared_spells:
		paths.append(spell.resource_path if spell != null and not spell.resource_path.is_empty() else null)
	return paths


func _clear_equipment_nodes() -> void:
	for slot_key in Enums.Slot.values():
		var data := _inventory.get_equipped(slot_key)
		if data != null:
			_teardown_equipment(slot_key, data)
	for ring in _inventory.get_rings():
		if ring != null:
			_teardown_equipment(null, ring)
	_inventory.clear()


func get_effective_stat(stat: Enums.Stat) -> float:
	var value: float = super.get_effective_stat(stat)
	for equip_data in _inventory.get_all_equipped():
		if equip_data.stat_modifiers.has(stat):
			value += equip_data.stat_modifiers[stat]
	if not _evaluating_conditionals:
		_evaluating_conditionals = true
		for equip_data in _inventory.get_all_equipped():
			for cm_res in equip_data.conditional_modifiers:
				var cm := cm_res as ConditionalModifier
				if cm == null or cm.stat != stat:
					continue
				if _cond_eval.evaluate(cm.guard_expression, self) > 0.0:
					value += _cond_eval.evaluate(cm.amount_expression, self)
		_evaluating_conditionals = false
	for blessing in _blessings:
		if blessing.stat_modifiers.has(stat):
			value += blessing.stat_modifiers[stat]
	return value


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
	return not _attack_animation_pending and not _cast_animation_pending and (_state == State.IDLE or _state == State.DEAD)


func _transition(next: State) -> void:
	_state = next


func _on_weapon_animation_finished() -> void:
	_attack_animation_pending = false


func _on_weapon_cast_animation_finished() -> void:
	_cast_animation_pending = false
	if _in_flight_spell == null:
		return
	var spell := _in_flight_spell
	var targets := _in_flight_spell_targets
	_in_flight_spell = null
	_in_flight_spell_targets = []
	cast_hit.emit(spell, targets)


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
