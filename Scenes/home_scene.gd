extends Control

class_name HomeScene

# Scene management
var dialogic: Node

# Systems
var affection_system: Affection_System
var meal_system: Meal_System
var health_system: Health_System

# HUD reference — used to push stat updates instead of HUD polling every frame
var hud: HUD

# Current time (8:00 AM = 8, 6:00 PM = 18, etc.)
var current_time: int = 8
var current_scene: String = "morning"

# Guard flag — ensures _ready() only runs once even if the node is re-parented
var _initialized: bool = false

func _ready() -> void:
	# BUGFIX: Prevent double/triple initialization if scene is instanced more than once.
	# If you still see this warning, check Project Settings > Autoload and your main
	# scene — HomeScene must appear in exactly ONE place.
	if _initialized:
		print("[HomeScene] WARNING: _ready() called again — skipping duplicate init.")
		return
	_initialized = true

	# Get system references (autoloaded)
	affection_system = get_node("/root/Affection_System")
	meal_system      = get_node("/root/Meal_System")
	health_system    = get_node("/root/Health_System")
	dialogic         = get_node("/root/Dialogic")

	# HUD lives inside this scene's CanvasLayer — get_node_or_null so missing HUD
	# doesn't crash the whole game
	hud = get_node_or_null("CanvasLayer/HUD")
	if not hud:
		push_warning("[HomeScene] HUD not found at CanvasLayer/HUD — stat display will not update.")

	if not affection_system:
		print("[HomeScene] ERROR: AffectionSystem not found in autoload!")
		return

	if not dialogic:
		print("[HomeScene] ERROR: Dialogic not found in autoload!")
		return

	print("[HomeScene] Systems loaded successfully.")
	print("  - AffectionSystem: affection = %d" % affection_system.current_affection)
	print("  - MealSystem: coins = %d" % meal_system.coins)
	print("  - HealthSystem: rin_health = %d" % health_system.rin_health)

	# Connect signals — guard prevents duplicates within this instance
	if not dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.connect(_on_dialogue_finished)

	if not dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.connect(_on_dialogic_signal)

	# Start the morning scene
	load_morning_scene()

func load_morning_scene() -> void:
	current_scene = "morning"
	current_time  = 8
	if hud:
		hud.set_time(8)
		hud.stop_time()
	if dialogic:
		print("[HomeScene] Loading morning scene...")
		dialogic.start("res://Timelines/scene_01_morning_wakeup.dtl")

func load_evening_scene() -> void:
	current_scene = "evening"
	current_time  = 18
	if hud:
		hud.set_time(18)
	if dialogic:
		print("[HomeScene] Loading evening scene...")
		dialogic.start("res://Timelines/scene_02_evening_return.dtl")

func load_doubt_scene() -> void:
	if not affection_system.affection_check(5):
		print("[HomeScene] Affection too low for doubt scene (need >= 5, have %d)" % affection_system.current_affection)
		return
	current_scene = "doubt"
	current_time  = 17
	if hud:
		hud.set_time(17)
	if dialogic:
		print("[HomeScene] Loading doubt scene...")
		dialogic.start("res://Timelines/scene_03_moment_of_doubt.dtl")

func _on_dialogue_finished() -> void:
	print("[HomeScene] Dialogue finished.")

	match current_scene:
		"morning":
			print("[HomeScene] Morning scene complete. (TODO: transition to next scene)")
		"evening":
			print("[HomeScene] Evening scene complete. (TODO: transition to next scene)")
		"doubt":
			print("[HomeScene] Doubt scene complete. (TODO: transition to next scene)")
		_:
			print("[HomeScene] Unknown scene: %s" % current_scene)

# Fires every time Dialogic hits a [signal arg="key:value"] line in a .dtl file
func _on_dialogic_signal(argument: String) -> void:
	print("[HomeScene] Dialogic signal received: %s" % argument)

	var parts := argument.split(":")
	if parts.size() < 2:
		print("[HomeScene] WARNING: Malformed signal argument: %s" % argument)
		return

	var event_name := parts[0].strip_edges()
	var value      := parts[1].strip_edges()

	match event_name:
		"affection":
			set_affection(int(value))
			print("[HomeScene] Affection changed by %s → now %d" % [value, affection_system.get_affection()])

		"meal":
			# meal handler applies affection + health internally via meal_system.
			# Never send separate affection/rin_health signals alongside meal: in .dtl.
			set_meal(value)

		"mood":
			print("[HomeScene] Mood set to: %s" % value)

		"coins":
			if meal_system:
				meal_system.add_coins(int(value))
				print("[HomeScene] Coins changed by %s → now %d" % [value, meal_system.get_coins()])
				if hud:
					hud.notify_coins_changed()

		"rin_health":
			if health_system:
				health_system.modify_health(int(value))
				print("[HomeScene] Rin health changed by %s → now %d" % [value, health_system.get_health()])
				if hud:
					hud.notify_health_changed()

		_:
			print("[HomeScene] WARNING: Unknown signal event '%s' with value '%s'" % [event_name, value])

# ============ SYSTEM CALL FUNCTIONS ============

func set_affection(amount: int) -> void:
	if affection_system:
		affection_system.modify_affection(amount)
		if hud:
			hud.notify_affection_changed()

func set_meal(meal_type: String) -> void:
	if not meal_system or not affection_system or not health_system:
		return

	if meal_system.purchase_meal(meal_type):
		var aff    = meal_system.get_affection_impact(meal_type)
		var health = meal_system.get_health_impact(meal_type)

		affection_system.modify_affection(aff)
		health_system.modify_health(health)

		# Notify HUD once after all stats are updated
		if hud:
			hud.notify_affection_changed()
			hud.notify_health_changed()
			hud.notify_coins_changed()

		print("[HomeScene] Meal processed: %s | Affection: %+d | Health: %+d" % [meal_type, aff, health])
	else:
		print("[HomeScene] Meal purchase failed: %s (not enough coins or invalid type)" % meal_type)

func set_mood(_mood_name: String) -> void:
	pass

func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
