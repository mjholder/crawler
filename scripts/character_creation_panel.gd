class_name CharacterCreationPanel
extends Control

# --- Signals ---
signal character_confirmed(player_name: String, class_data: PlayerClassData, background: BackgroundData, patron: PatronSaintData)

# --- Config ---
## Assign resources in the Inspector, or leave empty to auto-load from the
## conventional resources/ subdirectories.
@export var available_classes: Array[PlayerClassData] = []
@export var available_backgrounds: Array[BackgroundData] = []
@export var available_patrons: Array[PatronSaintData] = []

const STEP_TITLES: Array[String] = [
	"Choose Your Class",
	"Choose a Background",
	"Choose a Patron Saint",
	"Confirm Your Character",
]

# --- Node References ---
@onready var _step_title: Label = $PanelContainer/Margin/Root/StepTitleLabel
@onready var _step_indicator: Label = $PanelContainer/Margin/Root/StepIndicatorLabel
@onready var _steps: Array[Control] = [
	$PanelContainer/Margin/Root/Steps/Step1_Class,
	$PanelContainer/Margin/Root/Steps/Step2_Background,
	$PanelContainer/Margin/Root/Steps/Step3_Patron,
	$PanelContainer/Margin/Root/Steps/Step4_Confirm,
]

@onready var _name_input: LineEdit = $PanelContainer/Margin/Root/Steps/Step1_Class/NameInput
@onready var _class_list: ItemList = $PanelContainer/Margin/Root/Steps/Step1_Class/ClassList
@onready var _class_name_label: Label = $PanelContainer/Margin/Root/Steps/Step1_Class/ClassInfoScroll/ClassInfo/ClassNameLabel
@onready var _class_desc_label: Label = $PanelContainer/Margin/Root/Steps/Step1_Class/ClassInfoScroll/ClassInfo/ClassDescLabel
@onready var _class_stats_label: Label = $PanelContainer/Margin/Root/Steps/Step1_Class/ClassInfoScroll/ClassInfo/ClassStatsLabel

@onready var _bg_list: ItemList = $PanelContainer/Margin/Root/Steps/Step2_Background/BackgroundList
@onready var _bg_name_label: Label = $PanelContainer/Margin/Root/Steps/Step2_Background/BgInfoScroll/BgInfo/BgNameLabel
@onready var _bg_desc_label: Label = $PanelContainer/Margin/Root/Steps/Step2_Background/BgInfoScroll/BgInfo/BgDescLabel
@onready var _bg_effects_label: Label = $PanelContainer/Margin/Root/Steps/Step2_Background/BgInfoScroll/BgInfo/BgEffectsLabel

@onready var _patron_list: ItemList = $PanelContainer/Margin/Root/Steps/Step3_Patron/PatronList
@onready var _patron_name_label: Label = $PanelContainer/Margin/Root/Steps/Step3_Patron/PatronInfoScroll/PatronInfo/PatronNameLabel
@onready var _patron_desc_label: Label = $PanelContainer/Margin/Root/Steps/Step3_Patron/PatronInfoScroll/PatronInfo/PatronDescLabel
@onready var _patron_tiers_label: Label = $PanelContainer/Margin/Root/Steps/Step3_Patron/PatronInfoScroll/PatronInfo/PatronTiersLabel

@onready var _summary_label: Label = $PanelContainer/Margin/Root/Steps/Step4_Confirm/SummaryScroll/SummaryLabel
@onready var _back_button: Button = $PanelContainer/Margin/Root/NavBar/BackButton
@onready var _next_button: Button = $PanelContainer/Margin/Root/NavBar/NextButton

var _step: int = 0
var _selected_class: int = -1
var _selected_bg: int = -1
var _selected_patron: int = -1


func _ready() -> void:
	_class_list.item_selected.connect(_on_class_selected)
	_bg_list.item_selected.connect(_on_background_selected)
	_patron_list.item_selected.connect(_on_patron_selected)
	_name_input.text_changed.connect(_on_name_changed)
	_back_button.pressed.connect(_on_back_pressed)
	_next_button.pressed.connect(_on_next_pressed)

	if available_classes.is_empty():
		for res in _load_tres_from_directory("res://resources/classes/"):
			if res is PlayerClassData:
				available_classes.append(res)
	if available_backgrounds.is_empty():
		for res in _load_tres_from_directory("res://resources/backgrounds/"):
			if res is BackgroundData:
				available_backgrounds.append(res)
	if available_patrons.is_empty():
		for res in _load_tres_from_directory("res://resources/patron_saints/"):
			if res is PatronSaintData:
				available_patrons.append(res)

	_populate_list(_class_list, available_classes)
	_populate_list(_bg_list, available_backgrounds)
	_populate_list(_patron_list, available_patrons)
	_show_step(0)


# --- Resource loading ---

## Loads every .tres directly inside `path` (non-recursive) and returns them.
func _load_tres_from_directory(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + file_name)
			if res != null:
				out.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _populate_list(list: ItemList, items: Array) -> void:
	list.clear()
	for item in items:
		list.add_item(_display_name_of(item))


func _display_name_of(item: Variant) -> String:
	if item is PlayerClassData:
		return (item as PlayerClassData).class_name_text
	if item is BackgroundData:
		return (item as BackgroundData).display_name
	if item is PatronSaintData:
		return (item as PatronSaintData).display_name
	return "?"


# --- Step navigation ---

