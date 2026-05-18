extends Node

func run_tests() -> Array:
	return [
		_test_era_omini_limits(),
		_test_stat_caps(),
		_test_initial_state(),
		_test_distance_initial(),
		_test_divine_energy_initial(),
		_test_spend_energy_success(),
		_test_spend_energy_fail(),
		_test_advance_step_era_change(),
		_test_reset_run_preserves_memory(),
		_test_reset_run_preserves_prestige(),
		_test_get_living_entities(),
		_test_era_speed_multiplier(),
	]


func _test_era_omini_limits() -> Dictionary:
	var ok = GameState.ERA_ENTITY_LIMIT[1] == 4 and \
			 GameState.ERA_ENTITY_LIMIT[2] == 8 and \
			 GameState.ERA_ENTITY_LIMIT[3] == 15 and \
			 GameState.ERA_ENTITY_LIMIT[4] == 30 and \
			 GameState.ERA_ENTITY_LIMIT[5] == 50
	return {"name": "ERA_ENTITY_LIMIT values", "passed": ok}


func _test_stat_caps() -> Dictionary:
	var ok = GameState.ERA_STAT_CAP[1] == 15 and \
			 GameState.ERA_STAT_CAP[5] == 100
	return {"name": "ERA_STAT_CAP values", "passed": ok}


func _test_initial_state() -> Dictionary:
	var gs = GameState
	var ok = gs.current_era >= 1 and gs.current_era <= 5
	return {"name": "current_era in valid range", "passed": ok}


func _test_distance_initial() -> Dictionary:
	# After load, distance should be <= 1_000_000
	var ok = GameState.distance_from_center <= 1_000_000.0 and \
			 GameState.distance_from_center >= 0.0
	return {"name": "distance_from_center in valid range", "passed": ok}


func _test_divine_energy_initial() -> Dictionary:
	var ok = GameState.divine_energy >= 0.0 and \
			 GameState.divine_energy <= GameState.divine_energy_max
	return {"name": "divine_energy in valid range", "passed": ok}


func _test_spend_energy_success() -> Dictionary:
	var original = GameState.divine_energy
	GameState.divine_energy = 50.0
	var result = GameState.spend_divine_energy(20.0)
	var ok = result == true and is_equal_approx(GameState.divine_energy, 30.0)
	GameState.divine_energy = original
	return {"name": "spend_divine_energy success", "passed": ok}


func _test_spend_energy_fail() -> Dictionary:
	var original = GameState.divine_energy
	GameState.divine_energy = 10.0
	var result = GameState.spend_divine_energy(50.0)
	var ok = result == false and is_equal_approx(GameState.divine_energy, 10.0)
	GameState.divine_energy = original
	return {"name": "spend_divine_energy insufficient", "passed": ok}


func _test_advance_step_era_change() -> Dictionary:
	var original_era = GameState.current_era
	var original_step = GameState.current_step
	GameState.current_era = 1
	GameState.current_step = 10
	GameState.advance_step()  # step 11 > era*10=10 → should advance to era 2
	var ok = GameState.current_era == 2
	GameState.current_era = original_era
	GameState.current_step = original_step
	return {"name": "advance_step triggers era change", "passed": ok}


func _test_reset_run_preserves_memory() -> Dictionary:
	var original_count = GameState.memory_book.size()
	GameState.memory_book.append({"test": true})
	GameState.reset_run()
	var ok = GameState.memory_book.size() == original_count + 1
	# Cleanup
	GameState.memory_book.pop_back()
	return {"name": "reset_run preserves memory_book", "passed": ok}


func _test_reset_run_preserves_prestige() -> Dictionary:
	var original_prestige = GameState.prestige_count
	GameState.prestige_count = 3
	GameState.reset_run()
	var ok = GameState.prestige_count == 3
	GameState.prestige_count = original_prestige
	return {"name": "reset_run preserves prestige_count", "passed": ok}


func _test_get_living_entities() -> Dictionary:
	var original = GameState.entities.duplicate()
	GameState.entities.clear()
	var o1 = GameState.EntityData.new()
	o1.is_alive = true
	var o2 = GameState.EntityData.new()
	o2.is_alive = false
	GameState.entities = [o1, o2]
	var living = GameState.get_living_entities()
	var ok = living.size() == 1
	GameState.entities = original
	return {"name": "get_living_entities filters dead", "passed": ok}


func _test_era_speed_multiplier() -> Dictionary:
	var original_era = GameState.current_era
	GameState.current_era = 1
	var m1 = GameState.get_era_speed_multiplier()
	GameState.current_era = 3
	var m3 = GameState.get_era_speed_multiplier()
	var ok = m1 < m3 and is_equal_approx(m1, 1.0)
	GameState.current_era = original_era
	return {"name": "era_speed_multiplier increases with era", "passed": ok}
