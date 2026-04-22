class_name ConsumableBeltUI
extends HBoxContainer

signal consumable_use_requested(index: int)

var _inventory: Inventory
var _can_use: bool = true


func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_inventory.consumable_belt_changed.connect(_on_belt_changed)
	_inventory.belt_size_changed.connect(_on_belt_size_changed)
	_rebuild()


func set_can_use(value: bool) -> void:
	_can_use = value
	for i in get_child_count():
		var btn := get_child(i) as Button
		if btn != null:
			btn.disabled = not value or _inventory == null or _inventory.get_consumable_at(i) == null


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _inventory == null:
		return
	var belt := _inventory.get_consumable_belt()
	for i in belt.size():
		var btn := Button.new()
		var data: ConsumableData = belt[i]
		btn.text = data.item_name if data != null else "—"
		btn.disabled = not _can_use or data == null
		btn.pressed.connect(consumable_use_requested.emit.bind(i))
		add_child(btn)


func _on_belt_changed(index: int, _new_data: ConsumableData, _old_data: ConsumableData) -> void:
	var btn := get_child(index) as Button
	if btn == null:
		return
	var data: ConsumableData = _inventory.get_consumable_at(index)
	btn.text = data.item_name if data != null else "—"
	btn.disabled = not _can_use or data == null


func _on_belt_size_changed(_new_size: int) -> void:
	_rebuild()
