extends CanvasLayer

signal pressed

const POS: Vector2 = Vector2(326, 762)  # bottom-right thumb area
const SIZE: Vector2 = Vector2(54, 54)

var _button: Button


func _ready() -> void:
	layer = 65
	_build_button()


func _build_button() -> void:
	_button = Button.new()
	_button.text = "✦"
	_button.add_theme_font_size_override("font_size", 26)
	_button.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	_button.size = SIZE
	_button.position = POS
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.35, 0.7)
	style.corner_radius_top_left = 27
	style.corner_radius_top_right = 27
	style.corner_radius_bottom_left = 27
	style.corner_radius_bottom_right = 27
	_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	_button.add_theme_stylebox_override("hover", hover)
	_button.add_theme_stylebox_override("pressed", hover)
	_button.add_theme_stylebox_override("focus", style)
	_button.pressed.connect(_on_pressed)
	add_child(_button)


func _on_pressed() -> void:
	pressed.emit()


func set_visible_state(v: bool) -> void:
	visible = v


func _process(_delta: float) -> void:
	# Hide automatically when the Black Hole event is active — the player should
	# focus on the cosmic endgame, not browse the universe map.
	var should_hide: bool = GameState.is_blackhole_visible()
	if should_hide and _button and _button.visible:
		_button.visible = false
	elif not should_hide and _button and not _button.visible:
		_button.visible = true
