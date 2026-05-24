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


const PANEL_W: int = 366
const CONTENT_W: int = 330


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 10)
	_panel.size = Vector2(PANEL_W, 10)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	# Apply a fuller, slightly cosmic panel style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.07, 0.11, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.3, 0.5)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title_label.custom_minimum_size = Vector2(CONTENT_W, 0)
	vbox.add_child(_title_label)

	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 2)
	vbox.add_child(sep1)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(CONTENT_W, 0)
	vbox.add_child(_desc_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 12)
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
	var pw: float = max(_panel.size.x, float(PANEL_W))
	var ph: float = _panel.size.y
	_panel.position = Vector2(
		(390.0 - pw) / 2.0,
		max(60.0, 52.0 + (792.0 - ph) / 2.0)
	)


func _add_choice_button(choice, index: int, locked: bool = false, chosen: int = -1) -> void:
	# Each choice is rendered as a "card": a PanelContainer with a header (label + cost
	# badge) and a body (consequence text), plus an invisible Button overlaying the
	# whole card so the player has a big tap target.

	var label_text := ""
	var consequence_text := ""
	var divine_cost: float = 0.0
	if choice is Dictionary:
		label_text = choice.get("label", "")
		consequence_text = choice.get("consequence", "")
		var cost_dict: Dictionary = choice.get("cost", {})
		divine_cost = float(cost_dict.get("divine_energy", 0.0))
	else:
		label_text = str(choice)

	var is_chosen: bool = locked and index == chosen
	var cannot_afford: bool = divine_cost > 0.0 and not GameState.can_afford_divine_energy(divine_cost)
	var is_premium: bool = divine_cost > 0.0
	var is_interactive: bool = (not locked) and (not cannot_afford)

	# Card stylebox
	var card_style := StyleBoxFlat.new()
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	if is_chosen:
		card_style.bg_color = Color(0.08, 0.26, 0.12, 0.95)
		card_style.border_color = Color(0.4, 0.95, 0.55)
	elif is_premium:
		card_style.bg_color = Color(0.12, 0.08, 0.18, 0.95)
		card_style.border_color = Color(0.6, 0.5, 0.95) if is_interactive else Color(0.35, 0.3, 0.5)
	else:
		card_style.bg_color = Color(0.10, 0.10, 0.14, 0.95)
		card_style.border_color = Color(0.35, 0.35, 0.45)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)
	if not is_interactive:
		card.modulate.a = 0.55 if cannot_afford else 0.7
	_choices_box.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	# Header row: label + cost badge
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	card_vbox.add_child(header)

	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = ("✅ " + label_text) if is_chosen else label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if is_chosen:
		lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	elif is_premium:
		lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	header.add_child(lbl)

	if is_premium and not is_chosen:
		var badge := _make_cost_badge(int(divine_cost), cannot_afford)
		header.add_child(badge)

	# Body row: consequence text
	if consequence_text != "":
		var body := Label.new()
		body.text = consequence_text
		body.add_theme_font_size_override("font_size", 12)
		body.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(body)

	# Click area overlay (transparent button on top of the card)
	if is_interactive:
		var btn := Button.new()
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)
		btn.pressed.connect(_on_choice_pressed.bind(index))
		card.add_child(btn)


func _make_cost_badge(cost: int, unaffordable: bool) -> PanelContainer:
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	if unaffordable:
		bs.bg_color = Color(0.15, 0.10, 0.18, 0.95)
		bs.border_color = Color(0.5, 0.35, 0.5)
	else:
		bs.bg_color = Color(0.22, 0.15, 0.35, 0.95)
		bs.border_color = Color(0.75, 0.6, 1.0)
	bs.border_width_left = 1
	bs.border_width_right = 1
	bs.border_width_top = 1
	bs.border_width_bottom = 1
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	bs.content_margin_left = 8
	bs.content_margin_right = 8
	bs.content_margin_top = 3
	bs.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", bs)
	var l := Label.new()
	l.text = "🔮 %d" % cost
	l.add_theme_font_size_override("font_size", 12)
	if unaffordable:
		l.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
	else:
		l.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	badge.add_child(l)
	return badge


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
	# Close UI first, then apply effects, then emit. Avoids sprite-rebuild glitch on modal.
	_current_event = null
	_panel.visible = false
	_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	await get_tree().process_frame
	if not deferred:
		EventManager.resolve_event(resolved, index)
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
