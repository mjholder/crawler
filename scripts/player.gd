class_name Player
extends Combatant

# --- Signals ---
## `amount` is the HP-pool damage (drives the floating number); `total_amount` is the full hit
## before armor absorption (drives the combat log, which reports damage dealt, not just HP lost).
signal damaged(amount: float, is_crit: bool, total_amount: float)
signal healed(amount: float)
signal died
signal turn_ended
signal attack_performed(attack_data: AttackData, targets: Array)
signal attack_hit(attack_data: AttackData, targets: Array)
## Offhand equivalents of attack_performed / cast_performed. Kept separate so a weapon in the
## offhand only animates on offhand actions (and vice-versa for the mainhand).
signal offhand_attack_performed(attack_data: AttackData, targets: Array)
signal offhand_cast_performed(spell: SpellData, targets: Array)
## One hand's action finished resolving (animation + effects done). The turn does NOT end
## here — that's explicit via end_turn(). game.gd refreshes the action bar on this.
signal action_resolved(hand: int)
## A hand's available actions changed (equip/unequip, spell prep). Triggers a full
## action-bar rebuild in game.gd. Distinct from prepared_spells_changed (spell-prep UI).
signal hand_actions_changed
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
signal dodged
## Per-round armor buffer (DEF-derived) changed — current/maximum. UI listens to draw it.
signal armor_changed(current: float, maximum: float)
## A hit was (partly or wholly) soaked by the armor buffer. Drives combat-log feedback.
## fully_absorbed is true when the buffer ate the whole hit (no HP will be lost this
## hit) — lets listeners show a single "damage taken" number colored by outcome.
signal armor_absorbed(absorbed: float, fully_absorbed: bool)

# --- Stats ---
@export var player_name: String = "Player"
@export var strength: float = 50.0
## Innate armor buffer. Not a class attribute — starts at 0 and comes from equipment.
@export var defense: float = 0.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# --- Health / Mana Tuning ---
## max_health = effective_CON * health_modifier
@export var health_modifier: float = 2.0
## max_mana = effective_SPI * mana_modifier
@export var mana_modifier: float = 2.0


# --- XP Tuning ---
@export var xp_base: float = 100.0
@export var xp_growth_factor: float = 1.15

# --- State Machine ---
enum State { IDLE, DEAD }

# --- Hands (dual-action combat) ---
# Each hand is an independently-gated action slot. Mainhand = WEAPON slot, offhand =
# OFFHAND slot. A hand's action group is derived from the item it holds (see
# _rebuild_hand_actions). Actions never end the turn — only end_turn() does.
enum Hand { MAINHAND, OFFHAND }

var _state: State = State.IDLE
var max_health: float = 0.0
var health: float = 0.0
# Per-round armor buffer: absorbs incoming damage before HP, refreshed to effective DEF at
# the start of each round (begin_turn). Transient combat state — not saved.
var armor: float = 0.0
var max_armor: float = 0.0
# Successful dodges so far this round; dodge chance halves per prior dodge (see _roll_dodge).
var _dodge_streak: int = 0
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
var _mainhand_used: bool = false
var _offhand_used: bool = false
var _action_resolving: bool = false   # one action in flight; blocks a second until it resolves
var _pending_hand: Hand = Hand.MAINHAND
var _attack_animation_pending: bool = false
var _cast_animation_pending: bool = false
# Offhand equivalents, used only when a weapon (with an animating scene) sits in the offhand.
var _offhand_attack_animation_pending: bool = false
var _offhand_cast_animation_pending: bool = false
var _offhand_in_flight_attack_data: AttackData = null
var _offhand_in_flight_targets: Array = []
var _offhand_in_flight_spell: SpellData = null
var _offhand_in_flight_spell_targets: Array = []
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

# --- Character Creation Layers (background + patron saint) ---
var gold_reward_multiplier: float = 1.0  # background bonus, read by game.gd._apply_rewards
var shop_buy_multiplier: float = 1.0     # background bonus, stacks onto ShopData
var shop_sell_multiplier: float = 1.0    # background bonus, stacks onto ShopData
var _background: BackgroundData = null
var _patron: PatronSaintData = null
var _patron_tier_index: int = -1         # which saint tier is active; -1 = none

# --- Node References ---
@onready var _hurt_player: AudioStreamPlayer2D = $SFX/HurtPlayer
@onready var _death_player: AudioStreamPlayer2D = $SFX/DeathPlayer
@onready var _inventory: Inventory = $Inventory

