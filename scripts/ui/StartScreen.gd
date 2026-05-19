extends Control

@onready var video: VideoStreamPlayer = $Video
@onready var fade: ColorRect = $FadeOverlay

var _can_interact: bool = false


func _ready() -> void:
	fade.modulate.a = 1.0
	video.play()
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): _can_interact = true)
	video.finished.connect(_on_video_finished)


func _on_video_finished() -> void:
	video.play()


func _input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if event is InputEventMouseButton and event.pressed:
		_go_to_game()
	elif event is InputEventScreenTouch and event.pressed:
		_go_to_game()


func _go_to_game() -> void:
	_can_interact = false
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.8)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main/Main.tscn"))
