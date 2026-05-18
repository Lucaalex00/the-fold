extends Node

# Core signals
signal entity_died(entity_data)
signal era_changed(new_era: int)
signal prestige_triggered(count: int)
signal cohesion_changed(new_value: float)

# Balance constants
const ERA_ENTITY_LIMIT = {1: 4, 2: 8, 3: 15, 4: 30, 5: 50}
const ERA_STAT_CAP = {1: 15, 2: 25, 3: 40, 4: 60, 5: 100}

# Progress state
var current_era: int = 1
var current_step: int = 1
var prestige_count: int = 0
var current_day: int = 0

# Divine energy
var divine_energy: float = 100.0
var divine_energy_max: float = 100.0
var divine_energy_regen_per_hour: float = 5.0

# Universe counter
var distance_from_center: float = 1_000_000.0

# Prestige multipliers (cumulative, never reset)
var prestige_resource_multiplier: float = 1.0

# Active civilization
var entities: Array = []

# Permanent memory (never deleted, not even on prestige)
var memory_book: Array = []

# Current run metrics (for prestige bonus 2 calculation)
var conflicts_won: int = 0
var avg_cohesion: float = 100.0
var entities_lost: int = 0
var planets_visited: int = 0
var oldest_entity_age: int = 0


class EntityData:
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


# --- Civilization queries ---

func get_era_speed_multiplier() -> float:
	return 1.0 + (current_era - 1) * 0.3


func get_navigator_bonus() -> float:
	var count = 0
	for entity in entities:
		if entity.is_alive and entity.trait_primary == "explorer":
			count += 1
	return 1.0 + count * 0.05


func get_entity_limit() -> int:
	return ERA_ENTITY_LIMIT.get(current_era, 4)


func get_stat_cap() -> int:
	return ERA_STAT_CAP.get(current_era, 15)


func get_living_entities() -> Array:
	return entities.filter(func(o): return o.is_alive)


# --- Era / step progression ---

func advance_step() -> void:
	current_step += 1
	if current_step > current_era * 10:
		_advance_era()


func _advance_era() -> void:
	if current_era < 5:
		current_era += 1
		emit_signal("era_changed", current_era)


# --- Entity management ---

func register_entity_death(entity: EntityData, cause: String) -> void:
	entity.is_alive = false
	entity.death_cause = cause
	entities_lost += 1
	if entity.age_years > oldest_entity_age:
		oldest_entity_age = entity.age_years
	emit_signal("entity_died", entity)


# --- Divine energy management ---

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


# --- Reset run (does NOT touch memory_book or prestige) ---

func reset_run() -> void:
	current_era = 1
	current_step = 1
	current_day = 0
	divine_energy = divine_energy_max
	distance_from_center = 1_000_000.0
	entities.clear()
	conflicts_won = 0
	avg_cohesion = 100.0
	entities_lost = 0
	planets_visited = 0
	oldest_entity_age = 0
