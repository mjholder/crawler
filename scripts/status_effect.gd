class_name StatusEffect
extends Effect

@export var status_data: StatusData = null


func apply(source: Node, target: Node) -> void:
	if target == null or status_data == null or not target.has_method("apply_status"):
		return
	target.apply_status(status_data, source)
