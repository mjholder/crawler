class_name ConsumableBeltUI
extends HFlowContainer

signal consumable_pressed(index: int)

@export var template_button: Button

var _inventory: Inventory
var _can_use: bool = true
var _management_mode: bool = false


func _ready() -> void:
	if template_button == null:
		template_button = get_parent().get_node_or_null("ConsumableButton") as Button


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
			btn.disabled = (not _can_use and not _management_mode) or _inventory == null or _inventory.get_consumable_at(i) == null


func is_management_mode() -> bool:
	return _management_mode


func set_management_mode(value: bool) -> void:
	_management_mode = value
	for i in get_child_count():
		var btn := get_child(i) as Button
		if btn != null:
			btn.disabled = (not _can_use and not _management_mode) or _inventory == null or _inventory.get_consumable_at(i) == null


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _inventory == null or template_button == null:
		return
	var belt := _inventory.get_consumable_belt()
	for i in belt.size():
		var btn := template_button.duplicate() as Button
		_apply_slot_state(btn, belt[i])
		btn.visible = true
		btn.pressed.connect(consumable_pressed.emit.bind(i))
		add_child(btn)


func _apply_slot_state(btn: Button, data: ConsumableData) -> void:
	btn.text = data.item_name if data != null else "—"
	btn.disabled = (not _can_use and not _management_mode) or data == null


func _on_belt_changed(index: int, _new_data: ConsumableData, _old_data: ConsumableData) -> void:
	var btn := get_child(index) as Button
	if btn == null:
		return
	_apply_slot_state(btn, _inventory.get_consumable_at(index))


func _on_belt_size_changed(_new_size: int) -> void:
	_rebuild()
