extends Control

class_name HomeScene

# ─── Systems ─────────────────────────────────────────────────────
var affection_system: Affection_System
var meal_system:      Meal_System
var health_system:    Health_System

# ─── Dialogic ────────────────────────────────────────────────────
var dialogic: Node

# ─── HUD reference ───────────────────────────────────────────────
# Lives at CanvasLayer/HUD inside this scene.
var hud: HUD

# ─── Scene state ─────────────────────────────────────────────────
var current_time:  int    = 8
var current_scene: String = "morning"

# ─── BUG 1 FIX: Static flag shared across ALL instances ──────────
# Because Dialogic re-triggers the scene tree and can cause _ready()
# to fire on multiple HomeScene instances, a per-instance bool is not
# enough. A static var lives on the CLASS, so even if Godot creates a
# second instance mid-frame the guard still holds.
static var _scene_started: bool = false

# ─── BUG 2 FIX: Deferred start flag ─────────────────────────────
# dialogic.start() called directly inside _ready() can cause a freeze
# when Dialogic's layout node isn't fully in the tree yet. We queue
# the start to the next safe frame via call_deferred / a flag checked
# in _process().
var _pending_timeline: String = ""
var _start_deferred:   bool   = false

# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# BUG 1 FIX: If another HomeScene instance already ran init, bail out
	# immediately and also remove this duplicate node from the tree so it
	# doesn't render a second overlapping HUD (Bug 3).
	if _scene_started:
		push_warning("[HomeScene] Duplicate instance detected — freeing self to prevent overlapping HUD.")
		queue_free()
		return

	_scene_started = true

	# ── Grab autoloads ───────────────────────────────────────────
	affection_system = get_node_or_null("/root/Affection_System")
	meal_system      = get_node_or_null("/root/Meal_System")
	health_system    = get_node_or_null("/root/Health_System")
	dialogic         = get_node_or_null("/root/Dialogic")

	if not affection_system:
		push_error("[HomeScene] AffectionSystem not found in autoload!")
		return
	if not meal_system:
		push_error("[HomeScene] MealSystem not found in autoload!")
		return
	if not health_system:
		push_error("[HomeScene] HealthSystem not found in autoload!")
		return
	if not dialogic:
		push_error("[HomeScene] Dialogic not found in autoload!")
		return

	# ── HUD ──────────────────────────────────────────────────────
	hud = get_node_or_null("CanvasLayer/HUD")
	if not hud:
		push_warning("[HomeScene] HUD not found at CanvasLayer/HUD — stat display will not update.")

	# ── Log initial state ─────────────────────────────────────────
	print("[HomeScene] Systems loaded successfully.")
	print("  - AffectionSystem: affection = %d" % affection_system.current_affection)
	print("  - MealSystem: coins = %d"           % meal_system.coins)
	print("  - HealthSystem: rin_health = %d"    % health_system.rin_health)

	# ── Connect Dialogic signals (guarded against duplicates) ─────
	if not dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.connect(_on_dialogue_finished)

	if not dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.connect(_on_dialogic_signal)

	# ── BUG 2 FIX: Schedule timeline start for next frame ────────
	# Calling dialogic.start() synchronously in _ready() can deadlock
	# when Dialogic's internal VisualNovelLayout node isn't fully
	# initialised yet. Deferring one frame gives every node in the
	# tree time to finish their own _ready() calls first.
	_request_scene("morning")


func _process(_delta: float) -> void:
	# BUG 2 FIX: Execute the deferred start exactly once, then clear the flag.
	if _start_deferred and _pending_timeline != "":
		_start_deferred    = false
		var tl             := _pending_timeline
		_pending_timeline   = ""
		print("[HomeScene] Starting timeline: %s" % tl)
		dialogic.start(tl)


func _notification(what: int) -> void:
	# BUG 1 FIX: Reset the static guard when this scene is cleanly removed
	# (e.g. returning to a main menu and coming back), so the next legitimate
	# load works correctly.
	if what == NOTIFICATION_PREDELETE:
		_scene_started = false


# ─────────────────────────────────────────────────────────────────
# Internal helper — request a scene change safely
# ─────────────────────────────────────────────────────────────────

