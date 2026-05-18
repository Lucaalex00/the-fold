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
	EventManager.generate_daily_events()
	SaveManager.save_game()


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
