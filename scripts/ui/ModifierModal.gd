extends CanvasLayer

var _blocker: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _progress_label: Label
var _spread_btn: Button
var _accel_btn: Button
var _close_btn: Button
var _current_id: String = ""


func _ready() -> void:
	layer = 73
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	_panel = PanelContainer.new()
	_panel.size = Vector2(340, 10)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(308, 0)
	vbox.add_child(_desc_label)

	vbox.add_child(HSeparator.new())

	# Cure progress bar
	var pcontainer := Control.new()
	pcontainer.custom_minimum_size = Vector2(308, 22)
	vbox.add_child(pcontainer)

	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.1, 0.1, 0.15, 0.9)
	_progress_bg.position = Vector2.ZERO
	_progress_bg.size = Vector2(308, 22)
	pcontainer.add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.85, 0.2, 0.2, 0.9)
	_progress_fill.position = Vector2(2, 2)
	_progress_fill.size = Vector2(0, 18)
	pcontainer.add_child(_progress_fill)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 11)
	_progress_label.add_theme_color_override("font_color", Color.WHITE)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pcontainer.add_child(_progress_label)

	_spread_btn = Button.new()
	_spread_btn.text = "Spread the Cure"
	_spread_btn.add_theme_font_size_override("font_size", 13)
	_spread_btn.pressed.connect(_on_spread)
	vbox.add_child(_spread_btn)

	_accel_btn = Button.new()
	_accel_btn.add_theme_font_size_override("font_size", 12)
	_accel_btn.pressed.connect(_on_accelerate)
	vbox.add_child(_accel_btn)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)


func _process(_delta: float) -> void:
	if not visible or _current_id == "":
		return
	_refresh()


func show_modifier(modifier_id: String) -> void:
	_current_id = modifier_id
	var def: Dictionary = WorldModifierSystem.DEFINITIONS.get(modifier_id, {})
	_title_label.text = String(def.get("title", modifier_id))
	_desc_label.text = String(def.get("description", ""))
	visible = true
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_center_panel()


func _refresh() -> void:
	var m: WorldModifierSystem.WorldModifier = WorldModifierSystem.get_modifier(_current_id)
	if m == null:
		_close()
		return
	var now: int = Time.get_unix_time_from_system()
	var progress: float = m.cure_progress(now)
	var remaining: float = m.remaining_seconds(now)

	_progress_fill.size.x = 304.0 * progress
	_progress_label.text = "Cure progress  %d%%" % int(progress * 100.0)

	# Spread button only enabled at full progress
	_spread_btn.disabled = progress < 1.0
	_spread_btn.modulate.a = 1.0 if progress >= 1.0 else 0.45

	# Accelerate button — affordability check
	var cost: float = WorldModifierSystem.CURE_ACCELERATE_COST
	_accel_btn.text = "🔮 %d  Accelerate by %dh" % [int(cost), int(WorldModifierSystem.CURE_ACCELERATE_HOURS)]
	var afford: bool = GameState.can_afford_divine_energy(cost) and progress < 1.0
	_accel_btn.disabled = not afford
	_accel_btn.modulate.a = 1.0 if afford else 0.45


func _center_panel() -> void:
	var pw = _panel.size.x
	var ph = _panel.size.y
	_panel.position = Vector2((390.0 - pw) / 2.0, 52.0 + (792.0 - ph) / 2.0)


func _on_spread() -> void:
	if WorldModifierSystem.spread_cure(_current_id):
		_close()


func _on_accelerate() -> void:
	WorldModifierSystem.accelerate_cure(_current_id)


func _on_blocker_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap or is_touch:
		_close()


func _close() -> void:
	visible = false
	_current_id = ""