var _cond_eval: StatExprEval = StatExprEval.new()

# Baseline action for an empty hand — a bare-handed punch.
const _UNARMED: AttackData = preload("res://resources/equipment/weapons/unarmed_strike.tres")
# The punch is backed by an innate Fists weapon so its power/scaling reach the hit through the
# same weapon-anatomy path as any equipped weapon (fists aren't equippable, so it stays a bare
# base — no upgrade/rarity/tags to compose).
const _FISTS: WeaponData = preload("res://resources/equipment/weapons/fists.tres")

# --- Actions ---
# Per-hand registries: hand -> {action_name: Callable}. A mainhand "Strike" and an
# offhand "Punch" never collide. Register via register_action(name, callable, hand);
# call via execute_action(hand, name). _hand_attacks / _hand_spells hold the source
# resources so game.gd can build buttons and resolve names without re-deriving.
var _hand_actions := { Hand.MAINHAND: {}, Hand.OFFHAND: {} }
var _hand_attacks := { Hand.MAINHAND: [], Hand.OFFHAND: [] }   # hand -> Array[AttackData]
var _hand_spells := { Hand.MAINHAND: [], Hand.OFFHAND: [] }    # hand -> Array[SpellData]
# Live per-action cooldowns: hand -> {action_name: turns_remaining}. Seeded on use from
# the source resource's `cooldown`, decremented once per player turn in begin_turn().
var _cooldowns := { Hand.MAINHAND: {}, Hand.OFFHAND: {} }


func _ready() -> void:
	_register_actions()
	_transition(State.IDLE)
	_inventory.slot_changed.connect(_on_slot_changed)
	_inventory.ring_changed.connect(_on_ring_changed)


func _process(_delta: float) -> void:
	# An action resolves (animation + effects done) one frame after it's issued. Mark its
	# hand used and notify listeners — but never end the turn here; that's explicit.
	if _action_resolving and _is_turn_complete():
		_action_resolving = false
		_set_hand_used(_pending_hand)
		action_resolved.emit(_pending_hand)


# --- Initialization ---

func initialize(p_name: String, class_data: PlayerClassData, background: BackgroundData = null, patron: PatronSaintData = null) -> void:
	reset_run_state()
	_class_data = class_data
	player_name = p_name
	strength = class_data.strength
	defense = 0.0  # Equipment-derived; classes grant no innate armor.
	constitution = class_data.constitution
	agility = class_data.agility
	spirit = class_data.spirit
	luck = class_data.luck
	level = 1
	experience = 0
	pending_stat_points = 0
	pending_growth_bonuses = {}
	gold = 0
	_setup_starting_equipment(class_data)
	_setup_starting_blessings(class_data)
	_setup_background(background)
	_setup_patron(patron)
	_recalculate_max_health()
	_recalculate_max_mana()
	health = max_health
	_recalculate_prep_slots()
	_setup_starting_spells(class_data)
	restore_mana_to_full()


func reset_run_state() -> void:
	_clear_equipment_nodes()
	for bd in _blessings.duplicate():
		remove_blessing(bd)
	_active_statuses.clear()
	_hand_actions[Hand.MAINHAND].clear()
	_hand_actions[Hand.OFFHAND].clear()
	_hand_attacks[Hand.MAINHAND] = []
	_hand_attacks[Hand.OFFHAND] = []
	_hand_spells[Hand.MAINHAND] = []
	_hand_spells[Hand.OFFHAND] = []
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
	_mainhand_used = false
	_offhand_used = false
	for hand in _cooldowns:
		_cooldowns[hand].clear()
	_action_resolving = false
	armor = 0.0
	max_armor = 0.0
	_dodge_streak = 0
	_attack_animation_pending = false
	_cast_animation_pending = false
	is_dead = false
	gold_reward_multiplier = 1.0
	shop_buy_multiplier = 1.0
	shop_sell_multiplier = 1.0
	_background = null
	_patron = null
	_patron_tier_index = -1
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
			_inventory.add_to_bag(tome_res as TomeData)


func _setup_starting_blessings(class_data: PlayerClassData) -> void:
	for data in class_data.starting_blessings:
		add_blessing(data)


func _setup_background(background: BackgroundData) -> void:
	if background == null:
		return
	_background = background
	gold_reward_multiplier = background.gold_reward_multiplier
	shop_buy_multiplier = background.shop_buy_multiplier
	shop_sell_multiplier = background.shop_sell_multiplier
	add_gold(background.starting_gold)
	if background.passive != null:
		add_blessing(background.passive)


