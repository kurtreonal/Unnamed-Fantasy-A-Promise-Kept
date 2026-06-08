extends Node

class_name AffectionSystem

# ─── State ────────────────────────────────────────────────────────
var current_affection: int = 0
var affection_min:     int = -10
var affection_max:     int = 100
var current_mood:      int = 0   # 0 = CALM default

# ─── Mood constants (use these strings in dialogue signals) ───────
const MOOD_MAP := {
	"happy":    0,
	"content":  1,
	"calm":     2,
	"touched":  3,
	"sad":      4,
	"worried":  5,
	"hurt":     6,
	"distant":  7,
}

# NOTE: _ready() intentionally does NOT reset values.
# SaveSystem loads saved values after all autoloads are ready.
func _ready() -> void:
	print("[AffectionSystem] Ready — affection: %d | mood: %d" % [current_affection, current_mood])


func modify_affection(amount: int) -> void:
	current_affection = clamp(current_affection + amount, affection_min, affection_max)
	print("[AffectionSystem] Affection %+d → %d" % [amount, current_affection])


func set_affection(value: int) -> void:
	current_affection = clamp(value, affection_min, affection_max)


func get_affection() -> int:
	return current_affection


func affection_check(required: int) -> bool:
	return current_affection >= required


func set_mood(mood_name: String) -> void:
	current_mood = MOOD_MAP.get(mood_name.to_lower(), 2)
	print("[AffectionSystem] Mood → %s (%d)" % [mood_name, current_mood])


func get_mood() -> int:
	return current_mood


func reset() -> void:
	current_affection = 0
	current_mood      = 0
	print("[AffectionSystem] Reset to defaults.")
