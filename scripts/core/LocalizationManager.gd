extends Node

const SUPPORTED_LOCALES = ["en", "it"]
const DEFAULT_LOCALE = "en"
const TRANSLATIONS_PATH = "res://data/translations/"

var _strings: Dictionary = {}
var _current_locale: String = DEFAULT_LOCALE


func _ready() -> void:
	var saved_locale = _load_saved_locale()
	load_locale(saved_locale if saved_locale != "" else DEFAULT_LOCALE)


func load_locale(locale: String) -> void:
	if not locale in SUPPORTED_LOCALES:
		locale = DEFAULT_LOCALE
	var path = TRANSLATIONS_PATH + locale + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LocalizationManager: cannot open " + path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("LocalizationManager: invalid JSON in " + path)
		return
	_strings = parsed
	_current_locale = locale


# Main translation function — use L.tr("KEY") or L.tr("KEY", {var: val})
func tr(key: String, vars: Dictionary = {}) -> String:
	var text: String = _strings.get(key, key)
	for var_name in vars.keys():
		text = text.replace("{" + var_name + "}", str(vars[var_name]))
	return text


func get_locale() -> String:
	return _current_locale


func set_locale(locale: String) -> void:
	load_locale(locale)
	_save_locale(locale)


func get_trait_name(trait_key: String) -> String:
	return tr("TRAIT_" + trait_key.to_upper())


func get_stat_name(stat_key: String) -> String:
	return tr("STAT_" + stat_key.to_upper())


func get_death_cause(cause_key: String) -> String:
	var key = "DEATH_" + cause_key.to_upper().replace(" ", "_")
	return tr(key)


func get_era_name(era: int) -> String:
	return tr("ERA_" + str(era))


func _save_locale(locale: String) -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "locale", locale)
	config.save("user://settings.cfg")


func _load_saved_locale() -> String:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return ""
	return config.get_value("settings", "locale", "")
