extends Node

func run_tests() -> Array:
	return [
		_test_death_probability_under_20(),
		_test_death_probability_at_20(),
		_test_death_probability_at_25(),
		_test_death_probability_at_30(),
		_test_death_probability_over_30(),
		_test_death_never_100(),
		_test_founders_created(),
		_test_founder_builder_dna(),
		_test_founder_warrior_dna(),
		_test_name_generation(),
		_test_trait_database_loaded(),
		_test_base_stats_warrior(),
		_test_era_cap_applied(),
	]


func _make_entity_node() -> Node:
	var script = load("res://scripts/entities/Entity.gd")
	var node = script.new()
	var data = GameState.EntityData.new()
	data.is_alive = true
	data.trait_primary = "warrior"
	data.stats = TraitDatabase.get_base_stats("warrior")
	node.data = data
	return node


func _test_death_probability_under_20() -> Dictionary:
	var node = _make_entity_node()
	node.data.age_years = 15
	var prob = node.calculate_death_probability(15)
	var ok = is_equal_approx(prob, 0.0)
	node.free()
	return {"name": "death probability = 0 under age 20", "passed": ok}


func _test_death_probability_at_20() -> Dictionary:
	var node = _make_entity_node()
	var prob = node.calculate_death_probability(20)
	var ok = is_equal_approx(prob, 0.0)
	node.free()
	return {"name": "death probability = 0 at age 20", "passed": ok}


func _test_death_probability_at_25() -> Dictionary:
	var node = _make_entity_node()
	var prob = node.calculate_death_probability(25)
	var ok = prob > 0.0 and prob < 0.80
	node.free()
	return {"name": "death probability between 0-80% at age 25", "passed": ok}


func _test_death_probability_at_30() -> Dictionary:
	var node = _make_entity_node()
	var prob = node.calculate_death_probability(30)
	var ok = is_equal_approx(prob, 0.80)
	node.free()
	return {"name": "death probability = 80% at age 30", "passed": ok}


func _test_death_probability_over_30() -> Dictionary:
	var node = _make_entity_node()
	var prob = node.calculate_death_probability(50)
	var ok = prob > 0.80 and prob < 1.0
	node.free()
	return {"name": "death probability > 80% over age 30", "passed": ok}


func _test_death_never_100() -> Dictionary:
	var node = _make_entity_node()
	var prob = node.calculate_death_probability(500)
	var ok = prob < 1.0
	node.free()
	return {"name": "death probability never reaches 100%", "passed": ok}


func _test_founders_created() -> Dictionary:
	var founders = EntityGenerator.create_founders("test_planet")
	var ok = founders.size() == 2
	return {"name": "create_founders returns 2 entities", "passed": ok}


func _test_founder_builder_dna() -> Dictionary:
	var founders = EntityGenerator.create_founders("test_planet")
	var builder = founders[0]
	var ok = builder.trait_primary == "builder" and \
			 builder.dna["body_shape"] == 0
	return {"name": "founder builder has correct DNA", "passed": ok}


func _test_founder_warrior_dna() -> Dictionary:
	var founders = EntityGenerator.create_founders("test_planet")
	var warrior = founders[1]
	var ok = warrior.trait_primary == "warrior" and \
			 warrior.dna["body_shape"] == 1
	return {"name": "founder warrior has correct DNA", "passed": ok}


func _test_name_generation() -> Dictionary:
	var name1 = EntityGenerator.generate_name()
	var name2 = EntityGenerator.generate_name()
	var ok = name1.length() >= 4 and name2.length() >= 4
	return {"name": "generate_name produces valid names", "passed": ok}


func _test_trait_database_loaded() -> Dictionary:
	var traits = TraitDatabase.get_all_trait_names()
	var ok = traits.size() == 8 and "warrior" in traits and "builder" in traits
	return {"name": "TraitDatabase loaded 8 traits", "passed": ok}


func _test_base_stats_warrior() -> Dictionary:
	var stats = TraitDatabase.get_base_stats("warrior")
	var ok = stats.has("attack") and stats["attack"] > 0 and \
			 stats.has("health") and stats["health"] > 0
	return {"name": "warrior base stats have attack and health", "passed": ok}


func _test_era_cap_applied() -> Dictionary:
	var original_era = GameState.current_era
	GameState.current_era = 1
	var entity = EntityGenerator.create_entity("scientist", "test")
	var cap = GameState.ERA_STAT_CAP[1]
	var ok = true
	for stat in entity.stats.values():
		if stat > cap:
			ok = false
			break
	GameState.current_era = original_era
	return {"name": "era cap applied to new entity stats", "passed": ok}
