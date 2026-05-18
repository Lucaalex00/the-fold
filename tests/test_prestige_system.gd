extends Node

func run_tests() -> Array:
	return [
		_test_cannot_trigger_before_era5(),
		_test_resource_multiplier_era1(),
		_test_resource_multiplier_grows(),
		_test_resource_multiplier_slows_after_5(),
		_test_bonus_2_war_god(),
		_test_bonus_2_harmony_god(),
		_test_bonus_2_resilience_god(),
		_test_bonus_slots_cap_at_3(),
		_test_death_cap_bonus_with_eternal_god(),
		_test_cohesion_bonus_with_harmony_god(),
	]


func _test_cannot_trigger_before_era5() -> Dictionary:
	var original_era = GameState.current_era
	GameState.current_era = 3
	GameState.distance_from_center = 0.0
	var ok = PrestigeSystem.can_trigger_prestige() == false
	GameState.current_era = original_era
	GameState.distance_from_center = 1_000_000.0
	return {"name": "prestige cannot trigger before era 5", "passed": ok}


func _test_resource_multiplier_era1() -> Dictionary:
	var original = GameState.prestige_count
	GameState.prestige_count = 0
	var mult = GameState.calculate_prestige_resource_multiplier()
	var ok = is_equal_approx(mult, 1.0)
	GameState.prestige_count = original
	return {"name": "resource multiplier = 1.0 at prestige 0", "passed": ok}


func _test_resource_multiplier_grows() -> Dictionary:
	var original = GameState.prestige_count
	GameState.prestige_count = 1
	var m1 = GameState.calculate_prestige_resource_multiplier()
	GameState.prestige_count = 3
	var m3 = GameState.calculate_prestige_resource_multiplier()
	var ok = m3 > m1 and m1 > 1.0
	GameState.prestige_count = original
	return {"name": "resource multiplier grows with prestige", "passed": ok}


func _test_resource_multiplier_slows_after_5() -> Dictionary:
	var original = GameState.prestige_count
	GameState.prestige_count = 5
	var m5 = GameState.calculate_prestige_resource_multiplier()
	GameState.prestige_count = 6
	var m6 = GameState.calculate_prestige_resource_multiplier()
	GameState.prestige_count = 10
	var m10 = GameState.calculate_prestige_resource_multiplier()
	# Growth from 5?6 should be smaller than 4?5 (1.5x vs 1.15x)
	var growth_5_to_6 = m6 / m5
	var ok = is_equal_approx(growth_5_to_6, 1.15, 0.01) and m10 > m6
	GameState.prestige_count = original
	return {"name": "multiplier uses 1.15x factor after prestige 5", "passed": ok}


func _test_bonus_2_war_god() -> Dictionary:
	var metrics = {"conflicts_won": 15, "avg_cohesion": 50.0,
				   "entities_lost": 5, "planets_visited": 2, "oldest_entity_age": 20}
	var bonus = PrestigeSystem._determine_bonus_2(metrics)
	return {"name": "bonus_2 = war_god when conflicts_won > 10", "passed": bonus == "war_god"}


func _test_bonus_2_harmony_god() -> Dictionary:
	var metrics = {"conflicts_won": 3, "avg_cohesion": 80.0,
				   "entities_lost": 2, "planets_visited": 1, "oldest_entity_age": 10}
	var bonus = PrestigeSystem._determine_bonus_2(metrics)
	return {"name": "bonus_2 = harmony_god when avg_cohesion > 75", "passed": bonus == "harmony_god"}


func _test_bonus_2_resilience_god() -> Dictionary:
	var metrics = {"conflicts_won": 3, "avg_cohesion": 50.0,
				   "entities_lost": 20, "planets_visited": 1, "oldest_entity_age": 10}
	var bonus = PrestigeSystem._determine_bonus_2(metrics)
	return {"name": "bonus_2 = resilience_god when entities_lost > 15", "passed": bonus == "resilience_god"}


func _test_bonus_slots_cap_at_3() -> Dictionary:
	var original_bonuses = PrestigeSystem.active_bonuses.duplicate()
	PrestigeSystem.active_bonuses.clear()
	PrestigeSystem._add_or_replace_bonus("war_god")
	PrestigeSystem._add_or_replace_bonus("harmony_god")
	PrestigeSystem._add_or_replace_bonus("resilience_god")
	PrestigeSystem._add_or_replace_bonus("explorer_god")  # Should not be added
	var ok = PrestigeSystem.active_bonuses.size() == 3
	PrestigeSystem.active_bonuses = original_bonuses
	return {"name": "bonus slots capped at 3", "passed": ok}


func _test_death_cap_bonus_with_eternal_god() -> Dictionary:
	var original = PrestigeSystem.active_bonuses.duplicate()
	PrestigeSystem.active_bonuses = ["eternal_god"]
	var bonus = PrestigeSystem.get_death_cap_bonus()
	PrestigeSystem.active_bonuses = original
	return {"name": "eternal_god gives +5 death cap bonus", "passed": bonus == 5}


func _test_cohesion_bonus_with_harmony_god() -> Dictionary:
	var original = PrestigeSystem.active_bonuses.duplicate()
	PrestigeSystem.active_bonuses = ["harmony_god"]
	var bonus = PrestigeSystem.get_cohesion_bonus()
	PrestigeSystem.active_bonuses = original
	return {"name": "harmony_god gives +20 cohesion bonus", "passed": is_equal_approx(bonus, 20.0)}
