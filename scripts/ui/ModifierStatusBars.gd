extends CanvasLayer

signal bar_clicked(modifier_id: String)

const BAR_W: float = 110.0
const BAR_H: float = 24.0
const POS_START_X: float = 8.0
const POS_START_Y: float = 92.0  # below DivineEnergyChip
const BAR_GAP: float = 4.0

# modifier_id → { container, fill, label }
var _bars: Dictionary = {}


func _ready() -> void:
	layer = 65
	WorldModifierSystem.modifier_changed.connect(_rebuild)
	_rebuild()


func _process(_delta: float) -> void:
	var now: int = Time.get_unix_time_from_system()
	for modifier_id in _bars.keys():
		var bar_data: Dictionary = _bars[modifier_id] as Dictionary
		var m: WorldModifierSystem.WorldModifier = WorldModifierSystem.get_modifier(modifier_id)
		if m == null:
			continue
		var progress: float = m.cure_progress(now)
		var fill: ColorRect = bar_data["fill"] as ColorRect
		fill.size.x = (BAR_W - 4.0) * progress
		var label: Label = bar_data["label"] as Label
		var remaining_s: float = m.remaining_seconds(now)
		var h: int = int(remaining_s) / 3600
		var min_: int = (int(remaining_s) % 3600) / 60
		label.text = "%s  %02dh %02dm" % [_modifier_title(modifier_id), h, min_]


func _rebuild() -> void:
	# Clear existing bars
	for bar_data in _bars.values():
		var node: Control = bar_data["container"] as Control
		if is_instance_valid(node):
			node.queue_free()
	_bars.clear()

	var active: Array = WorldModifierSystem.active_modifiers
	for i in range(active.size()):
		var m: WorldModifierSystem.WorldModifier = active[i]
		var bar := _build_bar(m, i)
		add_child(bar)


func _modifier_title(modifier_id: String) -> String:
	var def: Dictionary = WorldModifierSystem.DEFINITIONS.get(modifier_id, {})
	return String(def.get("title", modifier_id))


func _modifier_color(modifier_id: String) -> Color:
	var def: Dictionary = WorldModifierSystem.DEFINITIONS.get(modifier_id, {})
	var arr: Array = def.get("icon_color", [1, 1, 1, 1])
	return Color(arr[0], arr[1], arr[2], arr[3])


func _build_bar(m: WorldModifierSystem.WorldModifier, index: int) -> Control:
	var color: Color = _modifier_color(m.id)

	var container := PanelContainer.new()
	container.position = Vector2(POS_START_X, POS_START_Y + float(index) * (BAR_H + BAR_GAP))
	container.custom_minimum_size = Vector2(BAR_W, BAR_H)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	container.add_theme_stylebox_override("panel", style)

	# Cure-progress fill (behind label)
	var fill := ColorRect.new()
	fill.color = Color(color.r, color.g, color.b, 0.35)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(0, BAR_H - 4)
	container.add_child(fill)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(label)

	# Click overlay
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): bar_clicked.emit(m.id))
	container.add_child(btn)

	_bars[m.id] = {"container": container, "fill": fill, "label": label}
	return container
