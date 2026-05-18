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
	GameState.entity_died.connect(_on_entity_died)


func daily_reset() -> void:
	resources["harvest"] = calculate_harvest()
	resources["fishing"] = calculate_fishing()
	resources["labor"] = calculate_labor()
	resources["trade"] = calculate_trade()

	_check_food_deficit()
	_food_consumed_today = false


func calculate_harvest() -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get("harvest", 0)
	return total


func calculate_fishing() -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get("fishing", 0)
	return total


func calculate_labor() -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get("construction", 0)
	return total


func calculate_trade() -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get("diplomacy", 0)
	return total


func get_total_food() -> int:
	return resources["harvest"] + resources["fishing"]


func _check_food_deficit() -> void:
	var living_count = GameState.get_living_entities().size()
	if living_count == 0:
		food_deficit_days = 0
		return

	# Deficit if produced food does not cover the base requirement
	var food_needed = living_count * 5
	if get_total_food() < food_needed:
		food_deficit_days += 1
	else:
		food_deficit_days = 0


func _on_entity_died(_entity_data) -> void:
	# Recalculate resources when an entity dies
	daily_reset()
