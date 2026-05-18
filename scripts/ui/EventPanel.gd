extends CanvasLayer

signal choice_made(event: EventManager.GameEvent, choice_index: int)

@onready var panel: Panel = $Panel
@onready var event_title: Label = $Panel/VBox/TitleLabel
@onready var event_description: Label = $Panel/VBox/DescriptionLabel
@onready var urgency_label: Label = $Panel/VBox/UrgencyLabel
@onready var choices_container: HBoxContainer = $Panel/VBox/ChoicesContainer
@onready var event_counter: Label = $EventCounter

var _current_event: EventManager.GameEvent = null
var _event_queue: Array = []
var _choice_buttons: Array = []


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	_refresh_event_queue()


func _refresh_event_queue() -> void:
	var all_events = EventManager.active_social_events.duplicate()
	if EventManager.active_cosmic_event != null:
		all_events.append(EventManager.active_cosmic_event)

	_event_queue = all_events
	event_counter.text = str(all_events.size())
	event_counter.visible = all_events.size() > 0

	if _current_event == null and not _event_queue.is_empty():
		_show_event(_event_queue[0])


func _show_event(event: EventManager.GameEvent) -> void:
	_current_event = event
	visible = true

	event_title.text = _get_event_title(event)
	event_description.text = _get_event_description(event)
	urgency_label.text = _urgency_text(event.urgency)

	_build_choice_buttons(event)


func _get_event_title(event: EventManager.GameEvent) -> String:
	var key = "EVENT_" + event.id.to_upper() + "_TITLE"
	var translated = L.tr(key)
	# Fallback if no translation key exists
	return translated if translated != key else event.title


func _get_event_description(event: EventManager.GameEvent) -> String:
	var key = "EVENT_" + event.id.to_upper() + "_DESC"
	var translated = L.tr(key)
	return translated if translated != key else event.description


func _build_choice_buttons(event: EventManager.GameEvent) -> void:
	for btn in _choice_buttons:
		btn.queue_free()
	_choice_buttons.clear()

	for i in range(event.choices.size()):
		var choice_key = event.choices[i]
		var btn = Button.new()
		btn.text = L.tr("CHOICE_" + str(choice_key).to_upper())
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)
		_choice_buttons.append(btn)


func _on_choice_pressed(index: int) -> void:
	if _current_event == null:
		return
	emit_signal("choice_made", _current_event, index)
	EventManager.resolve_event(_current_event, index)
	_current_event = null
	visible = false


func _urgency_text(urgency: int) -> String:
	match urgency:
		EventManager.EventUrgency.CRITICAL:
			return "🔴 " + L.tr("URGENCY_CRITICAL")
		EventManager.EventUrgency.URGENT:
			return "🟠 " + L.tr("URGENCY_URGENT")
		_:
			return "🟡 " + L.tr("URGENCY_MANAGEABLE")


func show_lifeboat_option() -> void:
	# Synthetic event: population critical
	var ev = EventManager.GameEvent.new()
	ev.id = "lifeboat_warning"
	ev.type = "social"
	ev.urgency = EventManager.EventUrgency.CRITICAL
	ev.title = L.tr("LIVING_OMINI_LABEL")
	ev.description = "Only 2 survivors remain."
	ev.choices = ["pray"]
	ev.created_at = Time.get_unix_time_from_system()
	ev.expires_in_hours = 24.0
	_show_event(ev)
