extends Node

var _traits: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var file = FileAccess.open("res://data/traits.json", FileAccess.READ)
	if not file:
		push_error("TraitDatabase: traits.json non trovato")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_traits = parsed


func get_trait(trait_name: String) -> Dictionary:
	return _traits.get(trait_name, {})


func get_all_trait_names() -> Array:
	return _traits.keys()


# Restituisce le stat base per un tratto, con variazione ±20% random
func get_base_stats(trait_name: String) -> Dictionary:
	var trait_data = get_trait(trait_name)
	var base: Dictionary = trait_data.get("base", {})

	var result = {
		"health": 0, "energy": 0, "intelligence": 0,
		"attack": 0, "construction": 0, "harvest": 0,
		"fishing": 0, "research": 0, "diplomacy": 0
	}

	for stat in base.keys():
		var val: int = base[stat]
		# Variazione ±20% per rendere ogni omino unico
		var variation = randf_range(-0.2, 0.2)
		result[stat] = maxi(1, roundi(val * (1.0 + variation)))

	return result


func is_valid_trait(trait_name: String) -> bool:
	return _traits.has(trait_name)
