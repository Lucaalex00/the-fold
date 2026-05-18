extends Node

# Segnali core
signal omino_died(omino_data)
signal era_changed(new_era: int)
signal prestige_triggered(count: int)
signal cohesion_changed(new_value: float)

# Costanti di bilanciamento
const ERA_OMINI_LIMIT = {1: 4, 2: 8, 3: 15, 4: 30, 5: 50}
const ERA_STAT_CAP = {1: 15, 2: 25, 3: 40, 4: 60, 5: 100}

# Stato progresso
var current_era: int = 1
var current_step: int = 1
var prestige_count: int = 0
var current_day: int = 0

# Energia divina
var divine_energy: float = 100.0
var divine_energy_max: float = 100.0
var divine_energy_regen_per_hour: float = 5.0

# Counter universo
var distance_from_center: float = 1_000_000.0

# Moltiplicatori prestige (cumulativi, non si resettano)
var prestige_resource_multiplier: float = 1.0

# Civiltà attiva
var omini: Array = []

# Memoria permanente (non si cancella mai, neanche col prestige)
var memory_book: Array = []

# Metriche run corrente (per calcolo bonus prestige 2)
var conflicts_won: int = 0
var avg_cohesion: float = 100.0
var omini_lost: int = 0
var planets_visited: int = 0
var oldest_omino_age: int = 0


class OminoData:
	var id: String = ""
	var name: String = ""
	var birth_day: int = 0
	var birth_date_real: String = ""
	var age_years: int = 0
	var is_alive: bool = true

	var trait_primary: String = ""
	var trait_secondary: String = ""

	var stats: Dictionary = {
		"health": 0,
		"energy": 0,
		"intelligence": 0,
		"attack": 0,
		"construction": 0,
		"harvest": 0,
		"fishing": 0,
		"research": 0,
		"diplomacy": 0
	}

	var dna: Dictionary = {
		"body_shape": 0,
		"color_primary": Color.WHITE,
		"color_secondary": Color.WHITE,
		"color_accent": Color.WHITE,
		"accessory_type": 0,
		"size_modifier": 1.0
	}

	var origin_planet: String = ""
	var generation: int = 1
	var parents: Array = []
	var children: Array = []
	var notable_events: Array = []
	var death_cause: String = ""


func _ready() -> void:
	_init_divine_energy_regen()


func _init_divine_energy_regen() -> void:
	var timer = Timer.new()
	timer.wait_time = 3600.0
	timer.autostart = true
	timer.timeout.connect(_on_energy_regen_tick)
	add_child(timer)


func _on_energy_regen_tick() -> void:
	divine_energy = min(divine_energy + divine_energy_regen_per_hour, divine_energy_max)


# --- Query stato civiltà ---

func get_era_speed_multiplier() -> float:
	return 1.0 + (current_era - 1) * 0.3


func get_omini_navigator_bonus() -> float:
	var count = 0
	for omino in omini:
		if omino.is_alive and omino.trait_primary == "explorer":
			count += 1
	return 1.0 + count * 0.05


func get_omini_limit() -> int:
	return ERA_OMINI_LIMIT.get(current_era, 4)


func get_stat_cap() -> int:
	return ERA_STAT_CAP.get(current_era, 15)


func get_living_omini() -> Array:
	return omini.filter(func(o): return o.is_alive)


# --- Avanzamento era/step ---

func advance_step() -> void:
	current_step += 1
	if current_step > current_era * 10:
		_advance_era()


func _advance_era() -> void:
	if current_era < 5:
		current_era += 1
		emit_signal("era_changed", current_era)


# --- Gestione omini ---

func register_omino_death(omino: OminoData, cause: String) -> void:
	omino.is_alive = false
	omino.death_cause = cause
	omini_lost += 1
	if omino.age_years > oldest_omino_age:
		oldest_omino_age = omino.age_years
	emit_signal("omino_died", omino)


# --- Gestione energia divina ---

func spend_divine_energy(amount: float) -> bool:
	if divine_energy < amount:
		return false
	divine_energy -= amount
	return true


# --- Prestige ---

func calculate_prestige_resource_multiplier() -> float:
	if prestige_count <= 5:
		return pow(1.5, prestige_count)
	else:
		return pow(1.5, 5) * pow(1.15, prestige_count - 5)


func apply_prestige_multiplier() -> void:
	prestige_resource_multiplier = calculate_prestige_resource_multiplier()


# --- Reset run (non tocca memory_book né prestige) ---

func reset_run() -> void:
	current_era = 1
	current_step = 1
	current_day = 0
	divine_energy = divine_energy_max
	distance_from_center = 1_000_000.0
	omini.clear()
	conflicts_won = 0
	avg_cohesion = 100.0
	omini_lost = 0
	planets_visited = 0
	oldest_omino_age = 0
