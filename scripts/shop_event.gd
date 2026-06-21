class_name ShopEvent
extends Event

# --- Signals ---

signal shop_requested(shop_name: String, stock: Array[EquipmentData], buy_mult: float, sell_mult: float)
signal stock_changed(stock: Array[EquipmentData])

# --- State ---

var _shop_name: String = ""
var _stock: Array[EquipmentData] = []
var _buy_mult: float = 1.0
var _sell_mult: float = 0.5


# --- Event API ---

func initialize(data: Dictionary) -> void:
	var shop: ShopData = data.get("shop")
	if shop == null:
		return
	_shop_name = shop.shop_name
	_stock = shop.stock.duplicate()
	# Background economy bonuses (injected by game.gd) stack onto the shop's own rates.
	_buy_mult = shop.buy_price_multiplier * data.get("buy_mult_player", 1.0)
	_sell_mult = shop.sell_price_multiplier * data.get("sell_mult_player", 1.0)


func on_buy(item: EquipmentData) -> void:
	_stock.erase(item)
	stock_changed.emit(_stock)


func on_sell(item: EquipmentData) -> void:
	_stock.append(item)
	stock_changed.emit(_stock)


func on_leave() -> void:
	_advance_phase()


func get_buy_price(item: EquipmentData) -> int:
	return roundi(item.price * _buy_mult)


func get_sell_price(item: EquipmentData) -> int:
	return roundi(item.price * _sell_mult)


# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	shop_requested.connect(game._on_shop_requested)
	stock_changed.connect(game._on_shop_stock_changed)
	var inventory: Inventory = game.player.get_node("Inventory")
	inventory.bag_changed.connect(game._on_shop_bag_changed)


func _on_exit(game: Node) -> void:
	shop_requested.disconnect(game._on_shop_requested)
	stock_changed.disconnect(game._on_shop_stock_changed)
	var inventory: Inventory = game.player.get_node("Inventory")
	inventory.bag_changed.disconnect(game._on_shop_bag_changed)


# --- Extension Hooks ---

func _on_setup() -> void:
	pass


func _on_running() -> void:
	shop_requested.emit(_shop_name, _stock, _buy_mult, _sell_mult)
