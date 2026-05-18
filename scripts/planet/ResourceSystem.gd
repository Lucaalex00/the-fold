extends Node

var resources: Dictionary = {
	"harvest": 0,
	"fishing": 0,
	"labor": 0,
	"trade": 0
}

var food_deficit_days: int = 0
var _food_consumed_today: bool = false


func _ready() -> void:
	GameState.omino_died.connect(_on_omino_died)


func daily_reset() -> void:
	resources["harvest"] = calculate_harvest()
	resources["fishing"] = calculate_fishing()
	resources["labor"] = calculate_labor()
	resources["trade"] = calculate_trade()

	_check_food_deficit()
	_food_consumed_today = false


func calculate_harvest() -> int:
	var total = 0
	for omino in GameState.get_living_omini():
		total += omino.stats.get("harvest", 0)
	return total


func calculate_fishing() -> int:
	var total = 0
	for omino in GameState.get_living_omini():
		total += omino.stats.get("fishing", 0)
	return total


func calculate_labor() -> int:
	var total = 0
	for omino in GameState.get_living_omini():
		total += omino.stats.get("construction", 0)
	return total


func calculate_trade() -> int:
	var total = 0
	for omino in GameState.get_living_omini():
		total += omino.stats.get("diplomacy", 0)
	return total


func get_total_food() -> int:
	return resources["harvest"] + resources["fishing"]


func _check_food_deficit() -> void:
	var living_count = GameState.get_living_omini().size()
	if living_count == 0:
		food_deficit_days = 0
		return

	# Deficit se il cibo prodotto non copre il fabbisogno base
	var food_needed = living_count * 5
	if get_total_food() < food_needed:
		food_deficit_days += 1
	else:
		food_deficit_days = 0


func _on_omino_died(_omino_data) -> void:
	# Ricalcola risorse quando muore un omino
	daily_reset()
