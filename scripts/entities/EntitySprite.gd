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
var _name_label: Label
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
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
	if not data.is_alive:
		_apply_dead_visual()
	GameState.entity_died.connect(_on_entity_died)


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
	_build_nameplate()


func _build_nameplate() -> void:
	_name_label = Label.new()
	_name_label.text = data.name if data else ""
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-20, -42)
	_name_label.size = Vector2(40, 12)
	add_child(_name_label)

	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.25, 0.04, 0.04, 0.9)
	_hp_bar_bg.position = Vector2(-14, -30)
	_hp_bar_bg.size = Vector2(28, 3)
	add_child(_hp_bar_bg)

	# HP bar fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.9, 0.12, 0.12)
	_hp_bar_fill.position = Vector2(-14, -30)
	_hp_bar_fill.size = Vector2(28, 3)
	add_child(_hp_bar_fill)
	_update_hp_bar()


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
	if not data:
		return
	if data.is_alive and (data.stats.get("health", 1) as int) <= 0:
		GameState.register_entity_death(data, "health_depleted")
	if not data.is_alive:
		_apply_dead_visual()
		return
	if not visible or not _sprite or _is_lifted:
		return
	_timer -= delta
	if _is_moving:
		_step_toward_target(delta)
	elif _timer <= 0.0:
		_pick_target()
	_update_perspective()


func _on_entity_died(entity_data: GameState.EntityData) -> void:
	if entity_data != data:
		return
	_apply_dead_visual()


func _apply_dead_visual() -> void:
	if not _sprite:
		return
	# Zombies (walking_dead active) stand upright + red.
	# Regular dead bodies lie horizontal + grey.
	if WorldModifierSystem.is_active("walking_dead"):
		_sprite.rotation = 0.0
		_sprite.modulate = Color(0.85, 0.25, 0.2, 0.85)
	else:
		_sprite.rotation = PI / 2.0
		_sprite.modulate = Color(0.35, 0.35, 0.35, 0.55)
	_is_moving = false
	_timer = 9999.0
	if _name_label:
		_name_label.modulate.a = 0.4
	if _hp_bar_bg:
		_hp_bar_bg.visible = false
	if _hp_bar_fill:
		_hp_bar_fill.visible = false


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
	if data == null:
		visible = false
		return
	visible = data.layer == view_layer
	if not visible:
		return
	if data.is_alive:
		if _sprite:
			_sprite.modulate = Color.WHITE
			_sprite.rotation = 0.0
		if _name_label:
			_name_label.modulate.a = 1.0
		if _hp_bar_bg:
			_hp_bar_bg.visible = true
		if _hp_bar_fill:
			_hp_bar_fill.visible = true
		_update_hp_bar()
	else:
		_apply_dead_visual()


func _update_hp_bar() -> void:
	if not _hp_bar_fill or not data:
		return
	var cap: float = float(GameState.ERA_STAT_CAP.get(GameState.current_era, 15) as int)
	var ratio: float = clamp(float(data.stats.get("health", 0) as int) / cap, 0.0, 1.0)
	_hp_bar_fill.size.x = 28.0 * ratio
