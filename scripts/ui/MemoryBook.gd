extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var entries_container: VBoxContainer = $Panel/VBox/Scroll/EntriesContainer
@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var empty_label: Label = $Panel/VBox/Scroll/EmptyLabel


func _ready() -> void:
	visible = false
	title_label.text = L.tr("MEMORY_BOOK_TITLE")
	close_button.text = L.tr("MEMORY_BOOK_CLOSE")
	close_button.pressed.connect(_on_close)


func populate() -> void:
	# Clear existing entries
	for child in entries_container.get_children():
		child.queue_free()

	var entries = GameState.memory_book
	empty_label.visible = entries.is_empty()

	for entry in entries:
		if entry.get("type") == "prestige_run":
			_add_prestige_entry(entry)
		else:
			_add_omino_entry(entry)


func _add_omino_entry(entry: Dictionary) -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var name_label = Label.new()
	name_label.text = L.tr("MEMORY_BOOK_ENTRY", {
		"name": entry.get("name", "?"),
		"trait": L.get_trait_name(entry.get("trait", "")),
		"age": entry.get("age_years", 0)
	})
	name_label.add_theme_font_size_override("font_size", 14)

	var born_label = Label.new()
	born_label.text = L.tr("MEMORY_BOOK_BORN", {"date": entry.get("born_date_real", "?")})
	born_label.add_theme_font_size_override("font_size", 11)

	var died_label = Label.new()
	died_label.text = L.tr("MEMORY_BOOK_DIED", {
		"date": entry.get("death_date_real", "?"),
		"cause": L.get_death_cause(entry.get("death_cause", ""))
	})
	died_label.add_theme_font_size_override("font_size", 11)

	var gen_label = Label.new()
	gen_label.text = L.tr("MEMORY_BOOK_GENERATION", {"gen": entry.get("generation", 1)}) + \
		"  |  " + L.tr("MEMORY_BOOK_CHILDREN", {"count": entry.get("children_count", 0)}) + \
		"  |  " + L.tr("MEMORY_BOOK_RUN", {"run": entry.get("prestige_run", 0)})
	gen_label.add_theme_font_size_override("font_size", 10)

	container.add_child(name_label)
	container.add_child(born_label)
	container.add_child(died_label)
	container.add_child(gen_label)

	var separator = HSeparator.new()
	container.add_child(separator)

	entries_container.add_child(container)


func _add_prestige_entry(entry: Dictionary) -> void:
	var label = Label.new()
	label.text = "── Run #%d — Era %d ──" % [
		entry.get("prestige_number", 0),
		entry.get("era_reached", 1)
	]
	label.add_theme_font_size_override("font_size", 12)
	entries_container.add_child(label)


func _on_close() -> void:
	visible = false
