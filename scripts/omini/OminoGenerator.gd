extends Node

# Nomi procedurali — sillabe combinabili
const SYLLABLES_A = ["Ka", "Re", "Mo", "Li", "Su", "Ao", "Ve", "Da", "Ni", "Fo"]
const SYLLABLES_B = ["ran", "lis", "dor", "ven", "kal", "mis", "ten", "ral", "son", "gon"]

# DNA fondatori — fissi per lore
const FOUNDER_BUILDER = {
	"body_shape": 0,        # Cubo
	"color_primary": Color(1.0, 0.85, 0.1, 1.0),    # Giallo
	"color_secondary": Color(0.9, 0.7, 0.05, 1.0),
	"color_accent": Color(1.0, 1.0, 0.5, 1.0),
	"accessory_type": 2,
	"size_modifier": 1.0
}

const FOUNDER_WARRIOR = {
	"body_shape": 1,        # Triangolo
	"color_primary": Color(0.85, 0.1, 0.1, 1.0),    # Rosso
	"color_secondary": Color(0.6, 0.05, 0.05, 1.0),
	"color_accent": Color(1.0, 0.4, 0.4, 1.0),
	"accessory_type": 0,
	"size_modifier": 1.05
}


func create_founders(origin_planet: String) -> Array:
	var builder = _create_founder("builder", FOUNDER_BUILDER, origin_planet)
	var warrior = _create_founder("warrior", FOUNDER_WARRIOR, origin_planet)
	return [builder, warrior]


func _create_founder(trait_name: String, dna: Dictionary, origin_planet: String) -> GameState.OminoData:
	var omino = GameState.OminoData.new()
	omino.id = _generate_uuid()
	omino.name = generate_name()
	omino.birth_day = GameState.current_day
	omino.birth_date_real = Time.get_date_string_from_system()
	omino.age_years = 0
	omino.is_alive = true
	omino.trait_primary = trait_name
	omino.trait_secondary = ""
	omino.dna = dna.duplicate(true)
	omino.origin_planet = origin_planet
	omino.generation = 1
	omino.stats = TraitDatabase.get_base_stats(trait_name)
	_apply_era_cap(omino)
	return omino


func create_omino(trait_name: String, origin_planet: String) -> GameState.OminoData:
	var omino = GameState.OminoData.new()
	omino.id = _generate_uuid()
	omino.name = generate_name()
	omino.birth_day = GameState.current_day
	omino.birth_date_real = Time.get_date_string_from_system()
	omino.age_years = 0
	omino.is_alive = true
	omino.trait_primary = trait_name
	omino.trait_secondary = ""
	omino.dna = generate_random_dna()
	omino.origin_planet = origin_planet
	omino.generation = 1
	omino.stats = TraitDatabase.get_base_stats(trait_name)
	_apply_era_cap(omino)
	return omino


func generate_random_dna() -> Dictionary:
	return {
		"body_shape": randi() % 8,
		"color_primary": Color(randf(), randf(), randf(), 1.0),
		"color_secondary": Color(randf(), randf(), randf(), 1.0),
		"color_accent": Color(randf(), randf(), randf(), 1.0),
		"accessory_type": randi() % 16,
		"size_modifier": randf_range(0.8, 1.2)
	}


func generate_name() -> String:
	var a = SYLLABLES_A[randi() % SYLLABLES_A.size()]
	var b = SYLLABLES_B[randi() % SYLLABLES_B.size()]
	return a + b


func _apply_era_cap(omino: GameState.OminoData) -> void:
	var cap = GameState.get_stat_cap()
	for stat in omino.stats.keys():
		omino.stats[stat] = mini(omino.stats[stat], cap)


func _generate_uuid() -> String:
	# UUID v4 semplificato
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%04x-4%03x-%04x-%012x" % [
		rng.randi(),
		rng.randi() % 0xFFFF,
		rng.randi() % 0xFFF,
		(rng.randi() % 0x3FFF) | 0x8000,
		rng.randi() * rng.randi() & 0xFFFFFFFFFFFF
	]
