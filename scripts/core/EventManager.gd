extends Node

enum EventUrgency { MANAGEABLE, URGENT, CRITICAL }

const MAX_SOCIAL_EVENTS = 3

var active_social_events: Array = []
var active_cosmic_event = null

var _events_data: Dictionary = {}
var _cosmic_data: Dictionary = {}


class GameEvent:
	var id: String = ""
	var type: String = ""        # "social" | "cosmic" | "resource"
	var urgency: int = 0         # EventUrgency value
	var title: String = ""
	var description: String = ""
	var expires_in_hours: float = 24.0
	var choices: Array = []
	var triggered_by: String = ""
	var created_at: int = 0


func _ready() -> void:
	_load_event_data()


func _load_event_data() -> void:
	var file = FileAccess.open("res://data/events.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			_events_data = parsed


# --- Event generation ---

func generate_daily_events() -> void:
	_expire_old_events()
	generate_social_events()
	if active_cosmic_event == null:
		_maybe_generate_cosmic_event()


func generate_social_events() -> void:
	if active_social_events.size() >= MAX_SOCIAL_EVENTS:
		return

	# Events emerge from the real state of the civilization
	# Access CultureSystem and ResourceSystem once implemented
	# For now uses base data from events.json

	var social_pool: Array = _events_data.get("social", [])
	if social_pool.is_empty():
		return

	for event_def in social_pool:
		if active_social_events.size() >= MAX_SOCIAL_EVENTS:
			break
		if _is_event_active(event_def.get("id", "")):
			continue
		if _check_social_trigger(event_def):
			_spawn_social_event(event_def)


func _check_social_trigger(event_def: Dictionary) -> bool:
	# Text trigger evaluation from JSON
	var trigger = event_def.get("trigger", "")
	if trigger.is_empty():
		return false
	# Base triggers implemented — expand with CultureSystem/ResourceSystem
	if trigger == "cohesion<30":
		return false  # placeholder: cohesion lives in CultureSystem, not GameState
	if trigger.begins_with("research>"):
		var threshold = int(trigger.split(">")[1])
		return _get_total_stat("research") > threshold
	return false


func _get_total_stat(stat: String) -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get(stat, 0)
	return total


func _spawn_social_event(event_def: Dictionary) -> void:
	var ev = GameEvent.new()
	ev.id = event_def.get("id", "")
	ev.type = "social"
	ev.urgency = _parse_urgency(event_def.get("urgency", "manageable"))
	ev.title = event_def.get("title", "")
	ev.description = event_def.get("description", "")
	ev.expires_in_hours = _urgency_to_hours(ev.urgency)
	ev.choices = event_def.get("choices", [])
	ev.triggered_by = event_def.get("trigger", "")
	ev.created_at = Time.get_unix_time_from_system()
	active_social_events.append(ev)


func _maybe_generate_cosmic_event() -> void:
	# Base 30% probability per day
	if randf() < 0.3:
		_generate_cosmic_event()


func _generate_cosmic_event() -> void:
	var cosmic_pool: Array = _events_data.get("cosmic", [])
	if cosmic_pool.is_empty():
		return

	# Filter by current era (solar_wind only from era 4+)
	var available = cosmic_pool.filter(func(e):
		if e.get("id", "") == "solar_wind" and GameState.current_era < 4:
			return false
		return true
	)
	if available.is_empty():
		return

	var event_def = available[randi() % available.size()]
	var ev = GameEvent.new()
	ev.id = event_def.get("id", "")
	ev.type = "cosmic"
	ev.urgency = _parse_urgency(event_def.get("urgency", "urgent"))
	ev.title = event_def.get("id", "").replace("_", " ").capitalize()
	ev.description = ""
	ev.expires_in_hours = float(event_def.get("warning_hours", 6))
	ev.choices = event_def.get("choices", [])
	ev.triggered_by = "cosmos"
	ev.created_at = Time.get_unix_time_from_system()
	active_cosmic_event = ev


# --- Risoluzione eventi ---

func resolve_event(event: GameEvent, choice_index: int) -> void:
	if event.type == "social":
		active_social_events.erase(event)
	elif event.type == "cosmic":
		if active_cosmic_event == event:
			active_cosmic_event = null
	SaveManager.save_game()


# --- Scadenza eventi ---

func _expire_old_events() -> void:
	var now = Time.get_unix_time_from_system()
	var to_remove = []
	for ev in active_social_events:
		var hours_passed = float(now - ev.created_at) / 3600.0
		if hours_passed >= ev.expires_in_hours:
			to_remove.append(ev)
	for ev in to_remove:
		active_social_events.erase(ev)

	if active_cosmic_event != null:
		var hours_passed = float(now - active_cosmic_event.created_at) / 3600.0
		if hours_passed >= active_cosmic_event.expires_in_hours:
			active_cosmic_event = null


# --- Utility ---

func _is_event_active(event_id: String) -> bool:
	for ev in active_social_events:
		if ev.id == event_id:
			return true
	return false


func _parse_urgency(urgency_str: String) -> int:
	match urgency_str.to_lower():
		"critical":
			return EventUrgency.CRITICAL
		"urgent":
			return EventUrgency.URGENT
		_:
			return EventUrgency.MANAGEABLE


func _urgency_to_hours(urgency: int) -> float:
	match urgency:
		EventUrgency.CRITICAL:
			return 4.0
		EventUrgency.URGENT:
			return 12.0
		_:
			return 48.0
