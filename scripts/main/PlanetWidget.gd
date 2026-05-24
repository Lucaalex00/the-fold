extends Control

signal layer_changed(layer_index: int)
signal entity_tapped(entity_data)

const LAYER_COUNT = 6
const GAMEPLAY_FRAMES = [0, 3, 6, 9, 12, 15]
const CORNER_POS = Vector2(0, 850)
const EXPANDED_POS = Vector2(195, 370)
const CORNER_SCALE = Vector2(2, 2)
const EXPANDED_SCALE = Vector2(3, 3)

const EntitySpriteScript = preload("res://scripts/entities/EntitySprite.gd")

# Scatter positions relative to EXPANDED_POS — inside the 150px planet circle
const ENTITY_OFFSETS = [
	Vector2(-52, 38), Vector2(44, 55), Vector2(-30, -48), Vector2(58, -18),
	Vector2(-62, -8), Vector2(18, 78), Vector2(68, 28), Vector2(-14, 72),
	Vector2(35, -62), Vector2(-45, 60), Vector2(72, -40), Vector2(-70, 30),
]

const LONG_PRESS_SECS = 0.5
const ENTITY_HIT_RADIUS = 22.0
const LAYER_DRAG_INTERVAL = 1.0
const PLANET_DRAG_RADIUS = 145.0

var _is_expanded: bool = false
var _view_layer: int = 0
var _drag_start_x: float = 0.0
var _is_dragging: bool = false
var _did_drag: bool = false
var _layer_changed_this_drag: bool = false
var _rotation_paused: bool = false
var _rotation_timer: Timer
var _planet_sprite: Sprite2D
var _entity_sprites: Array = []
var _pressed_entity = null
var _long_press_elapsed: float = 0.0
var _is_dragging_entity: bool = false
var _drag_entity_direction: int = 0
var _drag_entity_layer_timer: float = 0.0
var _rotation_resume_timer: float = 0.0
var _overlay: ColorRect = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_label: Label = null

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
	_build_entity_sprites()
	if not BubbleSystem.bubble_requested.is_connected(_on_bubble_requested):
		BubbleSystem.bubble_requested.connect(_on_bubble_requested)


func _build_entity_sprites() -> void:
	for es in _entity_sprites:
		if is_instance_valid(es):
			es.queue_free()
	_entity_sprites.clear()

	var all_entities = GameState.entities
	for i in range(all_entities.size()):
		var entity_data = all_entities[i]
		var es = EntitySpriteScript.new()
		var offset = ENTITY_OFFSETS[i % ENTITY_OFFSETS.size()]
		es.z_index = 10
		es.setup(entity_data, EXPANDED_POS + offset)
		get_parent().add_child(es)
		es.visible = false
		es.layer_transitioned.connect(_on_entity_layer_transitioned)
		_entity_sprites.append(es)


func refresh_entities() -> void:
	_build_entity_sprites()
	if _is_expanded:
		_show_entities()


func _show_entities() -> void:
	for es in _entity_sprites:
		if is_instance_valid(es):
			es.refresh_visibility(_view_layer)


func _hide_entities() -> void:
	for es in _entity_sprites:
		if is_instance_valid(es):
			es.visible = false


func _start_rotation() -> void:
	# Auto-rotation is purely decorative when the planet is in CORNER mode.
	# 30s per full rotation (16 frames @ 1.875s each). Paused while expanded.
	_rotation_timer = Timer.new()
	_rotation_timer.wait_time = 30.0 / 16.0
	_rotation_timer.autostart = true
	_rotation_timer.timeout.connect(_on_rotation_tick)
	add_child(_rotation_timer)


func _on_entity_layer_transitioned() -> void:
	if _is_expanded:
		_show_entities()


