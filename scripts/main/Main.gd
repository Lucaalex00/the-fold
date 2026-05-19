extends Node2D

@onready var hud: CanvasLayer = $HUD
@onready var event_panel: CanvasLayer = $EventPanel
@onready var memory_book: CanvasLayer = $MemoryBook
@onready var prestige_screen: CanvasLayer = $PrestigeScreen
@onready var universe: Node2D = $Universe
@onready var planet_corner_sprite: Sprite2D = $PlanetLayer/PlanetCornerSprite
@onready var planet_widget: Control = $PlanetLayer/PlanetInput

var _is_new_game: bool = false
var _bg_files: Array[String] = []
var _current_bg: Sprite2D = null
var _current_bg_index: int = -1


func _ready() -> void:
	_connect_signals()
	_setup_background()
	_init_game()


func _setup_background() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0))
	_scan_bg_files()
	if _bg_files.is_empty():
		return
	_current_bg_index = randi() % _bg_files.size()
	_current_bg = _spawn_bg(_bg_files[_current_bg_index], 0.5)
	var timer := Timer.new()
	timer.wait_time = 1800.0
	timer.autostart = true
	timer.timeout.connect(_on_bg_timer)
	add_child(timer)


func _scan_bg_files() -> void:
	var dir := DirAccess.open("res://assets/ui/backgrounds/")
	if not dir:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".png"):
			_bg_files.append("res://assets/ui/backgrounds/" + f)
		f = dir.get_next()
	dir.list_dir_end()


func _spawn_bg(path: String, alpha: float) -> Sprite2D:
	var tex := load(path) as Texture2D
	if not tex:
		return null
	var ts := tex.get_size()
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2.ZERO
	sp.scale = Vector2(390.0 / ts.x, 844.0 / ts.y)
	sp.z_index = -100
	sp.z_as_relative = false
	sp.modulate.a = alpha
	add_child(sp)
	move_child(sp, 0)
	return sp


func _on_bg_timer() -> void:
	if _bg_files.size() <= 1:
		return
	var next := _current_bg_index
	while next == _current_bg_index:
		next = randi() % _bg_files.size()
	_current_bg_index = next
	var old := _current_bg
	var new_bg := _spawn_bg(_bg_files[_current_bg_index], 0.0)
	if not new_bg:
		return
	_current_bg = new_bg
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new_bg, "modulate:a", 0.5, 2.0)
	if old:
		tw.tween_property(old, "modulate:a", 0.0, 2.0)
		tw.chain().tween_callback(old.queue_free)


func _connect_signals() -> void:
	GameState.entity_died.connect(_on_entity_died)
	GameState.era_changed.connect(_on_era_changed)
	GameState.prestige_triggered.connect(_on_prestige_triggered)
	GameState.cohesion_changed.connect(_on_cohesion_changed)
	PrestigeSystem.prestige_sequence_started.connect(_on_prestige_sequence_started)
	PrestigeSystem.prestige_sequence_finished.connect(_on_prestige_sequence_finished)
	PrestigeSystem.god_message_ready.connect(_on_god_message_ready)


func _init_game() -> void:
	_is_new_game = not FileAccess.file_exists("user://save.json")

	if _is_new_game:
		_start_new_game()
	else:
		_load_existing_game()

	hud.refresh()


func _start_new_game() -> void:
	var planet = universe.get_player_planet()
	if planet:
		planet.initialize_founders()
		_apply_prestige_bonuses_to_founders()
		_setup_planet_widget(planet)
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()
	SaveManager.save_game()


func _setup_planet_widget(planet: Planet) -> void:
	var index = (planet.sprite_index % 5) + 1
	var path = "res://assets/planets/planet_%02d.png" % index
	var source_tex = load(path) as Texture2D
	if not source_tex:
		return
	planet_widget.setup(planet_corner_sprite, source_tex)


func _load_existing_game() -> void:
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()
	var planet = universe.get_player_planet()
	if planet:
		_setup_planet_widget(planet)


func _apply_prestige_bonuses_to_founders() -> void:
	var attack_bonus = PrestigeSystem.get_founder_attack_bonus()
	if attack_bonus <= 0:
		return
	for entity in GameState.entities:
		if entity.generation == 1 and entity.trait_primary == "warrior":
			entity.stats["attack"] = mini(
				entity.stats["attack"] + attack_bonus,
				GameState.get_stat_cap()
			)


# --- Signal handlers ---

func _on_entity_died(entity_data) -> void:
	_check_population_collapse()


func _check_population_collapse() -> void:
	var living = GameState.get_living_entities()
	if living.size() == 0:
		# Game over - all entities dead
		_handle_civilization_end()
	elif living.size() <= 2:
		# Warning: near extinction
		event_panel.show_lifeboat_option()


func _handle_civilization_end() -> void:
	# TODO: show game over screen / restart prompt
	pass


func _on_era_changed(new_era: int) -> void:
	hud.show_era_notification(new_era)
	ResourceSystem.daily_reset()


func _on_prestige_triggered(_count: int) -> void:
	pass  # Handled by prestige sequence signals


func _on_cohesion_changed(new_value: float) -> void:
	hud.update_cohesion(new_value)
	_check_cohesion_events(new_value)


func _check_cohesion_events(cohesion: float) -> void:
	if cohesion < 20.0:
		EventManager.generate_social_events()


func _on_prestige_sequence_started() -> void:
	prestige_screen.visible = true
	hud.visible = false
	event_panel.visible = false


func _on_prestige_sequence_finished() -> void:
	PrestigeSystem.complete_prestige_reset()
	hud.visible = true
	prestige_screen.visible = false
	_start_new_game()


func _on_god_message_ready(message: String) -> void:
	prestige_screen.show_god_message(message)


# --- UI forwarding ---

func open_memory_book() -> void:
	memory_book.visible = true
	memory_book.populate()


func close_memory_book() -> void:
	memory_book.visible = false
