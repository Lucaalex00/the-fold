extends CanvasLayer

signal replace_chosen(target_id: String)
signal skipped

var _blocker: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _list_box: VBoxContainer
var _skip_btn: Button
var _new_entity: GameState.EntityData = null


func _ready() -> void:
	layer = 72
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.6)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)


func _on_blocker_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap or is_touch:
		_on_skip()

	_panel = PanelContainer.new()
	_panel.size = Vector2(350, 10)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Population at Cap"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(314, 0)
	vbox.add_child(_desc_label)

	vbox.add_child(HSeparator.new())

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_list_box)

	vbox.add_child(HSeparator.new())

	_skip_btn = Button.new()
	_skip_btn.text = "Skip — keep current population"
	_skip_btn.add_theme_font_size_override("font_size", 13)
	_skip_btn.pressed.connect(_on_skip)
	vbox.add_child(_skip_btn)


func show_replacement(new_entity: GameState.EntityData, current_entities: Array) -> void:
	_new_entity = new_entity
	_desc_label.text = "New arrival: %s (%s). Choose someone to replace or skip." % [
		new_entity.name, new_entity.trait_primary
	]
	for child in _list_box.get_children():
		child.queue_free()
	for entity in current_entities:
		_add_entity_button(entity)
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_center_panel()


func _add_entity_button(entity: GameState.EntityData) -> void:
	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.text = "Replace %s (%s, gen %d)" % [entity.name, entity.trait_primary, entity.generation]
	btn.pressed.connect(_on_replace.bind(entity.id))
	_list_box.add_child(btn)


func _center_panel() -> void:
	var pw = _panel.size.x
	var ph = _panel.size.y
	_panel.position = Vector2((390.0 - pw) / 2.0, 52.0 + (792.0 - ph) / 2.0)


func _on_replace(target_id: String) -> void:
	visible = false
	replace_chosen.emit(target_id)


func _on_skip() -> void:
	visible = false
	skipped.emit()
