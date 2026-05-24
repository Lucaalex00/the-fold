extends CanvasLayer

signal chip_clicked(event)

const URGENCY_COLOR: Dictionary = {
	EventManager.EventUrgency.MANAGEABLE: Color(0.4, 0.9, 0.5),
	EventManager.EventUrgency.URGENT:     Color(1.0, 0.75, 0.15),
	EventManager.EventUrgency.CRITICAL:   Color(1.0, 0.25, 0.25),
	EventManager.EventUrgency.FATAL:      Color(0.9, 0.0, 0.0),
}
const ENCOUNTER_COLOR: Color = Color(0.45, 0.7, 1.0)  # cool blue for planet encounters

const CHIP_W: float = 82.0
const CHIP_H: float = 28.0
const CHIP_RIGHT_MARGIN: float = 8.0
const CHIP_TOP_START: float = 86.0
const CHIP_GAP: float = 4.0

# event.id → { "node": Control, "event": EventManager.GameEvent }
var _chips: Dictionary = {}


func _ready() -> void:
	layer = 65


func add_chip(event: EventManager.GameEvent) -> void:
	if _chips.has(event.id):
		return
	var node: Control = _build_chip(event)
	add_child(node)
	_chips[event.id] = {"node": node, "event": event}
	_reposition()


func remove_chip(event_id: String) -> void:
	if not _chips.has(event_id):
		return
	var data: Dictionary = _chips[event_id] as Dictionary
	var node: Control = data["node"] as Control
	if is_instance_valid(node):
		node.queue_free()
	_chips.erase(event_id)
	_reposition()


func _build_chip(event: EventManager.GameEvent) -> Control:
	# Encounter events get a distinctive blue chip so they don't look like
	# generic notifications. Identified by id prefix "encounter_" (set in Main).
	var is_encounter: bool = String(event.id).begins_with("encounter_")
	var color: Color
	if is_encounter:
		color = ENCOUNTER_COLOR
	else:
		color = URGENCY_COLOR.get(event.urgency, Color.WHITE) as Color

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CHIP_W, CHIP_H)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "TimeLabel"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)
	btn.pressed.connect(func(): chip_clicked.emit(event))
	panel.add_child(btn)

	return panel


func _reposition() -> void:
	var ids: Array = _chips.keys()
	for i: int in range(ids.size()):
		var node: Control = (_chips[ids[i]] as Dictionary)["node"] as Control
		if is_instance_valid(node):
			node.position = Vector2(
				390.0 - CHIP_W - CHIP_RIGHT_MARGIN,
				CHIP_TOP_START + float(i) * (CHIP_H + CHIP_GAP)
			)


func _process(_delta: float) -> void:
	var now: int = Time.get_unix_time_from_system()
	var expired: Array = []

	for event_id: String in _chips.keys():
		var data: Dictionary = _chips[event_id] as Dictionary
		var node: Control = data["node"] as Control
		if not is_instance_valid(node):
			continue
		var event: EventManager.GameEvent = data["event"] as EventManager.GameEvent
		var elapsed_h: float = float(now - event.created_at) / 3600.0
		var remaining_s: float = maxf((event.expires_in_hours - elapsed_h) * 3600.0, 0.0)

		var label: Label = node.get_node_or_null("TimeLabel") as Label
		if label:
			var prefix: String = ""
			if event.chosen_choice_index >= 0:
				prefix = "✅ "
			elif String(event.id).begins_with("encounter_"):
				prefix = "🌐 "
			label.text = prefix + _format_time(remaining_s)

		if remaining_s <= 0.0:
			expired.append(event_id)
			continue

		if remaining_s < 3600.0:
			var pulse: float = (sin(float(Time.get_ticks_msec()) * 0.003) + 1.0) * 0.5
			node.modulate.a = lerp(0.5, 1.0, pulse)
		else:
			node.modulate.a = 1.0

	for event_id: String in expired:
		var data: Dictionary = _chips[event_id] as Dictionary
		var event: EventManager.GameEvent = data["event"] as EventManager.GameEvent
		var deferred: bool = (
			event.urgency == EventManager.EventUrgency.CRITICAL or
			event.urgency == EventManager.EventUrgency.FATAL
		)
		if deferred:
			EventManager.resolve_event(event, event.chosen_choice_index)
		remove_chip(event_id)


func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	return "%02dh %02dm" % [h, m]
