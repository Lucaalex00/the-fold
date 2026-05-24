extends Node

const SAVE_PATH = "user://save.json"


func _ready() -> void:
	var loaded = load_game()
	if not loaded:
		# First launch — store timestamp for future sessions
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
		"entities": _serialize_entities(),
		"memory_book": GameState.memory_book,
		"conflicts_won": GameState.conflicts_won,
		"avg_cohesion": GameState.avg_cohesion,
		"entities_lost": GameState.entities_lost,
		"planets_visited": GameState.planets_visited,
		"oldest_entity_age": GameState.oldest_entity_age,
		"active_modifiers": WorldModifierSystem.serialize(),
		"last_save_timestamp": Time.get_unix_time_from_system(),
		"last_event_check_ts": TimeManager.get_last_event_check_ts(),
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
	GameState.entities_lost = data.get("entities_lost", 0)
	GameState.planets_visited = data.get("planets_visited", 0)
	GameState.oldest_entity_age = data.get("oldest_entity_age", 0)

	GameState.entities.clear()
	for entity_raw in data.get("entities", []):
		GameState.entities.append(_deserialize_entity(entity_raw))

	WorldModifierSystem.deserialize(data.get("active_modifiers", []))

	# Apply offline progress from seconds elapsed since last save
	var last_ts = data.get("last_save_timestamp", 0)
	if last_ts > 0:
		var elapsed = Time.get_unix_time_from_system() - last_ts
		TimeManager.apply_offline_progress(float(elapsed))

	# Restore event-tick clock and consolidate any missed offline ticks
	var last_evt_ts: int = int(data.get("last_event_check_ts", 0))
	if last_evt_ts > 0:
		TimeManager.set_last_event_check_ts(last_evt_ts)
	TimeManager.consolidate_offline_event_ticks()

	TimeManager.update_timestamp()


func save_to_memory_book(entity: GameState.EntityData) -> void:
	var entry = {
		"id": entity.id,
		"name": entity.name,
		"trait": entity.trait_primary,
		"born_day": entity.birth_day,
		"born_date_real": entity.birth_date_real,
		"death_day": GameState.current_day,
		"death_date_real": Time.get_date_string_from_system(),
		"age_years": entity.age_years,
		"stats_final": entity.stats.duplicate(),
		"generation": entity.generation,
		"children_count": entity.children.size(),
		"origin_planet": entity.origin_planet,
		"notable_events": entity.notable_events.duplicate(),
		"death_cause": entity.death_cause,
		"dna_snapshot": _serialize_dna(entity.dna),
		"prestige_run": GameState.prestige_count
	}
	GameState.memory_book.append(entry)
	save_game()


func _serialize_entities() -> Array:
	var result = []
	for entity in GameState.entities:
		result.append({
			"id": entity.id,
			"name": entity.name,
			"birth_day": entity.birth_day,
			"birth_date_real": entity.birth_date_real,
			"age_years": entity.age_years,
			"is_alive": entity.is_alive,
			"trait_primary": entity.trait_primary,
			"trait_secondary": entity.trait_secondary,
			"stats": entity.stats.duplicate(),
			"dna": _serialize_dna(entity.dna),
			"origin_planet": entity.origin_planet,
			"generation": entity.generation,
			"parents": entity.parents.duplicate(),
			"children": entity.children.duplicate(),
			"notable_events": entity.notable_events.duplicate(),
			"death_cause": entity.death_cause,
			"layer": entity.layer
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


func _deserialize_entity(data: Dictionary) -> GameState.EntityData:
	var entity = GameState.EntityData.new()
	entity.id = data.get("id", "")
	entity.name = data.get("name", "")
	entity.birth_day = data.get("birth_day", 0)
	entity.birth_date_real = data.get("birth_date_real", "")
	entity.age_years = data.get("age_years", 0)
	entity.is_alive = data.get("is_alive", true)
	entity.trait_primary = data.get("trait_primary", "")
	entity.trait_secondary = data.get("trait_secondary", "")
	entity.stats = data.get("stats", entity.stats.duplicate())
	entity.origin_planet = data.get("origin_planet", "")
	entity.generation = data.get("generation", 1)
	entity.parents = data.get("parents", [])
	entity.children = data.get("children", [])
	entity.notable_events = data.get("notable_events", [])
	entity.death_cause = data.get("death_cause", "")
	entity.layer = data.get("layer", 0)
	var dna_raw = data.get("dna", {})
	if not dna_raw.is_empty():
		entity.dna = _deserialize_dna(dna_raw)
	return entity


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
