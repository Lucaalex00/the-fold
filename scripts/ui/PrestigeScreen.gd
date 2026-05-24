extends CanvasLayer

signal continue_pressed

@onready var background: ColorRect = $Background
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var god_message_label: Label = $VBox/GodMessageLabel
@onready var stats_label: Label = $VBox/StatsLabel
@onready var bonuses_label: Label = $VBox/BonusesLabel
@onready var continue_button: Button = $VBox/ContinueButton

const FADE_IN_TIME: float = 1.2
const MSG_FADE_TIME: float = 1.2
const TYPEWRITER_CPS: float = 90.0   # characters per second
const FLASH_DURATION: float = 2.5
const FADE_OUT_TIME: float = 1.0

const BONUS_LABELS: Dictionary = {
	"resource_multiplier": "Resource Multiplier",
	"war_god":             "War God (+3 attack to founder warriors)",
	"harmony_god":         "Harmony God (-20 cultural tension)",
	"resilience_god":      "Resilience God (free lifeboat once per run)",
	"explorer_god":        "Explorer God (+50% exploration)",
	"eternal_god":         "Eternal God (+5y to death cap)",
}

var _is_active: bool = false
var _new_bonus_keys: Array = []


func _ready() -> void:
	visible = false
	continue_button.modulate.a = 0.0
	stats_label.modulate.a = 0.0
	bonuses_label.modulate.a = 0.0
	continue_button.pressed.connect(_on_continue)

	PrestigeSystem.god_message_ready.connect(show_god_message)
	PrestigeSystem.prestige_sequence_started.connect(_start_sequence)
	PrestigeSystem.bonus_assigned.connect(_on_bonus_assigned)
	PrestigeSystem.prestige_sequence_finished.connect(_on_sequence_finished)


func _start_sequence() -> void:
	_is_active = true
	_new_bonus_keys = []
	visible = true

	# Reset visuals
	god_message_label.text = ""
	god_message_label.modulate.a = 0.0
	stats_label.text = ""
	stats_label.modulate.a = 0.0
	stats_label.visible_ratio = 0.0
	bonuses_label.text = ""
	bonuses_label.modulate.a = 0.0
	bonuses_label.visible_ratio = 0.0
	continue_button.modulate.a = 0.0
	continue_button.disabled = true
	flash_overlay.modulate.a = 0.0

	# Fade in black background
	background.modulate.a = 0.0
	var bg_tween := create_tween()
	bg_tween.tween_property(background, "modulate:a", 1.0, FADE_IN_TIME)
	bg_tween.tween_callback(PrestigeSystem.enter_black_hole)


func _on_bonus_assigned(_bonus_name: String, bonus_key: String) -> void:
	# Track newly-acquired bonuses for the "this run" section
	if bonus_key != "" and not _new_bonus_keys.has(bonus_key):
		_new_bonus_keys.append(bonus_key)


func show_god_message(message: String) -> void:
	god_message_label.text = message
	var tw := create_tween()
	tw.tween_property(god_message_label, "modulate:a", 1.0, MSG_FADE_TIME)


func _on_sequence_finished() -> void:
	# Sequence: god msg (already shown) → typewriter stats → typewriter bonuses → REBORN button
	await get_tree().create_timer(MSG_FADE_TIME + 0.6).timeout
	await _show_stats_typewriter()
	await get_tree().create_timer(0.8).timeout
	await _show_bonuses_typewriter()
	await get_tree().create_timer(0.4).timeout
	_reveal_continue_button()


func _show_stats_typewriter() -> void:
	stats_label.text = _build_stats_text()
	stats_label.modulate.a = 1.0
	stats_label.visible_ratio = 0.0
	var duration: float = float(stats_label.text.length()) / TYPEWRITER_CPS
	var tw := create_tween()
	tw.tween_property(stats_label, "visible_ratio", 1.0, duration)
	await tw.finished


func _show_bonuses_typewriter() -> void:
	bonuses_label.text = _build_bonuses_text()
	bonuses_label.modulate.a = 1.0
	bonuses_label.visible_ratio = 0.0
	var duration: float = float(bonuses_label.text.length()) / TYPEWRITER_CPS
	var tw := create_tween()
	tw.tween_property(bonuses_label, "visible_ratio", 1.0, duration)
	await tw.finished


func _reveal_continue_button() -> void:
	continue_button.disabled = false
	var tw := create_tween()
	tw.tween_property(continue_button, "modulate:a", 1.0, 0.6)