func _setup_patron(patron: PatronSaintData) -> void:
	if patron == null or patron.tiers.is_empty():
		return
	_patron = patron
	_patron_tier_index = 0
	var tier := patron.tiers[0]
	if tier != null:
		add_blessing(tier)


## Advances the active patron saint to its next tier (Phase 2 shrine ascension).
## Removes the current tier blessing and applies the next; no-op past the last tier.
func ascend_patron() -> void:
	if _patron == null or _patron_tier_index < 0 or _patron_tier_index >= _patron.tiers.size() - 1:
		return
	var current := _patron.tiers[_patron_tier_index]
	if current != null:
		remove_blessing(current)
	_patron_tier_index += 1
	var next := _patron.tiers[_patron_tier_index]
	if next != null:
		add_blessing(next)
	_recalculate_max_health()
	_recalculate_max_mana()


## The active patron saint, or null if none was chosen.
func get_patron() -> PatronSaintData:
	return _patron


## True when an active patron saint has a further tier to ascend into.
func can_ascend_patron() -> bool:
	return _patron != null and _patron_tier_index >= 0 and _patron_tier_index < _patron.tiers.size() - 1


## The currently active patron tier blessing, or null if none.
func get_active_tier() -> BlessingData:
	if _patron == null or _patron_tier_index < 0 or _patron_tier_index >= _patron.tiers.size():
		return null
	return _patron.tiers[_patron_tier_index]


## The tier the player would ascend into next, or null if already at the last tier.
func get_next_tier() -> BlessingData:
	if not can_ascend_patron():
		return null
	return _patron.tiers[_patron_tier_index + 1]


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


func register_action(action_name: String, callable: Callable, hand: Hand = Hand.MAINHAND) -> void:
	_hand_actions[hand][action_name] = callable


func unregister_action(action_name: String, hand: Hand = Hand.MAINHAND) -> void:
	_hand_actions[hand].erase(action_name)


## Resets both hands at the start of the player's turn. The offhand starts spent only
## when it has no action to offer (locked by a two-hander with no supporting action).
func begin_turn() -> void:
	_mainhand_used = false
	_offhand_used = _offhand_has_no_action()
	_action_resolving = false
	# Round start: full dodge chance and a fresh armor buffer for the round ahead.
	_dodge_streak = 0
	_tick_cooldowns()
	refresh_armor()
	# Burn (if an enemy inflicted it) discharges at the start of the player's turn too.
	resolve_turn_start_bursts()


## Refills the armor buffer to the current effective DEF. Called at the start of each round.
## Shatter: skipped while a suppressing status is active, so the buffer stays depleted.
func refresh_armor() -> void:
	if has_armor_refresh_suppressed():
		return
	max_armor = get_effective_stat(Enums.Stat.DEFENSE)
	armor = max_armor
	armor_changed.emit(armor, max_armor)


## Explicitly ends the player's turn. The End Turn button and the stun path both call
## this — an action never ends the turn on its own.
func end_turn() -> void:
	if is_dead or _action_resolving:
		return
	_tick_statuses()
	turn_ended.emit()


## Stun path: forfeit the whole turn.
func pass_turn() -> void:
	end_turn()


func is_hand_used(hand: Hand) -> bool:
	return _mainhand_used if hand == Hand.MAINHAND else _offhand_used


func is_offhand_locked() -> bool:
	return _inventory.is_slot_locked(Enums.Slot.OFFHAND)


func get_hand_attacks(hand: Hand) -> Array:
	return _hand_attacks[hand]


func get_hand_spells(hand: Hand) -> Array:
	return _hand_spells[hand]


## Weapon-anatomy variables for evaluating an attack's damage expressions: the effective power
## and scaling of the weapon whose hand owns this attack, plus the live value of that weapon's
## scaling stat bound to the neutral `scale` var. The empty-hand punch resolves through the innate
## Fists weapon; other non-weapon attacks (SELF actions with no backing item) return empty, so
## power/scaling/scale simply default to 0.
func weapon_context_for(attack_data: AttackData) -> Dictionary:
	if attack_data == null:
		return {}
	var slot := _weapon_slot_owning_attack(attack_data)
	var inst: ItemInstance = _inventory.get_equipped_instance(slot) if slot != -1 else null
	var ctx: Dictionary
	if inst != null and inst.base is WeaponData:
		# Effective (composed) power/scaling so smithing, rarity, and tags all reach the hit.
		ctx = _weapon_context_from(inst.effective_power(), inst.effective_scaling(), inst.scaling_stat())
	elif attack_data == _UNARMED:
		# No backing weapon instance (empty hand — the punch is registered into a hand's moveset even
		# when that hand holds nothing). The bare-handed punch is backed by the innate Fists weapon.
		ctx = _weapon_context_from(_FISTS.power, _FISTS.scaling, _FISTS.scaling_stat)
	else:
		return {}
	# Per-attack coefficient: the authored base K shifted by any active additive/multiplicative buffs.
	ctx["coeff"] = (attack_data.power_coefficient + get_attack_coeff_add()) * get_attack_coeff_mult()
	return ctx


