extends Node
class_name Planet

var planet_id: String = ""
var planet_name: String = ""
var sprite_index: int = 0      # 0-14, sprite index in assets/planets/

var entity_ids: Array = []      # IDs of entities on this planet


func setup(p_id: String, p_name: String, p_sprite: int) -> void:
	planet_id = p_id
	planet_name = p_name
	sprite_index = p_sprite


func initialize_founders() -> void:
	var founders = EntityGenerator.create_founders(planet_id)
	for entity in founders:
		GameState.entities.append(entity)
		entity_ids.append(entity.id)
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()


func get_living_entities() -> Array:
	return GameState.entities.filter(func(o): return o.is_alive and entity_ids.has(o.id))


func get_entity_count() -> int:
	return get_living_entities().size()


func can_add_entity() -> bool:
	return get_entity_count() < GameState.get_entity_limit()


func add_entity(entity: GameState.EntityData) -> void:
	if not entity_ids.has(entity.id):
		entity_ids.append(entity.id)
	if not GameState.entities.any(func(o): return o.id == entity.id):
		GameState.entities.append(entity)
	CultureSystem.update_cohesion()
