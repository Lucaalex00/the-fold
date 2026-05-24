extends CanvasLayer

# Passive flow visualization: shows the journey to the Black Hole.
# Player can NOT visit a planet from here — they must be physically encountered
# during the journey (Universe.planet_encountered signal → encounter event).

signal closed

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0

# Vertical flow geometry
const FLOW_TOP_Y: float = 140.0       # top of the timeline (far cosmos)
const FLOW_BOTTOM_Y: float = SCREEN_H - 180.0  # bottom of the timeline (BH)
const FLOW_X: float = SCREEN_W * 0.5   # vertical line position
const FLOW_THICKNESS: float = 3.0
const PLANET_NODE_RADIUS: float = 18.0
const BH_ICON_RADIUS: float = 36.0

# Distance bounds for mapping
const FAR_DISTANCE: float = 1_000_000.0
const NEAR_DISTANCE: float = 0.0

var _blocker: ColorRect
var _panel: Control
var _flow_line: ColorRect
var _bh_icon: PanelContainer
var _bh_label: Label
var _player_icon: PanelContainer
var _planet_nodes: Array = []  # Array[{node, planet, label}]
var _info_label: Label
var _close_button: Button
var _universe_ref = null


func _ready() -> void:
	layer = 70
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.02, 0.02, 0.05, 0.96)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Title
	var title := Label.new()
	title.text = "JOURNEY TO THE VOID"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	title.position = Vector2(0, 70)
	title.size = Vector2(SCREEN_W, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	# Subtitle: live distance
	var subtitle := Label.new()
	subtitle.name = "DistanceLabel"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	subtitle.position = Vector2(0, 96)
	subtitle.size = Vector2(SCREEN_W, 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(subtitle)

	# Vertical flow line
	_flow_line = ColorRect.new()
	_flow_line.color = Color(0.4, 0.3, 0.55, 0.8)
	_flow_line.position = Vector2(FLOW_X - FLOW_THICKNESS * 0.5, FLOW_TOP_Y)
	_flow_line.size = Vector2(FLOW_THICKNESS, FLOW_BOTTOM_Y - FLOW_TOP_Y)
	_flow_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_flow_line)

	# Top marker (far cosmos label)
	var top_lbl := Label.new()
	top_lbl.text = "↑ Outer cosmos"
	top_lbl.add_theme_font_size_override("font_size", 10)
	top_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	top_lbl.position = Vector2(0, FLOW_TOP_Y - 20)
	top_lbl.size = Vector2(SCREEN_W, 14)
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(top_lbl)

	# Black Hole / "?" marker at bottom
	_bh_icon = _make_circle_node(BH_ICON_RADIUS * 2.0, Color(0.06, 0.04, 0.12))
	_bh_icon.position = Vector2(FLOW_X - BH_ICON_RADIUS, FLOW_BOTTOM_Y - BH_ICON_RADIUS)
	_panel.add_child(_bh_icon)
	_bh_label = Label.new()
	_bh_label.add_theme_font_size_override("font_size", 22)
	_bh_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	_bh_label.text = "?"
	_bh_label.size = Vector2(BH_ICON_RADIUS * 2.0, BH_ICON_RADIUS * 2.0)
	_bh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bh_icon.add_child(_bh_label)

	var bh_caption := Label.new()
	bh_caption.text = "The void"
	bh_caption.add_theme_font_size_override("font_size", 11)
	bh_caption.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	bh_caption.position = Vector2(0, FLOW_BOTTOM_Y + BH_ICON_RADIUS + 8)
	bh_caption.size = Vector2(SCREEN_W, 14)
	bh_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(bh_caption)

	# Player marker (small blue dot moving along the flow)
	_player_icon = _make_circle_node(20.0, Color(0.4, 0.85, 1.0))
	_panel.add_child(_player_icon)
	var player_lbl := Label.new()
	player_lbl.text = "YOU"
	player_lbl.add_theme_font_size_override("font_size", 9)
	player_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	player_lbl.position = Vector2(24, 4)
	player_lbl.size = Vector2(50, 12)
	_player_icon.add_child(player_lbl)

	# Info text at the very bottom
	_info_label = Label.new()
	_info_label.text = "Planets cross your path as you fall.\nYou cannot divert — you can only choose when they're near."
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(20, SCREEN_H - 140)
	_info_label.size = Vector2(SCREEN_W - 40, 50)
	_panel.add_child(_info_label)

	# Close button (thumb-friendly)
	_close_button = Button.new()
	_close_button.text = "✕ Close"
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.size = Vector2(SCREEN_W - 32, 56)
	_close_button.position = Vector2(16, SCREEN_H - 80)
	_close_button.pressed.connect(_on_close_pressed)
	_panel.add_child(_close_button)


func _make_circle_node(diameter: float, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(diameter, diameter)
	panel.size = Vector2(diameter, diameter)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(diameter * 0.5)
	style.corner_radius_top_right = int(diameter * 0.5)
	style.corner_radius_bottom_left = int(diameter * 0.5)
	style.corner_radius_bottom_right = int(diameter * 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _distance_to_y(distance: float) -> float:
	# Map distance [FAR..NEAR] linearly to y [FLOW_TOP..FLOW_BOTTOM]
	var clamped: float = clampf(distance, NEAR_DISTANCE, FAR_DISTANCE)
	var t: float = 1.0 - (clamped / FAR_DISTANCE)
	return lerp(FLOW_TOP_Y, FLOW_BOTTOM_Y, t)


func show_map(universe_node) -> void:
	_universe_ref = universe_node
	visible = true
	_build_planet_nodes()
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()


func _refresh() -> void:
	# Update distance label
	var dist_label: Label = _panel.get_node_or_null("DistanceLabel") as Label
	if dist_label:
		dist_label.text = "Distance to the void: %s ly" % _format_distance(GameState.distance_from_center)

	# BH "?" or icon depending on visibility
	if GameState.is_blackhole_visible():
		_bh_label.text = "✦"
		_bh_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	else:
		_bh_label.text = "?"
		_bh_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))

	# Player marker position
	var player_y: float = _distance_to_y(GameState.distance_from_center)
	_player_icon.position = Vector2(FLOW_X - 10.0, player_y - 10.0)

	# Update planet markers (colors / visited states)
	for entry in _planet_nodes:
		var bot = entry["planet"]
		var node: PanelContainer = entry["node"] as PanelContainer
		var label: Label = entry["label"] as Label
		if not is_instance_valid(node):
			continue
		if bot.was_visited:
			node.modulate = Color(0.55, 0.95, 0.5)
			label.text = String(bot.planet_name) + " ✓"
		elif bot.was_encountered:
			node.modulate = Color(0.95, 0.85, 0.4)
			label.text = String(bot.planet_name) + " (passed)"
		else:
			node.modulate = Color(1, 1, 1)
			label.text = String(bot.planet_name)


func _build_planet_nodes() -> void:
	for entry in _planet_nodes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_planet_nodes.clear()
	if _universe_ref == null:
		return
	var bots: Array = _universe_ref.bot_planets
	# Sort by encounter_distance descending (far first, near last)
	bots = bots.duplicate()
	bots.sort_custom(func(a, b): return a.encounter_distance > b.encounter_distance)
	for i in range(bots.size()):
		var bot = bots[i]
		var y: float = _distance_to_y(bot.encounter_distance)
		var node := _make_circle_node(PLANET_NODE_RADIUS * 2.0, Color(0.5, 0.4, 0.6))
		# Stagger left/right alternately so labels don't overlap the flow line
		var side: int = 1 if i % 2 == 0 else -1
		node.position = Vector2(FLOW_X + side * 28.0 - PLANET_NODE_RADIUS, y - PLANET_NODE_RADIUS)
		_panel.add_child(node)
		# Name label
		var lbl := Label.new()
		lbl.text = String(bot.planet_name)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		if side > 0:
			lbl.position = Vector2(PLANET_NODE_RADIUS * 2.0 + 6, PLANET_NODE_RADIUS - 6)
			lbl.size = Vector2(100, 14)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			lbl.position = Vector2(-106, PLANET_NODE_RADIUS - 6)
			lbl.size = Vector2(100, 14)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		node.add_child(lbl)
		# Distance label
		var dlbl := Label.new()
		dlbl.text = _format_distance(bot.encounter_distance) + " ly"
		dlbl.add_theme_font_size_override("font_size", 8)
		dlbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
		if side > 0:
			dlbl.position = Vector2(PLANET_NODE_RADIUS * 2.0 + 6, PLANET_NODE_RADIUS + 6)
			dlbl.size = Vector2(100, 12)
		else:
			dlbl.position = Vector2(-106, PLANET_NODE_RADIUS + 6)
			dlbl.size = Vector2(100, 12)
		node.add_child(dlbl)
		_planet_nodes.append({"node": node, "planet": bot, "label": lbl})


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _format_distance(d: float) -> String:
	if d >= 1_000_000.0:
		return "%.2f M" % (d / 1_000_000.0)
	if d >= 1_000.0:
		return "%.1f K" % (d / 1_000.0)
	return str(int(d))
