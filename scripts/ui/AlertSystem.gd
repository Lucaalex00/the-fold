extends CanvasLayer

signal alert_finished(event)

enum AlertType { NOTIFY, WARNING, CRITICAL, FATAL }

const FRAMES_DIR = "res://assets/alerts/frames/"
const SHEET_VARIANT = "alert_01"
const DISPLAY_WIDTH = 293
const DISPLAY_HEIGHT = 159
const DISPLAY_X = 48.5
const TOPBAR_Y = 52.0

const TYPE_NAME = {
	AlertType.FATAL:    "fatal",
	AlertType.CRITICAL: "critical",
	AlertType.WARNING:  "warning",
	AlertType.NOTIFY:   "notify",
}
const HOLD_TIME = {
	AlertType.NOTIFY:   1.2,
	AlertType.WARNING:  1.5,
	AlertType.CRITICAL: 1.8,
	AlertType.FATAL:    2.2,
}
const TYPE_COLOR = {
	AlertType.NOTIFY:   Vector3(0.1, 0.4, 1.0),
	AlertType.WARNING:  Vector3(1.0, 0.75, 0.0),
	AlertType.CRITICAL: Vector3(0.85, 0.0, 0.0),
	AlertType.FATAL:    Vector3(0.85, 0.0, 0.0),
}

var _queue: Array = []
var _busy: bool = false
var _current_item: Dictionary = {}
var _container: Control
var _sprite: TextureRect
var _vignette: Control = null
var _vignette_mat: ShaderMaterial = null


func _ready() -> void:
	layer = 75

	_vignette = Control.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_build_vignette()

	_container = Control.new()
	_container.position = Vector2(DISPLAY_X, TOPBAR_Y - DISPLAY_HEIGHT)
	_container.size = Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.modulate.a = 0.0
	add_child(_container)

	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.size = Vector2(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_sprite)


func _build_vignette() -> void:
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = load("res://assets/shaders/vignette.gdshader")
	var rect = ColorRect.new()
	rect.material = _vignette_mat
	rect.position = Vector2.ZERO
	rect.size = Vector2(390, 844)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.add_child(rect)


func notify(message: String = "") -> void:
	_enqueue(AlertType.NOTIFY, null)

func warning(message: String = "") -> void:
	_enqueue(AlertType.WARNING, null)

func critical(message: String = "") -> void:
	_enqueue(AlertType.CRITICAL, null)

func fatal(message: String = "") -> void:
	_enqueue(AlertType.FATAL, null)

func notify_event(event) -> void:
	_enqueue(AlertType.NOTIFY, event)

func warning_event(event) -> void:
	_enqueue(AlertType.WARNING, event)

func critical_event(event) -> void:
	_enqueue(AlertType.CRITICAL, event)

func fatal_event(event) -> void:
	_enqueue(AlertType.FATAL, event)


func _enqueue(type: AlertType, event) -> void:
	_queue.append({type = type, event = event})
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_current_item = _queue.pop_front()
	_set_frame(_current_item.type)
	_play_fx(_current_item.type)

	var hold = HOLD_TIME[_current_item.type]
	var tw = create_tween()
	tw.tween_property(_container, "position", Vector2(DISPLAY_X, TOPBAR_Y), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_container, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hold)
	tw.tween_property(_container, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(_container, "position", Vector2(DISPLAY_X, TOPBAR_Y - DISPLAY_HEIGHT), 0.2)
	tw.tween_callback(_on_banner_done)


func _play_fx(type: AlertType) -> void:
	var col: Vector3 = TYPE_COLOR[type]
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("vignette_color", col)

	match type:
		AlertType.NOTIFY:
			_play_vignette_pulses(1, 0.45)
		AlertType.WARNING:
			_play_vignette_pulses(2, 0.5)
		AlertType.CRITICAL:
			_play_vignette_pulses(2, 0.55)
		AlertType.FATAL:
			_play_fatal_vignette()


func _play_vignette_pulses(count: int, peak: float) -> void:
	var tw = create_tween()
	for i in range(count):
		tw.tween_property(_vignette, "modulate:a", peak, 0.07)
		tw.tween_property(_vignette, "modulate:a", 0.0, 0.15)
		if i < count - 1:
			tw.tween_interval(0.05)


func _play_fatal_vignette() -> void:
	var tw = create_tween()
	tw.tween_property(_vignette, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(_vignette, "modulate:a", 0.4, 0.4)
	tw.tween_interval(0.4)
	tw.tween_property(_vignette, "modulate:a", 0.75, 0.3)
	tw.tween_interval(0.3)
	tw.tween_property(_vignette, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_frame(type: AlertType) -> void:
	var name = TYPE_NAME[type]
	var path = FRAMES_DIR + SHEET_VARIANT + "_" + name + ".png"
	_sprite.texture = load(path)


func _on_banner_done() -> void:
	_container.position = Vector2(DISPLAY_X, TOPBAR_Y - DISPLAY_HEIGHT)
	_container.modulate.a = 0.0
	var finished_event = _current_item.get("event", null)
	_current_item = {}
	alert_finished.emit(finished_event)
	_show_next()
