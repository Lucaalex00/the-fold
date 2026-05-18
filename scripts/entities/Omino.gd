extends Node

# Riferimento ai dati logici dell'omino
var data: GameState.OminoData = null


func setup(omino_data: GameState.OminoData) -> void:
	data = omino_data


# --- Aging & Morte ---

func tick_age(years: int = 2) -> void:
	if data == null or not data.is_alive:
		return
	data.age_years += years
	_check_death_by_age()


func _check_death_by_age() -> void:
	var prob = calculate_death_probability(data.age_years)
	if prob > 0.0 and roll_death():
		die("vecchiaia")


func calculate_death_probability(age_years: int) -> float:
	if age_years < 20:
		return 0.0
	elif age_years <= 30:
		# Curva crescente 0% → 80% tra 20 e 30 anni
		var t = (age_years - 20.0) / 10.0
		return t * 0.80
	else:
		# Oltre 30 anni: 80% + 0.05% per ogni anno extra
		# Max teorico ~98% a 200 anni — mai 100%
		var extra_years = age_years - 30
		return minf(0.80 + extra_years * 0.0005, 0.98)


func roll_death() -> bool:
	var prob = calculate_death_probability(data.age_years)
	return randf() < prob


func die(cause: String) -> void:
	if data == null or not data.is_alive:
		return
	GameState.register_omino_death(data, cause)
	SaveManager.save_to_memory_book(data)


# --- Utility ---

func is_alive() -> bool:
	return data != null and data.is_alive


func get_stat(stat: String) -> int:
	if data == null:
		return 0
	return data.stats.get(stat, 0)


func add_notable_event(description: String) -> void:
	if data != null:
		data.notable_events.append(description)
