extends Node


func generate_child(parent_a: GameState.EntityData, parent_b: GameState.EntityData, origin_planet: String) -> GameState.EntityData:
	var child = GameState.EntityData.new()
	child.id = EntityGenerator._generate_uuid()
	child.name = EntityGenerator.generate_name()
	child.birth_day = GameState.current_day
	child.birth_date_real = Time.get_date_string_from_system()
	child.age_years = 0
	child.is_alive = true
	child.origin_planet = origin_planet
	child.generation = maxi(parent_a.generation, parent_b.generation) + 1
	child.parents = [parent_a.id, parent_b.id]

	# Update children list for both parents
	parent_a.children.append(child.id)
	parent_b.children.append(child.id)

	# Stats: 70% of parent average
	for stat in child.stats.keys():
		var avg = (parent_a.stats.get(stat, 0) + parent_b.stats.get(stat, 0)) / 2.0
		child.stats[stat] = roundi(avg * 0.70)

	# Generation intelligence bonus: +5% per generation
	var gen_bonus = child.generation * 0.05
	child.stats["intelligence"] = roundi(child.stats["intelligence"] * (1.0 + gen_bonus))

	# Dominant trait from parent with higher average stat in their trait
	child.trait_primary = _dominant_trait(parent_a, parent_b)
	child.trait_secondary = _secondary_trait(parent_a, parent_b, child.trait_primary)

	# Visual DNA: parent mix with small variation
	child.dna = _mix_dna(parent_a.dna, parent_b.dna)

	return child


func _dominant_trait(parent_a: GameState.EntityData, parent_b: GameState.EntityData) -> String:
	var score_a = _trait_score(parent_a)
	var score_b = _trait_score(parent_b)
	# Parent with the highest overall score passes the dominant trait
	if score_a >= score_b:
		return parent_a.trait_primary
	return parent_b.trait_primary


func _trait_score(entity: GameState.EntityData) -> float:
	var total = 0
	for stat in entity.stats.values():
		total += stat
	return float(total)


func _secondary_trait(parent_a: GameState.EntityData, parent_b: GameState.EntityData, dominant: String) -> String:
	# Secondary trait from the other parent, only from era 2+
	if GameState.current_era < 2:
		return ""
	if parent_a.trait_primary != dominant:
		return parent_a.trait_primary
	if parent_b.trait_primary != dominant:
		return parent_b.trait_primary
	return ""


func _mix_dna(dna_a: Dictionary, dna_b: Dictionary) -> Dictionary:
	# 50/50 mix with ±10% color variation
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
	# Small random mutation on the H (hue) channel
	var h = fmod(base.h + randf_range(-0.05, 0.05) + 1.0, 1.0)
	return Color.from_hsv(h, base.s, base.v, 1.0)


func _apply_era_cap(entity: GameState.EntityData) -> void:
	var cap = GameState.get_stat_cap()
	for stat in entity.stats.keys():
		entity.stats[stat] = mini(entity.stats[stat], cap)
