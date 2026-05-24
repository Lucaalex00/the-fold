extends CanvasLayer

# Book-style Memory Book.
# Each "page" = one run. Player flips through with ◀ / ▶ buttons.
# Page content: run header (number, era reached, days, cause of collapse if any)
# + scrollable list of entities born during that run with their final state
# (trait, generation, age, alive/dead + cause).

signal closed

const SCREEN_W: float = 390.0
const SCREEN_H: float = 844.0
const PAGE_INSETS: Vector2 = Vector2(16, 70)  # padding from screen edges (x, y)
const ANIM_TIME: float = 0.22

var _blocker: ColorRect
var _panel: PanelContainer
var _page_label: Label
var _run_header: Label
var _run_subhead: Label
var _entries_box: VBoxContainer
var _scroll: ScrollContainer
var _empty_label: Label
var _prev_btn: Button
var _next_btn: Button
var _close_btn: Button

var _runs: Array = []     # Array of Dictionaries — one per run, sorted by run number
var _page_index: int = 0


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0.0, 0.0, 0.0, 0.65)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	# Book panel — parchment-tinted, full screen minus margins
	_panel = PanelContainer.new()
	_panel.position = PAGE_INSETS
	_panel.size = Vector2(SCREEN_W - PAGE_INSETS.x * 2, SCREEN_H - PAGE_INSETS.y * 2 - 16)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var book_style := StyleBoxFlat.new()
	book_style.bg_color = Color(0.96, 0.92, 0.82, 1.0)
	book_style.border_color = Color(0.45, 0.30, 0.15)
	book_style.border_width_left = 3
	book_style.border_width_right = 3
	book_style.border_width_top = 3
	book_style.border_width_bottom = 3
	book_style.corner_radius_top_left = 6
	book_style.corner_radius_top_right = 6
	book_style.corner_radius_bottom_left = 6
	book_style.corner_radius_bottom_right = 6
	book_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	book_style.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", book_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Top row: title centred + close button right
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "MEMORY BOOK"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.30, 0.18, 0.05))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(title)

	_close_btn = _make_book_button("✕", 24)
	_close_btn.custom_minimum_size = Vector2(40, 36)
	_close_btn.pressed.connect(_on_close_pressed)
	top_row.add_child(_close_btn)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Page header
	_run_header = Label.new()
	_run_header.add_theme_font_size_override("font_size", 20)
	_run_header.add_theme_color_override("font_color", Color(0.20, 0.10, 0.04))
	_run_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_run_header)

	_run_subhead = Label.new()
	_run_subhead.add_theme_font_size_override("font_size", 11)
	_run_subhead.add_theme_color_override("font_color", Color(0.40, 0.28, 0.15))
	_run_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_subhead.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_run_subhead)

	# Scrollable entity list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_entries_box = VBoxContainer.new()
	_entries_box.add_theme_constant_override("separation", 6)
	_entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_entries_box)

	_empty_label = Label.new()
	_empty_label.text = "No souls recorded in this run yet."
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	_entries_box.add_child(_empty_label)

	# Bottom nav row
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	vbox.add_child(nav_row)

	_prev_btn = _make_book_button("◀  Prev", 14)
	_prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prev_btn.custom_minimum_size = Vector2(0, 40)
	_prev_btn.pressed.connect(_on_prev_pressed)
	nav_row.add_child(_prev_btn)

	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 13)
	_page_label.add_theme_color_override("font_color", Color(0.30, 0.18, 0.05))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(60, 40)
	nav_row.add_child(_page_label)

	_next_btn = _make_book_button("Next  ▶", 14)
	_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_btn.custom_minimum_size = Vector2(0, 40)
	_next_btn.pressed.connect(_on_next_pressed)
	nav_row.add_child(_next_btn)


func _make_book_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.30, 0.18, 0.05))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.86, 0.78, 0.62, 1.0)
	s.border_color = Color(0.55, 0.40, 0.20)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	var sh := s.duplicate()
	sh.bg_color = Color(0.80, 0.70, 0.50, 1.0)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus", s)
	return btn


# --- Public API ---

func populate() -> void:
	_runs = _group_by_run(GameState.memory_book)
	# Default to the most recent page
	_page_index = maxi(_runs.size() - 1, 0)
	_render_page()
	visible = true
	# Smooth in
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, ANIM_TIME)
	tw.tween_property(_panel, "scale", Vector2.ONE, ANIM_TIME)


# --- Page rendering ---

