extends Node

func run_tests() -> Array:
	return [
		_test_child_generation_increments(),
		_test_child_stats_are_70_percent(),
		_test_child_intelligence_bonus(),
		_test_child_parents_recorded(),
		_test_child_era_cap(),
		_test_child_dna_is_mix(),
		_test_dominant_trait_from_higher_score(),
		_test_secondary_trait_only_from_era_2(),
	]


func _make_parent(trait_name: String, gen: int) -> GameState.OminoData:
	var o = GameState.OminoData.new()
	o.id = "test_" + trait_name + "_" + str(gen)
	o.trait_primary = trait_name
	o.generation = gen
	o.stats = TraitDatabase.get_base_stats(trait_name)
	o.dna = OminoGenerator.generate_random_dna()
	o.origin_planet = "test_planet"
	return o


func _test_child_generation_increments() -> Dictionary:
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("builder", 2)
	var child = GeneticSystem.generate_child(pa, pb, "test_planet")
	var ok = child.generation == 3
	return {"name": "child generation = max(parents) + 1", "passed": ok}


func _test_child_stats_are_70_percent() -> Dictionary:
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("warrior", 1)
	# Force known values
	pa.stats["attack"] = 10
	pb.stats["attack"] = 10
	var child = GeneticSystem.generate_child(pa, pb, "test")
	# Expected: round(10 * 0.70) = 7, then intelligence bonus applied
	var ok = child.stats["attack"] == 7
	return {"name": "child attack = 70% parent average", "passed": ok}


func _test_child_intelligence_bonus() -> Dictionary:
	var pa = _make_parent("scientist", 4)
	var pb = _make_parent("scientist", 4)
	pa.stats["intelligence"] = 10
	pb.stats["intelligence"] = 10
	var child = GeneticSystem.generate_child(pa, pb, "test")
	# gen=5, bonus=5*0.05=0.25, base=round(10*0.70)=7, boosted=round(7*1.25)=9
	var ok = child.stats["intelligence"] > 7
	return {"name": "intelligence boosted by generation bonus", "passed": ok}


func _test_child_parents_recorded() -> Dictionary:
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("builder", 1)
	var child = GeneticSystem.generate_child(pa, pb, "test")
	var ok = child.parents.has(pa.id) and child.parents.has(pb.id)
	return {"name": "child.parents contains both parent IDs", "passed": ok}


func _test_child_era_cap() -> Dictionary:
	var original_era = GameState.current_era
	GameState.current_era = 1
	var pa = _make_parent("scientist", 1)
	var pb = _make_parent("scientist", 1)
	# Inflate stats above cap
	for stat in pa.stats.keys():
		pa.stats[stat] = 99
		pb.stats[stat] = 99
	var child = GeneticSystem.generate_child(pa, pb, "test")
	var cap = GameState.ERA_STAT_CAP[1]
	var ok = true
	for stat in child.stats.values():
		if stat > cap:
			ok = false
	GameState.current_era = original_era
	return {"name": "child stats capped at era limit", "passed": ok}


func _test_child_dna_is_mix() -> Dictionary:
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("builder", 1)
	pa.dna["body_shape"] = 0
	pb.dna["body_shape"] = 4
	var child = GeneticSystem.generate_child(pa, pb, "test")
	var ok = child.dna.has("body_shape") and \
			 child.dna.has("color_primary") and \
			 child.dna["size_modifier"] >= 0.8 and \
			 child.dna["size_modifier"] <= 1.2
	return {"name": "child DNA has valid structure and size_modifier", "passed": ok}


func _test_dominant_trait_from_higher_score() -> Dictionary:
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("builder", 1)
	# Give warrior much higher total stats
	for stat in pa.stats.keys():
		pa.stats[stat] = 20
	for stat in pb.stats.keys():
		pb.stats[stat] = 5
	var child = GeneticSystem.generate_child(pa, pb, "test")
	var ok = child.trait_primary == "warrior"
	return {"name": "dominant trait from parent with higher total stats", "passed": ok}


func _test_secondary_trait_only_from_era_2() -> Dictionary:
	var original_era = GameState.current_era
	var pa = _make_parent("warrior", 1)
	var pb = _make_parent("builder", 1)

	GameState.current_era = 1
	var child_era1 = GeneticSystem.generate_child(pa, pb, "test")
	var ok_era1 = child_era1.trait_secondary == ""

	GameState.current_era = 2
	var child_era2 = GeneticSystem.generate_child(pa, pb, "test")
	var ok_era2 = child_era2.trait_secondary != ""

	GameState.current_era = original_era
	return {
		"name": "secondary trait empty in era 1, set in era 2+",
		"passed": ok_era1 and ok_era2
	}
