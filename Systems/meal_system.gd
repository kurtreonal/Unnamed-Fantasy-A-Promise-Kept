extends Node

class_name MealSystem

# Meal costs
const MEAL_COSTS = {
	"skip": 0,
	"simple": 1000,
	"grand": 3000,
	"takeout": 1500
}

# Meal quality impact on affection and health
const MEAL_AFFECTION = {
	"skip": -3,
	"simple": 2,
	"grand": 4,
	"takeout": -2
}

const MEAL_HEALTH = {
	"skip": -5,
	"simple": 10,
	"grand": 20,
	"takeout": 5
}

var coins: int = 5000
var last_meal: String = ""

func _ready() -> void:
	coins = 5000

# Purchase meal
func purchase_meal(meal_type: String) -> bool:
	if meal_type not in MEAL_COSTS:
		return false
	
	var cost = MEAL_COSTS[meal_type]
	if coins < cost:
		return false
	
	coins -= cost
	last_meal = meal_type
	return true

# Get meal impact values
func get_affection_impact(meal_type: String) -> int:
	return MEAL_AFFECTION.get(meal_type, 0)

func get_health_impact(meal_type: String) -> int:
	return MEAL_HEALTH.get(meal_type, 0)

# Get coin balance
func get_coins() -> int:
	return coins

# Add coins (from dungeon loot)
func add_coins(amount: int) -> void:
	coins += amount

# Get last meal
func get_last_meal() -> String:
	return last_meal
