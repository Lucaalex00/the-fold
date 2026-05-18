extends Node

const COHESION_THRESHOLDS = {
	"stable":   [60, 100],
	"tension":  [40, 60],
	"conflict": [20, 40],
	"collapse": [0,  20]
}

var cohesion: float = 100.0


func _ready() -> void:
	GameState.omino_died.connect(_on_omino_died)


func update_cohesion() -> void:
	var new_value = calculate_cohesion()
	if not is_equal_approx(new_value, cohesion):
		cohesion = new_value
		GameState.emit_signal("cohesion_changed", cohesion)


func calculate_cohesion() -> float:
	var living = GameState.get_living_omini()
	if living.is_empty():
		return 0.0

	var base = 100.0

	# Penalità warrior ratio > 50%
	var warrior_ratio = _get_trait_ratio("warrior", living)
	if warrior_ratio > 0.5:
		base -= (warrior_ratio - 0.5) * 100.0

	# Bonus stesso pianeta di origine
	var same_origin_bonus = _same_origin_ratio(living) * 20.0
	base += same_origin_bonus

	# Penalità per troppa diversità di origini (> 4)
	var unique_origins = _unique_origins(living)
	if unique_origins > 4:
		base -= float(unique_origins - 4) * 5.0

	return clampf(base, 0.0, 100.0)


func get_cohesion_state() -> String:
	for state in COHESION_THRESHOLDS.keys():
		var range_val = COHESION_THRESHOLDS[state]
		if cohesion >= range_val[0] and cohesion <= range_val[1]:
			return state
	return "collapse"


func get_war_penalty() -> float:
	# Riduce la velocità di avanzamento quando c'è conflitto
	match get_cohesion_state():
		"conflict":
			return 0.3
		"collapse":
			return 0.6
		_:
			return 0.0


func _get_trait_ratio(trait_name: String, living: Array) -> float:
	if living.is_empty():
		return 0.0
	var count = 0
	for omino in living:
		if omino.trait_primary == trait_name:
			count += 1
	return float(count) / float(living.size())


func _same_origin_ratio(living: Array) -> float:
	if living.size() <= 1:
		return 1.0
	var origin_counts = {}
	for omino in living:
		var origin = omino.origin_planet
		origin_counts[origin] = origin_counts.get(origin, 0) + 1
	var max_count = 0
	for count in origin_counts.values():
		if count > max_count:
			max_count = count
	return float(max_count) / float(living.size())


func _unique_origins(living: Array) -> int:
	var origins = {}
	for omino in living:
		origins[omino.origin_planet] = true
	return origins.size()


func _on_omino_died(_omino_data) -> void:
	update_cohesion()
