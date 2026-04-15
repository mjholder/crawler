class_name CharacterCreationPanel
extends Control

# --- Signals ---
signal character_confirmed(player_name: String, class_data: PlayerClassData)

# --- Config ---
## Assign PlayerClassData .tres resources in the Inspector.
@export var available_classes: Array[PlayerClassData] = []

# --- Node References ---
# Expected scene layout:
#   PanelContainer/VBoxContainer/
#     TitleLabel
#     NameInput      (LineEdit)
#     ClassList      (ItemList)
#     ClassInfo/     (VBoxContainer)
#       ClassNameLabel
#       ClassDescLabel
#       ClassStatsLabel
#     ContinueButton (Button)
@onready var _name_input: LineEdit = $PanelContainer/VBoxContainer/NameInput
@onready var _class_list: ItemList = $PanelContainer/VBoxContainer/ClassList
@onready var _class_name_label: Label = $PanelContainer/VBoxContainer/ClassInfo/ClassNameLabel
@onready var _class_desc_label: Label = $PanelContainer/VBoxContainer/ClassInfo/ClassDescLabel
@onready var _class_stats_label: Label = $PanelContainer/VBoxContainer/ClassInfo/ClassStatsLabel
@onready var _continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton

var _selected_index: int = -1


func _ready() -> void:
	_continue_button.disabled = true
	_continue_button.pressed.connect(_on_continue_pressed)
	_class_list.item_selected.connect(_on_class_selected)
	_name_input.text_changed.connect(_on_name_changed)
	if available_classes.is_empty():
		_load_classes_from_directory("res://resources/classes/")
	_populate_class_list()


func _load_classes_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + file_name)
			if res is PlayerClassData:
				available_classes.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _populate_class_list() -> void:
	_class_list.clear()
	for class_data in available_classes:
		_class_list.add_item(class_data.class_name_text)


func _on_class_selected(index: int) -> void:
	_selected_index = index
	var class_data: PlayerClassData = available_classes[index]
	_class_name_label.text = class_data.class_name_text
	_class_desc_label.text = class_data.description
	_class_stats_label.text = _build_stats_text(class_data)
	_update_continue_button()


func _on_name_changed(_text: String) -> void:
	_update_continue_button()


func _update_continue_button() -> void:
	_continue_button.disabled = _name_input.text.strip_edges().is_empty() or _selected_index < 0


func _build_stats_text(class_data: PlayerClassData) -> String:
	var stat_names := Enums.Stat.keys()
	var base_values := [
		class_data.strength, class_data.defense, class_data.constitution,
		class_data.agility, class_data.spirit, class_data.luck
	]
	var lines: Array[String] = []
	for i in Enums.Stat.values().size():
		var growth: float = class_data.growth_rates.get(i, 0.0)
		var growth_str: String = " (+%.0f/lvl)" % growth if growth > 0.0 else ""
		lines.append("%s: %.0f%s" % [stat_names[i], base_values[i], growth_str])
	return "\n".join(lines)


func _on_continue_pressed() -> void:
	if _selected_index < 0 or _name_input.text.strip_edges().is_empty():
		return
	character_confirmed.emit(
		_name_input.text.strip_edges(),
		available_classes[_selected_index]
	)
