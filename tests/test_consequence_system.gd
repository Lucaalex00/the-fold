extends Node

func run_tests() -> Array:
	return [
		_test_stat_delta_all(),
		_test_stat_delta_clamps_at_cap(),
		_test_stat_delta_clamps_at_zero(),
		_test_stat_delta_random_one(),
		_test_stat_delta_warriors_only(),
		_test_stat_delta_weakest_strongest(),
		_test_invalid_stat_ignored(),
		_test_planet_hp_damage_and_regen(),
		_test_divine_energy_clamps(),
		_test_cohesion_clamps(),
		_test_kill_entity(),
		_test_nothing_type(),
		_test_multiple_effects(),
		_test_empty_effects(),
	]


# --- Helpers ---

func _make_entity(trait_name: String = "builder", stats_override: Dictionary = {}) -> GameState.EntityData:
	var e = GameState.EntityData.new()
	e.is_alive = true
	e.trait_primary = trait_name
	e.origin_planet = "test"
	for k in stats_override.keys():
		e.stats[k] = stats_override[k]
	return e


func _snapshot_state() -> Dictionary:
	return {
		"entities": GameState.entities.duplicate(),
		"divine_energy": GameState.divine_energy,
		"planet_base_hp": GameState.planet_base_hp,
		"cohesion": CultureSystem.cohesion,
		"current_era": GameState.current_era,
	}


func _restore_state(snap: Dictionary) -> void:
	GameState.entities = snap["entities"]
	GameState.divine_energy = snap["divine_energy"]
	GameState.planet_base_hp = snap["planet_base_hp"]
	CultureSystem.cohesion = snap["cohesion"]
	GameState.current_era = snap["current_era"]


# --- Tests ---

func _test_stat_delta_all() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1
	GameState.entities = [_make_entity("builder", {"research": 5}), _make_entity("warrior", {"research": 3})]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "research", "delta": 4, "scope": "all"}])
	var ok = GameState.entities[0].stats["research"] == 9 and GameState.entities[1].stats["research"] == 7
	_restore_state(snap)
	return {"name": "stat delta applies to all entities", "passed": ok}


func _test_stat_delta_clamps_at_cap() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1  # cap = 15
	GameState.entities = [_make_entity("builder", {"intelligence": 14})]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "intelligence", "delta": 50, "scope": "all"}])
	var ok = GameState.entities[0].stats["intelligence"] == 15
	_restore_state(snap)
	return {"name": "stat delta clamps to era cap", "passed": ok}


func _test_stat_delta_clamps_at_zero() -> Dictionary:
	var snap = _snapshot_state()
	GameState.entities = [_make_entity("builder", {"attack": 3})]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "attack", "delta": -100, "scope": "all"}])
	var ok = GameState.entities[0].stats["attack"] == 0
	_restore_state(snap)
	return {"name": "stat delta clamps to zero", "passed": ok}


func _test_stat_delta_random_one() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1
	GameState.entities = [_make_entity("builder", {"harvest": 5}), _make_entity("builder", {"harvest": 5})]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "harvest", "delta": 5, "scope": "random_one"}])
	var total = GameState.entities[0].stats["harvest"] + GameState.entities[1].stats["harvest"]
	# Total should be 15 (one got +5, other unchanged) — verifies exactly one was touched
	var ok = total == 15
	_restore_state(snap)
	return {"name": "stat delta on random_one touches exactly one", "passed": ok}


func _test_stat_delta_warriors_only() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1
	GameState.entities = [
		_make_entity("warrior", {"attack": 5}),
		_make_entity("builder", {"attack": 5}),
		_make_entity("warrior", {"attack": 5}),
	]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "attack", "delta": 5, "scope": "warriors"}])
	var ok = (
		GameState.entities[0].stats["attack"] == 10 and
		GameState.entities[1].stats["attack"] == 5 and
		GameState.entities[2].stats["attack"] == 10
	)
	_restore_state(snap)
	return {"name": "scope warriors targets only warriors", "passed": ok}


func _test_stat_delta_weakest_strongest() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1
	# Make distinct totals using a single stat
	GameState.entities = [
		_make_entity("builder", {"harvest": 1}),  # weakest
		_make_entity("builder", {"harvest": 10}), # strongest
	]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "research", "delta": 5, "scope": "weakest"}])
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "research", "delta": 3, "scope": "strongest"}])
	var ok = (
		GameState.entities[0].stats["research"] == 5 and
		GameState.entities[1].stats["research"] == 3
	)
	_restore_state(snap)
	return {"name": "weakest/strongest scopes target the right entity", "passed": ok}


