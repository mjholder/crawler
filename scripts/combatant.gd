class_name Combatant
extends Node2D

# --- Status Signals ---
signal status_applied(data: StatusData)
signal status_ticked(data: StatusData, turns_remaining: int)
signal status_expired(data: StatusData)

# Seconds between each hit of a turn-start burst (burn), so the countdown reads as three
# distinct drops on the health bar rather than one instant drop.
const BURST_STEP_DELAY := 0.3

# --- Status State ---
var _active_statuses: Array[StatusInstance] = []

# True only while clear_combat_statuses() is sweeping the board at end of combat. Lets
# listeners tell a forced end-of-fight clear from a natural mid-fight expiry (both emit
# status_expired) so the combat log doesn't spam "wears off" when a fight resolves.
var _clearing_combat_statuses: bool = false

# The game.gd lifecycle bus, injected by whoever owns this combatant (Player at set_player,
# Enemy at _on_combat_enemy_added). Used to wire StatusData.subscriptions; null = no wiring.
var _status_bus: Node = null


func get_effective_stat(stat: Enums.Stat) -> float:
	var base: float = _get_base_stat(stat)
	var bonus: float = 0.0
	for instance in _active_statuses:
		if instance.data.stat_modifiers.has(stat):
			bonus += instance.data.stat_modifiers[stat]
	return base + bonus


## `stacks` is how many stacks this application grants (STACK policy only; ignored by
## REFRESH/MAX_DURATION, which are always intensity 1). A 3-stack burn hit lands as one
## instance at 3 stacks — e.g. a burst that detonates 3/2/1.
func apply_status(data: StatusData, source: Node, stacks: int = 1) -> void:
	if data == null:
		return
	var grant: int = maxi(stacks, 1)
	for instance in _active_statuses:
		if instance.data.tag == data.tag:
			match data.stack_policy:
				StatusData.StackPolicy.REFRESH:
					instance.turns_remaining = data.duration
				StatusData.StackPolicy.MAX_DURATION:
					instance.turns_remaining = maxi(instance.turns_remaining, data.duration)
				StatusData.StackPolicy.STACK:
					# One instance per tag: bump intensity rather than adding a parallel
					# instance. on_tick damage scales by stacks.
					instance.stacks += grant
					# Stack-decaying statuses (poison) are drained by ticks, so their lifetime
					# is the stack count; others just refresh their fixed duration.
					instance.turns_remaining = instance.stacks if data.stack_decays else data.duration
			if not data.stat_modifiers.is_empty():
				_on_stat_modifiers_changed()
			status_applied.emit(data)
			return
	var entry := StatusInstance.new()
	entry.data = data
	entry.stacks = grant if data.stack_policy == StatusData.StackPolicy.STACK else 1
	# A stack-decaying status lives one tick per stack (fresh = stacks); others use `duration`.
	entry.turns_remaining = entry.stacks if data.stack_decays else data.duration
	entry.source = source
	_active_statuses.append(entry)
	_wire_status_subscriptions(entry)
	if data.on_apply != null:
		(data.on_apply as Effect).apply(source, self)
	if not data.stat_modifiers.is_empty():
		_on_stat_modifiers_changed()
	status_applied.emit(data)


func remove_status(tag: StringName) -> void:
	for instance in _active_statuses:
		if instance.data.tag == tag:
			_active_statuses.erase(instance)
			_unwire_status_subscriptions(instance)
			if instance.data.on_expire != null:
				(instance.data.on_expire as Effect).apply(instance.source, self)
			if not instance.data.stat_modifiers.is_empty():
				_on_stat_modifiers_changed()
			status_expired.emit(instance.data)
			return


func clear_combat_statuses() -> void:
	# Sweep combat-inflicted statuses (poison, bleed, burn, buffs) when a fight ends;
	# PERSISTENT statuses (gear/background-granted) survive across the run. on_expire is
	# deliberately not fired — a forced clear is not a natural expiry.
	var cleared: Array[StatusInstance] = []
	for instance in _active_statuses:
		if instance.data.persistence == StatusData.Persistence.COMBAT:
			cleared.append(instance)
	if cleared.is_empty():
		return
	_clearing_combat_statuses = true
	var stats_changed := false
	for instance in cleared:
		_active_statuses.erase(instance)
		_unwire_status_subscriptions(instance)
		if not instance.data.stat_modifiers.is_empty():
			stats_changed = true
		status_expired.emit(instance.data)
	_clearing_combat_statuses = false
	if stats_changed:
		_on_stat_modifiers_changed()


func is_clearing_combat_statuses() -> bool:
	return _clearing_combat_statuses


func has_preventing_status() -> bool:
	for instance in _active_statuses:
		if instance.data.prevents_action:
			return true
	return false


## Product of all active statuses' incoming attack multipliers (vulnerable/ward). 1.0 = none.
## Flat per instance — stacks extend a status's timer, not its multiplier.
func get_incoming_attack_multiplier() -> float:
	var mult := 1.0
	for instance in _active_statuses:
		mult *= instance.data.incoming_attack_multiplier
	return mult