## Damage-expression variables for a spell cast. Spells share the uniform form
## `power * coeff + scale * scaling` with weapons, but carry no stat term: `scale`/`scaling` are 0,
## so a spell's damage is its flat authored `power`. SPI gates mana, not spell power — see
## journal/ideas/mana-as-capacity.md. `coeff` stays neutral (1.0); spells are flat-authored, not
## buffed through the attack-coefficient knob.
func spell_context_for(spell: SpellData) -> Dictionary:
	if spell == null:
		return {}
	return {
		# Flat power buffs (get_power_add) apply to casts too — the uniform term is (power + add) * coeff
		# + scale*scaling. This is a temporary combat buff, NOT SPI scaling, so it does not conflict with
		# mana-as-capacity's "SPI doesn't scale spell damage" (see journal/ideas/mana-as-capacity.md).
		"power": spell.power + get_power_add(),
		"scaling": 0.0,
		"scale": 0.0,
		"scale_stat": -1,  # no scaling stat; keeps the preview label from naming one
		"coeff": 1.0,
	}


## Builds the weapon-anatomy context dict from resolved power/scaling and a scaling stat, binding
## the neutral `scale` var to that stat's live effective value. Callers add `coeff` per attack.
func _weapon_context_from(power: float, scaling: float, scale_stat: Enums.Stat) -> Dictionary:
	return {
		# Flat power buffs fold into the base here, so the hit resolves (power + add) * coeff + scale*scaling.
		"power": power + get_power_add(),
		"scaling": scaling,
		"scale": get_effective_stat(scale_stat),
		"scale_stat": scale_stat,  # identity, for preview labels (StatExprEval ignores it)
	}


## Which equipped weapon slot's hand holds this attack (WEAPON / OFFHAND), or -1 if neither —
## unarmed punches and SELF actions from an empty hand have no backing weapon.
func _weapon_slot_owning_attack(attack_data: AttackData) -> int:
	if _hand_attacks[Hand.MAINHAND].has(attack_data):
		return Enums.Slot.WEAPON
	if _hand_attacks[Hand.OFFHAND].has(attack_data):
		return Enums.Slot.OFFHAND
	return -1


func execute_action(hand: Hand, action_name: String) -> void:
	if is_dead or _action_resolving or is_hand_used(hand):
		return
	if get_cooldown_remaining(hand, action_name) > 0:
		return
	if not _hand_actions[hand].has(action_name):
		return
	print("[PLAYER] Action (%s): %s" % ["main" if hand == Hand.MAINHAND else "off", action_name])
	_pending_hand = hand
	_hand_actions[hand][action_name].call()
	_action_resolving = true
	# An action that reaches here always commits, so start its cooldown now.
	var cd := _action_base_cooldown(hand, action_name)
	if cd > 0:
		_cooldowns[hand][action_name] = cd


## Returns the authored cooldown of the named action in this hand (0 if none).
func _action_base_cooldown(hand: Hand, action_name: String) -> int:
	for atk in _hand_attacks[hand]:
		if atk != null and atk.display_name == action_name:
			return atk.cooldown
	for spell in _hand_spells[hand]:
		if spell != null and spell.display_name == action_name:
			return spell.cooldown
	return 0


## Turns left before the named action can be used again (0 = ready).
func get_cooldown_remaining(hand: Hand, action_name: String) -> int:
	return _cooldowns[hand].get(action_name, 0)


## Snapshot of the hand's active cooldowns for the UI: {action_name: turns_remaining}.
func get_hand_cooldowns(hand: Hand) -> Dictionary:
	var out := {}
	for action_name in _cooldowns[hand]:
		var remaining: int = _cooldowns[hand][action_name]
		if remaining > 0:
			out[action_name] = remaining
	return out


