extends CanvasLayer

signal enter_pressed

const SPRITE_PATH = "res://assets/planets/events/black_hole_01.png"
const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const MIN_FRAME_DISPLAY: float = 80.0
const MAX_FRAME_DISPLAY: float = 1100.0
const MAX_DIM_ALPHA: float = 0.92
const FRAME_TOTAL: int = 16
const FRAME_TICK_MS: int = 90
const ENTER_BTN_FONT_SIZE: int = 60

var _sprite: Sprite2D = null
var _enter_button: Button = null
var _button_layer: CanvasLayer = null  # nested layer at 67 so the "..." sits above the planet
var _min_scale: float = 0.05
var _max_scale: float = 1.0
var _shown_enter_button: bool = false
var _bg_dim_rect: ColorRect = null  # owned externally — set via set_bg_dim
var _devouring: bool = false  # while true, _process leaves the sprite scale alone


func _ready() -> void:
	# BH sprite layer: above cosmos background (0) and dim (5), BELOW player planet (60),
	# topbar (50), HUD (55), chips (65), modifier bars (65). So the planet stays in front.
	layer = 10
	_build_sprite()
	_build_button_layer()
	_build_enter_button()
	visible = false


func _build_button_layer() -> void:
	# The "..." button MUST sit above the planet so it remains clickable when BH is reached.
	_button_layer = CanvasLayer.new()
	_button_layer.layer = 67
	add_child(_button_layer)


func set_bg_dim(rect: ColorRect) -> void:
	_bg_dim_rect = rect


func _build_sprite() -> void:
	var tex: Texture2D = load(SPRITE_PATH) as Texture2D
	if not tex:
		push_warning("BlackHoleApproach: missing texture " + SPRITE_PATH)
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
	var bx: float = (SCREEN_W - 150.0) * 0.5
	var by: float = (SCREEN_H - 150.0) * 0.5
	_enter_button.position = Vector2(bx, by)
	var style := StyleBoxEmpty.new()
	_enter_button.add_theme_stylebox_override("normal", style)
	_enter_button.add_theme_stylebox_override("hover", style)
	_enter_button.add_theme_stylebox_override("pressed", style)
	_enter_button.add_theme_stylebox_override("focus", style)
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.visible = false
	if _button_layer:
		_button_layer.add_child(_enter_button)
	else:
		add_child(_enter_button)


func _process(_delta: float) -> void:
	if _devouring:
		# Devour animation owns the sprite and dim; do nothing here
		return

	if not GameState.is_blackhole_visible():
		if visible:
			visible = false
			if _button_layer:
				_button_layer.visible = false
			_reset_button_state()
		_set_bg_dim(0.0)
		return
	if not visible:
		visible = true
		if _button_layer:
			_button_layer.visible = true

	var ratio: float = GameState.get_blackhole_proximity_ratio()
	var growth: float = pow(ratio, 0.45)

	if _sprite:
		var current_scale: float = lerp(_min_scale, _max_scale, growth)
		_sprite.scale = Vector2(current_scale, current_scale)
		var t: int = (Time.get_ticks_msec() / FRAME_TICK_MS) % FRAME_TOTAL
		_sprite.frame = t

	_set_bg_dim(MAX_DIM_ALPHA * ratio)

	var reached: bool = GameState.is_blackhole_reached()
	if reached and not _shown_enter_button:
		_shown_enter_button = true
		_enter_button.visible = true
		_enter_button.disabled = false
		var tw := create_tween()
		tw.tween_property(_enter_button, "modulate:a", 1.0, 1.0)
	elif not reached and _shown_enter_button:
		_reset_button_state()


func _set_bg_dim(alpha: float) -> void:
	if _bg_dim_rect:
		_bg_dim_rect.color.a = alpha


func _reset_button_state() -> void:
	_shown_enter_button = false
	if _enter_button:
		_enter_button.visible = false
		_enter_button.modulate.a = 0.0
		_enter_button.disabled = false


func _on_enter_pressed() -> void:
	_enter_button.disabled = true
	_shown_enter_button = false
	_devouring = true   # freeze _process scale/dim updates

	var devour_target_scale: float = _max_scale * 2.4
	var devour := create_tween()
	devour.tween_property(_enter_button, "modulate:a", 0.0, 0.25)
	devour.parallel().tween_property(_sprite, "scale", Vector2(devour_target_scale, devour_target_scale), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _bg_dim_rect:
		devour.parallel().tween_property(_bg_dim_rect, "color:a", 1.0, 1.2)
	devour.tween_interval(0.4)
	devour.tween_callback(_finish_devour)


func _finish_devour() -> void:
	# Emit the signal so PrestigeScreen starts taking over,
	# but KEEP the BH visible & at full devour scale until prestige's own
	# fade-in is well underway. _devouring stays true so _process won't shrink it.
	enter_pressed.emit()
	# Wait a beat to let PrestigeScreen's fade-in cover the screen,
	# then quietly hide the BH layer (no shrink animation).
	var hide_tw := create_tween()
	hide_tw.tween_interval(1.6)
	hide_tw.tween_callback(_hide_self)


func _hide_self() -> void:
	visible = false
	if _button_layer:
		_button_layer.visible = false
	_devouring = false
	# Reset so next time BH appears it starts at min scale, not the devour scale
	if _sprite:
		_sprite.scale = Vector2(_min_scale, _min_scale)
		_sprite.modulate.a = 1.0
	if _bg_dim_rect:
		_bg_dim_rect.color.a = 0.0
