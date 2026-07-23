extends Control

## Controller for target.tscn — the in-combat targeting overlay that rides on each candidate
## enemy. Shows the previewed raw-hit damage number (TargetLabel) and the statuses the action
## would apply (Statuses strip), fed by AttackPreview. Replaces the old code-drawn TargetIndicator.

var _label: Label = null
var _statuses: HBoxContainer = null


# Resolve child nodes on demand so set_preview() is safe even when called synchronously right
# after add_child() (game.gd's spawn pattern), before _ready() would have run.
func _resolve_nodes() -> void:
	if _label == null:
		_label = $TargetLabel
		_statuses = $Statuses


func _ready() -> void:
	# Fade pulse, ported from the old TargetIndicator, so the overlay reads as "live aim".
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 0.4, 0.4)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


## Populates the overlay for one candidate `target`. The stack-count badge shows the RESULTING
## total when the target already carries the status (existing stacks + granted).
func set_preview(preview: AttackPreview, target: Node) -> void:
	_resolve_nodes()
	var total := preview.total_damage()
	_label.visible = total > 0.0
	if _label.visible:
		_label.text = str(int(round(total)))

	for child in _statuses.get_children():
		child.queue_free()
	for line in preview.status_lines():
		_statuses.add_child(_make_status_icon(line, target))


func _make_status_icon(line: AttackPreview.Line, target: Node) -> Control:
	var icon := TextureRect.new()
	icon.texture = line.status_data.icon
	icon.custom_minimum_size = Vector2(32.0, 32.0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = line.status_data.display_name

	var total_stacks := line.stacks + _existing_stacks(target, line.status_data.tag)
	if total_stacks > 1:
		var count := Label.new()
		count.name = "StackCount"
		count.text = str(total_stacks)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(count)
	return icon


func _existing_stacks(target: Node, tag: StringName) -> int:
	if target == null or not target.has_method("get_active_statuses"):
		return 0
	for instance in target.get_active_statuses():
		if instance.data != null and instance.data.tag == tag:
			return instance.stacks
	return 0
