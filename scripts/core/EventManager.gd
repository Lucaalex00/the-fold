extends Node

enum EventUrgency { MANAGEABLE, URGENT, CRITICAL, FATAL }

signal event_created(event: GameEvent)

const MAX_SOCIAL_EVENTS = 3

# Real-time seconds between events of the same urgency
const URGENCY_COOLDOWN = {
	EventUrgency.MANAGEABLE: 86400,    # 1 day
	EventUrgency.URGENT:     259200,   # 3 days
	EventUrgency.CRITICAL:   604800,   # 7 days
	EventUrgency.FATAL:      1296000,  # 15 days
}

var active_social_events: Array = []
var active_cosmic_event = null

var _events_data: Dictionary = {}
var _last_urgency_time: Dictionary = {}


class GameEvent:
	var id: String = ""
	var type: String = ""
	var urgency: int = 0
	var title: String = ""
	var description: String = ""
	var expires_in_hours: float = 24.0
	var choices: Array = []
	var default_effects: Array = []
	var triggered_by: String = ""
	var created_at: int = 0
	var chosen_choice_index: int = -1


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

	# Build pool from all urgency buckets
	var pool: Array = []
	for bucket in ["notify", "warning", "critical", "fatal"]:
		for ev in _events_data.get(bucket, []):
			var d = ev.duplicate()
			d["_urgency"] = bucket
			pool.append(d)

	for event_def in pool:
		if active_social_events.size() >= MAX_SOCIAL_EVENTS:
			break
		if _is_event_active(event_def.get("id", "")):
			continue
		var urgency = _parse_urgency(event_def.get("_urgency", "notify"))
		if not _cooldown_passed(urgency):
			continue
		if _check_social_trigger(event_def):
			_spawn_social_event(event_def, urgency)


func _check_social_trigger(event_def: Dictionary) -> bool:
	var trigger = event_def.get("trigger", "")
	if trigger.is_empty():
		return false

	if trigger == "always":
		return true

	if trigger.begins_with("random:"):
		var prob = float(trigger.split(":")[1])
		return randf() < prob

	if trigger.begins_with("cohesion<"):
		var threshold = float(trigger.split("<")[1])
		return CultureSystem.cohesion < threshold

	if trigger.begins_with("cohesion>"):
		var threshold = float(trigger.split(">")[1])
		return CultureSystem.cohesion > threshold

	if trigger.begins_with("food_deficit>"):
		var threshold = int(trigger.split(">")[1])
		return ResourceSystem.food_deficit_days > threshold

	if trigger.begins_with("population<"):
		var threshold = int(trigger.split("<")[1])
		return GameState.get_living_entities().size() < threshold

	if trigger.begins_with("era>="):
		var threshold = int(trigger.split(">=")[1])
		return GameState.current_era >= threshold

	if trigger.begins_with("warrior_ratio>"):
		var threshold = float(trigger.split(">")[1])
		return CultureSystem.get_warrior_ratio() > threshold

	if trigger.begins_with("research>"):
		var threshold = int(trigger.split(">")[1])
		return _get_total_stat("research") > threshold

	return false


func _get_total_stat(stat: String) -> int:
	var total = 0
	for entity in GameState.get_living_entities():
		total += entity.stats.get(stat, 0)
	return total


func _spawn_social_event(event_def: Dictionary, urgency: int) -> void:
	var ev = GameEvent.new()
	ev.id = event_def.get("id", "")
	ev.type = "social"
	ev.urgency = urgency
	ev.title = event_def.get("title", "")
	ev.description = event_def.get("description", "")
	ev.expires_in_hours = _urgency_to_hours(urgency)
	ev.choices = event_def.get("choices", [])
	ev.default_effects = event_def.get("default_effects", [])
	ev.triggered_by = event_def.get("trigger", "")
	ev.created_at = Time.get_unix_time_from_system()
	active_social_events.append(ev)
	_last_urgency_time[urgency] = ev.created_at
	event_created.emit(ev)