## Decrements every active cooldown by one player turn, clearing those that reach 0.
func _tick_cooldowns() -> void:
	for hand in _cooldowns:
		for action_name in _cooldowns[hand].keys():
			var remaining: int = _cooldowns[hand][action_name] - 1
			if remaining > 0:
				_cooldowns[hand][action_name] = remaining
			else:
				_cooldowns[hand].erase(action_name)


func _set_hand_used(hand: Hand) -> void:
	if hand == Hand.MAINHAND:
		_mainhand_used = true
	else:
		_offhand_used = true


## Clears fight-scoped action state so nothing leaks into the next combat: per-action
## cooldowns and hand-used flags. Called from CombatEvent._on_exit() when a fight ends.
func reset_combat_state() -> void:
	for hand in _cooldowns:
		_cooldowns[hand].clear()
	_mainhand_used = false
	_offhand_used = false


## The offhand offers no action only when a two-handed weapon locks it and defines no
## locked_offhand_attacks. An empty (unlocked) offhand still yields the unarmed punch.
func _offhand_has_no_action() -> bool:
	if not _inventory.is_slot_locked(Enums.Slot.OFFHAND):
		return false
	var wdata := _inventory.get_equipped(Enums.Slot.WEAPON) as WeaponData
	return wdata == null or wdata.locked_offhand_attacks.is_empty()


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
	print("  Player performs: %s" % attack_data.display_name)
	# Each hand animates its own weapon scene when it holds one; otherwise the hit resolves
	# immediately. A non-SELF attack defers its hit until the weapon's hit_landed fires.
	if _pending_hand == Hand.MAINHAND:
		var weapon_data := _inventory.get_equipped(Enums.Slot.WEAPON)
		if weapon_data != null and weapon_data.scene != null and attack_data.target_mode != ActionData.TargetMode.SELF:
			_attack_animation_pending = true
			_in_flight_attack_data = attack_data
			_in_flight_targets = targets
		attack_performed.emit(attack_data, targets)
		if not _attack_animation_pending:
			attack_hit.emit(attack_data, targets)
	else:
		var off_data := _inventory.get_equipped(Enums.Slot.OFFHAND)
		if off_data is WeaponData and off_data.scene != null and attack_data.target_mode != ActionData.TargetMode.SELF:
			_offhand_attack_animation_pending = true
			_offhand_in_flight_attack_data = attack_data
			_offhand_in_flight_targets = targets
			offhand_attack_performed.emit(attack_data, targets)
		else:
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

func _is_burst_bearer_defeated() -> bool:
	return is_dead


func take_damage(amount: float, pierce: float = 0.0, bypass_armor: bool = false, is_attack: bool = true, is_crit: bool = false) -> void:
	if is_dead:
		return
	if _roll_dodge():
		dodged.emit()
		return
	# Vulnerable/ward scales the incoming hit before armor soaks it — DoT ticks pass is_attack=false.
	if is_attack:
		amount *= get_incoming_attack_multiplier()
	# Commit the hit to a whole number before the pierce split so the shown damage and the
	# HP/armor breakdown agree (e.g. 14 at 50% pierce reads as 7 to HP, 7 to armor).
	amount = roundf(amount)
	var net_amount: float = amount
	if not bypass_armor:
		net_amount = _apply_defense(amount, pierce)
		var absorbed := amount - net_amount
		if absorbed > 0.0:
			armor_absorbed.emit(absorbed, roundf(net_amount) <= 0.0)
	net_amount = roundf(net_amount)  # HP is integral — round the applied delta, not the raw math
	if net_amount <= 0.0:
		return  # the armor buffer soaked the whole hit — no HP loss, no hurt feedback
	health = maxf(health - net_amount, 0.0)
	print("  Player HP: %.0f / %.0f" % [health, max_health])
	damaged.emit(net_amount, is_crit, roundf(amount))
	_flash_hurt_overlay()
	if health <= 0.0:
		_die()
	else:
		_play_sfx(_hurt_player)


func heal(amount: float) -> void:
	if is_dead:
		return
	var actual := roundf(minf(amount, max_health - health))
	health += actual
	healed.emit(actual)


func _die() -> void:
	print("  [PLAYER] Died!")
	is_dead = true
	_play_sfx(_death_player)
	_transition(State.DEAD)
	died.emit()


