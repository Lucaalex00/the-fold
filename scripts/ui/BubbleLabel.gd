extends Node2D

enum BubbleType {
	QUESTION,    # ?   confusion
	EXCLAMATION, # !   discovery / danger
	HEART,       # ♥   bond / birth
	SWORD,       # ⚔   conflict
	ELLIPSIS,    # …   waiting / tension
	STAR,        # ★   evolution / milestone
	ARROW_UP,    # ↑   growth / agreement
	SPARKLE,     # ✦   cosmic event perceived
	SKULL,       # 💀  death
	FISH,        # 🐟  fishing
	WHEAT,       # 🌾  harvesting
	HAMMER,      # 🔨  building
	BOOK,        # 📖  research
}

const BUBBLE_SYMBOLS = {
	BubbleType.QUESTION:    "?",
	BubbleType.EXCLAMATION: "!",
	BubbleType.HEART:       "♥",
	BubbleType.SWORD:       "⚔",
	BubbleType.ELLIPSIS:    "…",
	BubbleType.STAR:        "★",
	BubbleType.ARROW_UP:    "↑",
	BubbleType.SPARKLE:     "✦",
	BubbleType.SKULL:       "💀",
	BubbleType.FISH:        "🐟",
	BubbleType.WHEAT:       "🌾",
	BubbleType.HAMMER:      "🔨",
	BubbleType.BOOK:        "📖",
}

const DISPLAY_DURATION = 2.5
const FLOAT_DISTANCE = 20.0

@onready var label: Label = $Label

var _elapsed: float = 0.0
var _start_y: float = 0.0


func _ready() -> void:
	_start_y = position.y
	modulate.a = 1.0


func set_type(type: BubbleType) -> void:
	label.text = BUBBLE_SYMBOLS.get(type, "?")


func _process(delta: float) -> void:
	_elapsed += delta
	var t = _elapsed / DISPLAY_DURATION

	# Float upward
	position.y = _start_y - FLOAT_DISTANCE * t

	# Fade out in last 30%
	if t > 0.7:
		modulate.a = 1.0 - ((t - 0.7) / 0.3)

	if _elapsed >= DISPLAY_DURATION:
		queue_free()


# Static helper — spawns a bubble on any Node2D
static func show_bubble(parent: Node2D, type: BubbleType) -> void:
	var scene = load("res://scenes/ui/BubbleLabel.tscn")
	if scene == null:
		return
	var bubble = scene.instantiate()
	bubble.position = Vector2(0, -40)  # above the parent
	parent.add_child(bubble)
	bubble.set_type(type)