func _on_rotation_tick() -> void:
	# Auto-rotation only happens while the planet is in CORNER mode (no entities
	# rendered). When the player opens the planet (_is_expanded) we pause so the
	# entities stay on a single, stable layer without flicker.
	if _rotation_paused or _is_expanded or not _planet_sprite:
		return
	_planet_sprite.frame = (_planet_sprite.frame + 1) % 16
	# Track the facing layer silently so cosmic events still know what's exposed,
	# but DON'T touch entities (they aren't visible in corner mode anyway).
	var idx: int = GAMEPLAY_FRAMES.find(_planet_sprite.frame)
	if idx != -1:
		_view_layer = idx
		facing_label.text = "LAYER: %d / %d" % [_view_layer + 1, LAYER_COUNT]
		_update_dots()
		layer_changed.emit(_view_layer)


func pause_rotation() -> void:
	_rotation_paused = true


func resume_rotation() -> void:
	_rotation_paused = false


func _process(delta: float) -> void:
	if _pressed_entity and not _is_dragging_entity:
		_long_press_elapsed += delta
		if _long_press_elapsed >= LONG_PRESS_SECS:
			_start_entity_drag()
	if _is_dragging_entity and _drag_entity_direction != 0:
		_drag_entity_layer_timer += delta
		if _drag_entity_layer_timer >= LAYER_DRAG_INTERVAL:
			_drag_entity_layer_timer = 0.0
			_advance_dragged_entity_layer()
	if _rotation_paused and not _is_dragging_entity and not _pressed_entity:
		_rotation_resume_timer -= delta
		if _rotation_resume_timer <= 0.0:
			resume_rotation()


func _snap_to_layer(layer_idx: int) -> void:
	_view_layer = layer_idx
	facing_label.text = "LAYER: %d / %d" % [_view_layer + 1, LAYER_COUNT]
	var target: int = GAMEPLAY_FRAMES[_view_layer]
	if not _planet_sprite:
		return
	var current := _planet_sprite.frame
	if current == target:
		_show_entities()
		return
	# Hide entities while we're tweening through transition frames
	_hide_entities()
	var fwd := (target - current + 16) % 16
	var bwd := (current - target + 16) % 16
	var tw := create_tween()
	if fwd <= bwd:
		for i in range(fwd):
			var f := (current + i + 1) % 16
			tw.tween_callback(_set_frame_and_sync.bind(f)).set_delay(10.0 / 16.0 * 0.25)
	else:
		for i in range(bwd):
			var f := (current - i - 1 + 16) % 16
			tw.tween_callback(_set_frame_and_sync.bind(f)).set_delay(10.0 / 16.0 * 0.25)


func _set_frame_and_sync(fr: int) -> void:
	# Used by _snap_to_layer's tween. Hides entities during transition frames,
	# shows them when landing on a gameplay frame. _snap_to_layer is only ever
	# called while the planet is expanded.
	if _planet_sprite:
		_planet_sprite.frame = fr
	if not _planet_sprite:
		return
	var idx: int = GAMEPLAY_FRAMES.find(_planet_sprite.frame)
	if idx != -1:
		_view_layer = idx
		facing_label.text = "LAYER: %d / %d" % [_view_layer + 1, LAYER_COUNT]
		_update_dots()
		_show_entities()
		layer_changed.emit(_view_layer)
	else:
		_hide_entities()


func _to_corner(animated: bool) -> void:
	_is_expanded = false
	_destroy_overlay()
	_destroy_hp_bar()
	_hide_entities()
	# Resume background rotation (decorative — no entities visible in corner)
	resume_rotation()
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
	# Freeze the rotation while the planet is open — the player needs the
	# entities of one stable layer, not a flickering carousel.
	pause_rotation()
	# Make sure the sprite is on a gameplay frame matching _view_layer so
	# the entities for that layer are visible immediately.
	if _planet_sprite:
		_planet_sprite.frame = GAMEPLAY_FRAMES[_view_layer]
	_create_overlay()
	_create_hp_bar()
	if _planet_sprite:
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_planet_sprite, "position", EXPANDED_POS, 0.5)
		tw.parallel().tween_property(_planet_sprite, "scale", EXPANDED_SCALE, 0.5)
	expanded_panel.modulate.a = 0.0
	expanded_panel.visible = true
	var tw2 = create_tween()
	tw2.tween_property(expanded_panel, "modulate:a", 1.0, 0.4)
	facing_label.text = "LAYER: %d / %d" % [_view_layer + 1, LAYER_COUNT]
	_update_dots()
	await get_tree().create_timer(0.5).timeout
	if not _is_expanded:
		return
	_show_entities()


