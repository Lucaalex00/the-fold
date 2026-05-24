extends Node

var base_speed_per_second: float = 1.0  # light years / second (base)
var offline_multiplier: float = 0.5

# --- Event ticks (decoupled from daily reset) ---
# Online: an event check fires every EVENT_TICK_HOURS hours.
# Offline: missed ticks are folded into AT MOST MAX_OFFLINE_BURST_TICKS catch-ups
# so a player coming back after weeks isn't flooded with events.
# The clock advances on the 6-hour grid so the next tick stays aligned regardless
# of whether the player opens the app every 5h, every 30 minutes, or after a month.
const EVENT_TICK_HOURS: float = 6.0
const MAX_OFFLINE_BURST_TICKS: int = 1

var _last_timestamp: int = 0
var _last_daily_reset_date: String = ""
var _last_event_check_ts: int = 0


func _ready() -> void:
	_last_timestamp = Time.get_unix_time_from_system()
	_last_daily_reset_date = Time.get_date_string_from_system()
	if _last_event_check_ts == 0:
		_last_event_check_ts = _last_timestamp


func _process(delta: float) -> void:
	# Distance counter — updated EVERY FRAME, never in a Timer
	GameState.distance_from_center -= _calculate_speed() * delta
	GameState.distance_from_center = maxf(GameState.distance_from_center, 0.0)
	_check_daily_reset()
	_check_event_tick()


# --- Event ticks ---

func _check_event_tick() -> void:
	var now: int = Time.get_unix_time_from_system()
	var elapsed_h: float = float(now - _last_event_check_ts) / 3600.0
	if elapsed_h >= EVENT_TICK_HOURS:
		_last_event_check_ts = now
		_fire_event_tick()


func _fire_event_tick() -> void:
	# One generation pass: events.json triggers + cooldowns + frequency
	# all already handle the rest.
	EventManager.generate_social_events()
	if EventManager.active_cosmic_event == null:
		EventManager._maybe_generate_cosmic_event()


# Called from SaveManager on load. Counts how many full tick windows elapsed
# since the previous check (including offline time) and fires up to
# MAX_OFFLINE_BURST_TICKS catch-up ticks. The clock advances to the EXACT
# multiple of the tick interval so the next tick fires at the right grid moment.
#
# Examples (EVENT_TICK_HOURS=6, MAX_OFFLINE_BURST_TICKS=1):
#   open every 5h → on each open, elapsed accumulates; once it crosses 6h,
#     1 catch-up tick fires and _last_event_check_ts advances by exactly 6h.
#     Next tick due 1h later → fires while the player is online.
#   absent 30 days → on resume, elapsed=720h, missed=120, fires 1 (capped),
#     clock skips to today so the player isn't drowned.
func consolidate_offline_event_ticks() -> void:
	var now: int = Time.get_unix_time_from_system()
	var elapsed_s: int = now - _last_event_check_ts
	if elapsed_s < int(EVENT_TICK_HOURS * 3600.0):
		return
	var missed_ticks: int = int(float(elapsed_s) / (EVENT_TICK_HOURS * 3600.0))
	var to_fire: int = mini(missed_ticks, MAX_OFFLINE_BURST_TICKS)
	for i in range(to_fire):
		_fire_event_tick()
	# Advance the clock by the full elapsed grid windows (NOT capped to to_fire),
	# so we don't re-trigger the same missed window on the next open.
	_last_event_check_ts += missed_ticks * int(EVENT_TICK_HOURS * 3600.0)


func get_last_event_check_ts() -> int:
	return _last_event_check_ts


func set_last_event_check_ts(ts: int) -> void:
	_last_event_check_ts = ts


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
	# Events are driven by 6-hour ticks now, not the daily reset.
	# (See _check_event_tick + consolidate_offline_event_ticks.)
	# We still run one expire-old-events pass to clear stale stuff.
	EventManager._expire_old_events()
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
