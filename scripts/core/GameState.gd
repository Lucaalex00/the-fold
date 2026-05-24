extends Node

# Core signals
signal entity_died(entity_data)
signal entities_purged
signal era_changed(new_era: int)
signal prestige_triggered(count: int)
signal cohesion_changed(new_value: float)
signal planet_collapsed
signal blackhole_reached

# Balance constants
const ERA_ENTITY_LIMIT = {1: 4, 2: 8, 3: 15, 4: 30, 5: 50}
const ERA_STAT_CAP = {1: 15, 2: 25, 3: 40, 4: 60, 5: 100}

# Progress state
var current_era: int = 1
var current_step: int = 1
var prestige_count: int = 0
var current_day: int = 0

# Divine energy
const DIVINE_ENERGY_BASE_MAX: float = 100.0
const DIVINE_ENERGY_ERA_INCREMENT: float = 50.0
const DAILY_COHESION_GIFT_THRESHOLD: float = 70.0
const DAILY_COHESION_GIFT_AMOUNT: float = 10.0
signal divine_energy_changed(new_value: float, new_max: float)

var divine_energy: float = 50.0
var divine_energy_max: float = DIVINE_ENERGY_BASE_MAX

# Universe counter
var distance_from_center: float = 1_000_000.0

# Background — random per session, set once on launch
var session_background_index: int = -1

# Planet rotation — which layer faces the cosmos (advances every 4h)
var facing_layer: int = 0
var last_planet_rotate_time: int = 0

# Planet HP — base component (regens); entity health is added on top
var planet_base_hp: float = 100.0
const PLANET_BASE_HP_MAX: float = 100.0

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
# Last cause of death registered (used by REBORN screen)
var last_death_cause: String = ""


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
	var layer: int = 0
	var parents: Array = []
	var children: Array = []
	var notable_events: Array = []
	var death_cause: String = ""


func _ready() -> void:
	_update_divine_energy_max_for_era()


# --- Divine Energy ---

func _update_divine_energy_max_for_era() -> void:
	divine_energy_max = DIVINE_ENERGY_BASE_MAX + float(current_era - 1) * DIVINE_ENERGY_ERA_INCREMENT
	divine_energy = minf(divine_energy, divine_energy_max)
	divine_energy_changed.emit(divine_energy, divine_energy_max)


func modify_divine_energy(delta: float) -> void:
	var new_value: float = clampf(divine_energy + delta, 0.0, divine_energy_max)
	if not is_equal_approx(new_value, divine_energy):
		divine_energy = new_value
		divine_energy_changed.emit(divine_energy, divine_energy_max)


func can_afford_divine_energy(amount: float) -> bool:
	return divine_energy >= amount


# --- Planet HP ---

func get_planet_hp() -> float:
	var entity_health := 0.0
	for e in get_living_entities():
		entity_health += float(e.stats.get("health", 0))
	return planet_base_hp + entity_health


func get_planet_hp_max() -> float:
	var cap := float(ERA_STAT_CAP.get(current_era, 15))
	return PLANET_BASE_HP_MAX + cap * float(get_living_entities().size())


func get_planet_hp_ratio() -> float:
	var max_hp := get_planet_hp_max()
	if max_hp <= 0.0:
		return 1.0
	return clamp(get_planet_hp() / max_hp, 0.0, 1.0)


func purge_dead_entities() -> void:
	entities = entities.filter(func(e: EntityData): return e.is_alive)
	entities_purged.emit()


func damage_planet(amount: float) -> void:
	planet_base_hp = maxf(planet_base_hp - amount, 0.0)
	_check_collapse()


func regen_planet_hp(amount: float) -> void:
	planet_base_hp = minf(planet_base_hp + amount, PLANET_BASE_HP_MAX)


func is_collapsed() -> bool:
	return get_planet_hp() <= 0.0 or get_living_entities().is_empty()


func _check_collapse() -> void:
	if is_collapsed():
		planet_collapsed.emit()


# --- Black Hole proximity ---

const BLACKHOLE_VISIBLE_DISTANCE: float = 100_000.0
const BLACKHOLE_REACHED_DISTANCE: float = 0.0


func is_blackhole_visible() -> bool:
	return distance_from_center <= BLACKHOLE_VISIBLE_DISTANCE


func get_blackhole_proximity_ratio() -> float:
	# 0.0 = just appeared (at VISIBLE_DISTANCE), 1.0 = at the center
	if distance_from_center >= BLACKHOLE_VISIBLE_DISTANCE:
		return 0.0
	if distance_from_center <= BLACKHOLE_REACHED_DISTANCE:
		return 1.0
	return 1.0 - (distance_from_center / BLACKHOLE_VISIBLE_DISTANCE)


func is_blackhole_reached() -> bool:
	return distance_from_center <= BLACKHOLE_REACHED_DISTANCE


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
		_update_divine_energy_max_for_era()
		emit_signal("era_changed", current_era)


# --- Entity management ---

func register_entity_death(entity: EntityData, cause: String) -> void:
	entity.is_alive = false
	entity.death_cause = cause
	last_death_cause = cause
	entities_lost += 1
	if entity.age_years > oldest_entity_age:
		oldest_entity_age = entity.age_years
	emit_signal("entity_died", entity)
	_check_collapse()


# --- Divine energy management ---

func spend_divine_energy(amount: float) -> bool:
	if not can_afford_divine_energy(amount):
		return false
	modify_divine_energy(-amount)
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
	_update_divine_energy_max_for_era()
	divine_energy = divine_energy_max * 0.5  # Start at half max
	divine_energy_changed.emit(divine_energy, divine_energy_max)
	distance_from_center = 1_000_000.0
	entities.clear()
	planet_base_hp = PLANET_BASE_HP_MAX
	conflicts_won = 0
	avg_cohesion = 100.0
	entities_lost = 0
	planets_visited = 0
	oldest_entity_age = 0
	last_death_cause = ""
