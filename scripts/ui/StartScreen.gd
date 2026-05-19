extends Control

@onready var background: TextureRect = $Background
@onready var fade: ColorRect = $FadeOverlay

const FRAME_COUNT = 72
const FPS = 12.5

var _frames: Array = []
var _current_frame: int = 0
var _timer: Timer
var _can_interact: bool = false


func _ready() -> void:
	for i in range(1, FRAME_COUNT + 1):
		_frames.append(load("res://assets/ui/splash_frames/frame_%04d.png" % i))
	background.texture = _frames[0]

	_timer = Timer.new()
	_timer.wait_time = 1.0 / FPS
	_timer.autostart = true
	_timer.timeout.connect(_next_frame)
	add_child(_timer)

	fade.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): _can_interact = true)


func _next_frame() -> void:
	_current_frame = (_current_frame + 1) % FRAME_COUNT
	background.texture = _frames[_current_frame]


func _input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if event is InputEventMouseButton and event.pressed:
		_go_to_game()
	elif event is InputEventScreenTouch and event.pressed:
		_go_to_game()


func _go_to_game() -> void:
	_can_interact = false
	_timer.stop()
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.8)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main/Main.tscn"))
