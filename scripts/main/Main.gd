extends Node2D

const BACKGROUNDS = [
	"res://assets/ui/backgrounds/red_background.png",
	"res://assets/ui/backgrounds/blue-backgrounds.png",
]

@onready var background: TextureRect = $Background
@onready var hud: CanvasLayer = $HUD
@onready var event_panel: CanvasLayer = $EventPanel
@onready var memory_book: CanvasLayer = $MemoryBook
@onready var prestige_screen: CanvasLayer = $PrestigeScreen
@onready var universe: Node2D = $Universe

var _is_new_game: bool = false


func _ready() -> void:
	_set_session_background()
	_connect_signals()
	_init_game()


func _set_session_background() -> void:
	if GameState.session_background_index < 0:
		GameState.session_background_index = randi() % BACKGROUNDS.size()
	background.texture = load(BACKGROUNDS[GameState.session_background_index])


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
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()
	SaveManager.save_game()


func _load_existing_game() -> void:
	# SaveManager._ready() already loaded the save — just refresh UI
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()


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
