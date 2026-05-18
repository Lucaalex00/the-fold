extends CanvasLayer

@onready var distance_label: Label = $TopBar/DistanceLabel
@onready var distance_bar: ProgressBar = $TopBar/DistanceBar
@onready var era_label: Label = $TopBar/EraLabel
@onready var cohesion_bar: ProgressBar = $StatusBar/CohesionBar
@onready var cohesion_label: Label = $StatusBar/CohesionLabel
@onready var divine_energy_bar: ProgressBar = $StatusBar/DivineEnergyBar
@onready var divine_energy_label: Label = $StatusBar/DivineEnergyLabel
@onready var population_label: Label = $StatusBar/PopulationLabel
@onready var notification_label: Label = $NotificationLabel

const DISTANCE_START = 1_000_000.0
var _notification_timer: float = 0.0
const NOTIFICATION_DURATION = 3.0


func _process(delta: float) -> void:
	_update_distance()
	_update_divine_energy()
	_tick_notification(delta)


func _update_distance() -> void:
	var dist = GameState.distance_from_center
	var pct = clampf(1.0 - (dist / DISTANCE_START), 0.0, 1.0) * 100.0

	distance_label.text = L.t("DISTANCE_LABEL", {
		"distance": _format_distance(dist)
	})
	distance_bar.value = pct


func _update_divine_energy() -> void:
	divine_energy_bar.value = (GameState.divine_energy / GameState.divine_energy_max) * 100.0
	divine_energy_label.text = L.t("DIVINE_ENERGY_LABEL") + ": %d/%d" % [
		int(GameState.divine_energy),
		int(GameState.divine_energy_max)
	]


func refresh() -> void:
	update_cohesion(CultureSystem.cohesion)
	_update_era()
	_update_population()


func update_cohesion(value: float) -> void:
	cohesion_bar.value = value
	var state = CultureSystem.get_cohesion_state()
	cohesion_label.text = L.t("COHESION_LABEL") + ": " + L.t("COHESION_" + state.to_upper())


func _update_era() -> void:
	era_label.text = L.t("ERA_LABEL", {
		"era": GameState.current_era,
		"name": L.get_era_name(GameState.current_era)
	})


func _update_population() -> void:
	population_label.text = L.t("LIVING_OMINI_LABEL") + ": " + \
		str(GameState.get_living_entities().size()) + "/" + str(GameState.get_entity_limit())


func show_era_notification(era: int) -> void:
	_update_era()
	_update_population()
	show_notification(L.t("ERA_LABEL", {
		"era": era,
		"name": L.get_era_name(era)
	}))


func show_notification(text: String) -> void:
	notification_label.text = text
	notification_label.visible = true
	_notification_timer = NOTIFICATION_DURATION


func _tick_notification(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			notification_label.visible = false


func show_lifeboat_option() -> void:
	show_notification("⚠ " + L.t("LIVING_OMINI_LABEL") + ": 2")


func _format_distance(dist: float) -> String:
	if dist >= 1_000_000:
		return "%.2f M" % (dist / 1_000_000.0)
	if dist >= 1_000:
		return "%.1f K" % (dist / 1_000.0)
	return str(int(dist))
