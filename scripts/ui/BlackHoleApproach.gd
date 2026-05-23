extends CanvasLayer

signal enter_pressed

const SPRITE_PATH = "res://assets/planets/events/black_hole_01.png"
const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const TARGET_FILL_SIZE: float = 760.0  # ~90% of viewport height
const MIN_FILL_SIZE: float = 80.0      # starts at ~10% of viewport width when first visible
const ENTER_BTN_FONT_SIZE: int = 56
const FADE_BLOCK_THRESHOLD: float = 0.70

var _sprite: Sprite2D = null
var _enter_button: Button = null
var _ui_dim_overlay: ColorRect = null
var _shown_enter_button: bool = false
var _min_scale: float = 0.05


func _ready() -> void:
	layer = -5
	_build_sprite()
	_build_enter_button()
	_build_ui_dim()
	visible = false


func _build_sprite() -> void:
	var tex: Texture2D = load(SPRITE_PATH) as Texture2D
	if not tex:
		push_warning("BlackHoleApproach: missing texture %s" % SPRITE_PATH)
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.position = Vector2(SCREEN_W * 0.5, SCREEN_H * 0.5)
	var tex_w: float = float(tex.get_width())
	_min_scale = MIN_FILL_SIZE / tex_w
	_sprite.scale = Vector2(_min_scale, _min_scale)
	add_child(_sprite)


func _build_enter_button() -> void:
	_enter_button = Button.new()
	_enter_button.text = "..."
	_enter_button.add_theme_font_size_override("font_size", ENTER_BTN_FONT_SIZE)
	_enter_button.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	_enter_button.modulate.a = 0.0
	_enter_button.size = Vector2(120, 120)
	_enter_button.position = Vector2(
		(SCREEN_W - 120.0) * 0.5,
		(SCREEN_H - 120.0) * 0.5
	)
	var style := StyleBoxEmpty.new()
	_enter_button.add_theme_stylebox_override("normal", style)
	_enter_button.add_theme_stylebox_override("hover", style)
	_enter_button.add_theme_stylebox_override("pressed", style)
	_enter_button.add_theme_stylebox_override("focus", style)
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.visible = false
	add_child(_enter_button)


func _build_ui_dim() -> void:
	# When BH is near-full, this overlay darkens the rest of the world's UI
	_ui_dim_overlay = ColorRect.new()
	_ui_dim_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_ui_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_dim_overlay)


func _process(_delta: float) -> void:
	if not GameState.is_blackhole_visible():
		if visible:
			visible = false
		return
	if not visible:
		visible = true

	var ratio: float = GameState.get_blackhole_proximity_ratio()  # 0..1
	if _sprite:
		# Curve: pow(ratio, 0.55) grows fast early then plateaus — more visible at every "magnitude step"
		var growth: float = pow(ratio, 0.55)
		var tex_w: float = float(_sprite.texture.get_width())
		var target_scale: float = TARGET_FILL_SIZE / tex_w
		var current_scale: float = lerp(_min_scale, target_scale, growth)
		_sprite.scale = Vector2(current_scale, current_scale)

	# When near-full, dim background UI and show enter button
	if ratio >= FADE_BLOCK_THRESHOLD:
		var dim_alpha: float = (ratio - FADE_BLOCK_THRESHOLD) / (1.0 - FADE_BLOCK_THRESHOLD)
		_ui_dim_overlay.color.a = dim_alpha * 0.7
	else:
		_ui_dim_overlay.color.a = 0.0

	# Show "..." button only when fully reached
	if GameState.is_blackhole_reached() and not _shown_enter_button:
		_shown_enter_button = true
		_enter_button.visible = true
		var tw := create_tween()
		tw.tween_property(_enter_button, "modulate:a", 1.0, 1.2)


func _on_enter_pressed() -> void:
	enter_pressed.emit()
	# Fade out so the prestige screen can take over cleanly
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_enter_button, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): visible = false)
	_shown_enter_button = false
