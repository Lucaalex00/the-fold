extends Node

signal power_used(power_name: String)
signal power_failed(power_name: String, reason: String)

const DIVINE_POWERS = {
	"create_mountain":        {"era_required": 1, "cost": 30, "category": "geography"},
	"create_wall":            {"era_required": 1, "cost": 20, "category": "geography"},
	"create_ocean":           {"era_required": 2, "cost": 50, "category": "geography"},
	"create_island":          {"era_required": 2, "cost": 40, "category": "geography"},
	"change_temperature":     {"era_required": 1, "cost": 25, "category": "physics"},
	"change_gravity":         {"era_required": 2, "cost": 60, "category": "physics"},
	"accelerate_day":         {"era_required": 3, "cost": 45, "category": "physics"},
	"mutate_faction":         {"era_required": 1, "cost": 35, "category": "biology"},
	"accelerate_evolution":   {"era_required": 2, "cost": 70, "category": "biology"},
	"create_disease":         {"era_required": 2, "cost": 30, "category": "biology"},
	"grant_immunity":         {"era_required": 2, "cost": 40, "category": "biology"}
}


func use_power(power_name: String) -> bool:
	if not DIVINE_POWERS.has(power_name):
		emit_signal("power_failed", power_name, "unknown_power")
		return false

	var power = DIVINE_POWERS[power_name]

	if GameState.current_era < power["era_required"]:
		emit_signal("power_failed", power_name, "era_required")
		return false

	if not GameState.spend_divine_energy(power["cost"]):
		emit_signal("power_failed", power_name, "insufficient_energy")
		return false

	_apply_power(power_name)
	emit_signal("power_used", power_name)
	SaveManager.save_game()
	return true


func can_use_power(power_name: String) -> bool:
	if not DIVINE_POWERS.has(power_name):
		return false
	var power = DIVINE_POWERS[power_name]
	return GameState.current_era >= power["era_required"] and \
		   GameState.divine_energy >= power["cost"]


func get_powers_for_era(era: int) -> Array:
	var result = []
	for name in DIVINE_POWERS.keys():
		if DIVINE_POWERS[name]["era_required"] <= era:
			result.append(name)
	return result


func get_power_cost(power_name: String) -> float:
	return float(DIVINE_POWERS.get(power_name, {}).get("cost", 0))


func get_power_category(power_name: String) -> String:
	return DIVINE_POWERS.get(power_name, {}).get("category", "")


func get_power_display_name(power_name: String) -> String:
	return L.tr("POWER_" + power_name.to_upper())


func _apply_power(power_name: String) -> void:
	match power_name:
		"create_mountain":
			_power_create_mountain()
		"create_wall":
			_power_create_wall()
		"change_temperature":
			_power_change_temperature()
		"mutate_faction":
			_power_mutate_faction()
		"grant_immunity":
			_power_grant_immunity()
		"create_disease":
			_power_create_disease()
		"accelerate_evolution":
			_power_accelerate_evolution()
		"accelerate_day":
			_power_accelerate_day()
		_:
			pass  # geography powers: visual only at this stage


func _power_create_mountain() -> void:
	# Increases construction output — terrain bonus
	for entity in GameState.get_living_entities():
		if entity.trait_primary == "builder":
			entity.stats["construction"] = mini(
				entity.stats["construction"] + 2,
				GameState.get_stat_cap()
			)


func _power_create_wall() -> void:
	# Reduces conflict probability — defensive bonus
	CultureSystem.cohesion = minf(CultureSystem.cohesion + 10.0, 100.0)


func _power_change_temperature() -> void:
	# Boosts harvest for 1 day (flag handled in ResourceSystem)
	ResourceSystem.resources["harvest"] = roundi(ResourceSystem.resources["harvest"] * 1.5)


func _power_mutate_faction() -> void:
	# Random stat boost to all entities of the weakest trait group
	var living = GameState.get_living_entities()
	if living.is_empty():
		return
	for entity in living:
		var random_stat = entity.stats.keys()[randi() % entity.stats.size()]
		entity.stats[random_stat] = mini(
			entity.stats[random_stat] + randi_range(1, 3),
			GameState.get_stat_cap()
		)


func _power_grant_immunity() -> void:
	# Boost health of all living entities
	for entity in GameState.get_living_entities():
		entity.stats["health"] = mini(
			entity.stats["health"] + 3,
			GameState.get_stat_cap()
		)


func _power_create_disease() -> void:
	# Deal damage to all living entities health
	for entity in GameState.get_living_entities():
		entity.stats["health"] = maxi(entity.stats["health"] - randi_range(1, 4), 1)


func _power_accelerate_evolution() -> void:
	GameState.advance_step()


func _power_accelerate_day() -> void:
	TimeManager.advance_game_year()