func _update_dots() -> void:
	for i in range(layer_dots.get_child_count()):
		layer_dots.get_child(i).modulate.a = 1.0 if i == _view_layer else 0.25


func _is_on_planet(pos: Vector2) -> bool:
	if not _planet_sprite:
		return false
	var radius = 50.0 * _planet_sprite.scale.x
	return pos.distance_to(_planet_sprite.position) <= radius


func is_planet_expanded() -> bool:
	return _is_expanded


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
		_pressed_entity = _entity_at(pos)
		if _pressed_entity:
			_drag_start_x = pos.x
			_long_press_elapsed = 0.0
		else:
			_drag_start_x = pos.x
			_is_dragging = true
			_did_drag = false
			_layer_changed_this_drag = false

	elif is_release:
		if _is_dragging_entity:
			if is_instance_valid(_pressed_entity):
				var outside = _pressed_entity.position.distance_to(EXPANDED_POS) > PLANET_DRAG_RADIUS
				if outside:
					var offset = ENTITY_OFFSETS[randi() % ENTITY_OFFSETS.size()]
					_pressed_entity.position = EXPANDED_POS + offset
			_cancel_entity_drag()
			get_viewport().set_input_as_handled()
			return
		if _pressed_entity:
			# Quick tap (no long-press, no drag) → request entity details modal
			if is_instance_valid(_pressed_entity) and _pressed_entity.data != null and _long_press_elapsed < LONG_PRESS_SECS:
				entity_tapped.emit(_pressed_entity.data)
			_pressed_entity = null
			_long_press_elapsed = 0.0
			return
		_is_dragging = false
		if not _did_drag:
			if not _is_expanded:
				if _is_on_planet(pos):
					_to_expanded()
					get_viewport().set_input_as_handled()
			else:
				if not _is_on_planet(pos):
					_to_corner(true)
					get_viewport().set_input_as_handled()

	elif is_motion:
		if _is_dragging_entity:
			if is_instance_valid(_pressed_entity):
				_pressed_entity.position = pos
				var dist = pos.distance_to(EXPANDED_POS)
				if dist > PLANET_DRAG_RADIUS:
					_drag_entity_direction = -1 if pos.x < EXPANDED_POS.x else 1
				else:
					_drag_entity_direction = 0
			get_viewport().set_input_as_handled()
			return
		if _is_dragging and _is_expanded:
			var delta = pos.x - _drag_start_x
			if abs(delta) > 50 and not _layer_changed_this_drag:
				_did_drag = true
				_layer_changed_this_drag = true
				pause_rotation()
				_rotation_resume_timer = 4.0
				var next := (_view_layer + (1 if delta < 0 else -1) + LAYER_COUNT) % LAYER_COUNT
				_snap_to_layer(next)
				_update_dots()
				layer_changed.emit(_view_layer)


func _entity_at(pos: Vector2):
	if not _is_expanded:
		return null
	for es in _entity_sprites:
		if is_instance_valid(es) and es.visible:
			if pos.distance_to(es.position) <= ENTITY_HIT_RADIUS:
				return es
	return null


func _start_entity_drag() -> void:
	_is_dragging_entity = true
	_drag_entity_layer_timer = 0.0
	_drag_entity_direction = 0
	pause_rotation()
	if is_instance_valid(_pressed_entity):
		_pressed_entity.lift()


func _cancel_entity_drag() -> void:
	if is_instance_valid(_pressed_entity):
		_pressed_entity.drop()
		_show_entities()
	_pressed_entity = null
	_is_dragging_entity = false
	_long_press_elapsed = 0.0
	_drag_entity_direction = 0
	_drag_entity_layer_timer = 0.0
	_rotation_resume_timer = 3.0


