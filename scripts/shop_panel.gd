class_name ShopPanel
extends Control

# --- Signals ---

signal buy_requested(item: EquipmentData)
signal sell_requested(item: EquipmentData)
signal leave_requested

# --- Node References ---

@onready var _shop_name_label: Label = $HBoxContainer/PanelContainer/VBoxContainer/ShopNameLabel
@onready var _gold_label: Label = $HBoxContainer/PanelContainer/VBoxContainer/GoldLabel
@onready var _buy_tab_button: Button = $HBoxContainer/PanelContainer/VBoxContainer/ModeButtons/BuyTabButton
@onready var _sell_tab_button: Button = $HBoxContainer/PanelContainer/VBoxContainer/ModeButtons/SellTabButton
@onready var _item_list: VBoxContainer = $HBoxContainer/PanelContainer/VBoxContainer/ItemList
@onready var _status_label: Label = $HBoxContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _leave_button: Button = $HBoxContainer/PanelContainer/VBoxContainer/LeaveButton
@onready var _detail_panel: PanelContainer = $HBoxContainer/DetailPanel
@onready var _detail_name_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailNameLabel
@onready var _detail_price_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailPriceLabel
@onready var _detail_stats_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailStatsLabel
@onready var _detail_desc_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailDescLabel

@export var _button: PackedScene

# --- State ---

enum Mode { BUY, SELL }

var _mode: Mode = Mode.BUY
var _stock: Array[EquipmentData] = []
var _bag: Array[EquipmentData] = []
var _gold: int = 0
var _buy_mult: float = 1.0
var _sell_mult: float = 0.5
var _bag_full: bool = false
var _row_buttons: Dictionary = {}  # EquipmentData -> Button


func _ready() -> void:
	_buy_tab_button.pressed.connect(_on_buy_tab_pressed)
	_sell_tab_button.pressed.connect(_on_sell_tab_pressed)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_hide_detail()


# --- Panel API ---

func setup(
	shop_name: String,
	stock: Array[EquipmentData],
	bag: Array[EquipmentData],
	gold: int,
	buy_mult: float,
	sell_mult: float,
	bag_full: bool
) -> void:
	_stock = stock
	_bag = bag
	_gold = gold
	_buy_mult = buy_mult
	_sell_mult = sell_mult
	_bag_full = bag_full
	_shop_name_label.text = shop_name
	_gold_label.text = "Gold: %d" % gold
	_set_mode(Mode.BUY)
	_hide_detail()
	_status_label.hide()


func refresh_stock(stock: Array[EquipmentData], bag_full: bool) -> void:
	_stock = stock
	_bag_full = bag_full
	if _mode == Mode.BUY:
		_rebuild_list()


func refresh_bag(bag: Array[EquipmentData], bag_full: bool) -> void:
	_bag = bag
	_bag_full = bag_full
	if _mode == Mode.SELL:
		_rebuild_list()
	else:
		_update_buy_disabled_states()


func refresh_gold(gold: int) -> void:
	_gold = gold
	_gold_label.text = "Gold: %d" % gold
	if _mode == Mode.BUY:
		_update_buy_disabled_states()


func show_status(msg: String) -> void:
	if msg.is_empty():
		_status_label.hide()
	else:
		_status_label.text = msg
		_status_label.show()


# --- Mode ---

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_buy_tab_button.button_pressed = (mode == Mode.BUY)
	_sell_tab_button.button_pressed = (mode == Mode.SELL)
	_hide_detail()
	_status_label.hide()
	_rebuild_list()


func _on_buy_tab_pressed() -> void:
	_set_mode(Mode.BUY)


func _on_sell_tab_pressed() -> void:
	_set_mode(Mode.SELL)


# --- List Building ---

func _rebuild_list() -> void:
	for child in _item_list.get_children():
		child.queue_free()
	_row_buttons.clear()

	var items: Array[EquipmentData] = _stock if _mode == Mode.BUY else _bag
	for item in items:
		var price := _get_display_price(item)
		var btn : Button = _button.instantiate()
		btn.text = "%s — %dg" % [item.item_name, price]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _mode == Mode.BUY:
			btn.disabled = price > _gold or _bag_full
		btn.pressed.connect(_on_row_pressed.bind(item))
		btn.mouse_entered.connect(_show_detail.bind(item))
		btn.mouse_exited.connect(_hide_detail)
		_item_list.add_child(btn)
		_row_buttons[item] = btn


func _update_buy_disabled_states() -> void:
	for item: EquipmentData in _row_buttons:
		var btn: Button = _row_buttons[item]
		btn.disabled = _get_display_price(item) > _gold or _bag_full


# --- Row Handlers ---

func _on_row_pressed(item: EquipmentData) -> void:
	if _mode == Mode.BUY:
		buy_requested.emit(item)
	else:
		sell_requested.emit(item)


# --- Detail Panel ---

func _show_detail(item: EquipmentData) -> void:
	var price := _get_display_price(item)
	_detail_name_label.text = item.item_name
	_detail_price_label.text = "Price: %dg" % price
	_detail_stats_label.text = _format_stat_modifiers(item.stat_modifiers)
	_detail_desc_label.text = item.description
	_detail_panel.show()


func _hide_detail() -> void:
	_detail_panel.hide()


# --- Helpers ---

func _get_display_price(item: EquipmentData) -> int:
	if _mode == Mode.BUY:
		return roundi(item.price * _buy_mult)
	return roundi(item.price * _sell_mult)


func _format_stat_modifiers(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return ""
	var stat_names := Enums.Stat.keys()
	var lines: Array[String] = []
	for stat_key in modifiers:
		var value: float = modifiers[stat_key]
		var name: String = stat_names[stat_key] if stat_key < stat_names.size() else str(stat_key)
		var sign: String = "+" if value >= 0.0 else ""
		var formatted: String = str(int(value)) if value == floorf(value) else "%.1f" % value
		lines.append(sign + formatted + " " + name)
	return "\n".join(lines)
