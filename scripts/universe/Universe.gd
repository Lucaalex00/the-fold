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

# Bot planet asset pool — picked randomly per bot. Each is a 16-frame 1600x100 spritesheet.
const BOT_PLANET_ASSETS: Array = [
	{"path": "res://assets/planets/bots/planet_dry_01.png",  "type": "dry"},
	{"path": "res://assets/planets/bots/planet_dry_02.png",  "type": "dry"},
	{"path": "res://assets/planets/bots/planet_dry_03.png",  "type": "dry"},
	{"path": "res://assets/planets/bots/planet_dry_04.png",  "type": "dry"},
	{"path": "res://assets/planets/bots/planet_dry_05.png",  "type": "dry"},
	{"path": "res://assets/planets/bots/planet_gas_01.png",  "type": "gas"},
	{"path": "res://assets/planets/bots/planet_gas_02.png",  "type": "gas"},
	{"path": "res://assets/planets/bots/planet_gas_03.png",  "type": "gas"},
	{"path": "res://assets/planets/bots/planet_ice_01.png",  "type": "ice"},
	{"path": "res://assets/planets/bots/planet_island_01.png","type": "island"},
	{"path": "res://assets/planets/bots/planet_island_02.png","type": "island"},
	{"path": "res://assets/planets/bots/planet_lava_01.png", "type": "lava"},
	{"path": "res://assets/planets/bots/planet_lava_02.png", "type": "lava"},
	{"path": "res://assets/planets/bots/planet_lava_03.png", "type": "lava"},
	{"path": "res://assets/planets/bots/planet_no_atmosphere_01.png", "type": "barren"},
	{"path": "res://assets/planets/bots/planet_no_atmosphere_02.png", "type": "barren"},
]

var player_planet: Planet = null
var bot_planets: Array = []

@export var planet_scene: PackedScene
@export var bot_planet_scene: PackedScene


func _ready() -> void:
	_setup_player_planet()
	_generate_bot_planets()
	PrestigeSystem.prestige_sequence_finished.connect(_on_prestige_finished)


func regenerate_bot_planets() -> void:
	for bot in bot_planets:
		if is_instance_valid(bot):
			bot.queue_free()
	bot_planets.clear()
	_generate_bot_planets()


var _last_distance: float = -1.0


func _process(_delta: float) -> void:
	_check_encounters()


func _check_encounters() -> void:
	var d: float = GameState.distance_from_center
	# Edge-detection: only fire when the player CROSSES the encounter threshold
	# from above this frame. Prevents a burst of encounters when distance is reset
	# (prestige flow regenerates bots while distance is still at 0, then resets to 1M).
	if _last_distance < 0.0:
		_last_distance = d
		return
	if d >= _last_distance:
		# Distance increased (reset) or stayed — no new crossings to fire
		_last_distance = d
		return
	for bot in bot_planets:
		if bot.was_encountered:
			continue
		# Crossed downward through encounter_distance this frame
		if _last_distance > bot.encounter_distance and d <= bot.encounter_distance:
			bot.was_encountered = true
			planet_encountered.emit(bot)
	_last_distance = d


func _on_prestige_finished() -> void:
	regenerate_bot_planets()
	# Re-arm edge detection so the first frame after reset doesn't count as a crossing
	_last_distance = -1.0


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
		# Random visual identity: pick an asset + a random frame from its 16-frame strip
		var asset: Dictionary = BOT_PLANET_ASSETS[randi() % BOT_PLANET_ASSETS.size()]
		bot.display_sprite_path = String(asset["path"])
		bot.display_type = String(asset["type"])
		bot.display_frame = randi() % 16
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
