extends Node2D

@onready var hud: CanvasLayer = $HUD
@onready var event_panel: CanvasLayer = $EventPanel
@onready var memory_book: CanvasLayer = $MemoryBook
@onready var prestige_screen: CanvasLayer = $PrestigeScreen
@onready var universe: Node2D = $Universe
@onready var planet_corner_sprite: Sprite2D = $PlanetLayer/PlanetCornerSprite
@onready var planet_widget: Control = $PlanetLayer/PlanetInput

var _is_new_game: bool = false
var _event_queue: Array = []
var _processing_event: bool = false
var _bg_files: Array[String] = []
var _current_bg: Sprite2D = null
var _current_bg_index: int = -1
var _timer_chips: CanvasLayer = null
var _divine_chip: CanvasLayer = null
var _spawn_modal: CanvasLayer = null
var _pending_spawn_entity: GameState.EntityData = null
var _blackhole_approach: CanvasLayer = null
var _modifier_bars: CanvasLayer = null
var _modifier_modal: CanvasLayer = null


func _ready() -> void:
	_setup_timer_chips()
	_connect_signals()
	_setup_background()
	_init_game()


# --- DEBUG SHORTCUTS (remove before release) ---
# Number keys with F-key fallbacks. Avoids F8 (Godot stop) and F11 (fullscreen).
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() and not OS.has_feature("editor"):
		return
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	var kc: int = k.keycode

	if kc == KEY_1 or kc == KEY_F1:
		print("[DEBUG] Forcing collapse")
		for e in GameState.entities:
			if e.is_alive:
				GameState.register_entity_death(e, "debug")
		GameState.planet_base_hp = 0.0
		GameState.emit_signal("planet_collapsed")
	elif kc == KEY_2 or kc == KEY_F2:
		print("[DEBUG] Distance -> 50000 (BH visible)")
		GameState.distance_from_center = 50_000.0
	elif kc == KEY_3 or kc == KEY_F3:
		print("[DEBUG] Distance -> 0 (BH reached)")
		GameState.distance_from_center = 0.0
	elif kc == KEY_4 or kc == KEY_F4:
		print("[DEBUG] Activate walking_dead (72h)")
		WorldModifierSystem.activate("walking_dead", 72.0)
	elif kc == KEY_5 or kc == KEY_F5:
		print("[DEBUG] Activate poison_rain (48h)")
		WorldModifierSystem.activate("poison_rain", 48.0)
	elif kc == KEY_6 or kc == KEY_F6:
		print("[DEBUG] Spawn child")
		SpawnSystem.spawn("child")
	elif kc == KEY_7 or kc == KEY_F7:
		print("[DEBUG] Spawn founder")
		SpawnSystem.spawn("founder")
	elif kc == KEY_8:
		print("[DEBUG] +100 divine energy")
		GameState.modify_divine_energy(100.0)
	elif kc == KEY_9 or kc == KEY_F9:
		print("[DEBUG] Damage random entity -20 health")
		var living: Array = GameState.get_living_entities()
		if not living.is_empty():
			var t = living[randi() % living.size()]
			t.stats["health"] = maxi(int(t.stats.get("health", 0)) - 20, 0)
	elif kc == KEY_0 or kc == KEY_F10:
		print("[DEBUG] Force daily reset")
		TimeManager._perform_daily_reset()
	elif kc == KEY_Q:
		print("[DEBUG] Generate social events")
		EventManager.generate_social_events()
	elif kc == KEY_W or kc == KEY_F12:
		print("[DEBUG] Generate cosmic event")
		EventManager._maybe_generate_cosmic_event()
	elif kc == KEY_E:
		print("[DEBUG] State dump:")
		print("  Era: %d  Day: %d  Distance: %.0f" % [GameState.current_era, GameState.current_day, GameState.distance_from_center])
		print("  Planet HP: %.1f / %.1f" % [GameState.get_planet_hp(), GameState.get_planet_hp_max()])
		print("  Divine: %.0f / %.0f" % [GameState.divine_energy, GameState.divine_energy_max])
		print("  Cohesion: %.0f" % CultureSystem.cohesion)
		print("  Entities (living/total): %d/%d" % [GameState.get_living_entities().size(), GameState.entities.size()])
		print("  Modifiers: %d" % WorldModifierSystem.active_modifiers.size())


