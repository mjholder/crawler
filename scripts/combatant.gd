class_name Combatant
extends Node2D

# --- Status Signals ---
signal status_applied(data: StatusData)
signal status_ticked(data: StatusData, turns_remaining: int)
signal status_expired(data: StatusData)

# --- Status State ---
var _active_statuses: Array[StatusInstance] = []


func get_effective_stat(stat: Enums.Stat) -> float:
	var base: float = _get_base_stat(stat)
	var bonus: float = 0.0
	for instance in _active_statuses:
		if instance.data.stat_modifiers.has(stat):
			bonus += instance.data.stat_modifiers[stat]
	return base + bonus


func apply_status(data: StatusData, source: Node) -> void:
	if data == null:
		return
	for instance in _active_statuses:
		if instance.data.tag == data.tag and data.stack_policy != StatusData.StackPolicy.STACK:
			match data.stack_policy:
				StatusData.StackPolicy.REFRESH:
					instance.turns_remaining = data.duration
				StatusData.StackPolicy.MAX_DURATION:
					instance.turns_remaining = maxi(instance.turns_remaining, data.duration)
			return
	var entry := StatusInstance.new()
	entry.data = data
	entry.turns_remaining = data.duration
	entry.source = source
	_active_statuses.append(entry)
	if data.on_apply != null:
		(data.on_apply as Effect).apply(source, self)
	if not data.stat_modifiers.is_empty():
		_on_stat_modifiers_changed()
	status_applied.emit(data)


func remove_status(tag: StringName) -> void:
	for instance in _active_statuses:
		if instance.data.tag == tag:
			_active_statuses.erase(instance)
			if instance.data.on_expire != null:
				(instance.data.on_expire as Effect).apply(instance.source, self)
			if not instance.data.stat_modifiers.is_empty():
				_on_stat_modifiers_changed()
			status_expired.emit(instance.data)
			return


func has_preventing_status() -> bool:
	for instance in _active_statuses:
		if instance.data.prevents_action:
			return true
	return false


func _tick_statuses() -> void:
	var expired: Array = []
	for instance in _active_statuses:
		if instance.data.on_tick != null:
			(instance.data.on_tick as Effect).apply(instance.source, self)
		if instance.data.duration == -1:
			continue
		instance.turns_remaining -= 1
		if instance.turns_remaining <= 0:
			expired.append(instance)
		else:
			status_ticked.emit(instance.data, instance.turns_remaining)
	for instance in expired:
		_active_statuses.erase(instance)
		if instance.data.on_expire != null:
			(instance.data.on_expire as Effect).apply(instance.source, self)
		if not instance.data.stat_modifiers.is_empty():
			_on_stat_modifiers_changed()
		status_expired.emit(instance.data)


func get_active_statuses() -> Array:
	return _active_statuses


func to_status_save_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _active_statuses:
		if instance.data == null or instance.data.resource_path.is_empty():
			continue
		result.append({"data_path": instance.data.resource_path, "turns_remaining": instance.turns_remaining})
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
		_active_statuses.append(instance)
	if not _active_statuses.is_empty():
		_on_stat_modifiers_changed()


func _on_stat_modifiers_changed() -> void:
	pass


func _get_base_stat(_stat: Enums.Stat) -> float:
	return 0.0
