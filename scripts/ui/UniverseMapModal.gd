extends CanvasLayer

# Passive flow visualization: shows the journey to the Black Hole.
# Tap a planet to inspect it. Visiting only happens via encounter events,
# never from this map.

signal closed

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0

# Vertical flow geometry
const FLOW_TOP_Y: float = 130.0
const FLOW_LINE_BOTTOM_Y: float = SCREEN_H - 340.0  # where the timeline line ends
const BH_CENTER_Y: float = SCREEN_H - 290.0         # BH lives BELOW the line, separated
const FLOW_X: float = SCREEN_W * 0.5
const FLOW_THICKNESS: float = 2.0
const PLANET_NODE_DIAMETER: float = 30.0
const BH_DIAMETER: float = 72.0
const PLAYER_DIAMETER: float = 22.0

const FAR_DISTANCE: float = 1_000_000.0
const NEAR_DISTANCE: float = 0.0

# Pleasant palette cycled by planet index
const PLANET_PALETTE: Array = [
	Color(0.95, 0.55, 0.45),  # warm coral
	Color(0.55, 0.85, 0.95),  # sky teal
	Color(0.85, 0.75, 0.45),  # sand gold
	Color(0.75, 0.55, 0.95),  # lilac
	Color(0.45, 0.85, 0.65),  # sea green
	Color(0.95, 0.65, 0.85),  # rose
]

var _blocker: ColorRect
var _root: Control
var _flow_line: ColorRect
var _bh_holder: Control
var _bh_circle: PanelContainer
var _bh_label: Label
var _player_circle: PanelContainer
var _planet_entries: Array = []  # [{node, planet, ring, default_color}]
var _info_panel: PanelContainer
var _info_title: Label
var _info_body: Label
var _close_button: Button
var _universe_ref = null
var _selected = null
var _distance_label: Label


func _ready() -> void:
	layer = 70
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.02, 0.02, 0.05, 0.96)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- Header ---
	var title := Label.new()
	title.text = "JOURNEY TO THE VOID"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 1.0))
	title.position = Vector2(0, 64)
	title.size = Vector2(SCREEN_W, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	_distance_label = Label.new()
	_distance_label.add_theme_font_size_override("font_size", 11)
	_distance_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.85))
	_distance_label.position = Vector2(0, 90)
	_distance_label.size = Vector2(SCREEN_W, 16)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_distance_label)

	# "Outer cosmos" label above the line
	var top_lbl := Label.new()
	top_lbl.text = "↑  Outer cosmos"
	top_lbl.add_theme_font_size_override("font_size", 10)
	top_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	top_lbl.position = Vector2(0, FLOW_TOP_Y - 22)
	top_lbl.size = Vector2(SCREEN_W, 14)
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(top_lbl)

	# Vertical flow line
	_flow_line = ColorRect.new()
	_flow_line.color = Color(0.35, 0.28, 0.5, 0.6)
	_flow_line.position = Vector2(FLOW_X - FLOW_THICKNESS * 0.5, FLOW_TOP_Y)
	_flow_line.size = Vector2(FLOW_THICKNESS, FLOW_LINE_BOTTOM_Y - FLOW_TOP_Y)
	_flow_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flow_line)

	# Player marker (on the line)
	_player_circle = _make_circle(PLAYER_DIAMETER, Color(0.4, 0.85, 1.0), Color(0.95, 1, 1, 0.9))
	_root.add_child(_player_circle)
	# "YOU" label fixed to the player's side
	var you_lbl := Label.new()
	you_lbl.text = "YOU"
	you_lbl.add_theme_font_size_override("font_size", 10)
	you_lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	you_lbl.size = Vector2(40, 12)
	you_lbl.position = Vector2(PLAYER_DIAMETER + 4, (PLAYER_DIAMETER - 12) * 0.5)
	_player_circle.add_child(you_lbl)

	# "Down to the void" arrow between line end and BH
	var pull_lbl := Label.new()
	pull_lbl.text = "↓"
	pull_lbl.add_theme_font_size_override("font_size", 18)
	pull_lbl.add_theme_color_override("font_color", Color(0.45, 0.35, 0.65))
	pull_lbl.size = Vector2(40, 22)
	pull_lbl.position = Vector2(FLOW_X - 20, FLOW_LINE_BOTTOM_Y + 4)
	pull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(pull_lbl)

	# Black Hole — sits BELOW the timeline line with a clear gap
	_bh_holder = Control.new()
	_bh_holder.size = Vector2(BH_DIAMETER + 80, BH_DIAMETER + 30)
	_bh_holder.position = Vector2(FLOW_X - (BH_DIAMETER + 80) * 0.5, BH_CENTER_Y - BH_DIAMETER * 0.5)
	_root.add_child(_bh_holder)

	_bh_circle = _make_circle(BH_DIAMETER, Color(0.06, 0.03, 0.12), Color(0.55, 0.35, 0.85, 0.85))
	_bh_circle.position = Vector2((_bh_holder.size.x - BH_DIAMETER) * 0.5, 0)
	_bh_holder.add_child(_bh_circle)

	_bh_label = Label.new()
	_bh_label.add_theme_font_size_override("font_size", 32)
	_bh_label.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
	_bh_label.text = "?"
	_bh_label.size = Vector2(BH_DIAMETER, BH_DIAMETER)
	_bh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bh_circle.add_child(_bh_label)

	var bh_caption := Label.new()
	bh_caption.text = "The Void"
	bh_caption.add_theme_font_size_override("font_size", 11)
	bh_caption.add_theme_color_override("font_color", Color(0.6, 0.5, 0.75))
	bh_caption.size = Vector2(_bh_holder.size.x, 14)
	bh_caption.position = Vector2(0, BH_DIAMETER + 6)
	bh_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bh_holder.add_child(bh_caption)

	# Info panel (planet details on tap)
	_info_panel = PanelContainer.new()
	_info_panel.position = Vector2(16, SCREEN_H - 196)
	_info_panel.size = Vector2(SCREEN_W - 32, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.3, 0.55)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_info_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_info_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_info_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 14)
	_info_title.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	vbox.add_child(_info_title)

	_info_body = Label.new()
	_info_body.add_theme_font_size_override("font_size", 11)
	_info_body.add_theme_color_override("font_color", Color(0.78, 0.78, 0.9))
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_body.custom_minimum_size = Vector2(SCREEN_W - 60, 0)
	vbox.add_child(_info_body)

	# Close button
	_close_button = Button.new()
	_close_button.text = "✕ Close"
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.size = Vector2(SCREEN_W - 32, 56)
	_close_button.position = Vector2(16, SCREEN_H - 80)
	_close_button.pressed.connect(_on_close_pressed)
	_root.add_child(_close_button)


