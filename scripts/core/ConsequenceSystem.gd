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
		"stat":           _apply_stat(effect)
		"planet_hp":      _apply_planet_hp(effect)
		"divine_energy":  _apply_divine_energy(effect)
		"cohesion":       _apply_cohesion(effect)
		"kill":           _apply_kill(effect)
		"spawn":          _apply_spawn(effect)
		"collapse":       _apply_collapse(effect)
		"world_modifier": _apply_world_modifier(effect)
		"nothing", "":    pass


func _apply_world_modifier(effect: Dictionary) -> void:
	var action: String = String(effect.get("action", "activate"))
	var modifier_id: String = String(effect.get("id", ""))
	if modifier_id == "":
		return
	match action:
		"activate":
			var duration: float = float(effect.get("duration", 72.0))
			var props: Dictionary = effect.get("properties", {})
			WorldModifierSystem.activate(modifier_id, duration, props)
		"deactivate":
			WorldModifierSystem.deactivate(modifier_id)


func _apply_collapse(_effect: Dictionary) -> void:
	GameState.planet_base_hp = 0.0
	GameState.planet_collapsed.emit()


# --- Stat delta (modular: one method handles all stats) ---

func _apply_stat(effect: Dictionary) -> void:
	var stat: String = String(effect.get("stat", ""))
	if not VALID_STATS.has(stat):
		push_warning("ConsequenceSystem: invalid stat '%s'" % stat)
		return
	var delta: int = int(effect.get("delta", 0))
	var scope: String = String(effect.get("scope", "all"))
	var targets: Array = _select_targets(scope)
	# No upper cap — stats can scale infinitely. Only floor at 0.
	for entity in targets:
		if not entity.is_alive:
			continue
		var current: int = int(entity.stats.get(stat, 0))
		entity.stats[stat] = maxi(current + delta, 0)


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
	GameState.modify_divine_energy(delta)


# --- Cohesion ---

func _apply_cohesion(effect: Dictionary) -> void:
	var delta: float = float(effect.get("delta", 0.0))
	CultureSystem.modify_cohesion(delta)


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


# --- Spawn entity ---

func _apply_spawn(effect: Dictionary) -> void:
	var kind: String = String(effect.get("kind", "child"))
	var options: Dictionary = {}
	if effect.has("trait"):
		options["trait"] = effect["trait"]
	if effect.has("origin"):
		options["origin"] = effect["origin"]
	SpawnSystem.spawn(kind, options)
