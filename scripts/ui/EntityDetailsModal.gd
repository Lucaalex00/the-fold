extends CanvasLayer

# Tap an entity on the planet → this modal slides in showing its avatar,
# current HP, age, trait, generation, and a sorted list of all stats.
# Outside click → close. Click inside the panel → stays.

signal closed

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const PANEL_W: float = 320.0
const ANIM_TIME: float = 0.22
const AVATAR_SIZE: float = 96.0

const SPRITESHEET_PATH = "res://assets/entities/spritesheet.png"
const HFRAMES = 8
const VFRAMES = 4

const STAT_ORDER: Array = [
	"health", "energy", "intelligence",
	"attack", "construction", "harvest",
	"fishing", "research", "diplomacy",
]
const STAT_ICONS: Dictionary = {
	"health": "❤", "energy": "⚡", "intelligence": "🧠",
	"attack": "⚔", "construction": "🏗", "harvest": "🌾",
	"fishing": "🎣", "research": "🔬", "diplomacy": "🤝",
}

var _blocker: ColorRect
var _panel: PanelContainer
var _avatar: TextureRect
var _name_label: Label
var _meta_label: Label
var _stats_box: VBoxContainer
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _shown_entity = null


func _ready() -> void:
	layer = 72
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 10)
	_panel.size = Vector2(PANEL_W, 10)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP   # absorbs taps inside the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.11, 0.97)
	style.border_color = Color(0.35, 0.3, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header: avatar + name/meta side by side
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	_avatar = TextureRect.new()
	_avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(_avatar)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 4)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_box.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.add_theme_font_size_override("font_size", 11)
	_meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_box.add_child(_meta_label)

	vbox.add_child(HSeparator.new())

	# HP bar
	var hp_caption := Label.new()
	hp_caption.text = "Health"
	hp_caption.add_theme_font_size_override("font_size", 11)
	hp_caption.add_theme_color_override("font_color", Color(0.65, 0.65, 0.8))
	vbox.add_child(hp_caption)

	var hp_holder := Control.new()
	hp_holder.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(hp_holder)

	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	_hp_bg.position = Vector2.ZERO
	_hp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_holder.add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.85, 0.2, 0.2)
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(0, 20)
	hp_holder.add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_holder.add_child(_hp_label)

	vbox.add_child(HSeparator.new())

	# Stats list
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_box)


func show_entity(entity_data) -> void:
	if entity_data == null:
		return
	_shown_entity = entity_data
	_populate(entity_data)
	visible = true
	# Animate in
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame
	await get_tree().process_frame
	_center_panel()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, ANIM_TIME)
	tw.tween_property(_panel, "scale", Vector2.ONE, ANIM_TIME)


func _populate(entity) -> void:
	# Avatar — pick the entity's frame from the spritesheet
	var tex: Texture2D = load(SPRITESHEET_PATH) as Texture2D
	if tex:
		var body_shape: int = int(entity.dna.get("body_shape", 0))
		var frame_w: float = float(tex.get_width()) / float(HFRAMES)
		var frame_h: float = float(tex.get_height()) / float(VFRAMES)
		var col: int = body_shape % HFRAMES
		var row: int = body_shape / HFRAMES
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		_avatar.texture = atlas

	_name_label.text = String(entity.name) if entity.name != "" else "Unnamed"
	var trait_name: String = String(entity.trait_primary).capitalize()
	_meta_label.text = "%s · Gen %d · Age %d" % [trait_name, int(entity.generation), int(entity.age_years)]

	# HP bar — entity health as ratio of era stat cap (visual reference)
	var hp: int = int(entity.stats.get("health", 0))
	var cap: int = GameState.get_stat_cap()
	var ratio: float = clampf(float(hp) / float(maxi(cap, 1)), 0.0, 1.0)
	_hp_fill.size.x = _hp_bg.size.x * ratio if _hp_bg.size.x > 0 else 0
	_hp_label.text = "%d / %d" % [hp, cap]
	# Color: green > 60%, yellow 30-60%, red < 30%
	if ratio > 0.6:
		_hp_fill.color = Color(0.3, 0.85, 0.4)
	elif ratio > 0.3:
		_hp_fill.color = Color(0.95, 0.75, 0.25)
	else:
		_hp_fill.color = Color(0.85, 0.2, 0.2)

	# Stats list — descending by value
	for child in _stats_box.get_children():
		child.queue_free()
	var sorted_stats: Array = []
	for s in STAT_ORDER:
		sorted_stats.append([s, int(entity.stats.get(s, 0))])
	sorted_stats.sort_custom(func(a, b): return a[1] > b[1])
	for pair in sorted_stats:
		var stat_name: String = pair[0]
		var val: int = pair[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		var icon: String = String(STAT_ICONS.get(stat_name, ""))
		name_lbl.text = "%s %s" % [icon, stat_name.capitalize()]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
		var val_lbl := Label.new()
		val_lbl.text = str(val)
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		row.add_child(name_lbl)
		row.add_child(val_lbl)
		_stats_box.add_child(row)


func _center_panel() -> void:
	# Refresh HP fill width after layout settled
	var hp_holder: Control = _hp_bg.get_parent() as Control
	if hp_holder and hp_holder.size.x > 0:
		_hp_bg.size = Vector2(hp_holder.size.x, 20)
		var ratio: float = 0.0 if _hp_label.text == "" else float(_hp_label.text.split(" / ")[0].to_int()) / float(maxi(_hp_label.text.split(" / ")[1].to_int(), 1))
		_hp_fill.size = Vector2(hp_holder.size.x * ratio, 20)
	var ph: float = _panel.size.y
	_panel.position = Vector2((SCREEN_W - PANEL_W) * 0.5, max(80.0, (SCREEN_H - ph) * 0.5))
	_panel.pivot_offset = Vector2(PANEL_W * 0.5, ph * 0.5)


func _on_blocker_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap or is_touch:
		_close()


func _close() -> void:
	if not visible:
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "modulate:a", 0.0, ANIM_TIME * 0.8)
	tw.tween_property(_panel, "scale", Vector2(0.94, 0.94), ANIM_TIME * 0.8)
	tw.chain().tween_callback(_finalize_close)


func _finalize_close() -> void:
	visible = false
	_shown_entity = null
	closed.emit()
