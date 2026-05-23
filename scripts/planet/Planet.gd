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


func initialize_founders(random: bool = false) -> void:
	var founders: Array
	if random:
		founders = _create_random_pair()
	else:
		founders = EntityGenerator.create_founders(planet_id)
	for entity in founders:
		GameState.entities.append(entity)
		entity_ids.append(entity.id)
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()


func _create_random_pair() -> Array:
	var trait_pool: Array = ["builder", "warrior", "fisher", "scientist", "diplomat", "farmer", "healer", "explorer"]
	var first_trait: String = trait_pool[randi() % trait_pool.size()]
	var second_trait: String = trait_pool[randi() % trait_pool.size()]
	while second_trait == first_trait and trait_pool.size() > 1:
		second_trait = trait_pool[randi() % trait_pool.size()]
	var a := EntityGenerator.create_entity(first_trait, planet_id)
	var b := EntityGenerator.create_entity(second_trait, planet_id)
	return [a, b]


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