func _setup_timer_chips() -> void:
	var script = load("res://scripts/ui/EventTimerChips.gd")
	_timer_chips = CanvasLayer.new()
	_timer_chips.set_script(script)
	add_child(_timer_chips)

	var de_script = load("res://scripts/ui/DivineEnergyChip.gd")
	_divine_chip = CanvasLayer.new()
	_divine_chip.set_script(de_script)
	add_child(_divine_chip)

	var sm_script = load("res://scripts/ui/SpawnReplacementModal.gd")
	_spawn_modal = CanvasLayer.new()
	_spawn_modal.set_script(sm_script)
	add_child(_spawn_modal)
	_spawn_modal.replace_chosen.connect(_on_spawn_replace_chosen)
	_spawn_modal.skipped.connect(_on_spawn_skipped)

	var bh_script = load("res://scripts/ui/BlackHoleApproach.gd")
	_blackhole_approach = CanvasLayer.new()
	_blackhole_approach.set_script(bh_script)
	add_child(_blackhole_approach)
	_blackhole_approach.enter_pressed.connect(_on_blackhole_enter_pressed)

	# Cosmos dim: dedicated CanvasLayer at layer 5 → above background sprite (default
	# layer 0, z_index -100), below TopBar (50), HUD (55), Planet (60), chips (65).
	# Topbar, HUD, planet, chips, modifier bars, timer chips → all stay bright.
	var bh_dim_layer := CanvasLayer.new()
	bh_dim_layer.layer = 5
	add_child(bh_dim_layer)
	var bh_bg_dim := ColorRect.new()
	bh_bg_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	bh_bg_dim.position = Vector2.ZERO
	bh_bg_dim.size = Vector2(390, 844)
	bh_bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bh_dim_layer.add_child(bh_bg_dim)
	_blackhole_approach.set_bg_dim(bh_bg_dim)

	var bars_script = load("res://scripts/ui/ModifierStatusBars.gd")
	_modifier_bars = CanvasLayer.new()
	_modifier_bars.set_script(bars_script)
	add_child(_modifier_bars)
	_modifier_bars.bar_clicked.connect(_on_modifier_bar_clicked)

	var modal_script = load("res://scripts/ui/ModifierModal.gd")
	_modifier_modal = CanvasLayer.new()
	_modifier_modal.set_script(modal_script)
	add_child(_modifier_modal)


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
	GameState.entities_purged.connect(_on_entities_purged)
	GameState.era_changed.connect(_on_era_changed)
	GameState.prestige_triggered.connect(_on_prestige_triggered)
	GameState.cohesion_changed.connect(_on_cohesion_changed)
	GameState.planet_collapsed.connect(_on_planet_collapsed)
	GameState.blackhole_reached.connect(_on_blackhole_reached)
	SpawnSystem.needs_replacement.connect(_on_spawn_needs_replacement)
	SpawnSystem.spawned.connect(_on_spawn_completed)
	PrestigeSystem.prestige_sequence_started.connect(_on_prestige_sequence_started)
	PrestigeSystem.prestige_sequence_finished.connect(_on_prestige_sequence_finished)
	PrestigeSystem.god_message_ready.connect(_on_god_message_ready)
	EventManager.event_created.connect(_on_event_created)
	AlertSystem.alert_finished.connect(_on_alert_finished)
	event_panel.event_resolved.connect(_on_event_resolved)
	_timer_chips.chip_clicked.connect(_on_chip_clicked)
	prestige_screen.continue_pressed.connect(_on_prestige_continue)


func _init_game() -> void:
	_is_new_game = not FileAccess.file_exists("user://save.json")

	if _is_new_game:
		_start_new_game()
	else:
		_load_existing_game()

	hud.refresh()

	# If the save returned in a collapsed state, trigger the auto-prestige flow
	# BEFORE generating any new events, so the player sees only the collapse screen.
	if not _is_new_game and GameState.is_collapsed():
		EventManager.active_social_events.clear()
		EventManager.active_cosmic_event = null
		_on_planet_collapsed()
		return

	EventManager.generate_daily_events()


func _start_new_game(random_rebirth: bool = false) -> void:
	var planet = universe.get_player_planet()
	if planet:
		planet.entity_ids.clear()
		# On rebirth, randomize the planet sprite so the new world looks different
		if random_rebirth:
			planet.sprite_index = randi() % PLAYER_PLANET_COUNT
		planet.initialize_founders(random_rebirth)
		_apply_prestige_bonuses_to_founders()
		_setup_planet_widget(planet)
		planet_widget.refresh_entities()
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()
	hud.refresh()
	SaveManager.save_game()


const PLAYER_PLANET_COUNT = 18

func _setup_planet_widget(planet: Planet) -> void:
	var index = (planet.sprite_index % PLAYER_PLANET_COUNT) + 1
	var path = "res://assets/planets/player/planet_%02d.png" % index
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


# --- Event flow ---

func _on_event_created(event: EventManager.GameEvent) -> void:
	_timer_chips.add_chip(event)
	_event_queue.append(event)
	if not _processing_event:
		_process_next_event()


