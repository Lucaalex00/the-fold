extends CanvasLayer

const CHIP_W: float = 90.0
const CHIP_H: float = 28.0
const POS: Vector2 = Vector2(8.0, 60.0)
const ACCENT: Color = Color(0.75, 0.55, 1.0)

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 65
	_build_ui()
	_refresh()
	if not GameState.divine_energy_changed.is_connected(_on_changed):
		GameState.divine_energy_changed.connect(_on_changed)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	_panel.position = POS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = ACCENT
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", ACCENT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


func _on_changed(_value: float, _max_value: float) -> void:
	_refresh()


func _refresh() -> void:
	if _label:
		_label.text = "🔮 %d/%d" % [int(GameState.divine_energy), int(GameState.divine_energy_max)]
