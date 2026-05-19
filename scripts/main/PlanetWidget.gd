extends Control

signal layer_changed(layer_index: int)

const LAYER_COUNT = 6
const CORNER_POS = Vector2(0, 850)
const EXPANDED_POS = Vector2(195, 422)
const CORNER_SCALE = Vector2(2, 2)
const EXPANDED_SCALE = Vector2(3, 3)

var _is_expanded: bool = false
var _view_layer: int = 0
var _drag_start_x: float = 0.0
var _is_dragging: bool = false
var _did_drag: bool = false
var _planet_sprite: Sprite2D

@onready var expanded_panel: Control = $ExpandedPanel
@onready var layer_dots: HBoxContainer = $ExpandedPanel/LayerDots
@onready var facing_label: Label = $ExpandedPanel/FacingLabel


func setup(sprite: Sprite2D, texture: Texture2D) -> void:
	_planet_sprite = sprite
	_planet_sprite.texture = texture
	_planet_sprite.hframes = 16
	_planet_sprite.vframes = 1
	_planet_sprite.frame = 0
	_planet_sprite.centered = true
	_to_corner(false)
	_start_rotation()


func _start_rotation() -> void:
	var timer := Timer.new()
	timer.wait_time = 10.0 / 16.0
	timer.autostart = true
	timer.timeout.connect(_on_rotation_tick)
	add_child(timer)


func _on_rotation_tick() -> void:
	if _planet_sprite:
		_planet_sprite.frame = (_planet_sprite.frame + 1) % 16


func _to_corner(animated: bool) -> void:
	_is_expanded = false
	if _planet_sprite:
		if animated:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(_planet_sprite, "position", CORNER_POS, 0.4)
			tw.parallel().tween_property(_planet_sprite, "scale", CORNER_SCALE, 0.4)
			tw.parallel().tween_property(expanded_panel, "modulate:a", 0.0, 0.2)
			tw.tween_callback(func(): expanded_panel.visible = false)
		else:
			_planet_sprite.position = CORNER_POS
			_planet_sprite.scale = CORNER_SCALE
			expanded_panel.visible = false
	else:
		expanded_panel.visible = false


func _to_expanded() -> void:
	_is_expanded = true
	if _planet_sprite:
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_planet_sprite, "position", EXPANDED_POS, 0.4)
		tw.parallel().tween_property(_planet_sprite, "scale", EXPANDED_SCALE, 0.4)
	expanded_panel.modulate.a = 0.0
	expanded_panel.visible = true
	var tw2 = create_tween()
	tw2.tween_property(expanded_panel, "modulate:a", 1.0, 0.3)
	facing_label.text = "FRONT: %d" % (GameState.facing_layer + 1)
	_update_dots()


func _update_dots() -> void:
	for i in range(layer_dots.get_child_count()):
		layer_dots.get_child(i).modulate.a = 1.0 if i == _view_layer else 0.25


func _is_on_planet(pos: Vector2) -> bool:
	if not _planet_sprite:
		return false
	var radius = 50.0 * _planet_sprite.scale.x
	return pos.distance_to(_planet_sprite.position) <= radius


func _gui_input(event: InputEvent) -> void:
	var pos: Vector2
	var is_press := false
	var is_release := false
	var is_motion := false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
		is_motion = true

	if is_press:
		_drag_start_x = pos.x
		_is_dragging = true
		_did_drag = false

	elif is_release:
		_is_dragging = false
		if not _did_drag:
			if not _is_expanded:
				# corner: tap must land on the sphere
				if _is_on_planet(pos):
					_to_expanded()
					get_viewport().set_input_as_handled()
			else:
				# expanded: tap outside the sphere closes (modal)
				if not _is_on_planet(pos):
					_to_corner(true)
					get_viewport().set_input_as_handled()

	elif is_motion and _is_dragging and _is_expanded:
		var delta = pos.x - _drag_start_x
		if abs(delta) > 50:
			_did_drag = true
			_view_layer = (_view_layer + (1 if delta < 0 else -1) + LAYER_COUNT) % LAYER_COUNT
			_drag_start_x = pos.x
			_update_dots()
			layer_changed.emit(_view_layer)
