extends Node

signal modifier_activated(modifier_id: String)
signal modifier_deactivated(modifier_id: String)
signal modifier_changed

const MAX_ACTIVE: int = 2
const CURE_ACCELERATE_COST: float = 30.0
const CURE_ACCELERATE_HOURS: float = 6.0

# Modifier definitions — narrative + mechanics keyed by id
const DEFINITIONS: Dictionary = {
	"walking_dead": {
		"title": "The Dead Walk",
		"description": "Your fallen rise again. They remember. They hunger.",
		"icon_color": [0.85, 0.15, 0.15, 1.0],
	},
	"poison_rain": {
		"title": "Poison Rain",
		"description": "Black droplets fall. Each daily cycle erodes your people.",
		"icon_color": [0.4, 0.85, 0.2, 1.0],
	},
}


class WorldModifier:
	var id: String = ""
	var activated_at: int = 0
	var duration_hours: float = 72.0
	var properties: Dictionary = {}

	func remaining_seconds(now: int) -> float:
		var elapsed: float = float(now - activated_at)
		return maxf(duration_hours * 3600.0 - elapsed, 0.0)

	func cure_progress(now: int) -> float:
		var total: float = duration_hours * 3600.0
		if total <= 0.0:
			return 1.0
		var elapsed: float = float(now - activated_at)
		return clampf(elapsed / total, 0.0, 1.0)


var active_modifiers: Array = []  # Array[WorldModifier]


# --- Public API ---

func activate(modifier_id: String, duration_hours: float = 72.0, properties: Dictionary = {}) -> bool:
	if is_active(modifier_id):
		return false
	if active_modifiers.size() >= MAX_ACTIVE:
		return false
	if not DEFINITIONS.has(modifier_id):
		push_warning("WorldModifierSystem: unknown modifier '%s'" % modifier_id)
		return false
	var m := WorldModifier.new()
	m.id = modifier_id
	m.activated_at = Time.get_unix_time_from_system()
	m.duration_hours = duration_hours
	m.properties = properties.duplicate(true)
	active_modifiers.append(m)
	_on_modifier_activated(m)
	modifier_activated.emit(modifier_id)
	modifier_changed.emit()
	return true


func deactivate(modifier_id: String) -> void:
	for m in active_modifiers:
		if m.id == modifier_id:
			active_modifiers.erase(m)
			_on_modifier_deactivated(modifier_id)
			modifier_deactivated.emit(modifier_id)
			modifier_changed.emit()
			return


func is_active(modifier_id: String) -> bool:
	for m in active_modifiers:
		if m.id == modifier_id:
			return true
	return false


func get_modifier(modifier_id: String) -> WorldModifier:
	for m in active_modifiers:
		if m.id == modifier_id:
			return m
	return null


func spread_cure(modifier_id: String) -> bool:
	# Player spreads the cure when bar is full — instant resolve
	var m: WorldModifier = get_modifier(modifier_id)
	if m == null:
		return false
	var now: int = Time.get_unix_time_from_system()
	if m.cure_progress(now) < 1.0:
		return false
	deactivate(modifier_id)
	return true


func accelerate_cure(modifier_id: String) -> bool:
	# Spend divine energy to skip CURE_ACCELERATE_HOURS of remaining time
	var m: WorldModifier = get_modifier(modifier_id)
	if m == null:
		return false
	if not GameState.can_afford_divine_energy(CURE_ACCELERATE_COST):
		return false
	GameState.spend_divine_energy(CURE_ACCELERATE_COST)
	# Move activated_at backwards in time → cure_progress increases
	m.activated_at -= int(CURE_ACCELERATE_HOURS * 3600.0)
	modifier_changed.emit()
	return true


# --- Daily hook (called by TimeManager) ---

func process_daily_effects() -> void:
	for m in active_modifiers:
		_apply_daily(m)


func _apply_daily(m: WorldModifier) -> void:
	match m.id:
		"walking_dead":
			_walking_dead_daily(m)
		"poison_rain":
			_poison_rain_daily(m)


# --- Walking Dead ---

func _walking_dead_daily(_m: WorldModifier) -> void:
	# Each zombie attacks one random living entity, but damage is capped low
	# to avoid wiping the whole population in a single daily tick.
	var living: Array = GameState.get_living_entities()
	if living.is_empty():
		return
	var zombie_count: int = 0
	for e in GameState.entities:
		if not e.is_alive:
			zombie_count += 1
	if zombie_count == 0:
		return
	# Total damage budget per day: at most half of total living health, never more
	for e in GameState.entities:
		if e.is_alive:
			continue
		if living.is_empty():
			break
		var target = living[randi() % living.size()]
		var zombie_attack: int = int(e.stats.get("attack", 0))
		# Capped per-attack damage: max 4 hp regardless of zombie attack stat
		var capped_dmg: int = mini(zombie_attack, 4)
		var variance: float = randf_range(0.6, 1.1)
		var final_dmg: int = maxi(int(float(capped_dmg) * variance), 1)
		target.stats["health"] = maxi(int(target.stats.get("health", 0)) - final_dmg, 0)
		if int(target.stats["health"]) <= 0:
			living = GameState.get_living_entities()


func _poison_rain_daily(_m: WorldModifier) -> void:
	for e in GameState.get_living_entities():
		e.stats["health"] = maxi(int(e.stats.get("health", 0)) - 3, 0)


# --- Activation / deactivation hooks ---

func _on_modifier_activated(m: WorldModifier) -> void:
	# Walking dead: keep dead bodies until cure spreads
	pass


func _on_modifier_deactivated(modifier_id: String) -> void:
	# Walking dead cured → purge any remaining bodies
	if modifier_id == "walking_dead":
		GameState.purge_dead_entities()


# --- Save / load ---

func serialize() -> Array:
	var out: Array = []
	for m in active_modifiers:
		out.append({
			"id": m.id,
			"activated_at": m.activated_at,
			"duration_hours": m.duration_hours,
			"properties": m.properties,
		})
	return out


func deserialize(arr: Array) -> void:
	active_modifiers.clear()
	for raw in arr:
		var m := WorldModifier.new()
		m.id = String(raw.get("id", ""))
		m.activated_at = int(raw.get("activated_at", 0))
		m.duration_hours = float(raw.get("duration_hours", 72.0))
		m.properties = raw.get("properties", {})
		if DEFINITIONS.has(m.id):
			active_modifiers.append(m)
	modifier_changed.emit()


func reset() -> void:
	active_modifiers.clear()
	modifier_changed.emit()