func _make_planet_visual(bot, fallback_color: Color) -> Control:
	# If the bot has a sprite path, render it via AtlasTexture (one frame from the strip).
	# Otherwise fall back to a coloured circle.
	var path: String = String(bot.display_sprite_path) if "display_sprite_path" in bot else ""
	if path != "":
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			var frame: int = int(bot.display_frame) if "display_frame" in bot else 0
			var frame_w: float = float(tex.get_width()) / 16.0
			var frame_h: float = float(tex.get_height())
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(frame * frame_w, 0, frame_w, frame_h)
			var tr := TextureRect.new()
			tr.texture = atlas
			tr.size = Vector2(PLANET_NODE_DIAMETER, PLANET_NODE_DIAMETER)
			tr.custom_minimum_size = Vector2(PLANET_NODE_DIAMETER, PLANET_NODE_DIAMETER)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tr
	# Fallback: a coloured circle
	return _make_circle(PLANET_NODE_DIAMETER, fallback_color, Color(fallback_color.r * 0.55, fallback_color.g * 0.55, fallback_color.b * 0.55, 0.95))


func _make_circle(diameter: float, fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(diameter, diameter)
	panel.size = Vector2(diameter, diameter)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = int(diameter * 0.5)
	style.corner_radius_top_right = int(diameter * 0.5)
	style.corner_radius_bottom_left = int(diameter * 0.5)
	style.corner_radius_bottom_right = int(diameter * 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _distance_to_y(distance: float) -> float:
	var clamped: float = clampf(distance, NEAR_DISTANCE, FAR_DISTANCE)
	var t: float = 1.0 - (clamped / FAR_DISTANCE)
	return lerp(FLOW_TOP_Y, FLOW_LINE_BOTTOM_Y, t)


func show_map(universe_node) -> void:
	_universe_ref = universe_node
	_selected = null
	visible = true
	_build_planet_nodes()
	_refresh_info_panel()
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()


func _refresh() -> void:
	_distance_label.text = "Distance to the void: %s ly" % _format_distance(GameState.distance_from_center)

	# BH icon state
	if GameState.is_blackhole_reached():
		_bh_label.text = "✦"
		_bh_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif GameState.is_blackhole_visible():
		_bh_label.text = "✦"
		_bh_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.95))
	else:
		_bh_label.text = "?"
		_bh_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))

	# Player marker position (centered on the flow line)
	var player_y: float = _distance_to_y(GameState.distance_from_center)
	_player_circle.position = Vector2(FLOW_X - PLAYER_DIAMETER * 0.5, player_y - PLAYER_DIAMETER * 0.5)

	# Refresh planet colors / statuses
	for entry in _planet_entries:
		var bot = entry["planet"]
		var node: Control = entry["node"] as Control
		if not is_instance_valid(node):
			continue
		var ring: Control = entry["ring"] as Control
		var tint: Color = Color(1, 1, 1)  # natural sprite colour
		if bot.was_visited:
			tint = Color(0.55, 0.95, 0.55)
		elif bot.was_encountered:
			tint = Color(1.1, 0.95, 0.55)
		if is_instance_valid(ring):
			ring.modulate = tint


