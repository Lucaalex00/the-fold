extends CanvasLayer

signal continue_pressed

@onready var background: ColorRect = $Background
@onready var god_message_label: Label = $VBox/GodMessageLabel
@onready var analyzing_label: Label = $VBox/AnalyzingLabel
@onready var bonus_label: Label = $VBox/BonusLabel
@onready var continue_button: Button = $VBox/ContinueButton

var _sequence_step: int = 0
var _tween: Tween = null


func _ready() -> void:
	visible = false
	continue_button.text = L.tr("PRESTIGE_CONTINUE")
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue)

	PrestigeSystem.god_message_ready.connect(show_god_message)
	PrestigeSystem.bonus_assigned.connect(_on_bonus_assigned)
	PrestigeSystem.prestige_sequence_started.connect(_start_sequence)
	PrestigeSystem.prestige_sequence_finished.connect(_on_sequence_finished)


func _start_sequence() -> void:
	_sequence_step = 0
	god_message_label.modulate.a = 0.0
	analyzing_label.text = L.tr("PRESTIGE_ANALYZING")
	analyzing_label.visible = true
	bonus_label.visible = false
	continue_button.visible = false

	# Fade in black background
	background.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(background, "modulate:a", 1.0, 1.5)
	_tween.tween_callback(PrestigeSystem.enter_black_hole)


func show_god_message(message: String) -> void:
	god_message_label.text = message
	god_message_label.visible = true

	_tween = create_tween()
	_tween.tween_property(god_message_label, "modulate:a", 1.0, 2.0)
	_tween.tween_interval(2.0)
	_tween.tween_callback(_show_analyzing)


func _show_analyzing() -> void:
	analyzing_label.visible = true


func _on_bonus_assigned(bonus_name: String, _bonus_key: String) -> void:
	bonus_label.text = L.tr("PRESTIGE_BONUS_ASSIGNED") + "\n" + bonus_name
	bonus_label.visible = true
	bonus_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(bonus_label, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(1.5)
	_tween.tween_callback(_show_continue)


func _show_continue() -> void:
	continue_button.visible = true


func _on_sequence_finished() -> void:
	pass  # Main.gd handles the rest after continue is pressed


func _on_continue() -> void:
	emit_signal("continue_pressed")
	# Fade out
	_tween = create_tween()
	_tween.tween_property(background, "modulate:a", 0.0, 1.0)
	_tween.tween_callback(func(): visible = false)
