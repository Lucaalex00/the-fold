extends CanvasLayer

signal closed

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const PLANET_NODE_SIZE: float = 48.0
const ORBIT_RADIUS: float = 130.0
const CENTER: Vector2 = Vector2(SCREEN_W * 0.5, SCREEN_H * 0.5 - 20.0)

var _blocker: ColorRect
var _panel: Control
var _player_icon: Control
var _bot_nodes: Array = []  # Array of { node, planet }
var _detail_label: Label
var _detail_button: Button
var _close_button: Button
var _selected_bot = null
var _visited_ids: Dictionary = {}  # planet_id → true


func _ready() -> void:
	layer = 70
	visible = false
	_build_ui()
	PrestigeSystem.prestige_sequence_finished.connect(_on_prestige_finished)


func _on_prestige_finished() -> void:
	# Run ended → forget visited planets so the new universe is fresh
	_visited_ids.clear()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.02, 0.02, 0.05, 0.94)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Title
	var title := Label.new()
	title.text = "UNIVERSE MAP"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	title.position = Vector2(0, 70)
	title.size = Vector2(SCREEN_W, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	# Subtitle: distance to BH
	var subtitle := Label.new()
	subtitle.name = "DistanceLabel"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	subtitle.position = Vector2(0, 96)
	subtitle.size = Vector2(SCREEN_W, 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(subtitle)

	# Player planet at center
	_player_icon = _make_planet_node("Your World", true)
	_player_icon.position = CENTER - Vector2(PLANET_NODE_SIZE * 0.5, PLANET_NODE_SIZE * 0.5)
	_panel.add_child(_player_icon)

	# Detail box at bottom
	var detail_panel := PanelContainer.new()
	detail_panel.position = Vector2(16, SCREEN_H - 220)
	detail_panel.size = Vector2(SCREEN_W - 32, 130)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.3, 0.55)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	detail_panel.add_theme_stylebox_override("panel", style)
	_panel.add_child(detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_vbox)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	detail_panel.add_child(margin)
	margin.add_child(detail_vbox)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_label.text = "Tap a planet to inspect."
	detail_vbox.add_child(_detail_label)

	_detail_button = Button.new()
	_detail_button.text = "Visit Planet"
	_detail_button.add_theme_font_size_override("font_size", 14)
	_detail_button.disabled = true
	_detail_button.pressed.connect(_on_visit_pressed)
	detail_vbox.add_child(_detail_button)

	# Close button (thumb-friendly, bottom)
	_close_button = Button.new()
	_close_button.text = "✕ Close"
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.size = Vector2(SCREEN_W - 32, 56)
	_close_button.position = Vector2(16, SCREEN_H - 80)
	_close_button.pressed.connect(_on_close_pressed)
	_panel.add_child(_close_button)


func _make_planet_node(planet_name: String, is_player: bool, planet = null) -> Control:
	var holder := Control.new()
	holder.size = Vector2(PLANET_NODE_SIZE, PLANET_NODE_SIZE + 18)

	var circle := ColorRect.new()
	circle.color = Color(0.5, 0.7, 1.0) if is_player else Color(0.5, 0.4, 0.6)
	circle.size = Vector2(PLANET_NODE_SIZE, PLANET_NODE_SIZE)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = circle.color
	cstyle.corner_radius_top_left = int(PLANET_NODE_SIZE / 2)
	cstyle.corner_radius_top_right = int(PLANET_NODE_SIZE / 2)
	cstyle.corner_radius_bottom_left = int(PLANET_NODE_SIZE / 2)
	cstyle.corner_radius_bottom_right = int(PLANET_NODE_SIZE / 2)
	# ColorRect doesn't take stylebox, so use a Panel underneath
	var inner_panel := PanelContainer.new()
	inner_panel.size = Vector2(PLANET_NODE_SIZE, PLANET_NODE_SIZE)
	inner_panel.add_theme_stylebox_override("panel", cstyle)
	inner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(inner_panel)

	# Name label
	var name_label := Label.new()
	name_label.text = planet_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.position = Vector2(-20, PLANET_NODE_SIZE + 2)
	name_label.size = Vector2(PLANET_NODE_SIZE + 40, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(name_label)

	if not is_player and planet != null:
		# Click button overlay
		var btn := Button.new()
		btn.flat = true
		btn.size = Vector2(PLANET_NODE_SIZE, PLANET_NODE_SIZE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)
		btn.pressed.connect(_on_bot_clicked.bind(planet))
		holder.add_child(btn)

	return holder


func show_map(universe_node) -> void:
	visible = true
	_selected_bot = null
	_detail_label.text = "Tap a planet to inspect."
	_detail_button.disabled = true
	_detail_button.text = "Visit Planet"

	# Update distance label
	var dist_label: Label = _panel.get_node_or_null("DistanceLabel") as Label
	if dist_label:
		dist_label.text = "Distance to the void: %s ly" % _format_distance(GameState.distance_from_center)

	# Rebuild bot planets
	for entry in _bot_nodes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_bot_nodes.clear()

	if universe_node == null:
		return
	var bots: Array = universe_node.bot_planets
	for i in range(bots.size()):
		var bot = bots[i]
		var name: String = String(bot.planet_name) if "planet_name" in bot else "Unknown"
		var angle: float = (TAU / float(bots.size())) * float(i) - PI * 0.5
		var pos: Vector2 = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		var node := _make_planet_node(name, false, bot)
		node.position = pos - Vector2(PLANET_NODE_SIZE * 0.5, PLANET_NODE_SIZE * 0.5)
		# Highlight visited planets
		var bot_id: String = String(bot.planet_id) if "planet_id" in bot else ""
		if _visited_ids.has(bot_id):
			node.modulate = Color(0.7, 0.9, 0.7)
		_panel.add_child(node)
		_bot_nodes.append({"node": node, "planet": bot})


func _on_bot_clicked(planet) -> void:
	_selected_bot = planet
	var name: String = String(planet.planet_name) if "planet_name" in planet else "Unknown"
	var bot_id: String = String(planet.planet_id) if "planet_id" in planet else ""
	var visited: bool = _visited_ids.has(bot_id)
	_detail_label.text = "%s\n%s" % [
		name,
		"Already visited" if visited else "Unexplored"
	]
	_detail_button.disabled = visited
	_detail_button.text = "Visited ✓" if visited else "Visit Planet"


func _on_visit_pressed() -> void:
	if _selected_bot == null:
		return
	var bot_id: String = String(_selected_bot.planet_id) if "planet_id" in _selected_bot else ""
	if bot_id == "" or _visited_ids.has(bot_id):
		return
	_visited_ids[bot_id] = true
	GameState.planets_visited += 1
	# Refresh the visual state
	for entry in _bot_nodes:
		if entry["planet"] == _selected_bot and is_instance_valid(entry["node"]):
			entry["node"].modulate = Color(0.7, 0.9, 0.7)
			break
	_detail_label.text = "%s\nVisited! +1 explored." % (
		String(_selected_bot.planet_name) if "planet_name" in _selected_bot else "Unknown"
	)
	_detail_button.disabled = true
	_detail_button.text = "Visited ✓"


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _format_distance(d: float) -> String:
	if d >= 1_000_000.0:
		return "%.2f M" % (d / 1_000_000.0)
	if d >= 1_000.0:
		return "%.1f K" % (d / 1_000.0)
	return str(int(d))