func _process_next_event() -> void:
	if _event_queue.is_empty():
		_processing_event = false
		event_panel.unlock_input()
		return
	_processing_event = true
	event_panel.lock_input()
	var event = _event_queue.pop_front()
	match event.urgency:
		EventManager.EventUrgency.FATAL:    AlertSystem.fatal_event(event)
		EventManager.EventUrgency.CRITICAL: AlertSystem.critical_event(event)
		EventManager.EventUrgency.URGENT:   AlertSystem.warning_event(event)
		_:                                  AlertSystem.notify_event(event)


func _on_alert_finished(event) -> void:
	if event == null:
		return
	await get_tree().create_timer(0.3).timeout
	event_panel.activate_blocker()
	event_panel.show_event(event)


func _on_event_resolved(event) -> void:
	if event != null:
		# Keep chip for: CRITICAL/FATAL (always), or any urgency dismissed without choice
		var keep: bool = (
			event.urgency == EventManager.EventUrgency.CRITICAL or
			event.urgency == EventManager.EventUrgency.FATAL or
			event.chosen_choice_index < 0
		)
		if not keep:
			_timer_chips.remove_chip(event.id)
	if _event_queue.is_empty():
		_processing_event = false
		event_panel.unlock_input()
		return
	await get_tree().create_timer(2.5).timeout
	_process_next_event()


func _on_chip_clicked(event) -> void:
	event_panel.activate_blocker()
	event_panel.show_event(event)


# --- Spawn flow ---

func _on_spawn_needs_replacement(new_entity: GameState.EntityData, current_entities: Array) -> void:
	_pending_spawn_entity = new_entity
	_spawn_modal.show_replacement(new_entity, current_entities)


func _on_spawn_replace_chosen(target_id: String) -> void:
	if _pending_spawn_entity:
		SpawnSystem.replace_entity(target_id, _pending_spawn_entity)
		_pending_spawn_entity = null


func _on_spawn_skipped() -> void:
	if _pending_spawn_entity:
		SpawnSystem.cancel_spawn(_pending_spawn_entity)
		_pending_spawn_entity = null


func _on_spawn_completed(_new_entity: GameState.EntityData) -> void:
	planet_widget.refresh_entities()


# --- Black Hole ending ---

func _on_blackhole_enter_pressed() -> void:
	_on_blackhole_reached()


# --- World Modifier UI ---

func _on_modifier_bar_clicked(modifier_id: String) -> void:
	_modifier_modal.show_modifier(modifier_id)


# --- Signal handlers ---

func _on_entity_died(entity_data) -> void:
	_check_population_collapse()
	planet_widget.refresh_entities()


func _on_entities_purged() -> void:
	planet_widget.refresh_entities()


func _check_population_collapse() -> void:
	var living = GameState.get_living_entities()
	if living.size() == 0:
		_on_planet_collapsed()


var _collapse_in_progress: bool = false


func _on_planet_collapsed() -> void:
	if _collapse_in_progress:
		return
	_collapse_in_progress = true
	# Clear pending event flow before starting collapse
	_event_queue.clear()
	_processing_event = false
	event_panel.unlock_input()
	_clear_all_chips()
	PrestigeSystem.trigger_collapse_prestige()


func _on_blackhole_reached() -> void:
	if _collapse_in_progress:
		return
	_collapse_in_progress = true
	_event_queue.clear()
	_processing_event = false
	event_panel.unlock_input()
	_clear_all_chips()
	PrestigeSystem.trigger_blackhole_ending()


func _clear_all_chips() -> void:
	# Remove all chips since events are being wiped
	if _timer_chips:
		for id in _timer_chips._chips.keys():
			_timer_chips.remove_chip(id)


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
	planet_widget.visible = false
	if _divine_chip:
		_divine_chip.visible = false
	if _modifier_bars:
		_modifier_bars.visible = false
	if _timer_chips:
		_timer_chips.visible = false


func _on_prestige_sequence_finished() -> void:
	# Triggered after god message + bonus assignment; wait for player continue tap.
	# Continue is wired below via prestige_screen.continue_pressed
	pass


func _on_prestige_continue() -> void:
	# PrestigeScreen manages its own fade-out; do not toggle its visibility here.
	PrestigeSystem.complete_prestige_reset()
	hud.visible = true
	event_panel.visible = false
	planet_widget.visible = true
	if _divine_chip:
		_divine_chip.visible = true
	if _modifier_bars:
		_modifier_bars.visible = true
	if _timer_chips:
		_timer_chips.visible = true
	_collapse_in_progress = false
	_start_new_game(true)  # rebirth → random pair of founders


func _on_god_message_ready(message: String) -> void:
	prestige_screen.show_god_message(message)


# --- UI forwarding ---

func open_memory_book() -> void:
	memory_book.visible = true
	memory_book.populate()


func close_memory_book() -> void:
	memory_book.visible = false
