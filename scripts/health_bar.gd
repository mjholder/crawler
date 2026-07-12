class_name HealthBar
extends Control

@onready var _health_bar: ProgressBar = $Health/ProgressBar
@onready var _health_label: Label = $Health/Label
## Wrapping Control for the armor overlay; hidden whenever max_armor <= 0 (no DEF).
@onready var _armor: Control = $Armor
@onready var _armor_bar: ProgressBar = $Armor/ProgressBar
@onready var _armor_label: Label = $Armor/Label
## Status-icon strip; populated externally (see GUI.refresh_enemy_statuses).
@onready var statuses: HBoxContainer = $Statuses

var max_health: float = 100.0
var current_health: float = 100.0

var max_armor: float = 0.0
var current_armor: float = 0.0

func set_max_health(value: float) -> void:
	max_health = maxf(value, 1.0)
	_health_bar.max_value = max_health
	set_current_health(current_health)  # Re-clamp current health to new max

func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	_health_bar.value = current_health
	_health_label.text = "%d/%d" % [int(current_health), int(max_health)]

func subtract_health(amount: float) -> void:
	set_current_health(current_health - amount)

func add_health(amount: float) -> void:
	set_current_health(current_health + amount)

func set_armor(value: float, maximum: float) -> void:
	max_armor = maximum
	current_armor = clampf(value, 0.0, maxf(max_armor, 0.0))
	_armor.visible = max_armor > 0.0
	_armor_bar.max_value = maxf(max_armor, 1.0)
	_armor_bar.value = current_armor
	_armor_label.text = "%d/%d" % [int(current_armor), int(max_armor)]
