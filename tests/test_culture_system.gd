extends Node

func run_tests() -> Array:
	return [
		_test_cohesion_empty_population(),
		_test_cohesion_full_same_origin(),
		_test_cohesion_warrior_penalty(),
		_test_cohesion_clamps_to_100(),
		_test_cohesion_state_stable(),
		_test_cohesion_state_conflict(),
		_test_cohesion_state_collapse(),
		_test_war_penalty_none_when_stable(),
		_test_war_penalty_when_conflict(),
	]


func _setup_entities(trait_name: String, count: int, origin: String) -> Array:
	var result = []
	for i in range(count):
		var o = GameState.EntityData.new()
		o.is_alive = true
		o.trait_primary = trait_name
		o.origin_planet = origin
		result.append(o)
	return result


func _test_cohesion_empty_population() -> Dictionary:
	var original = GameState.entities.duplicate()
	GameState.entities.clear()
	var cohesion = CultureSystem.calculate_cohesion()
	var ok = is_equal_approx(cohesion, 0.0)
	GameState.entities = original
	return {"name": "cohesion = 0 with empty population", "passed": ok}


func _test_cohesion_full_same_origin() -> Dictionary:
	var original = GameState.entities.duplicate()
	GameState.entities = _setup_entities("builder", 4, "planet_a")
	var cohesion = CultureSystem.calculate_cohesion()
	# 4 builders same origin: warrior_ratio=0, same_origin=1.0 → bonus 20, base 100 → 120 clamped 100
	var ok = cohesion >= 90.0
	GameState.entities = original
	return {"name": "cohesion high with same origin non-warriors", "passed": ok}


func _test_cohesion_warrior_penalty() -> Dictionary:
	var original = GameState.entities.duplicate()
	# 3 warriors out of 4 = 75% ratio → penalty = (0.75-0.5)*100 = 25
	var entities = _setup_entities("warrior", 3, "planet_a")
	entities.append_array(_setup_entities("builder", 1, "planet_a"))
	GameState.entities = entities
	var cohesion = CultureSystem.calculate_cohesion()
	var ok = cohesion < 100.0
	GameState.entities = original
	return {"name": "warrior majority reduces cohesion", "passed": ok}


func _test_cohesion_clamps_to_100() -> Dictionary:
	var original = GameState.entities.duplicate()
	GameState.entities = _setup_entities("builder", 2, "planet_a")
	var cohesion = CultureSystem.calculate_cohesion()
	var ok = cohesion <= 100.0
	GameState.entities = original
	return {"name": "cohesion never exceeds 100", "passed": ok}


func _test_cohesion_state_stable() -> Dictionary:
	CultureSystem.cohesion = 75.0
	var state = CultureSystem.get_cohesion_state()
	return {"name": "cohesion 75 = stable", "passed": state == "stable"}


func _test_cohesion_state_conflict() -> Dictionary:
	CultureSystem.cohesion = 30.0
	var state = CultureSystem.get_cohesion_state()
	return {"name": "cohesion 30 = conflict", "passed": state == "conflict"}


func _test_cohesion_state_collapse() -> Dictionary:
	CultureSystem.cohesion = 10.0
	var state = CultureSystem.get_cohesion_state()
	return {"name": "cohesion 10 = collapse", "passed": state == "collapse"}


func _test_war_penalty_none_when_stable() -> Dictionary:
	CultureSystem.cohesion = 80.0
	var penalty = CultureSystem.get_war_penalty()
	return {"name": "war penalty = 0 when stable", "passed": is_equal_approx(penalty, 0.0)}


func _test_war_penalty_when_conflict() -> Dictionary:
	CultureSystem.cohesion = 30.0
	var penalty = CultureSystem.get_war_penalty()
	return {"name": "war penalty > 0 in conflict", "passed": penalty > 0.0}