func _request_scene(scene_key: String) -> void:
	# BUG 3 FIX: If Dialogic is already playing, end it cleanly before
	# starting a new timeline. This prevents the layout node from being
	# added a second time on top of the existing one.
	if dialogic.current_timeline != null:
		push_warning("[HomeScene] Dialogic already running — ending current timeline before starting '%s'." % scene_key)
		dialogic.end_timeline()

	match scene_key:
		"morning":
			current_scene      = "morning"
			current_time       = 8
			_pending_timeline  = "res://Timelines/scene_01_morning_wakeup.dtl"
			if hud:
				hud.set_time(8)
				hud.stop_time()
		"evening":
			current_scene      = "evening"
			current_time       = 18
			_pending_timeline  = "res://Timelines/scene_02_evening_return.dtl"
			if hud:
				hud.set_time(18)
		"doubt":
			if not affection_system.affection_check(5):
				print("[HomeScene] Affection too low for doubt scene (need >= 5, have %d)" % affection_system.current_affection)
				return
			current_scene      = "doubt"
			current_time       = 17
			_pending_timeline  = "res://Timelines/scene_03_moment_of_doubt.dtl"
			if hud:
				hud.set_time(17)
		_:
			push_error("[HomeScene] _request_scene: unknown key '%s'" % scene_key)
			return

	_start_deferred = true


# ─────────────────────────────────────────────────────────────────
# Public scene-load API (call these from other scripts / UI buttons)
# ─────────────────────────────────────────────────────────────────

func load_morning_scene() -> void:
	_request_scene("morning")

func load_evening_scene() -> void:
	_request_scene("evening")

func load_doubt_scene() -> void:
	_request_scene("doubt")


# ─────────────────────────────────────────────────────────────────
# Dialogic signal handlers
# ─────────────────────────────────────────────────────────────────

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
			print("[HomeScene] Unknown scene finished: %s" % current_scene)


# Fires every time Dialogic hits a [signal arg="key:value"] line in a .dtl file.
func _on_dialogic_signal(argument: String) -> void:
	print("[HomeScene] Dialogic signal received: %s" % argument)

	# BUG 1 FIX: Values like "+2" come through as "affection:+2".
	# Split on the FIRST colon only so values that contain colons are safe.
	var colon_idx := argument.find(":")
	if colon_idx == -1:
		push_warning("[HomeScene] Malformed signal (no colon): %s" % argument)
		return

	var event_name := argument.left(colon_idx).strip_edges()
	var value      := argument.right(argument.length() - colon_idx - 1).strip_edges()

	match event_name:
		"affection":
			set_affection(int(value))
			print("[HomeScene] Affection changed by %s → now %d" % [value, affection_system.get_affection()])

		"meal":
			# meal handler applies affection + health internally via meal_system.
			# Never send separate affection/rin_health signals alongside meal: in .dtl.
			set_meal(value)

		"mood":
			set_mood(value)

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
			push_warning("[HomeScene] Unknown signal event '%s' with value '%s'" % [event_name, value])


# ─────────────────────────────────────────────────────────────────
# System call functions
# ─────────────────────────────────────────────────────────────────

func set_affection(amount: int) -> void:
	if affection_system:
		affection_system.modify_affection(amount)
		if hud:
			hud.notify_affection_changed()


func set_meal(meal_type: String) -> void:
	if not meal_system or not affection_system or not health_system:
		return

	if meal_system.purchase_meal(meal_type):
		var aff:    int = meal_system.get_affection_impact(meal_type)
		var health: int = meal_system.get_health_impact(meal_type)

		affection_system.modify_affection(aff)
		health_system.modify_health(health)

		# Notify HUD once after all stats are updated.
		if hud:
			hud.notify_affection_changed()
			hud.notify_health_changed()
			hud.notify_coins_changed()

		print("[HomeScene] Meal processed: %s | Affection: %+d | Health: %+d" % [meal_type, aff, health])
	else:
		print("[HomeScene] Meal purchase failed: %s (not enough coins or invalid type)" % meal_type)


func set_mood(mood_name: String) -> void:
	# Extend this when mood system is implemented.
	print("[HomeScene] Mood set to: %s" % mood_name)


func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
