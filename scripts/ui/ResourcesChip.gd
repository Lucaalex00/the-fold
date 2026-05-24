extends CanvasLayer

# Compact resources display: 🌾 Harvest · 🐟 Fishing · 🔨 Labor · 🤝 Trade
# Sits at bottom-center between the planet corner and the universe map button.

const POS: Vector2 = Vector2(110, 802)
const SIZE: Vector2 = Vector2(210, 30)

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 65
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = SIZE
	_panel.position = POS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


func _process(_delta: float) -> void:
	if not _label:
		return
	var r: Dictionary = ResourceSystem.resources
	_label.text = "🌾 %d · 🐟 %d · 🔨 %d · 🤝 %d" % [
		int(r.get("harvest", 0)),
		int(r.get("fishing", 0)),
		int(r.get("labor", 0)),
		int(r.get("trade", 0)),
	]
