extends Node

class_name AffectionSystem

# Affection tracking for Rin
var current_affection: int = 0
var affection_min: int = -10
var affection_max: int = 100

# Mood states
enum MoodState {
	HAPPY = 0,
	CONTENT = 1,
	CALM = 2,
	TOUCHED = 3,
	SAD = 4,
	WORRIED = 5,
	HURT = 6,
	DISTANT = 7
}

var current_mood: int = MoodState.CALM

func _ready() -> void:
	current_affection = 0
	current_mood = MoodState.CALM

# Add or subtract affection
func modify_affection(amount: int) -> void:
	current_affection = clamp(current_affection + amount, affection_min, affection_max)
	print("Affection: %d" % current_affection)

# Set mood state
func set_mood(mood: int) -> void:
	current_mood = mood

# Get affection for branching dialogue
func get_affection() -> int:
	return current_affection

# Get mood for branching dialogue
func get_mood() -> int:
	return current_mood

# Check if affection threshold met
func affection_check(required: int) -> bool:
	return current_affection >= required

# Reset affection (for testing)
func reset_affection() -> void:
	current_affection = 0
	current_mood = MoodState.CALM