func _show_step(index: int) -> void:
	_step = clampi(index, 0, _steps.size() - 1)
	for i in _steps.size():
		_steps[i].visible = (i == _step)
	_step_title.text = STEP_TITLES[_step]
	_step_indicator.text = "Step %d of %d" % [_step + 1, _steps.size()]
	_back_button.disabled = _step == 0
	_next_button.text = "Begin" if _is_last_step() else "Next"
	if _is_last_step():
		_summary_label.text = _build_summary_text()
	_update_next_button()


func _is_last_step() -> bool:
	return _step == _steps.size() - 1


func _update_next_button() -> void:
	_next_button.disabled = not _can_advance()


func _can_advance() -> bool:
	match _step:
		0:
			return not _name_input.text.strip_edges().is_empty() and _selected_class >= 0
		1:
			return _selected_bg >= 0
		2:
			return _selected_patron >= 0
		_:
			return true


func _on_back_pressed() -> void:
	if _step > 0:
		_show_step(_step - 1)


func _on_next_pressed() -> void:
	if not _can_advance():
		return
	if _is_last_step():
		_confirm()
		return
	_show_step(_step + 1)


func _confirm() -> void:
	character_confirmed.emit(
		_name_input.text.strip_edges(),
		available_classes[_selected_class],
		available_backgrounds[_selected_bg] if _selected_bg >= 0 else null,
		available_patrons[_selected_patron] if _selected_patron >= 0 else null,
	)


# --- Selection handlers ---

func _on_name_changed(_text: String) -> void:
	_update_next_button()


func _on_class_selected(index: int) -> void:
	_selected_class = index
	var data: PlayerClassData = available_classes[index]
	_class_name_label.text = data.class_name_text
	_class_desc_label.text = data.description
	_class_stats_label.text = _build_stats_text(data)
	_update_next_button()


func _on_background_selected(index: int) -> void:
	_selected_bg = index
	var data: BackgroundData = available_backgrounds[index]
	_bg_name_label.text = data.display_name
	_bg_desc_label.text = data.description
	_bg_effects_label.text = _build_bg_effects_text(data)
	_update_next_button()


func _on_patron_selected(index: int) -> void:
	_selected_patron = index
	var data: PatronSaintData = available_patrons[index]
	_patron_name_label.text = data.display_name
	_patron_desc_label.text = data.description
	_patron_tiers_label.text = _build_patron_tiers_text(data)
	_update_next_button()


# --- Info text builders ---

func _build_stats_text(data: PlayerClassData) -> String:
	var stat_names := Enums.Stat.keys()
	var base_values := [
		data.strength, data.defense, data.constitution,
		data.agility, data.spirit, data.luck
	]
	var lines: Array[String] = []
	for i in Enums.Stat.values().size():
		var growth: float = data.growth_rates.get(i, 0.0)
		var growth_str: String = " (+%.0f/lvl)" % growth if growth > 0.0 else ""
		lines.append("%s: %.0f%s" % [stat_names[i], base_values[i], growth_str])
	return "\n".join(lines)


func _build_bg_effects_text(data: BackgroundData) -> String:
	var stat_names := Enums.Stat.keys()
	var lines: Array[String] = []
	for stat in data.stat_modifiers:
		var amount: float = data.stat_modifiers[stat]
		var sign_str := "+" if amount >= 0.0 else ""
		lines.append("%s%.0f %s" % [sign_str, amount, stat_names[int(stat)]])
	if data.starting_gold != 0:
		lines.append("Starting gold: %d" % data.starting_gold)
	if not is_equal_approx(data.gold_reward_multiplier, 1.0):
		lines.append("Gold rewards x%.2f" % data.gold_reward_multiplier)
	if not is_equal_approx(data.shop_buy_multiplier, 1.0):
		lines.append("Buy prices: %+d%%" % roundi((data.shop_buy_multiplier - 1.0) * 100.0))
	if not is_equal_approx(data.shop_sell_multiplier, 1.0):
		lines.append("Sell prices: %+d%%" % roundi((data.shop_sell_multiplier - 1.0) * 100.0))
	if data.passive != null:
		lines.append("Passive: %s" % data.passive.display_name)
	return "\n".join(lines)


func _build_patron_tiers_text(data: PatronSaintData) -> String:
	var lines: Array[String] = []
	for i in data.tiers.size():
		var tier: BlessingData = data.tiers[i]
		if tier == null:
			continue
		lines.append("Act %d — %s" % [i + 1, tier.display_name])
		if not tier.description.is_empty():
			lines.append("  %s" % tier.description)
	return "\n".join(lines)


func _build_summary_text() -> String:
	var lines: Array[String] = []
	lines.append("Name: %s" % _name_input.text.strip_edges())
	if _selected_class >= 0:
		lines.append("Class: %s" % available_classes[_selected_class].class_name_text)
	if _selected_bg >= 0:
		lines.append("Background: %s" % available_backgrounds[_selected_bg].display_name)
	if _selected_patron >= 0:
		lines.append("Patron Saint: %s" % available_patrons[_selected_patron].display_name)
	return "\n".join(lines)


# --- Reset ---

func reset() -> void:
	_name_input.text = ""
	_class_list.deselect_all()
	_bg_list.deselect_all()
	_patron_list.deselect_all()
	_selected_class = -1
	_selected_bg = -1
	_selected_patron = -1
	_class_name_label.text = ""
	_class_desc_label.text = ""
	_class_stats_label.text = ""
	_bg_name_label.text = ""
	_bg_desc_label.text = ""
	_bg_effects_label.text = ""
	_patron_name_label.text = ""
	_patron_desc_label.text = ""
	_patron_tiers_label.text = ""
	_show_step(0)
