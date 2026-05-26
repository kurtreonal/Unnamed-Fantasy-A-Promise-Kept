extends Node

class_name HomeScene

# Scene management
@onready var dialogic = $Dialogic
@onready var ui = $UI

# Systems
var affection_system: AffectionSystem
var meal_system: MealSystem
var health_system: HealthSystem

# Current time (8:00 AM = 8, 6:00 PM = 18, etc.)
var current_time: int = 8
var current_scene: String = "morning"

func _ready() -> void:
	# Initialize systems
	affection_system = get_node("/root/Game/AffectionSystem")
	meal_system = get_node("/root/Game/MealSystem")
	health_system = get_node("/root/Game/HealthSystem")
	
	# Start morning scene
	load_morning_scene()

func load_morning_scene() -> void:
	current_scene = "morning"
	current_time = 8
	dialogic.start("res://Timelines/scene_01_morning_wakeup.dtl")
	dialogic.dialogic_signal.connect(_on_dialogue_finished)

func load_evening_scene() -> void:
	current_scene = "evening"
	current_time = 18
	dialogic.start("res://Timelines/scene_02_evening_return.dtl")
	dialogic.dialogic_signal.connect(_on_dialogue_finished)

func load_doubt_scene() -> void:
	# Check affection threshold
	if affection_system.affection_check(5):
		current_scene = "doubt"
		current_time = 17
		dialogic.start("res://Timelines/scene_03_moment_of_doubt.dtl")
		dialogic.dialogic_signal.connect(_on_dialogue_finished)
	else:
		print("Affection too low for doubt scene. Skipping.")

func _on_dialogue_finished(state: String) -> void:
	match state:
		"ready_for_dungeon":
			# Transition to dungeon exploration
			get_tree().change_scene_to_file("res://scenes/dungeon_scene.tscn")
		
		"ready_for_next_day":
			# Transition to next day's morning
			await get_tree().create_timer(1.0).timeout
			load_morning_scene()
		
		"new_direction_unlocked":
			# Scholar quest is now available
			print("Scholar quest unlocked!")
			load_evening_scene()

# Handle Dialogic variable changes
func set_affection(amount: int) -> void:
	affection_system.modify_affection(amount)

func set_mood(mood_name: String) -> void:
	var mood_map = {
		"happy": affection_system.MoodState.HAPPY,
		"content": affection_system.MoodState.CONTENT,
		"sad": affection_system.MoodState.SAD,
		"worried": affection_system.MoodState.WORRIED,
		"touched": affection_system.MoodState.TOUCHED,
	}
	affection_system.set_mood(mood_map.get(mood_name, affection_system.MoodState.CALM))

func set_meal(meal_type: String, coins: int) -> void:
	if meal_system.purchase_meal(meal_type):
		var affection_change = meal_system.get_affection_impact(meal_type)
		var health_change = meal_system.get_health_impact(meal_type)
		
		affection_system.modify_affection(affection_change)
		health_system.modify_health(health_change)
		print("Meal: %s | Affection: %+d | Health: %+d" % [meal_type, affection_change, health_change])

# Update UI with current state
func update_ui() -> void:
	ui.set_affection(affection_system.get_affection())
	ui.set_health(health_system.get_health())
	ui.set_coins(meal_system.get_coins())
	ui.set_time(current_time)
