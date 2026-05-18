extends Node


func generate_child(parent_a: GameState.OminoData, parent_b: GameState.OminoData, origin_planet: String) -> GameState.OminoData:
	var child = GameState.OminoData.new()
	child.id = OminoGenerator._generate_uuid()
	child.name = OminoGenerator.generate_name()
	child.birth_day = GameState.current_day
	child.birth_date_real = Time.get_date_string_from_system()
	child.age_years = 0
	child.is_alive = true
	child.origin_planet = origin_planet
	child.generation = maxi(parent_a.generation, parent_b.generation) + 1
	child.parents = [parent_a.id, parent_b.id]

	# Aggiorna lista figli dei genitori
	parent_a.children.append(child.id)
	parent_b.children.append(child.id)

	# Stats: 70% della media dei genitori
	for stat in child.stats.keys():
		var avg = (parent_a.stats.get(stat, 0) + parent_b.stats.get(stat, 0)) / 2.0
		child.stats[stat] = roundi(avg * 0.70)

	# Bonus intelligenza generazionale: +5% per generazione
	var gen_bonus = child.generation * 0.05
	child.stats["intelligence"] = roundi(child.stats["intelligence"] * (1.0 + gen_bonus))

	# Tratto dominante dal genitore con stat media più alta nel suo tratto
	child.trait_primary = _dominant_trait(parent_a, parent_b)
	child.trait_secondary = _secondary_trait(parent_a, parent_b, child.trait_primary)

	# DNA visivo: mix dei genitori con piccola variazione
	child.dna = _mix_dna(parent_a.dna, parent_b.dna)

	_apply_era_cap(child)
	return child


func _dominant_trait(parent_a: GameState.OminoData, parent_b: GameState.OminoData) -> String:
	var score_a = _trait_score(parent_a)
	var score_b = _trait_score(parent_b)
	# Il genitore con score complessivo più alto trasmette il tratto dominante
	if score_a >= score_b:
		return parent_a.trait_primary
	return parent_b.trait_primary


func _trait_score(omino: GameState.OminoData) -> float:
	var total = 0
	for stat in omino.stats.values():
		total += stat
	return float(total)


func _secondary_trait(parent_a: GameState.OminoData, parent_b: GameState.OminoData, dominant: String) -> String:
	# Tratto secondario dall'altro genitore, solo da era 2+
	if GameState.current_era < 2:
		return ""
	if parent_a.trait_primary != dominant:
		return parent_a.trait_primary
	if parent_b.trait_primary != dominant:
		return parent_b.trait_primary
	return ""


func _mix_dna(dna_a: Dictionary, dna_b: Dictionary) -> Dictionary:
	# Mix 50/50 con variazione ±10% sui colori
	var mixed = {}
	mixed["body_shape"] = dna_a["body_shape"] if randf() < 0.5 else dna_b["body_shape"]
	mixed["accessory_type"] = dna_a["accessory_type"] if randf() < 0.5 else dna_b["accessory_type"]
	mixed["size_modifier"] = (dna_a["size_modifier"] + dna_b["size_modifier"]) / 2.0
	mixed["size_modifier"] = clampf(mixed["size_modifier"] + randf_range(-0.05, 0.05), 0.8, 1.2)

	mixed["color_primary"] = _mix_color(dna_a["color_primary"], dna_b["color_primary"])
	mixed["color_secondary"] = _mix_color(dna_a["color_secondary"], dna_b["color_secondary"])
	mixed["color_accent"] = _mix_color(dna_a["color_accent"], dna_b["color_accent"])
	return mixed


func _mix_color(c_a: Color, c_b: Color) -> Color:
	var base = c_a.lerp(c_b, 0.5)
	# Piccola mutazione casuale sul canale H
	var h = fmod(base.h + randf_range(-0.05, 0.05) + 1.0, 1.0)
	return Color.from_hsv(h, base.s, base.v, 1.0)


func _apply_era_cap(omino: GameState.OminoData) -> void:
	var cap = GameState.get_stat_cap()
	for stat in omino.stats.keys():
		omino.stats[stat] = mini(omino.stats[stat], cap)