const COLLAPSE_CAUSE_LABELS: Dictionary = {
	"old_age":         "the last of you died of old age",
	"health_depleted": "your people starved",
	"plague":          "a plague took everyone",
	"starvation":      "famine claimed the last",
	"meteorite":       "a meteorite shattered the world",
	"radiation":       "radiation poisoned the world",
	"poison":          "the poison rain finished you",
	"virus":           "an extinction virus erased you",
	"black_hole":      "the void pulled you in",
	"supernova":       "a star exploded too close",
	"ice_age":         "the world froze",
	"tide":            "cosmic tides drowned the layers",
	"civil_war":       "civil war tore you apart",
	"uprising":        "your warriors took everything",
	"exodus":          "your people fled",
	"sacrifice":       "the last sacrifice was made",
	"replaced":        "the cycle replaced you",
	"debug":           "fate cut the thread (debug)",
}


func _build_stats_text() -> String:
	var lines: Array = []
	if PrestigeSystem.current_mode == PrestigeSystem.Mode.COLLAPSE:
		var cause_key: String = String(GameState.last_death_cause)
		var cause_text: String = String(COLLAPSE_CAUSE_LABELS.get(cause_key, cause_key if cause_key != "" else "the world simply ended"))
		lines.append("Cause: %s" % cause_text)
		lines.append("")
	lines.append("— this run —")
	lines.append("Era reached: %d" % GameState.current_era)
	lines.append("Days survived: %d" % GameState.current_day)
	lines.append("Light years travelled: %s" % _format_distance(1_000_000.0 - GameState.distance_from_center))
	lines.append("Conflicts won: %d" % GameState.conflicts_won)
	lines.append("Entities lost: %d" % GameState.entities_lost)
	lines.append("Oldest entity age: %d" % GameState.oldest_entity_age)
	lines.append("Planets visited: %d" % GameState.planets_visited)
	lines.append("Average cohesion: %d" % int(GameState.avg_cohesion))
	return "\n".join(lines)


func _build_bonuses_text() -> String:
	var lines: Array = []
	if not _new_bonus_keys.is_empty():
		lines.append("— new bonus this run —")
		for key in _new_bonus_keys:
			lines.append("+ " + BONUS_LABELS.get(key, key))
		lines.append("")

	var all_bonuses: Array = PrestigeSystem.active_bonuses
	if not all_bonuses.is_empty():
		lines.append("— permanent bonuses —")
		for key in all_bonuses:
			lines.append("• " + BONUS_LABELS.get(key, key))
	# Add BH multiplier line if applicable
	if PrestigeSystem.last_blackhole_multiplier > 1.0:
		lines.append("• Black Hole bonus  x%.2f" % PrestigeSystem.last_blackhole_multiplier)
	if lines.is_empty():
		return ""
	return "\n".join(lines)


func _format_distance(d: float) -> String:
	if d >= 1_000_000.0:
		return "%.2f M" % (d / 1_000_000.0)
	if d >= 1_000.0:
		return "%.1f K" % (d / 1_000.0)
	return str(int(d))


func _on_continue() -> void:
	if not _is_active:
		return
	_is_active = false
	continue_button.disabled = true

	# Flash sequence: 6 cycles in ~2.5s
	var flash_tween := create_tween()
	var flash_count: int = 6
	var per_flash: float = FLASH_DURATION / float(flash_count * 2)
	for i in range(flash_count):
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.9, per_flash)
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, per_flash)
	flash_tween.tween_property(flash_overlay, "modulate:a", 1.0, 0.35)
	flash_tween.tween_callback(_emit_continue)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, FADE_OUT_TIME)
	flash_tween.tween_callback(func(): visible = false)

	# Fade content out during the flash
	var content_tween := create_tween()
	content_tween.tween_property(stats_label, "modulate:a", 0.0, FLASH_DURATION * 0.5)
	var bonus_tween := create_tween()
	bonus_tween.tween_property(bonuses_label, "modulate:a", 0.0, FLASH_DURATION * 0.5)
	var msg_tween := create_tween()
	msg_tween.tween_property(god_message_label, "modulate:a", 0.0, FLASH_DURATION * 0.6)
	var btn_tween := create_tween()
	btn_tween.tween_property(continue_button, "modulate:a", 0.0, FLASH_DURATION * 0.4)
	var bg_tween := create_tween()
	bg_tween.tween_interval(FLASH_DURATION + 0.35)
	bg_tween.tween_property(background, "modulate:a", 0.0, FADE_OUT_TIME)


func _emit_continue() -> void:
	emit_signal("continue_pressed")
