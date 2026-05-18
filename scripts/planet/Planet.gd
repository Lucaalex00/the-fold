extends Node

var planet_id: String = ""
var planet_name: String = ""
var sprite_index: int = 0      # 0-14, indice sprite in assets/planets/

var omini_ids: Array = []      # ID degli omini su questo pianeta


func setup(p_id: String, p_name: String, p_sprite: int) -> void:
	planet_id = p_id
	planet_name = p_name
	sprite_index = p_sprite


func initialize_founders() -> void:
	var founders = OminoGenerator.create_founders(planet_id)
	for omino in founders:
		GameState.omini.append(omino)
		omini_ids.append(omino.id)
	CultureSystem.update_cohesion()
	ResourceSystem.daily_reset()


func get_living_omini() -> Array:
	return GameState.omini.filter(func(o): return o.is_alive and omini_ids.has(o.id))


func get_omini_count() -> int:
	return get_living_omini().size()


func can_add_omino() -> bool:
	return get_omini_count() < GameState.get_omini_limit()


func add_omino(omino: GameState.OminoData) -> void:
	if not omini_ids.has(omino.id):
		omini_ids.append(omino.id)
	if not GameState.omini.any(func(o): return o.id == omino.id):
		GameState.omini.append(omino)
	CultureSystem.update_cohesion()