func _test_invalid_stat_ignored() -> Dictionary:
	var snap = _snapshot_state()
	GameState.entities = [_make_entity("builder", {"health": 5})]
	ConsequenceSystem.apply_effects([{"type": "stat", "stat": "nonsense", "delta": 100, "scope": "all"}])
	var ok = GameState.entities[0].stats["health"] == 5
	_restore_state(snap)
	return {"name": "invalid stat name does nothing", "passed": ok}


func _test_planet_hp_damage_and_regen() -> Dictionary:
	var snap = _snapshot_state()
	GameState.planet_base_hp = 50.0
	ConsequenceSystem.apply_effects([{"type": "planet_hp", "delta": -20.0}])
	var after_damage = GameState.planet_base_hp == 30.0
	ConsequenceSystem.apply_effects([{"type": "planet_hp", "delta": 15.0}])
	var after_regen = GameState.planet_base_hp == 45.0
	_restore_state(snap)
	return {"name": "planet HP damage and regen both work", "passed": after_damage and after_regen}


func _test_divine_energy_clamps() -> Dictionary:
	var snap = _snapshot_state()
	GameState.divine_energy = 90.0
	GameState.divine_energy_max = 100.0
	ConsequenceSystem.apply_effects([{"type": "divine_energy", "delta": 50.0}])
	var clamped_max = GameState.divine_energy == 100.0
	ConsequenceSystem.apply_effects([{"type": "divine_energy", "delta": -200.0}])
	var clamped_min = GameState.divine_energy == 0.0
	_restore_state(snap)
	return {"name": "divine energy clamps [0, max]", "passed": clamped_max and clamped_min}


func _test_cohesion_clamps() -> Dictionary:
	var snap = _snapshot_state()
	CultureSystem.cohesion = 95.0
	ConsequenceSystem.apply_effects([{"type": "cohesion", "delta": 20.0}])
	var clamped_max = CultureSystem.cohesion == 100.0
	ConsequenceSystem.apply_effects([{"type": "cohesion", "delta": -300.0}])
	var clamped_min = CultureSystem.cohesion == 0.0
	_restore_state(snap)
	return {"name": "cohesion clamps [0, 100]", "passed": clamped_max and clamped_min}


func _test_kill_entity() -> Dictionary:
	var snap = _snapshot_state()
	GameState.entities = [
		_make_entity("builder", {"harvest": 1}),
		_make_entity("builder", {"harvest": 10}),
	]
	ConsequenceSystem.apply_effects([{"type": "kill", "count": 1, "scope": "weakest", "cause": "test"}])
	var dead_count = 0
	var weakest_dead = false
	for e in GameState.entities:
		if not e.is_alive:
			dead_count += 1
			if e.stats["harvest"] == 1:
				weakest_dead = true
	var ok = dead_count == 1 and weakest_dead
	_restore_state(snap)
	return {"name": "kill effect kills target by scope", "passed": ok}


func _test_nothing_type() -> Dictionary:
	var snap = _snapshot_state()
	GameState.entities = [_make_entity("builder", {"health": 5})]
	var before = GameState.divine_energy
	ConsequenceSystem.apply_effects([{"type": "nothing"}])
	var ok = GameState.divine_energy == before and GameState.entities[0].stats["health"] == 5
	_restore_state(snap)
	return {"name": "nothing type is a no-op", "passed": ok}


func _test_multiple_effects() -> Dictionary:
	var snap = _snapshot_state()
	GameState.current_era = 1
	GameState.entities = [_make_entity("builder", {"research": 5})]
	GameState.divine_energy = 50.0
	CultureSystem.cohesion = 50.0
	ConsequenceSystem.apply_effects([
		{"type": "stat", "stat": "research", "delta": 3, "scope": "all"},
		{"type": "divine_energy", "delta": 10.0},
		{"type": "cohesion", "delta": 5.0},
	])
	var ok = (
		GameState.entities[0].stats["research"] == 8 and
		GameState.divine_energy == 60.0 and
		CultureSystem.cohesion == 55.0
	)
	_restore_state(snap)
	return {"name": "multiple effects applied in order", "passed": ok}


func _test_empty_effects() -> Dictionary:
	var snap = _snapshot_state()
	GameState.entities = [_make_entity("builder", {"health": 5})]
	var dh = GameState.divine_energy
	ConsequenceSystem.apply_effects([])
	var ok = GameState.divine_energy == dh and GameState.entities[0].stats["health"] == 5
	_restore_state(snap)
	return {"name": "empty effects array is a no-op", "passed": ok}
