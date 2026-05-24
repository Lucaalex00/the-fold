extends Node2D

signal planet_encountered(bot)

const BOT_PLANET_COUNT = 5
const PLANET_SPRITES = [
	"Earth", "Mars", "Jupiter", "Saturn", "Neptune",
	"Venus", "Mercury", "Moon", "Uranus", "Crystal",
	"Hot", "Icy", "Radiated", "Terrestrial", "Sun"
]

# Encounter distances: spread across the journey. First encounter ~750K, last ~120K.
const ENCOUNTER_DISTANCES: Array = [750_000.0, 550_000.0, 380_000.0, 230_000.0, 120_000.0]

var player_planet: Planet = null
var bot_planets: Array = []

@export var planet_scene: PackedScene
@export var bot_planet_scene: PackedScene


func _ready() -> void:
	_setup_player_planet()
	_generate_bot_planets()
	PrestigeSystem.prestige_sequence_finished.connect(_on_prestige_finished)


func _on_prestige_finished() -> void:
	regenerate_bot_planets()


func regenerate_bot_planets() -> void:
	for bot in bot_planets:
		if is_instance_valid(bot):
			bot.queue_free()
	bot_planets.clear()
	_generate_bot_planets()


func _process(_delta: float) -> void:
	_check_encounters()


func _check_encounters() -> void:
	var d: float = GameState.distance_from_center
	for bot in bot_planets:
		if bot.was_encountered:
			continue
		if d <= bot.encounter_distance:
			bot.was_encountered = true
			planet_encountered.emit(bot)


func _setup_player_planet() -> void:
	if planet_scene == null:
		return
	var planet_node = planet_scene.instantiate()
	add_child(planet_node)
	player_planet = planet_node
	player_planet.setup("player_planet_0", "Your World", 0)
	player_planet.position = Vector2(195, 422)  # Center of 390x844 viewport


func _generate_bot_planets() -> void:
	for i in range(BOT_PLANET_COUNT):
		var bot = BotPlanet.new()
		bot.setup(
			"bot_planet_%d" % i,
			_random_planet_name(),
			(i + 1) % PLANET_SPRITES.size()
		)
		# Assign a distinct encounter distance along the journey (±10% jitter)
		var base_d: float = ENCOUNTER_DISTANCES[i % ENCOUNTER_DISTANCES.size()]
		var jittered: float = base_d * randf_range(0.9, 1.1)
		bot.set_encounter_distance(jittered)
		bot_planets.append(bot)
		add_child(bot)
		bot.position = _bot_position(i)


func _bot_position(index: int) -> Vector2:
	var angle = (TAU / BOT_PLANET_COUNT) * index
	var radius = 280.0
	return Vector2(195, 422) + Vector2(cos(angle), sin(angle)) * radius


func _random_planet_name() -> String:
	var prefixes = ["Xen", "Vor", "Kal", "Mir", "Sol", "Ara", "Tos", "Vel"]
	var suffixes = ["ara", "ion", "ux", "eth", "orn", "iel", "ax", "um"]
	return prefixes[randi() % prefixes.size()] + suffixes[randi() % suffixes.size()]


func get_player_planet() -> Planet:
	return player_planet
