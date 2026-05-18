extends Node2D

var planet_id: String = ""
var planet_name: String = ""
var sprite_index: int = 0
var bot_era: int = 1
var bot_step: int = 1
var bot_distance: float = 1_000_000.0

# Bots advance very slowly — fraction of player speed
const BOT_SPEED_MULTIPLIER = 0.05

var _advance_timer: float = 0.0
const BOT_ADVANCE_INTERVAL = 600.0  # advance every 10 min real time


func setup(p_id: String, p_name: String, p_sprite: int) -> void:
	planet_id = p_id
	planet_name = p_name
	sprite_index = p_sprite
	# Scatter bots at different starting distances
	bot_distance = randf_range(800_000.0, 1_000_000.0)


func _process(delta: float) -> void:
	bot_distance -= _calculate_bot_speed() * delta
	bot_distance = maxf(bot_distance, 0.0)

	_advance_timer += delta
	if _advance_timer >= BOT_ADVANCE_INTERVAL:
		_advance_timer = 0.0
		_maybe_advance_bot_step()


func _calculate_bot_speed() -> float:
	return TimeManager.base_speed_per_second * BOT_SPEED_MULTIPLIER * (1.0 + (bot_era - 1) * 0.1)


func _maybe_advance_bot_step() -> void:
	if randf() < 0.3:
		bot_step += 1
		if bot_step > bot_era * 10 and bot_era < 5:
			bot_era += 1
			bot_step = 1


func get_progress_pct() -> float:
	return 1.0 - (bot_distance / 1_000_000.0)
