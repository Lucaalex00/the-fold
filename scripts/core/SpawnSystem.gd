extends Node

signal needs_replacement(new_entity: GameState.EntityData, current_entities: Array)
signal spawned(new_entity: GameState.EntityData)


func spawn(kind: String, options: Dictionary = {}) -> void:
	var origin: String = String(options.get("origin", _current_planet_id()))
	var new_entity: GameState.EntityData = null
	match kind:
		"child":
			new_entity = _spawn_child(origin)
		"immigrant":
			new_entity = _spawn_immigrant(String(options.get("trait", "explorer")), origin)
		"founder":
			new_entity = _spawn_founder(origin)
		_:
			push_warning("SpawnSystem: unknown kind '%s'" % kind)
			return
	if new_entity == null:
		return
	_register_or_replace(new_entity)


func _spawn_child(origin: String) -> GameState.EntityData:
	var living: Array = GameState.get_living_entities()
	if living.size() < 2:
		# Fall back to immigrant if there aren't two parents available
		return _spawn_immigrant("explorer", origin)
	var p1 = living[randi() % living.size()]
	var p2 = p1
	var attempts: int = 0
	while p2 == p1 and attempts < 10:
		p2 = living[randi() % living.size()]
		attempts += 1
	return GeneticSystem.generate_child(p1, p2, origin)


func _spawn_immigrant(trait_name: String, origin: String) -> GameState.EntityData:
	return EntityGenerator.create_entity(trait_name, origin)


func _spawn_founder(origin: String) -> GameState.EntityData:
	# Founder-tier entity: random trait, base stats boosted by 50%
	var traits: Array = ["builder", "warrior", "scientist", "diplomat", "healer", "explorer"]
	var pick: String = traits[randi() % traits.size()]
	var entity: GameState.EntityData = EntityGenerator.create_entity(pick, origin)
	for stat in entity.stats.keys():
		entity.stats[stat] = int(float(entity.stats[stat]) * 1.5)
	return entity


func _register_or_replace(new_entity: GameState.EntityData) -> void:
	# Living-only count vs entity limit (dead bodies don't block spawn)
	var living: Array = GameState.get_living_entities()
	if living.size() < GameState.get_entity_limit():
		GameState.entities.append(new_entity)
		spawned.emit(new_entity)
		return
	# At cap — ask the player to replace (or skip)
	needs_replacement.emit(new_entity, living)


func replace_entity(target_id: String, new_entity: GameState.EntityData) -> void:
	# Remove the target (treat as event-driven death) and append the new one
	for e in GameState.entities:
		if e.id == target_id and e.is_alive:
			GameState.register_entity_death(e, "replaced")
			break
	GameState.entities.append(new_entity)
	spawned.emit(new_entity)


func cancel_spawn(_new_entity: GameState.EntityData) -> void:
	# Player chose to skip the replacement → discard the spawn
	pass


func _current_planet_id() -> String:
	# Lightweight identifier — placeholder; full universe integration may override later.
	return "planet_player"
