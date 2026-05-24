extends CanvasLayer

signal map_pressed
signal memory_pressed

const MAIN_POS: Vector2 = Vector2(326, 762)
const MAIN_SIZE: Vector2 = Vector2(54, 54)
const SUB_SIZE: Vector2 = Vector2(54, 54)
const SUB_GAP: float = 8.0
const SLIDE_DURATION: float = 0.22

var _main_btn: Button
var _map_btn: Button
var _memory_btn: Button
var _blocker: ColorRect
var _is_open: bool = false


func _ready() -> void:
	layer = 65
	_build_blocker()
	_build_main_button()
	_build_sub_buttons()


func _build_blocker() -> void:
	# Invisible full-screen blocker so a tap anywhere outside closes the menu.
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)


func _build_main_button() -> void:
	_main_btn = _make_round_button("☰", Color(0.85, 0.85, 0.95), Color(0.4, 0.4, 0.55))
	_main_btn.size = MAIN_SIZE
	_main_btn.position = MAIN_POS
	_main_btn.pressed.connect(_on_main_pressed)
	add_child(_main_btn)


func _build_sub_buttons() -> void:
	_map_btn = _make_round_button("🌐", Color(0.85, 0.7, 1.0), Color(0.5, 0.35, 0.7))
	_map_btn.size = SUB_SIZE
	_map_btn.position = MAIN_POS  # start under main, will slide up
	_map_btn.modulate.a = 0.0
	_map_btn.visible = false
	_map_btn.pressed.connect(_on_map_pressed)
	add_child(_map_btn)

	_memory_btn = _make_round_button("📖", Color(0.95, 0.85, 0.5), Color(0.6, 0.45, 0.2))
	_memory_btn.size = SUB_SIZE
	_memory_btn.position = MAIN_POS
	_memory_btn.modulate.a = 0.0
	_memory_btn.visible = false
	_memory_btn.pressed.connect(_on_memory_pressed)
	add_child(_memory_btn)


func _make_round_button(icon: String, fg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", fg)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.10, 0.94)
	s.border_color = border
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 27
	s.corner_radius_top_right = 27
	s.corner_radius_bottom_left = 27
	s.corner_radius_bottom_right = 27
	var sh := s.duplicate()
	sh.bg_color = Color(0.12, 0.10, 0.18, 0.97)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus", s)
	return btn


func _on_main_pressed() -> void:
	if _is_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	_is_open = true
	_blocker.visible = true
	_main_btn.text = "✕"
	_map_btn.visible = true
	_memory_btn.visible = true
	var step: float = SUB_SIZE.y + SUB_GAP
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_map_btn, "position:y", MAIN_POS.y - step, SLIDE_DURATION)
	tw.tween_property(_map_btn, "modulate:a", 1.0, SLIDE_DURATION)
	tw.tween_property(_memory_btn, "position:y", MAIN_POS.y - step * 2.0, SLIDE_DURATION)
	tw.tween_property(_memory_btn, "modulate:a", 1.0, SLIDE_DURATION)


func _close_menu() -> void:
	_is_open = false
	_blocker.visible = false
	_main_btn.text = "☰"
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_map_btn, "position:y", MAIN_POS.y, SLIDE_DURATION)
	tw.tween_property(_map_btn, "modulate:a", 0.0, SLIDE_DURATION)
	tw.tween_property(_memory_btn, "position:y", MAIN_POS.y, SLIDE_DURATION)
	tw.tween_property(_memory_btn, "modulate:a", 0.0, SLIDE_DURATION)
	tw.chain().tween_callback(_hide_subs)


func _hide_subs() -> void:
	if not _is_open:
		_map_btn.visible = false
		_memory_btn.visible = false


func _on_map_pressed() -> void:
	_close_menu()
	map_pressed.emit()


func _on_memory_pressed() -> void:
	_close_menu()
	memory_pressed.emit()


func _on_blocker_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap or is_touch:
		_close_menu()


func _process(_delta: float) -> void:
	# Hide menu entirely while BH is in the cosmos (don't distract)
	var should_hide: bool = GameState.is_blackhole_visible()
	if should_hide:
		if _main_btn.visible:
			_main_btn.visible = false
		if _is_open:
			_close_menu()
	else:
		if not _main_btn.visible:
			_main_btn.visible = true