## Shatter: true while any active status suppresses the per-round armor refresh.
func has_armor_refresh_suppressed() -> bool:
	for instance in _active_statuses:
		if instance.data.suppresses_armor_refresh:
			return true
	return false


func _tick_statuses() -> void:
	var expired: Array = []
	for instance in _active_statuses:
		# Burst statuses (burn) discharge at turn start via resolve_turn_start_bursts and are
		# gone before this runs; skip so a burst never also ticks at end of turn.
		if instance.data.burst_on_turn_start:
			continue
		if instance.data.on_tick != null:
			(instance.data.on_tick as Effect).apply_tick(instance.source, self, instance)
		# Stack-decaying statuses drain one stack per tick (kept in lockstep with
		# turns_remaining), so the next tick's damage is one stack lower.
		if instance.data.stack_decays:
			instance.stacks -= 1
		if instance.data.duration == -1:
			continue
		instance.turns_remaining -= 1
		if instance.turns_remaining <= 0:
			expired.append(instance)
		else:
			status_ticked.emit(instance.data, instance.turns_remaining)
	for instance in expired:
		_active_statuses.erase(instance)
		_unwire_status_subscriptions(instance)
		if instance.data.on_expire != null:
			(instance.data.on_expire as Effect).apply(instance.source, self)
		if not instance.data.stat_modifiers.is_empty():
			_on_stat_modifiers_changed()
		status_expired.emit(instance.data)


## Discharge every burst status (burn) at the start of the bearer's turn, before it acts.
## Each burst empties its whole stack pool as a countdown: on_tick fires for stacks,
## stacks-1, ... 1 (a plain DamageEffect at "1" deals base * stacks = the current count),
## with a delay between hits so the drops are visible, then the status is removed. Async:
## callers `await` it so the burst resolves before the turn's action.
func resolve_turn_start_bursts() -> void:
	var bursts: Array[StatusInstance] = []
	for instance in _active_statuses:
		if instance.data.burst_on_turn_start:
			bursts.append(instance)
	for instance in bursts:
		var effect := instance.data.on_tick as Effect
		while instance.stacks > 0:
			if effect != null:
				effect.apply_tick(instance.source, self, instance)
			status_ticked.emit(instance.data, instance.stacks)
			instance.stacks -= 1
			if _is_burst_bearer_defeated():
				break
			if instance.stacks > 0:
				await get_tree().create_timer(BURST_STEP_DELAY).timeout
		_active_statuses.erase(instance)
		_unwire_status_subscriptions(instance)
		if instance.data.on_expire != null:
			(instance.data.on_expire as Effect).apply(instance.source, self)
		if not instance.data.stat_modifiers.is_empty():
			_on_stat_modifiers_changed()
		status_expired.emit(instance.data)


## True once the bearer is dead, so a burst stops hitting a corpse. Overridden by
## Player/Enemy (both expose `is_dead`); the base class never dies.
func _is_burst_bearer_defeated() -> bool:
	return false


func get_active_statuses() -> Array:
	return _active_statuses


func to_status_save_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _active_statuses:
		if instance.data == null or instance.data.resource_path.is_empty():
			continue
		result.append({"data_path": instance.data.resource_path, "turns_remaining": instance.turns_remaining, "stacks": instance.stacks})
	return result


func apply_status_save_array(arr: Array) -> void:
	_active_statuses.clear()
	for entry in arr:
		var data := load(entry["data_path"]) as StatusData
		if data == null:
			push_warning("[Combatant] Could not load StatusData: %s" % entry["data_path"])
			continue
		var instance := StatusInstance.new()
		instance.data = data
		instance.turns_remaining = entry["turns_remaining"]
		instance.stacks = entry.get("stacks", 1)
		_active_statuses.append(instance)
		_wire_status_subscriptions(instance)
	if not _active_statuses.is_empty():
		_on_stat_modifiers_changed()


# --- Status Subscriptions ---

## Wire a status's `subscriptions` (signal-name -> Effect) to the lifecycle bus, mirroring
## the blessing pattern (player.gd add_blessing). Handlers fire effect.apply(source, bearer).
## No-op when no bus is injected or the status declares no subscriptions.
func _wire_status_subscriptions(instance: StatusInstance) -> void:
	if _status_bus == null or instance.data.subscriptions.is_empty():
		return
	var sub := Subscription.new()
	var bearer := self
	var src := instance.source
	for trigger in instance.data.subscriptions:
		var effect := instance.data.subscriptions[trigger] as Effect
		if effect == null:
			continue
		sub.add(Signal(_status_bus, trigger), func() -> void: effect.apply(src, bearer))
	instance._subscription = sub


func _unwire_status_subscriptions(instance: StatusInstance) -> void:
	if instance._subscription != null:
		instance._subscription.clear_all()
		instance._subscription = null


func _on_stat_modifiers_changed() -> void:
	pass


func _get_base_stat(_stat: Enums.Stat) -> float:
	return 0.0
