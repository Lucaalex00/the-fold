extends CanvasLayer

signal continue_pressed

@onready var background: ColorRect = $Background
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var god_message_label: Label = $VBox/GodMessageLabel
@onready var continue_button: Button = $VBox/ContinueButton

const FADE_IN_TIME: float = 1.5
const MSG_FADE_TIME: float = 1.5
const FLASH_DURATION: float = 2.5
const FADE_OUT_TIME: float = 1.0

var _tween: Tween = null
var _is_active: bool = false


func _ready() -> void:
	visible = false
	continue_button.modulate.a = 0.0
	continue_button.pressed.connect(_on_continue)

	PrestigeSystem.god_message_ready.connect(show_god_message)
	PrestigeSystem.prestige_sequence_started.connect(_start_sequence)
	PrestigeSystem.prestige_sequence_finished.connect(_on_sequence_finished)


func _start_sequence() -> void:
	_is_active = true
	visible = true

	# Reset visual state
	god_message_label.text = ""
	god_message_label.modulate.a = 0.0
	continue_button.modulate.a = 0.0
	continue_button.disabled = true
	flash_overlay.modulate.a = 0.0

	# Fade in black background
	background.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(background, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_callback(PrestigeSystem.enter_black_hole)


func show_god_message(message: String) -> void:
	god_message_label.text = message
	_tween = create_tween()
	_tween.tween_property(god_message_label, "modulate:a", 1.0, MSG_FADE_TIME)


func _on_sequence_finished() -> void:
	# After god message + bonus assignment, reveal REBORN button
	await get_tree().create_timer(1.5).timeout
	_tween = create_tween()
	_tween.tween_property(continue_button, "modulate:a", 1.0, 0.6)
	continue_button.disabled = false


func _on_continue() -> void:
	if not _is_active:
		return
	_is_active = false
	continue_button.disabled = true

	# Flash sequence (sequential) — 6 cycles in ~2.5s
	var flash_tween := create_tween()
	var flash_count: int = 6
	var per_flash: float = FLASH_DURATION / float(flash_count * 2)
	for i in range(flash_count):
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.9, per_flash)
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, per_flash)
	# Final white wash → emit continue → fade everything out
	flash_tween.tween_property(flash_overlay, "modulate:a", 1.0, 0.35)
	flash_tween.tween_callback(_emit_continue)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, FADE_OUT_TIME)
	flash_tween.tween_callback(func(): visible = false)

	# Independent content fades (parallel by virtue of separate tweens)
	var content_tween := create_tween()
	content_tween.tween_property(god_message_label, "modulate:a", 0.0, FLASH_DURATION * 0.6)
	var btn_tween := create_tween()
	btn_tween.tween_property(continue_button, "modulate:a", 0.0, FLASH_DURATION * 0.5)
	# Background fade-out runs synced with the final overlay fade
	var bg_tween := create_tween()
	bg_tween.tween_interval(FLASH_DURATION + 0.35)
	bg_tween.tween_property(background, "modulate:a", 0.0, FADE_OUT_TIME)


func _emit_continue() -> void:
	emit_signal("continue_pressed")
