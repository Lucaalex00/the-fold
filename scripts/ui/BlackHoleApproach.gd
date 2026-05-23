extends CanvasLayer

signal enter_pressed

const SPRITE_PATH = "res://assets/planets/events/black_hole_01.png"
const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const MIN_FRAME_DISPLAY: float = 80.0   # px of single-frame at first appearance
const MAX_FRAME_DISPLAY: float = 1100.0  # at distance 0 → covers full viewport (>844 tall)
const MAX_DIM_ALPHA: float = 0.92         # darkness at distance 0
const FRAME_TOTAL: int = 16
const FRAME_TICK_MS: int = 90
const ENTER_BTN_FONT_SIZE: int = 60

var _dim_bg: ColorRect = null
var _sprite: Sprite2D = null
var _enter_button: Button = null
var _min_scale: float = 0.05
var _max_scale: float = 1.0
var _shown_enter_button: bool = false


func _ready() -> void:
	# Layer 67: above planets/HUD (60) and modifier bars/chips (65), below event panel (70)
	layer = 67
	_build_dim_bg()
	_build_sprite()
	_build_enter_button()
	visible = false


func _build_dim_bg() -> void:
	# Full-screen black overlay that progressively darkens the entire world
	_dim_bg = ColorRect.new()
	_dim_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim_bg)


func _build_sprite() -> void:
	var tex: Texture2D = load(SPRITE_PATH) as Texture2D
	if not tex:
		push_warning("BlackHoleApproach: missing texture %s" % SPRITE_PATH)
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = FRAME_TOTAL
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.position = Vector2(SCREEN_W * 0.5, SCREEN_H * 0.5)
	var frame_w: float = float(tex.get_width()) / float(FRAME_TOTAL)
	_min_scale = MIN_FRAME_DISPLAY / frame_w
	_max_scale = MAX_FRAME_DISPLAY / frame_w
	_sprite.scale = Vector2(_min_scale, _min_scale)
	add_child(_sprite)


func _build_enter_button() -> void:
	_enter_button = Button.new()
	_enter_button.text = "..."
	_enter_button.add_theme_font_size_override("font_size", ENTER_BTN_FONT_SIZE)
	_enter_button.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	_enter_button.modulate.a = 0.0
	_enter_button.size = Vector2(150, 150)
	_enter_button.position = Vector2(
		(SCREEN_W - 150.0) * 0.5,
		(SCREEN_H - 150.0) * 0.5
	)
	var style := StyleBoxEmpty.new()
	_enter_button.add_theme_stylebox_override("normal", style)
	_enter_button.add_theme_stylebox_override("hover", style)
	_enter_button.add_theme_stylebox_override("pressed", style)
	_enter_button.add_theme_stylebox_override("focus", style)
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.visible = false
	add_child(_enter_button)


func _process(_delta: float) -> void:
	if not GameState.is_blackhole_visible():
		if visible:
			visible = false
			_reset_button_state()
		return
	if not visible:
		visible = true

	var ratio: float = GameState.get_blackhole_proximity_ratio()  # 0..1
	# Growth curve: pow(ratio, 0.45) grows fast at first appearance, plateaus near max
	var growth: float = pow(ratio, 0.45)

	# BH sprite scale
	if _sprite:
		var current_scale: float = lerp(_min_scale, _max_scale, growth)
		_sprite.scale = Vector2(current_scale, current_scale)
		var t: int = (Time.get_ticks_msec() / FRAME_TICK_MS) % FRAME_TOTAL
		_sprite.frame = t

	# Background dim — grows with ratio (linear feels fine here)
	if _dim_bg:
		_dim_bg.color.a = MAX_DIM_ALPHA * ratio

	# "..." button only at distance 0 (exact full proximity)
	var reached: bool = GameState.is_blackhole_reached()
	if reached and not _shown_enter_button:
		_shown_enter_button = true
		_enter_button.visible = true
		_enter_button.disabled = false
		var tw := create_tween()
		tw.tween_property(_enter_button, "modulate:a", 1.0, 1.0)
	elif not reached and _shown_enter_button:
		_reset_button_state()


func _reset_button_state() -> void:
	_shown_enter_button = false
	if _enter_button:
		_enter_button.visible = false
		_enter_button.modulate.a = 0.0
		_enter_button.disabled = false


func _on_enter_pressed() -> void:
	_enter_button.disabled = true
	_shown_enter_button = false

	# Dramatic "devour" sequence — BH expands huge, everything goes pitch black
	var devour_target_scale: float = _max_scale * 2.4
	var devour := create_tween()
	# Hide the "..." quickly
	devour.tween_property(_enter_button, "modulate:a", 0.0, 0.25)
	# BH grows past the screen edge (like it's about to swallow the camera)
	devour.parallel().tween_property(_sprite, "scale", Vector2(devour_target_scale, devour_target_scale), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	devour.parallel().tween_property(_dim_bg, "color:a", 1.0, 1.2)
	# Hold the full-black moment briefly so the player feels swallowed
	devour.tween_interval(0.4)
	# Now hand off to the prestige sequence
	devour.tween_callback(_finish_devour)


func _finish_devour() -> void:
	enter_pressed.emit()
	# Fade BH sprite and dim out so prestige can render on top
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	fade.parallel().tween_property(_dim_bg, "color:a", 0.0, 0.6)
	fade.tween_callback(func(): visible = false)
