extends Node

# Bridge between systems that want to show a thought-bubble over an entity
# and the planet widget that owns the EntitySprite nodes.
# Subscribers connect to `bubble_requested`; the planet widget renders the bubble.

signal bubble_requested(entity_data, bubble_type_string: String)

const TYPE_NAMES: Array = [
	"question", "exclamation", "heart",
	"sword", "ellipsis", "star",
	"arrow_up", "sparkle", "skull",
	"fish", "wheat", "hammer", "book",
]

# Every death shows a skull. The cause is recorded separately on the entity.
const DEATH_BUBBLE: String = "skull"


func _ready() -> void:
	GameState.entity_died.connect(_on_entity_died)
	EventManager.event_created.connect(_on_event_created)


func request_for_entity(entity_data, bubble_type_string: String) -> void:
	if entity_data == null:
		return
	var t: String = bubble_type_string.to_lower()
	if not TYPE_NAMES.has(t):
		t = "exclamation"
	bubble_requested.emit(entity_data, t)


# --- Wired reactions ---

func _on_entity_died(entity_data) -> void:
	if entity_data == null:
		return
	bubble_requested.emit(entity_data, DEATH_BUBBLE)


func _on_event_created(event) -> void:
	# Show a "something is happening" cue on a random living entity
	var living: Array = GameState.get_living_entities()
	if living.is_empty():
		return
	var target = living[randi() % living.size()]
	var bubble: String = "sparkle"
	if event != null:
		match event.urgency:
			EventManager.EventUrgency.MANAGEABLE: bubble = "question"
			EventManager.EventUrgency.URGENT:     bubble = "exclamation"
			EventManager.EventUrgency.CRITICAL:   bubble = "exclamation"
			EventManager.EventUrgency.FATAL:      bubble = "sparkle"
	bubble_requested.emit(target, bubble)
