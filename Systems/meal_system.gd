extends Node

class_name MealSystem

# ─── State ────────────────────────────────────────────────────────
var coins:     int    = 5000
var last_meal: String = ""

# ─── Constants ────────────────────────────────────────────────────
const MEAL_COSTS := {
	"skip":    0,
	"simple":  1000,
	"grand":   3000,
	"takeout": 1500,
}

const MEAL_AFFECTION := {
	"skip":    -3,
	"simple":   2,
	"grand":    4,
	"takeout": -2,
}

const MEAL_HEALTH := {
	"skip":    -5,
	"simple":  10,
	"grand":   20,
	"takeout":  5,
}

# NOTE: _ready() intentionally does NOT reset values.
# SaveSystem loads saved values after all autoloads are ready.
func _ready() -> void:
	print("[MealSystem] Ready — coins: %d | last_meal: '%s'" % [coins, last_meal])


func purchase_meal(meal_type: String) -> bool:
	if meal_type not in MEAL_COSTS:
		push_warning("[MealSystem] Unknown meal type: '%s'" % meal_type)
		return false

	var cost: int = MEAL_COSTS[meal_type]
	if coins < cost:
		print("[MealSystem] Not enough coins for '%s' (need %d, have %d)" % [meal_type, cost, coins])
		return false

	coins    -= cost
	last_meal = meal_type
	print("[MealSystem] Meal '%s' purchased — coins remaining: %d" % [meal_type, coins])
	return true


func get_affection_impact(meal_type: String) -> int:
	return MEAL_AFFECTION.get(meal_type, 0)


func get_health_impact(meal_type: String) -> int:
	return MEAL_HEALTH.get(meal_type, 0)


func get_coins() -> int:
	return coins


func add_coins(amount: int) -> void:
	coins += amount
	print("[MealSystem] Coins +%d → %d" % [amount, coins])


func get_last_meal() -> String:
	return last_meal


func reset() -> void:
	coins     = 5000
	last_meal = ""
	print("[MealSystem] Reset to defaults.")
