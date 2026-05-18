extends Node

func run_tests() -> Array:
	return [
		_test_default_locale_is_english(),
		_test_english_key_exists(),
		_test_missing_key_returns_key(),
		_test_variable_substitution(),
		_test_switch_to_italian(),
		_test_italian_key_translated(),
		_test_trait_name_english(),
		_test_trait_name_italian(),
		_test_era_name(),
		_test_supported_locales(),
		_test_switch_back_to_english(),
	]


func _test_default_locale_is_english() -> Dictionary:
	# Force reload English
	L.load_locale("en")
	return {"name": "default locale is en", "passed": L.get_locale() == "en"}


func _test_english_key_exists() -> Dictionary:
	L.load_locale("en")
	var text = L.tr("GAME_TITLE")
	return {"name": "GAME_TITLE key exists in English", "passed": text == "The Fold"}


func _test_missing_key_returns_key() -> Dictionary:
	var text = L.tr("NONEXISTENT_KEY_XYZ")
	return {"name": "missing key returns key itself", "passed": text == "NONEXISTENT_KEY_XYZ"}


func _test_variable_substitution() -> Dictionary:
	L.load_locale("en")
	var text = L.tr("ERA_LABEL", {"era": 3, "name": "Civil"})
	var ok = "3" in text and "Civil" in text
	return {"name": "variable substitution works in tr()", "passed": ok}


func _test_switch_to_italian() -> Dictionary:
	L.load_locale("it")
	return {"name": "switch to Italian locale", "passed": L.get_locale() == "it"}


func _test_italian_key_translated() -> Dictionary:
	L.load_locale("it")
	var text = L.tr("DEATH_OLD_AGE")
	var ok = text == "Vecchiaia"
	return {"name": "DEATH_OLD_AGE translated in Italian", "passed": ok}


func _test_trait_name_english() -> Dictionary:
	L.load_locale("en")
	var name = L.get_trait_name("warrior")
	return {"name": "trait warrior = Warrior in English", "passed": name == "Warrior"}


func _test_trait_name_italian() -> Dictionary:
	L.load_locale("it")
	var name = L.get_trait_name("warrior")
	return {"name": "trait warrior = Guerriero in Italian", "passed": name == "Guerriero"}


func _test_era_name() -> Dictionary:
	L.load_locale("en")
	var name = L.get_era_name(2)
	return {"name": "era 2 name = Biological in English", "passed": name == "Biological"}


func _test_supported_locales() -> Dictionary:
	var ok = "en" in L.SUPPORTED_LOCALES and "it" in L.SUPPORTED_LOCALES
	return {"name": "supported locales include en and it", "passed": ok}


func _test_switch_back_to_english() -> Dictionary:
	L.load_locale("en")
	return {"name": "restore English locale after suite", "passed": L.get_locale() == "en"}
