extends Node

# Bridge between systems that want to show a thought-bubble over an entity
# and the planet widget that owns the EntitySprite nodes.
# Subscribers connect to `bubble_requested`; the planet widget renders the bubble.

signal bubble_requested(entity_data, bubble_type_string: String)

const TYPE_NAMES: Array = [
	"question", "exclamation", "heart",
	"sword", "ellipsis", "star",
	"arrow_up", "sparkle",
]

# Causes → bubble symbol mapping for natural reactions
const DEATH_CAUSE_BUBBLE: Dictionary = {
	"old_age":          "heart",
	"health_depleted":  "heart",
	"plague":           "exclamation",
	"starvation":       "ellipsis",
	"meteorite":        "sparkle",
	"radiation":        "sparkle",
	"poison":           "exclamation",
	"virus":            "exclamation",
	"black_hole":       "sparkle",
	"supernova":        "sparkle",
	"ice_age":          "ellipsis",
	"tide":             "exclamation",
	"civil_war":        "sword",
	"uprising":         "sword",
	"suppression":      "sword",
	"sacrifice":        "heart",
	"exile":            "ellipsis",
	"exodus":           "ellipsis",
	"replaced":         "ellipsis",
}


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
	var cause: String = String(entity_data.death_cause)
	var bubble: String = String(DEATH_CAUSE_BUBBLE.get(cause, "heart"))
	bubble_requested.emit(entity_data, bubble)


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
