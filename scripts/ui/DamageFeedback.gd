extends CanvasLayer

# Visual feedback for "bad things just happened":
#   - flash_red(intensity): full-screen red pulse
#   - shake(amplitude, duration): horizontal jitter on a target Control
# Listens to GameState signals (entity_died, cohesion_changed, planet damage)
# to fire automatic feedback so the player feels the hit.

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const FLASH_FADE_IN: float = 0.07
const FLASH_FADE_OUT: float = 0.45
const SHAKE_STEP: float = 0.04   # seconds per shake step

var _flash_rect: ColorRect
var _shake_target: Node = null
var _shake_base_offset: Vector2 = Vector2.ZERO
var _shaking: bool = false
var _last_cohesion: float = -1.0
var _last_planet_hp: float = -1.0


func _ready() -> void:
	# Above the event modal (70) but below the prestige screen (80) so even a
	# damaging event resolution still flashes visibly.
	layer = 76
	_build_flash()
	# Wire signals once GameState is loaded (it is — autoload order)
	GameState.entity_died.connect(_on_entity_died)
	GameState.cohesion_changed.connect(_on_cohesion_changed)
	_last_cohesion = CultureSystem.cohesion
	_last_planet_hp = GameState.get_planet_hp()


func _build_flash() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.85, 0.1, 0.1, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)


func set_shake_target(node: Node) -> void:
	# Best target is the main world container (planet_widget). Shaking it
	# jitters the planet/entities without touching modals or HUD.
	_shake_target = node
	if node and node is Node2D:
		_shake_base_offset = (node as Node2D).position
	elif node and node is Control:
		_shake_base_offset = (node as Control).position


# --- Public API ---

func flash_red(intensity: float = 0.55) -> void:
	if not _flash_rect:
		return
	var clamped: float = clampf(intensity, 0.1, 0.95)
	_flash_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", clamped, FLASH_FADE_IN)
	tw.tween_property(_flash_rect, "color:a", 0.0, FLASH_FADE_OUT)


func shake(amplitude: float = 8.0, duration: float = 0.35) -> void:
	if _shake_target == null or _shaking:
		return
	_shaking = true
	var steps: int = int(duration / SHAKE_STEP)
	if steps < 2:
		steps = 2
	var tw := create_tween()
	for i in range(steps):
		var sign: int = 1 if (i % 2 == 0) else -1
		var amp: float = amplitude * (1.0 - float(i) / float(steps))
		tw.tween_callback(_apply_shake_offset.bind(Vector2(sign * amp, 0))).set_delay(SHAKE_STEP)
	tw.tween_callback(_apply_shake_offset.bind(Vector2.ZERO))
	tw.tween_callback(_clear_shaking)


func _apply_shake_offset(off: Vector2) -> void:
	if _shake_target == null:
		return
	if _shake_target is Node2D:
		(_shake_target as Node2D).position = _shake_base_offset + off
	elif _shake_target is Control:
		(_shake_target as Control).position = _shake_base_offset + off


func _clear_shaking() -> void:
	_shaking = false


# --- Auto-triggered reactions ---

func _on_entity_died(_entity) -> void:
	flash_red(0.45)
	shake(6.0, 0.30)


func _on_cohesion_changed(new_value: float) -> void:
	if _last_cohesion < 0.0:
		_last_cohesion = new_value
		return
	var delta: float = new_value - _last_cohesion
	_last_cohesion = new_value
	# Only react to significant negative changes (>=10 points dropped)
	if delta <= -10.0:
		flash_red(0.40)


# Called from outside (e.g., Main) on any moment we want extra feedback.
func planet_damage_taken(amount: float) -> void:
	if amount <= 0.0:
		return
	var intensity: float = clampf(amount / 25.0, 0.25, 0.85)
	flash_red(intensity)
	shake(minf(amount, 12.0), 0.35)