func _maybe_generate_cosmic_event() -> void:
	# Events with warning_hours are treated as cosmic-style (timed threat)
	var pool: Array = []
	for bucket in ["notify", "warning", "critical", "fatal"]:
		for ev in _events_data.get(bucket, []):
			if ev.has("warning_hours"):
				var d = ev.duplicate()
				d["_urgency"] = bucket
				pool.append(d)

	pool.shuffle()
	for event_def in pool:
		var urgency = _parse_urgency(event_def.get("_urgency", "notify"))
		if not _cooldown_passed(urgency):
			continue
		if not _check_social_trigger(event_def):
			continue
		var prob: float
		match urgency:
			EventUrgency.FATAL:    prob = 0.07
			EventUrgency.CRITICAL: prob = 0.14
			EventUrgency.URGENT:   prob = 0.33
			_:                     prob = 0.30
		if randf() < prob:
			_spawn_cosmic_event(event_def, urgency)
			return


func _spawn_cosmic_event(event_def: Dictionary, urgency: int) -> void:
	var ev = GameEvent.new()
	ev.id = event_def.get("id", "")
	ev.type = "cosmic"
	ev.urgency = urgency
	ev.title = event_def.get("title", ev.id.replace("_", " ").capitalize())
	ev.description = event_def.get("description", "")
	ev.expires_in_hours = float(event_def.get("warning_hours", 6))
	ev.choices = event_def.get("choices", [])
	ev.default_effects = event_def.get("default_effects", [])
	ev.triggered_by = "cosmos"
	ev.created_at = Time.get_unix_time_from_system()
	active_cosmic_event = ev
	_last_urgency_time[urgency] = ev.created_at
	event_created.emit(ev)


# --- Event resolution ---

func resolve_event(event: GameEvent, choice_index: int) -> void:
	# Apply effects: chosen choice when index >= 0, otherwise default_effects
	if choice_index >= 0 and choice_index < event.choices.size():
		var choice: Dictionary = event.choices[choice_index]
		# Deduct divine energy cost (if any) before applying effects
		var cost_dict: Dictionary = choice.get("cost", {})
		var divine_cost: float = float(cost_dict.get("divine_energy", 0.0))
		if divine_cost > 0.0:
			GameState.spend_divine_energy(divine_cost)
		ConsequenceSystem.apply_effects(choice.get("effects", []))
	else:
		ConsequenceSystem.apply_effects(event.default_effects)

	if event.type == "social":
		active_social_events.erase(event)
	elif event.type == "cosmic":
		if active_cosmic_event == event:
			active_cosmic_event = null
	SaveManager.save_game()


# --- Expiry ---

func _expire_old_events() -> void:
	var now = Time.get_unix_time_from_system()
	var to_remove = []
	for ev in active_social_events:
		var hours_passed = float(now - ev.created_at) / 3600.0
		if hours_passed >= ev.expires_in_hours:
			to_remove.append(ev)
	for ev in to_remove:
		# Expired without player choice → apply default_effects
		ConsequenceSystem.apply_effects(ev.default_effects)
		active_social_events.erase(ev)

	if active_cosmic_event != null:
		var hours_passed = float(now - active_cosmic_event.created_at) / 3600.0
		if hours_passed >= active_cosmic_event.expires_in_hours:
			ConsequenceSystem.apply_effects(active_cosmic_event.default_effects)
			active_cosmic_event = null


# --- Utility ---

func _is_event_active(event_id: String) -> bool:
	for ev in active_social_events:
		if ev.id == event_id:
			return true
	return false


func _cooldown_passed(urgency: int) -> bool:
	if not _last_urgency_time.has(urgency):
		return true
	var elapsed = Time.get_unix_time_from_system() - _last_urgency_time[urgency]
	return elapsed >= URGENCY_COOLDOWN[urgency]


func _parse_urgency(urgency_str: String) -> int:
	match urgency_str.to_lower():
		"fatal":    return EventUrgency.FATAL
		"critical": return EventUrgency.CRITICAL
		"urgent":   return EventUrgency.URGENT
		_:          return EventUrgency.MANAGEABLE


func _urgency_to_hours(urgency: int) -> float:
	match urgency:
		EventUrgency.FATAL:    return 2.0
		EventUrgency.CRITICAL: return 4.0
		EventUrgency.URGENT:   return 12.0
		_:                     return 48.0