func _build_planet_nodes() -> void:
	for entry in _planet_entries:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_planet_entries.clear()
	if _universe_ref == null:
		return
	var bots: Array = _universe_ref.bot_planets.duplicate()
	bots.sort_custom(func(a, b): return a.encounter_distance > b.encounter_distance)
	for i in range(bots.size()):
		var bot = bots[i]
		_planet_entries.append(_build_planet_entry(bot, i))


func _build_planet_entry(bot, index: int) -> Dictionary:
	var color: Color = PLANET_PALETTE[index % PLANET_PALETTE.size()]
	var y: float = _distance_to_y(bot.encounter_distance)
	var side: int = 1 if (index % 2 == 0) else -1
	# Wrapper holder so labels can be positioned outside the circle's bounds
	var holder := Control.new()
	holder.size = Vector2(PLANET_NODE_DIAMETER + 130, PLANET_NODE_DIAMETER + 4)
	holder.position = Vector2(FLOW_X - holder.size.x * 0.5, y - holder.size.y * 0.5)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)

	# Visual node: try real planet sprite, fall back to coloured circle
	var ring: Control = _make_planet_visual(bot, color)
	var ring_x: float = (holder.size.x - PLANET_NODE_DIAMETER) * 0.5
	var ring_y: float = (holder.size.y - PLANET_NODE_DIAMETER) * 0.5
	ring.position = Vector2(ring_x, ring_y)
	holder.add_child(ring)

	# Click hitbox covering the ring
	var hit := Button.new()
	hit.flat = true
	hit.size = Vector2(PLANET_NODE_DIAMETER + 12, PLANET_NODE_DIAMETER + 12)
	hit.position = Vector2(ring_x - 6, ring_y - 6)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.pressed.connect(_on_planet_clicked.bind(bot))
	holder.add_child(hit)

	# Name label outside the circle on the chosen side
	var name_lbl := Label.new()
	name_lbl.text = String(bot.planet_name)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	name_lbl.size = Vector2(80, 14)
	# Position on the side OPPOSITE to where the circle wants to lean
	if side > 0:
		name_lbl.position = Vector2(ring_x + PLANET_NODE_DIAMETER + 8, ring_y - 2)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		name_lbl.position = Vector2(ring_x - 88, ring_y - 2)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	holder.add_child(name_lbl)

	# Distance under the name
	var dist_lbl := Label.new()
	dist_lbl.text = _format_distance(bot.encounter_distance) + " ly"
	dist_lbl.add_theme_font_size_override("font_size", 9)
	dist_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	dist_lbl.size = Vector2(80, 12)
	if side > 0:
		dist_lbl.position = Vector2(ring_x + PLANET_NODE_DIAMETER + 8, ring_y + 12)
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		dist_lbl.position = Vector2(ring_x - 88, ring_y + 12)
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	holder.add_child(dist_lbl)

	return {"node": holder, "planet": bot, "ring": ring, "default_color": color}


func _on_planet_clicked(bot) -> void:
	_selected = bot
	_refresh_info_panel()


func _refresh_info_panel() -> void:
	if _selected == null:
		_info_title.text = "Tap a planet to inspect."
		_info_body.text = "Planets cross your path as you fall toward the void. You cannot divert — you must wait for them to come close."
		return
	var bot = _selected
	var type_name: String = String(bot.display_type) if "display_type" in bot else "world"
	_info_title.text = "%s   ·   %s" % [String(bot.planet_name), type_name.capitalize()]
	var status_line: String = ""
	if bot.was_visited:
		status_line = "Status: ✓ Visited"
	elif bot.was_encountered:
		status_line = "Status: passed by"
	else:
		var d: float = GameState.distance_from_center - float(bot.encounter_distance)
		if d > 0.0:
			status_line = "Approaching in %s ly" % _format_distance(d)
		else:
			status_line = "On approach…"
	_info_body.text = "%s\nEncounter distance: %s ly" % [
		status_line,
		_format_distance(bot.encounter_distance)
	]


func _on_blocker_input(event: InputEvent) -> void:
	# Tap outside any interactive element deselects the current planet
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if (is_tap or is_touch) and _selected != null:
		_selected = null
		_refresh_info_panel()


func _on_close_pressed() -> void:
	visible = false
	_selected = null
	closed.emit()


func _format_distance(d: float) -> String:
	if d >= 1_000_000.0:
		return "%.2f M" % (d / 1_000_000.0)
	if d >= 1_000.0:
		return "%.1f K" % (d / 1_000.0)
	return str(int(d))
