extends Node

const SAVE_PATH = "user://save.json"


func _ready() -> void:
	var loaded = load_game()
	if not loaded:
		# Prima apertura — calcola timestamp per sessioni future
		TimeManager.update_timestamp()


func save_game() -> void:
	var data = {
		"version": 1,
		"current_era": GameState.current_era,
		"current_step": GameState.current_step,
		"prestige_count": GameState.prestige_count,
		"current_day": GameState.current_day,
		"divine_energy": GameState.divine_energy,
		"divine_energy_max": GameState.divine_energy_max,
		"distance_from_center": GameState.distance_from_center,
		"prestige_resource_multiplier": GameState.prestige_resource_multiplier,
		"omini": _serialize_omini(),
		"memory_book": GameState.memory_book,
		"conflicts_won": GameState.conflicts_won,
		"avg_cohesion": GameState.avg_cohesion,
		"omini_lost": GameState.omini_lost,
		"planets_visited": GameState.planets_visited,
		"oldest_omino_age": GameState.oldest_omino_age,
		"last_save_timestamp": Time.get_unix_time_from_system()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		return false
	_apply_save_data(parsed)
	return true


func _apply_save_data(data: Dictionary) -> void:
	GameState.current_era = data.get("current_era", 1)
	GameState.current_step = data.get("current_step", 1)
	GameState.prestige_count = data.get("prestige_count", 0)
	GameState.current_day = data.get("current_day", 0)
	GameState.divine_energy = data.get("divine_energy", 100.0)
	GameState.divine_energy_max = data.get("divine_energy_max", 100.0)
	GameState.distance_from_center = data.get("distance_from_center", 1_000_000.0)
	GameState.prestige_resource_multiplier = data.get("prestige_resource_multiplier", 1.0)
	GameState.memory_book = data.get("memory_book", [])
	GameState.conflicts_won = data.get("conflicts_won", 0)
	GameState.avg_cohesion = data.get("avg_cohesion", 100.0)
	GameState.omini_lost = data.get("omini_lost", 0)
	GameState.planets_visited = data.get("planets_visited", 0)
	GameState.oldest_omino_age = data.get("oldest_omino_age", 0)

	GameState.omini.clear()
	for omino_raw in data.get("omini", []):
		GameState.omini.append(_deserialize_omino(omino_raw))

	# Applica progresso offline dai secondi trascorsi dall'ultimo salvataggio
	var last_ts = data.get("last_save_timestamp", 0)
	if last_ts > 0:
		var elapsed = Time.get_unix_time_from_system() - last_ts
		TimeManager.apply_offline_progress(float(elapsed))

	TimeManager.update_timestamp()


func save_to_memory_book(omino: GameState.OminoData) -> void:
	var entry = {
		"id": omino.id,
		"name": omino.name,
		"trait": omino.trait_primary,
		"born_day": omino.birth_day,
		"born_date_real": omino.birth_date_real,
		"death_day": GameState.current_day,
		"death_date_real": Time.get_date_string_from_system(),
		"age_years": omino.age_years,
		"stats_final": omino.stats.duplicate(),
		"generation": omino.generation,
		"children_count": omino.children.size(),
		"origin_planet": omino.origin_planet,
		"notable_events": omino.notable_events.duplicate(),
		"death_cause": omino.death_cause,
		"dna_snapshot": _serialize_dna(omino.dna),
		"prestige_run": GameState.prestige_count
	}
	GameState.memory_book.append(entry)
	save_game()


func _serialize_omini() -> Array:
	var result = []
	for omino in GameState.omini:
		result.append({
			"id": omino.id,
			"name": omino.name,
			"birth_day": omino.birth_day,
			"birth_date_real": omino.birth_date_real,
			"age_years": omino.age_years,
			"is_alive": omino.is_alive,
			"trait_primary": omino.trait_primary,
			"trait_secondary": omino.trait_secondary,
			"stats": omino.stats.duplicate(),
			"dna": _serialize_dna(omino.dna),
			"origin_planet": omino.origin_planet,
			"generation": omino.generation,
			"parents": omino.parents.duplicate(),
			"children": omino.children.duplicate(),
			"notable_events": omino.notable_events.duplicate(),
			"death_cause": omino.death_cause
		})
	return result


func _serialize_dna(dna: Dictionary) -> Dictionary:
	return {
		"body_shape": dna.get("body_shape", 0),
		"color_primary": _color_to_array(dna.get("color_primary", Color.WHITE)),
		"color_secondary": _color_to_array(dna.get("color_secondary", Color.WHITE)),
		"color_accent": _color_to_array(dna.get("color_accent", Color.WHITE)),
		"accessory_type": dna.get("accessory_type", 0),
		"size_modifier": dna.get("size_modifier", 1.0)
	}


func _color_to_array(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


func _deserialize_omino(data: Dictionary) -> GameState.OminoData:
	var omino = GameState.OminoData.new()
	omino.id = data.get("id", "")
	omino.name = data.get("name", "")
	omino.birth_day = data.get("birth_day", 0)
	omino.birth_date_real = data.get("birth_date_real", "")
	omino.age_years = data.get("age_years", 0)
	omino.is_alive = data.get("is_alive", true)
	omino.trait_primary = data.get("trait_primary", "")
	omino.trait_secondary = data.get("trait_secondary", "")
	omino.stats = data.get("stats", omino.stats.duplicate())
	omino.origin_planet = data.get("origin_planet", "")
	omino.generation = data.get("generation", 1)
	omino.parents = data.get("parents", [])
	omino.children = data.get("children", [])
	omino.notable_events = data.get("notable_events", [])
	omino.death_cause = data.get("death_cause", "")
	var dna_raw = data.get("dna", {})
	if not dna_raw.is_empty():
		omino.dna = _deserialize_dna(dna_raw)
	return omino


func _deserialize_dna(data: Dictionary) -> Dictionary:
	return {
		"body_shape": data.get("body_shape", 0),
		"color_primary": _array_to_color(data.get("color_primary", [1, 1, 1, 1])),
		"color_secondary": _array_to_color(data.get("color_secondary", [1, 1, 1, 1])),
		"color_accent": _array_to_color(data.get("color_accent", [1, 1, 1, 1])),
		"accessory_type": data.get("accessory_type", 0),
		"size_modifier": data.get("size_modifier", 1.0)
	}


func _array_to_color(arr: Array) -> Color:
	if arr.size() < 4:
		return Color.WHITE
	return Color(arr[0], arr[1], arr[2], arr[3])