## Dodge chance is (effective AGI as a percent) halved once per successful dodge already
## made this round — a high-AGI build can't variance-dodge an entire multi-attack round.
## Only a *successful* dodge decays the chance; the streak resets at round start.
func _roll_dodge() -> bool:
	var eff_agi := get_effective_stat(Enums.Stat.AGILITY)
	var chance := minf(eff_agi / 100.0, 1.0) / pow(2.0, _dodge_streak)
	if randf() < chance:
		_dodge_streak += 1
		return true
	return false


## The armor buffer soaks incoming damage before HP; only the overflow bleeds through. A hit
## bigger than the remaining buffer pierces to HP, so immunity is impossible by construction.
## `pierce` is a 0–1 ratio: that share of the hit goes straight to HP and never touches the
## buffer; the remainder hits armor normally and overflows if the buffer is spent. Armor drains
## only by what it absorbs, so pierce is a strict upgrade — it can never reduce total HP damage.
func _apply_defense(amount: float, pierce: float = 0.0) -> float:
	var ratio := clampf(pierce, 0.0, 1.0)
	var to_hp := floorf(amount * ratio)      # bypasses armor entirely
	var remainder := amount - to_hp
	var absorbed := minf(armor, remainder)
	armor -= absorbed
	if absorbed > 0.0:
		armor_changed.emit(armor, max_armor)
	return to_hp + (remainder - absorbed)


# --- Equipment ---

func _recalculate_max_health() -> void:
	if _class_data == null:
		return
	var old_max := max_health
	var effective_con := get_effective_stat(Enums.Stat.CONSTITUTION)
	max_health = roundf(effective_con * health_modifier)
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
	max_mana = effective_spi * mana_modifier
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
		_prepared_spells.resize(new_size)
	else:
		_prepared_spells.resize(new_size)
		for i in range(prep_slots, new_size):
			_prepared_spells[i] = null
	prep_slots = new_size
	prep_slots_changed.emit(prep_slots)
	prepared_spells_changed.emit(get_castable_spells())
	_rebuild_hand_actions()


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
	_prepared_spells[index] = spell
	prepared_spells_changed.emit(get_castable_spells())
	_rebuild_hand_actions()


func unprepare_spell(index: int) -> void:
	if index < 0 or index >= _prepared_spells.size():
		return
	var spell := _prepared_spells[index]
	if spell == null:
		return
	_prepared_spells[index] = null
	prepared_spells_changed.emit(get_castable_spells())
	_rebuild_hand_actions()


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
			if spell != null and spell.display_name == name:
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
		push_warning("[PLAYER] _do_cast() insufficient mana for: %s" % spell.display_name)
		return
	print("  Player casts: %s" % spell.display_name)
	# Each hand animates its own weapon scene when it holds one; otherwise the cast resolves
	# immediately. A non-SELF cast defers its hit until the weapon's cast animation finishes.
	if _pending_hand == Hand.MAINHAND:
		var weapon_data := _inventory.get_equipped(Enums.Slot.WEAPON)
		if weapon_data != null and weapon_data.scene != null and spell.target_mode != ActionData.TargetMode.SELF:
			_cast_animation_pending = true
			_in_flight_spell = spell
			_in_flight_spell_targets = targets
		cast_performed.emit(spell, targets)
		if not _cast_animation_pending:
			cast_hit.emit(spell, targets)
	else:
		var off_data := _inventory.get_equipped(Enums.Slot.OFFHAND)
		if off_data is WeaponData and off_data.scene != null and spell.target_mode != ActionData.TargetMode.SELF:
			_offhand_cast_animation_pending = true
			_offhand_in_flight_spell = spell
			_offhand_in_flight_spell_targets = targets
			offhand_cast_performed.emit(spell, targets)
		else:
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
	_rebuild_hand_actions()
	stats_changed.emit(build_stats_dict())


func _on_ring_changed(_index: int, new_data: EquipmentData, old_data: EquipmentData) -> void:
	if old_data != null:
		_teardown_equipment(null, old_data)
	if new_data != null:
		_setup_equipment(null, new_data)
	_recalculate_max_health()
	_recalculate_max_mana()
	_recalculate_prep_slots()
	_rebuild_hand_actions()
	stats_changed.emit(build_stats_dict())


# --- Hand action registry ---

## Single source of truth for what each hand can do. Rebuilds both registries and their
## source-resource lists from the currently equipped items + castable repertoire, then
## announces the change so the action bar rebuilds. Called on any equip/unequip or
## spell-prep change — never per turn.
func _rebuild_hand_actions() -> void:
	_hand_actions[Hand.MAINHAND].clear()
	_hand_actions[Hand.OFFHAND].clear()
	_hand_attacks[Hand.MAINHAND] = []
	_hand_attacks[Hand.OFFHAND] = []
	_hand_spells[Hand.MAINHAND] = []
	_hand_spells[Hand.OFFHAND] = []
	_rebuild_innate_spell_names()
	_build_hand_actions(Hand.MAINHAND, Enums.Slot.WEAPON)
	_build_hand_actions(Hand.OFFHAND, Enums.Slot.OFFHAND)
	hand_actions_changed.emit()