func _advance_dragged_entity_layer() -> void:
	if not is_instance_valid(_pressed_entity):
		_cancel_entity_drag()
		return
	var new_layer: int = (_pressed_entity.data.layer + _drag_entity_direction + LAYER_COUNT) % LAYER_COUNT
	_pressed_entity.data.layer = new_layer
	_snap_to_layer(new_layer)
	_update_dots()
	layer_changed.emit(_view_layer)


func _create_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.position = Vector2(0, 52)
	_overlay.size = Vector2(390, 792)
	get_parent().add_child(_overlay)
	get_parent().move_child(_overlay, 0)
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "color:a", 0.5, 0.5)


func _create_hp_bar() -> void:
	if _hp_bar_bg and is_instance_valid(_hp_bar_bg):
		return
	var bar_w := 180.0
	var bar_h := 5.0
	var bar_x := EXPANDED_POS.x - bar_w / 2.0
	var bar_y := EXPANDED_POS.y - 165.0

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.2, 0.03, 0.03, 0.9)
	_hp_bar_bg.position = Vector2(bar_x, bar_y)
	_hp_bar_bg.size = Vector2(bar_w, bar_h)
	get_parent().add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.88, 0.1, 0.1)
	_hp_bar_fill.position = Vector2(bar_x, bar_y)
	_hp_bar_fill.size = Vector2(bar_w, bar_h)
	get_parent().add_child(_hp_bar_fill)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))
	_hp_label.position = Vector2(bar_x, bar_y - 18.0)
	_hp_label.size = Vector2(bar_w, 16.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_parent().add_child(_hp_label)
	_refresh_hp_bar()


func _refresh_hp_bar() -> void:
	if not _hp_bar_fill or not is_instance_valid(_hp_bar_fill):
		return
	var ratio := GameState.get_planet_hp_ratio()
	var bar_w := 180.0
	_hp_bar_fill.size.x = bar_w * ratio
	var hp := int(GameState.get_planet_hp())
	var hp_max := int(GameState.get_planet_hp_max())
	_hp_label.text = "%d / %d HP" % [hp, hp_max]


func _destroy_hp_bar() -> void:
	for node in [_hp_bar_bg, _hp_bar_fill, _hp_label]:
		if node and is_instance_valid(node):
			node.queue_free()
	_hp_bar_bg = null
	_hp_bar_fill = null
	_hp_label = null


func _destroy_overlay() -> void:
	if not _overlay or not is_instance_valid(_overlay):
		return
	var ol := _overlay
	_overlay = null
	var tw = create_tween()
	tw.tween_property(ol, "color:a", 0.0, 0.2)
	tw.tween_callback(ol.queue_free)


# --- Bubble system bridge ---

const BUBBLE_TYPE_MAP: Dictionary = {
	"question":    0,  # BubbleLabel.BubbleType.QUESTION
	"exclamation": 1,
	"heart":       2,
	"sword":       3,
	"ellipsis":    4,
	"star":        5,
	"arrow_up":    6,
	"sparkle":     7,
	"skull":       8,
	"fish":        9,
	"wheat":       10,
	"hammer":      11,
	"book":        12,
}


func _on_bubble_requested(entity_data, bubble_type_string: String) -> void:
	if not _is_expanded:
		return
	# Find the entity's current visual position
	var spawn_pos: Vector2 = Vector2.ZERO
	var found: bool = false
	for es in _entity_sprites:
		if not is_instance_valid(es):
			continue
		if es.data == entity_data:
			spawn_pos = es.position
			found = true
			break
	if not found:
		return
	# Spawn the bubble on get_parent() (PlanetLayer) so it survives the entity
	# sprite being freed during refresh_entities() right after a death.
	var t: int = int(BUBBLE_TYPE_MAP.get(bubble_type_string, 1))
	var scene := load("res://scenes/ui/BubbleLabel.tscn")
	if scene == null:
		return
	var bubble: Node2D = scene.instantiate() as Node2D
	if bubble == null:
		return
	bubble.position = spawn_pos + Vector2(0, -40)
	bubble.z_index = 20
	get_parent().add_child(bubble)
	bubble.set_type(t)
