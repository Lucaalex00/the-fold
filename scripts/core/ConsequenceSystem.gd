extends Node

# Modular effect resolver for event choices and expiry.
# Effects are dictionaries with shape:
#   {"type": EFFECT_TYPE, ...args}
# Supported effect types: stat, planet_hp, divine_energy, cohesion, kill, spawn, nothing

const VALID_STATS: Array = [
	"health", "energy", "intelligence",
	"attack", "construction", "harvest",
	"fishing", "research", "diplomacy",
]

const VALID_SCOPES: Array = [
	"all", "random_one", "warriors", "builders",
	"healers", "scientists", "weakest", "strongest",
]


# --- Public API ---

func apply_effects(effects: Array) -> void:
	if effects == null:
		return
	for effect in effects:
		if effect is Dictionary:
			_apply_one(effect)


# --- Dispatch ---

func _apply_one(effect: Dictionary) -> void:
	var type: String = String(effect.get("type", ""))
	match type:
		"stat":          _apply_stat(effect)
		"planet_hp":     _apply_planet_hp(effect)
		"divine_energy": _apply_divine_energy(effect)
		"cohesion":      _apply_cohesion(effect)
		"kill":          _apply_kill(effect)
		"spawn":         _apply_spawn(effect)
		"nothing", "":   pass


# --- Stat delta (modular: one method handles all stats) ---

func _apply_stat(effect: Dictionary) -> void:
	var stat: String = String(effect.get("stat", ""))
	if not VALID_STATS.has(stat):
		push_warning("ConsequenceSystem: invalid stat '%s'" % stat)
		return
	var delta: int = int(effect.get("delta", 0))
	var scope: String = String(effect.get("scope", "all"))
	var targets: Array = _select_targets(scope)
	var cap: int = GameState.get_stat_cap()
	for entity in targets:
		if not entity.is_alive:
			continue
		var current: int = int(entity.stats.get(stat, 0))
		entity.stats[stat] = clampi(current + delta, 0, cap)


# --- Target selection (modular: one method handles all scopes) ---

func _select_targets(scope: String) -> Array:
	var living: Array = GameState.get_living_entities()
	if living.is_empty():
		return []
	match scope:
		"all":
			return living
		"random_one":
			return [living.pick_random()]
		"warriors":
			return living.filter(func(e): return e.trait_primary == "warrior")
		"builders":
			return living.filter(func(e): return e.trait_primary == "builder")
		"healers":
			return living.filter(func(e): return e.trait_primary == "healer")
		"scientists":
			return living.filter(func(e): return e.trait_primary == "scientist")
		"weakest":
			return [_find_extreme(living, true)]
		"strongest":
			return [_find_extreme(living, false)]
	push_warning("ConsequenceSystem: unknown scope '%s'" % scope)
	return []


func _find_extreme(living: Array, want_min: bool):
	var best = living[0]
	var best_total: int = _stats_total(best)
	for entity in living:
		var t: int = _stats_total(entity)
		if (want_min and t < best_total) or (not want_min and t > best_total):
			best_total = t
			best = entity
	return best


func _stats_total(entity) -> int:
	var total: int = 0
	for k in entity.stats.keys():
		total += int(entity.stats[k])
	return total


# --- Planet HP ---

func _apply_planet_hp(effect: Dictionary) -> void:
	var delta: float = float(effect.get("delta", 0.0))
	if delta > 0.0:
		GameState.regen_planet_hp(delta)
	else:
		GameState.damage_planet(absf(delta))


# --- Divine energy ---

func _apply_divine_energy(effect: Dictionary) -> void:
	var delta: float = float(effect.get("delta", 0.0))
	GameState.divine_energy = clampf(
		GameState.divine_energy + delta,
		0.0,
		GameState.divine_energy_max
	)


# --- Cohesion ---

func _apply_cohesion(effect: Dictionary) -> void:
	var delta: float = float(effect.get("delta", 0.0))
	CultureSystem.cohesion = clampf(CultureSystem.cohesion + delta, 0.0, 100.0)
	GameState.emit_signal("cohesion_changed", CultureSystem.cohesion)


# --- Kill entities ---

func _apply_kill(effect: Dictionary) -> void:
	var count: int = int(effect.get("count", 1))
	var scope: String = String(effect.get("scope", "random_one"))
	var cause: String = String(effect.get("cause", "event"))
	var targets: Array = _select_targets(scope)
	var n: int = mini(count, targets.size())
	for i in range(n):
		var target = targets[i]
		if target.is_alive:
			GameState.register_entity_death(target, cause)


# --- Spawn entity (era 2+ feature, placeholder) ---

func _apply_spawn(_effect: Dictionary) -> void:
	# TODO: integrate with EntityGenerator once founders-vs-procedural is finalized
	pass