## Populates one hand from the item in its slot. Attacks come from the item's `attacks`;
## casting (the prepared repertoire) requires the item to be a focus (grants_casting);
## a weapon always channels its own innate spells. A locked offhand draws its supporting
## actions from the two-hander; an empty, capability-less hand falls back to the punch.
func _build_hand_actions(hand: Hand, slot: Enums.Slot) -> void:
	if slot == Enums.Slot.OFFHAND and _inventory.is_slot_locked(Enums.Slot.OFFHAND):
		var wdata := _inventory.get_equipped(Enums.Slot.WEAPON) as WeaponData
		if wdata != null:
			for atk_res in wdata.locked_offhand_attacks:
				_register_hand_attack(hand, atk_res as AttackData)
		return
	var data := _inventory.get_equipped(slot)
	if data == null:
		_register_hand_attack(hand, _UNARMED)
		return
	# A weapon placed in the offhand uses its as_offhand_attacks moveset if it defines one,
	# otherwise its normal attacks.
	var attack_source: Array = data.attacks
	if slot == Enums.Slot.OFFHAND and data is WeaponData:
		var off_moveset := (data as WeaponData).as_offhand_attacks
		if not off_moveset.is_empty():
			attack_source = off_moveset
	var granted := false
	for atk_res in attack_source:
		granted = _register_hand_attack(hand, atk_res as AttackData) or granted
	if data.grants_casting:
		for spell in get_castable_spells():
			granted = _register_hand_spell(hand, spell) or granted
	elif data is WeaponData:
		for spell_res in (data as WeaponData).innate_spells:
			granted = _register_hand_spell(hand, spell_res as SpellData) or granted
	if not granted:
		_register_hand_attack(hand, _UNARMED)


func _register_hand_attack(hand: Hand, atk: AttackData) -> bool:
	if atk == null:
		return false
	register_action(atk.display_name, _do_attack, hand)
	_hand_attacks[hand].append(atk)
	return true


func _register_hand_spell(hand: Hand, spell: SpellData) -> bool:
	if spell == null:
		return false
	register_action(spell.display_name, _do_cast, hand)
	_hand_spells[hand].append(spell)
	return true


## Rebuilds the innate-spell name list from the mainhand weapon so get_castable_spells()
## (which resolves innate names against the equipped weapon) stays correct.
func _rebuild_innate_spell_names() -> void:
	_innate_spell_names.clear()
	var wdata := _inventory.get_equipped(Enums.Slot.WEAPON) as WeaponData
	if wdata == null:
		return
	for spell_res in wdata.innate_spells:
		var spell := spell_res as SpellData
		if spell != null:
			_innate_spell_names.append(spell.display_name)


