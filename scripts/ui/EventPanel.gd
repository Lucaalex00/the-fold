extends CanvasLayer

signal event_resolved(event)

const URGENCY_TITLE_COLOR = {
	EventManager.EventUrgency.MANAGEABLE: Color(0.4, 0.9, 0.5),
	EventManager.EventUrgency.URGENT:     Color(1.0, 0.75, 0.15),
	EventManager.EventUrgency.CRITICAL:   Color(1.0, 0.25, 0.25),
	EventManager.EventUrgency.FATAL:      Color(0.9, 0.0, 0.0),
}

var _blocker: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _choices_box: VBoxContainer
var _current_event = null


func _ready() -> void:
	layer = 70
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	_panel = PanelContainer.new()
	_panel.size = Vector2(350, 10)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title_label.custom_minimum_size = Vector2(314, 0)
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(314, 0)
	vbox.add_child(_desc_label)

	vbox.add_child(HSeparator.new())

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_choices_box)


func lock_input() -> void:
	visible = true
	_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	_blocker.visible = true
	_panel.visible = false


func unlock_input() -> void:
	_panel.visible = false
	_blocker.visible = false
	visible = false


func activate_blocker() -> void:
	visible = true
	_blocker.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocker.visible = true
	_panel.visible = false


func show_event(event) -> void:
	_current_event = event

	var color = URGENCY_TITLE_COLOR.get(event.urgency, Color.WHITE)
	_title_label.text = event.title
	_title_label.add_theme_color_override("font_color", color)
	_desc_label.text = event.description

	for child in _choices_box.get_children():
		child.queue_free()

	var locked: bool = event.chosen_choice_index >= 0
	for i in range(event.choices.size()):
		_add_choice_button(event.choices[i], i, locked, event.chosen_choice_index)

	_panel.visible = true

	# Center panel after layout is computed
	await get_tree().process_frame
	await get_tree().process_frame
	var pw = _panel.size.x
	var ph = _panel.size.y
	_panel.position = Vector2(
		(390.0 - pw) / 2.0,
		52.0 + (792.0 - ph) / 2.0
	)


func _add_choice_button(choice, index: int, locked: bool = false, chosen: int = -1) -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	_choices_box.add_child(container)

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)

	var label_text := ""
	var consequence_text := ""
	if choice is Dictionary:
		label_text = choice.get("label", "")
		consequence_text = choice.get("consequence", "")
	else:
		label_text = str(choice)

	var is_chosen := locked and index == chosen
	if is_chosen:
		btn.text = "✅ " + label_text
		btn.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.28, 0.1, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.85, 0.4)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("disabled", style)
	else:
		btn.text = label_text

	if locked:
		btn.disabled = true
		if not is_chosen:
			btn.modulate.a = 0.4
	else:
		btn.pressed.connect(_on_choice_pressed.bind(index))

	container.add_child(btn)

	if consequence_text != "":
		var cons = Label.new()
		cons.text = consequence_text
		cons.add_theme_font_size_override("font_size", 11)
		cons.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		cons.autowrap_mode = TextServer.AUTOWRAP_WORD
		cons.custom_minimum_size = Vector2(314, 0)
		container.add_child(cons)


func _on_blocker_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not (is_tap or is_touch):
		return
	var ev: EventManager.GameEvent = _current_event
	_current_event = null
	_panel.visible = false
	_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	if ev != null:
		event_resolved.emit(ev)


func _on_choice_pressed(index: int) -> void:
	if _current_event == null:
		return
	var resolved = _current_event
	resolved.chosen_choice_index = index
	var deferred: bool = (
		resolved.urgency == EventManager.EventUrgency.CRITICAL or
		resolved.urgency == EventManager.EventUrgency.FATAL
	)
	if not deferred:
		EventManager.resolve_event(resolved, index)
	_current_event = null
	_panel.visible = false
	_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	event_resolved.emit(resolved)


func show_lifeboat_option() -> void:
	var ev = EventManager.GameEvent.new()
	ev.id = "lifeboat_warning"
	ev.type = "social"
	ev.urgency = EventManager.EventUrgency.CRITICAL
	ev.title = "Population Critical"
	ev.description = "Only 2 survivors remain. Your civilization is on the brink of extinction."
	ev.choices = [{"id": "pray", "label": "Pray for survival", "consequence": "Hope for a miracle"}]
	ev.created_at = Time.get_unix_time_from_system()
	ev.expires_in_hours = 24.0
	activate_blocker()
	show_event(ev)
