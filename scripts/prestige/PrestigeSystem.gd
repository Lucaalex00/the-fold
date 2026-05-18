extends Node

signal prestige_sequence_started
signal prestige_sequence_finished
signal god_message_ready(message: String)
signal bonus_assigned(bonus_name: String, bonus_key: String)

# Bonus slot cap: 3 from prestige 3 onward
const MAX_BONUS_SLOTS = 3

var active_bonuses: Array = []   # Array of bonus keys (persistent across runs)
var _pending_bonus_2_key: String = ""


func can_trigger_prestige() -> bool:
	return GameState.current_era >= 5 and GameState.distance_from_center <= 0.0


func enter_black_hole() -> void:
	emit_signal("prestige_sequence_started")
	var metrics = _analyze_run_metrics()
	var god_msg = _get_god_message()
	emit_signal("god_message_ready", god_msg)
	_assign_prestige_bonuses(metrics)
	_save_run_to_memory_book(metrics)
	GameState.prestige_count += 1
	GameState.apply_prestige_multiplier()
	emit_signal("prestige_sequence_finished")


func _analyze_run_metrics() -> Dictionary:
	return {
		"conflicts_won": GameState.conflicts_won,
		"avg_cohesion": GameState.avg_cohesion,
		"entities_lost": GameState.entities_lost,
		"planets_visited": GameState.planets_visited,
		"oldest_entity_age": GameState.oldest_entity_age,
		"prestige_count": GameState.prestige_count
	}


func _get_god_message() -> String:
	var p = GameState.prestige_count + 1  # count after this prestige
	match p:
		1: return L.tr("PRESTIGE_MSG_1")
		2: return L.tr("PRESTIGE_MSG_2")
		3: return L.tr("PRESTIGE_MSG_3")
		4: return L.tr("PRESTIGE_MSG_4")
		5: return L.tr("PRESTIGE_MSG_5")
		_: return L.tr("PRESTIGE_MSG_DEFAULT")


func _assign_prestige_bonuses(metrics: Dictionary) -> void:
	# Bonus 1: fixed resource multiplier (always assigned)
	_add_or_replace_bonus("resource_multiplier")

	# Bonus 2: dynamic based on run behavior
	_pending_bonus_2_key = _determine_bonus_2(metrics)
	if _pending_bonus_2_key != "":
		_add_or_replace_bonus(_pending_bonus_2_key)
		emit_signal("bonus_assigned", L.tr("PRESTIGE_BONUS_" + _pending_bonus_2_key.to_upper()), _pending_bonus_2_key)


func _determine_bonus_2(metrics: Dictionary) -> String:
	if metrics["conflicts_won"] > 10:
		return "war_god"
	if metrics["avg_cohesion"] > 75.0:
		return "harmony_god"
	if metrics["entities_lost"] > 15:
		return "resilience_god"
	if metrics["planets_visited"] > 5:
		return "explorer_god"
	if metrics["oldest_entity_age"] > 60:
		return "eternal_god"
	return ""


func _add_or_replace_bonus(bonus_key: String) -> void:
	if active_bonuses.has(bonus_key):
		return
	if active_bonuses.size() < MAX_BONUS_SLOTS:
		active_bonuses.append(bonus_key)
	# From prestige 4+: player chooses which slot to replace (handled by UI)


func apply_bonus_effects() -> void:
	for bonus in active_bonuses:
		_apply_bonus(bonus)


func _apply_bonus(bonus_key: String) -> void:
	match bonus_key:
		"war_god":
			# +3 attack for founders — applied at run start
			pass
		"harmony_god":
			# -20 cultural tension base
			pass
		"resilience_god":
			# Free lifeboat once per run
			pass
		"explorer_god":
			# +50% exploration radius
			pass
		"eternal_god":
			# +5 years to death cap
			pass


func get_death_cap_bonus() -> int:
	if active_bonuses.has("eternal_god"):
		return 5
	return 0


func get_cohesion_bonus() -> float:
	if active_bonuses.has("harmony_god"):
		return 20.0
	return 0.0


func get_founder_attack_bonus() -> int:
	if active_bonuses.has("war_god"):
		return 3
	return 0


func _save_run_to_memory_book(metrics: Dictionary) -> void:
	var entry = {
		"type": "prestige_run",
		"prestige_number": GameState.prestige_count + 1,
		"date": Time.get_date_string_from_system(),
		"era_reached": GameState.current_era,
		"omini_total": GameState.entities.size(),
		"memory_book_entries": GameState.memory_book.size(),
		"metrics": metrics,
		"bonus_2": _pending_bonus_2_key,
		"god_message": _get_god_message()
	}
	GameState.memory_book.append(entry)


func complete_prestige_reset() -> void:
	GameState.reset_run()
	SaveManager.save_game()