func _setup_equipment(slot, data: EquipmentData) -> void:
	for effect_res in data.on_equip_effects:
		if effect_res is Effect:
			(effect_res as Effect).apply(self, self)
	if data.scene != null:
		var node := data.scene.instantiate() as Equipment
		node.data = data
		# Named slots carry an ItemInstance so tag-composed procs subscribe; rings pass slot=null.
		if slot != null:
			node.item_instance = _inventory.get_equipped_instance(slot)
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
		elif slot == Enums.Slot.OFFHAND and node is Weapon:
			print("[PLAYER] Equipped offhand weapon scene: %s" % data.item_name)
			node.visible = _weapon_visible
			node.scale.x = -1  # mirror the mainhand animation for the offhand
			offhand_attack_performed.connect((node as Weapon)._on_player_attacked)
			(node as Weapon).animation_finished.connect(_on_offhand_animation_finished)
			(node as Weapon).hit_landed.connect(_on_offhand_hit_landed)
			offhand_cast_performed.connect((node as Weapon)._on_player_cast)
			(node as Weapon).cast_animation_finished.connect(_on_offhand_cast_animation_finished)
	# A two-handed weapon evicts and locks the offhand. Hand action registries are
	# rebuilt centrally in _rebuild_hand_actions() (called from _on_slot_changed).
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		print("[PLAYER] Equipped weapon: %s" % data.item_name)
		var wdata := data as WeaponData
		if wdata.is_two_handed:
			if _inventory.get_equipped(Enums.Slot.OFFHAND) != null:
				_inventory.unequip(Enums.Slot.OFFHAND)
			_inventory.lock_slot(Enums.Slot.OFFHAND)


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
				elif slot == Enums.Slot.OFFHAND and child is Weapon:
					offhand_attack_performed.disconnect((child as Weapon)._on_player_attacked)
					(child as Weapon).animation_finished.disconnect(_on_offhand_animation_finished)
					(child as Weapon).hit_landed.disconnect(_on_offhand_hit_landed)
					offhand_cast_performed.disconnect((child as Weapon)._on_player_cast)
					(child as Weapon).cast_animation_finished.disconnect(_on_offhand_cast_animation_finished)
				child.queue_free()
				break
	# Unlock the offhand a two-hander held. Action registries are rebuilt centrally.
	if slot == Enums.Slot.WEAPON and data is WeaponData:
		var wdata := data as WeaponData
		if wdata.is_two_handed:
			_inventory.unlock_slot(Enums.Slot.OFFHAND)


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
	# An offhand weapon shares the mainhand's exploration/combat visibility.
	var offhand := get_equipped_node(Enums.Slot.OFFHAND)
	if offhand is Weapon:
		offhand.visible = show


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
		"background_path": _background.resource_path if _background != null else "",
		"patron_path": _patron.resource_path if _patron != null else "",
		"patron_tier_index": _patron_tier_index,
		"gold_reward_multiplier": gold_reward_multiplier,
		"shop_buy_multiplier": shop_buy_multiplier,
		"shop_sell_multiplier": shop_sell_multiplier,
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
	# The background passive and active saint tier are restored via the blessings
	# array below; here we only re-bind the layer references and economy multipliers.
	var bg_path: String = d.get("background_path", "")
	_background = load(bg_path) as BackgroundData if not bg_path.is_empty() else null
	var patron_path: String = d.get("patron_path", "")
	_patron = load(patron_path) as PatronSaintData if not patron_path.is_empty() else null
	_patron_tier_index = d.get("patron_tier_index", -1)
	gold_reward_multiplier = d.get("gold_reward_multiplier", 1.0)
	shop_buy_multiplier = d.get("shop_buy_multiplier", 1.0)
	shop_sell_multiplier = d.get("shop_sell_multiplier", 1.0)
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
	health = roundf(minf(d["health"], max_health))
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
	# Effective modifiers = base + tags, composed per instance (ItemInstance folds tag deltas on
	# top of the base's stat_modifiers / conditional_modifiers).
	for inst in _inventory.get_all_equipped_instances():
		var mods := inst.effective_stat_modifiers()
		if mods.has(stat):
			value += mods[stat]
	if not _evaluating_conditionals:
		_evaluating_conditionals = true
		for inst in _inventory.get_all_equipped_instances():
			for cm_res in inst.effective_conditional_modifiers():
				var cm := cm_res as ConditionalModifier
				if cm == null or cm.stat != stat:
					continue
				if _cond_eval.evaluate(cm.guard_expression, self) > 0.0:
					value += _cond_eval.evaluate(cm.amount_expression, self)
		_evaluating_conditionals = false
	for blessing in _blessings:
		if blessing.stat_modifiers.has(stat):
			value += blessing.stat_modifiers[stat]
	if _background != null and _background.stat_modifiers.has(stat):
		value += _background.stat_modifiers[stat]
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
	if _attack_animation_pending or _cast_animation_pending:
		return false
	if _offhand_attack_animation_pending or _offhand_cast_animation_pending:
		return false
	return _state == State.IDLE or _state == State.DEAD


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


func _on_offhand_animation_finished() -> void:
	_offhand_attack_animation_pending = false


func _on_offhand_cast_animation_finished() -> void:
	_offhand_cast_animation_pending = false
	if _offhand_in_flight_spell == null:
		return
	var spell := _offhand_in_flight_spell
	var targets := _offhand_in_flight_spell_targets
	_offhand_in_flight_spell = null
	_offhand_in_flight_spell_targets = []
	cast_hit.emit(spell, targets)


func _on_offhand_hit_landed() -> void:
	if _offhand_in_flight_attack_data == null:
		return
	var attack_data := _offhand_in_flight_attack_data
	var targets := _offhand_in_flight_targets
	_offhand_in_flight_attack_data = null
	_offhand_in_flight_targets = []
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