func _group_by_run(book: Array) -> Array:
	# Returns an Array of dicts: { number, era_reached, days, cause, entities: [...] }
	# sorted by run number ascending. The CURRENT (in-progress) run is included as
	# the highest-numbered page even if no prestige entry exists yet.
	var by_run: Dictionary = {}

	for entry in book:
		if entry.get("type", "") == "prestige_run":
			var n: int = int(entry.get("prestige_number", 0))
			var rec: Dictionary = by_run.get(n, _new_run_record(n))
			rec["era_reached"] = int(entry.get("era_reached", rec.get("era_reached", 1)))
			rec["god_message"] = String(entry.get("god_message", ""))
			rec["metrics"] = entry.get("metrics", {})
			by_run[n] = rec
		else:
			var n2: int = int(entry.get("prestige_run", 0))
			var rec2: Dictionary = by_run.get(n2, _new_run_record(n2))
			rec2["entities"].append(entry)
			by_run[n2] = rec2

	# Also include the in-progress current run if it has no records yet
	var current_run_n: int = int(GameState.prestige_count)
	if not by_run.has(current_run_n):
		by_run[current_run_n] = _new_run_record(current_run_n)
	# Annotate current with live data
	var current: Dictionary = by_run[current_run_n]
	current["is_current"] = true
	current["era_reached"] = int(GameState.current_era)
	current["days"] = int(GameState.current_day)

	var keys: Array = by_run.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append(by_run[k])
	return out


func _new_run_record(n: int) -> Dictionary:
	return {
		"number": n,
		"era_reached": 1,
		"days": 0,
		"cause": "",
		"entities": [],
		"is_current": false,
		"god_message": "",
		"metrics": {},
	}


func _render_page() -> void:
	if _runs.is_empty():
		_run_header.text = "No runs yet"
		_run_subhead.text = ""
		_page_label.text = "0 / 0"
		_prev_btn.disabled = true
		_next_btn.disabled = true
		_empty_label.visible = true
		return
	_page_index = clampi(_page_index, 0, _runs.size() - 1)
	var run: Dictionary = _runs[_page_index]

	_run_header.text = "Run #%d  ·  Era %d" % [run["number"], run["era_reached"]]
	var subparts: Array = []
	if bool(run.get("is_current", false)):
		subparts.append("(current run)")
		subparts.append("Day %d" % int(run.get("days", 0)))
	var entities: Array = run.get("entities", [])
	subparts.append("%d soul%s" % [entities.size(), "" if entities.size() == 1 else "s"])
	var god_msg: String = String(run.get("god_message", ""))
	if god_msg != "":
		subparts.append("“%s”" % god_msg)
	_run_subhead.text = "  ·  ".join(subparts)

	# Entities list
	for child in _entries_box.get_children():
		if child != _empty_label:
			child.queue_free()
	_empty_label.visible = entities.is_empty()

	for entity_entry in entities:
		var card := _make_entity_card(entity_entry)
		_entries_box.add_child(card)

	_page_label.text = "%d / %d" % [_page_index + 1, _runs.size()]
	_prev_btn.disabled = _page_index <= 0
	_next_btn.disabled = _page_index >= _runs.size() - 1


func _make_entity_card(entity: Dictionary) -> Control:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.88, 0.82, 0.68, 1.0)
	s.border_color = Color(0.55, 0.40, 0.20, 0.7)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", s)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)

	var name_lbl := Label.new()
	var name_str: String = String(entity.get("name", "?"))
	var trait_str: String = String(entity.get("trait", "")).capitalize()
	name_lbl.text = "💀 %s · %s" % [name_str, trait_str]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)

	var age_lbl := Label.new()
	age_lbl.text = "Age %d · Gen %d" % [int(entity.get("age_years", 0)), int(entity.get("generation", 1))]
	age_lbl.add_theme_font_size_override("font_size", 11)
	age_lbl.add_theme_color_override("font_color", Color(0.45, 0.32, 0.18))
	top.add_child(age_lbl)

	var details := Label.new()
	var cause: String = String(entity.get("death_cause", ""))
	var died_date: String = String(entity.get("death_date_real", ""))
	var bits: Array = []
	if cause != "":
		bits.append("Cause: %s" % cause.replace("_", " "))
	if died_date != "":
		bits.append(died_date)
	details.text = " · ".join(bits) if not bits.is_empty() else ""
	details.add_theme_font_size_override("font_size", 10)
	details.add_theme_color_override("font_color", Color(0.45, 0.32, 0.18))
	v.add_child(details)

	return card


# --- Navigation ---

func _on_prev_pressed() -> void:
	_page_index = maxi(_page_index - 1, 0)
	_render_page()


func _on_next_pressed() -> void:
	_page_index = mini(_page_index + 1, _runs.size() - 1)
	_render_page()


# --- Close ---

func _on_blocker_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap or is_touch:
		_on_close_pressed()


func _on_close_pressed() -> void:
	if not visible:
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "modulate:a", 0.0, ANIM_TIME * 0.8)
	tw.tween_property(_panel, "scale", Vector2(0.96, 0.96), ANIM_TIME * 0.8)
	tw.chain().tween_callback(_finalize_close)


func _finalize_close() -> void:
	visible = false
	closed.emit()
