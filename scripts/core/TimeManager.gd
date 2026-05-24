extends Node

var base_speed_per_second: float = 1.0  # light years / second (base)
var offline_multiplier: float = 0.5

var _last_timestamp: int = 0
var _last_daily_reset_date: String = ""


func _ready() -> void:
	_last_timestamp = Time.get_unix_time_from_system()
	_last_daily_reset_date = Time.get_date_string_from_system()


func _process(delta: float) -> void:
	# Distance counter — updated EVERY FRAME, never in a Timer
	GameState.distance_from_center -= _calculate_speed() * delta
	GameState.distance_from_center = maxf(GameState.distance_from_center, 0.0)
	_check_daily_reset()


func _calculate_speed() -> float:
	var speed = base_speed_per_second
	speed *= GameState.get_era_speed_multiplier()
	speed *= GameState.get_navigator_bonus()
	speed *= GameState.prestige_resource_multiplier
	return maxf(speed, base_speed_per_second * 0.1)


func _check_daily_reset() -> void:
	var today = Time.get_date_string_from_system()
	if today != _last_daily_reset_date:
		_last_daily_reset_date = today
		_perform_daily_reset()


func _perform_daily_reset() -> void:
	GameState.current_day += 1
	advance_game_year()
	WorldModifierSystem.process_daily_effects()
	_check_entity_deaths()
	GameState.regen_planet_hp(randf_range(1.0, 2.0))
	_apply_cohesion_divine_gift()
	if not WorldModifierSystem.is_active("walking_dead"):
		GameState.purge_dead_entities()
	EventManager.generate_daily_events()
	SaveManager.save_game()


func _apply_cohesion_divine_gift() -> void:
	if CultureSystem.cohesion >= GameState.DAILY_COHESION_GIFT_THRESHOLD:
		GameState.modify_divine_energy(GameState.DAILY_COHESION_GIFT_AMOUNT)


func _check_entity_deaths() -> void:
	for entity in GameState.entities:
		if not entity.is_alive:
			continue
		# Health-depleted: always lethal
		if (entity.stats.get("health", 1) as int) <= 0:
			GameState.register_entity_death(entity, "health_depleted")
			continue
		# Old age — probabilistic roll on every daily reset
		if _roll_old_age_death(entity):
			GameState.register_entity_death(entity, "old_age")


func _roll_old_age_death(entity: GameState.EntityData) -> bool:
	var prob: float = _old_age_death_probability(entity.age_years)
	if prob <= 0.0:
		return false
	return randf() < prob


func _old_age_death_probability(age_years: int) -> float:
	# Per-daily roll. GDD gives an aggregate "by age X" curve;
	# we apply it as a small per-tick probability so the chance compounds across days.
	var death_cap_bonus: int = PrestigeSystem.get_death_cap_bonus()
	var safe_age: int = 20 + death_cap_bonus
	if age_years < safe_age:
		return 0.0
	# Per-day probability ramps from ~3% at safe_age to ~15% at safe_age+10,
	# then +0.2%/year beyond that. Hard floor 0%, soft ceiling ~80%.
	var over: int = age_years - safe_age
	var base: float = 0.03 + min(float(over) / 10.0, 1.0) * 0.12
	if over > 10:
		base += float(over - 10) * 0.002
	return clampf(base, 0.0, 0.8)


func advance_game_year() -> void:
	# 1 real day = 2 game years
	for entity in GameState.entities:
		if entity.is_alive:
			entity.age_years += 2


func apply_offline_progress(seconds_offline: float) -> void:
	if seconds_offline <= 60.0:
		return
	var progress = base_speed_per_second * seconds_offline * offline_multiplier
	GameState.distance_from_center -= progress
	GameState.distance_from_center = maxf(GameState.distance_from_center, 0.0)


func calculate_offline_progress(seconds_offline: float) -> float:
	return base_speed_per_second * seconds_offline * offline_multiplier


func get_last_timestamp() -> int:
	return _last_timestamp


func update_timestamp() -> void:
	_last_timestamp = Time.get_unix_time_from_system()
