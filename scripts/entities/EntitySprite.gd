extends Node2D

signal layer_transitioned

const SPRITESHEET_PATH = "res://assets/entities/spritesheet.png"
const HFRAMES = 8
const VFRAMES = 4
const ENTITY_SCALE = Vector2(0.09, 0.09)
const BASE_SCALE_MULT = 2.0
const LIFT_SCALE_MULT = 3.2

const PLANET_CENTER = Vector2(195.0, 370.0)
const WALK_RADIUS_X = 140.0
const WALK_RADIUS_Y = 55.0
const LAYER_THRESHOLD_X = 125.0
const LAYER_COUNT = 6

const MOVE_SPEED = 18.0
const IDLE_MIN = 1.5
const IDLE_MAX = 4.5

var data: GameState.EntityData
var _sprite: Sprite2D
var _size_mod: float = 1.0
var _move_target: Vector2
var _is_moving: bool = false
var _timer: float = 0.0
var _is_lifted: bool = false


func setup(entity_data: GameState.EntityData, screen_pos: Vector2) -> void:
	data = entity_data
	position = screen_pos
	_move_target = screen_pos
	_build_sprite()
	_timer = randf_range(0.5, 3.0)


func _build_sprite() -> void:
	_size_mod = data.dna.get("size_modifier", 1.0)
	var tex = load(SPRITESHEET_PATH) as Texture2D
	if not tex:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = HFRAMES
	_sprite.vframes = VFRAMES
	_sprite.frame = data.dna.get("body_shape", 0)
	_sprite.scale = ENTITY_SCALE * _size_mod * BASE_SCALE_MULT
	_sprite.centered = true
	add_child(_sprite)


func lift() -> void:
	_is_lifted = true
	_is_moving = false
	_timer = 9999.0
	if _sprite:
		var tw = create_tween()
		tw.tween_property(_sprite, "scale", ENTITY_SCALE * _size_mod * LIFT_SCALE_MULT, 0.15)


func drop() -> void:
	_is_lifted = false
	_timer = randf_range(IDLE_MIN, IDLE_MAX)
	if _sprite:
		_update_perspective()


func _process(delta: float) -> void:
	if not visible or not _sprite or _is_lifted:
		return
	_timer -= delta
	if _is_moving:
		_step_toward_target(delta)
	elif _timer <= 0.0:
		_pick_target()
	_update_perspective()


func _step_toward_target(delta: float) -> void:
	var diff = _move_target - position
	var dist = diff.length()
	var step = MOVE_SPEED * delta
	if step >= dist:
		position = _move_target
		_is_moving = false
		_timer = randf_range(IDLE_MIN, IDLE_MAX)
	else:
		position += diff.normalized() * step
	_check_layer_edge()


func _pick_target() -> void:
	var x = randf_range(PLANET_CENTER.x - WALK_RADIUS_X, PLANET_CENTER.x + WALK_RADIUS_X)
	var y = randf_range(PLANET_CENTER.y - WALK_RADIUS_Y, PLANET_CENTER.y + WALK_RADIUS_Y)
	_move_target = Vector2(x, y)
	_is_moving = true


func _update_perspective() -> void:
	var t = 1.0 - abs(position.x - PLANET_CENTER.x) / LAYER_THRESHOLD_X
	var scale_factor = lerp(0.8, 1.2, clamp(t, 0.0, 1.0))
	_sprite.scale = ENTITY_SCALE * _size_mod * BASE_SCALE_MULT * scale_factor


func _check_layer_edge() -> void:
	var dist_x = position.x - PLANET_CENTER.x
	if dist_x < -LAYER_THRESHOLD_X:
		data.layer = (data.layer - 1 + LAYER_COUNT) % LAYER_COUNT
		position.x = PLANET_CENTER.x + LAYER_THRESHOLD_X - 35.0
		position.y = randf_range(PLANET_CENTER.y - WALK_RADIUS_Y * 0.5, PLANET_CENTER.y + WALK_RADIUS_Y * 0.5)
		_is_moving = false
		_timer = randf_range(0.3, 1.2)
		layer_transitioned.emit()
	elif dist_x > LAYER_THRESHOLD_X:
		data.layer = (data.layer + 1) % LAYER_COUNT
		position.x = PLANET_CENTER.x - LAYER_THRESHOLD_X + 35.0
		position.y = randf_range(PLANET_CENTER.y - WALK_RADIUS_Y * 0.5, PLANET_CENTER.y + WALK_RADIUS_Y * 0.5)
		_is_moving = false
		_timer = randf_range(0.3, 1.2)
		layer_transitioned.emit()


func refresh_visibility(view_layer: int) -> void:
	visible = data != null and data.is_alive and data.layer == view_layer
