extends Control

@onready var bg: TextureRect = $Background
@onready var fade: ColorRect = $FadeOverlay

var _can_interact: bool = false


func _ready() -> void:
	fade.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): _can_interact = true)
	_start_pulse()


func _start_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(bg, "modulate:a", 0.82, 1.4)
	tween.tween_property(bg, "modulate:a", 1.0, 1.4)


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
