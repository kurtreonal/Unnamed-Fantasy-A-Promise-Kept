extends Control

class_name HomeScene

# ─── Systems ─────────────────────────────────────────────────────
var affection_system: Affection_System
var meal_system:      Meal_System
var health_system:    Health_System

# ─── Dialogic ────────────────────────────────────────────────────
var dialogic: Node

# ─── HUD reference ───────────────────────────────────────────────
var hud: HUD

# ─── Scene state ─────────────────────────────────────────────────
var current_time:  int    = 8
var current_scene: String = "morning"

# ─── Duplicate-instance guard (static = shared across all instances) ─
static var _scene_started: bool = false

# ─── Deferred timeline start ─────────────────────────────────────
var _pending_timeline: String = ""
var _start_deferred:   bool   = false

# ─── Signal connection guard ─────────────────────────────────────
# Tracks whether THIS instance has connected its signal handlers.
# Fixes double-firing: Dialogic autoload persists across scene reloads,
# so without per-instance tracking, connecting on every _ready() piles
# up duplicate connections to the same autoload signals.
var _signals_connected: bool = false

# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────
func _init() -> void:
	if _scene_started:
		# Kill it before it ever enters the tree — no flash, no _ready() side effects
		set_process(false)
		set_physics_process(false)
		return
		
func _ready() -> void:
	if _scene_started:
		hide()
		queue_free()
		return
	_scene_started = true

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

	hud = get_node_or_null("CanvasLayer/HUD")
	if not hud:
		push_warning("[HomeScene] HUD not found at CanvasLayer/HUD.")

	print("[HomeScene] Systems loaded successfully.")
	print("  - AffectionSystem: affection = %d" % affection_system.current_affection)
	print("  - MealSystem: coins = %d"           % meal_system.coins)
	print("  - HealthSystem: rin_health = %d"    % health_system.rin_health)

	_connect_dialogic_signals()

	if dialogic.current_timeline == null:
		_request_scene("morning")


func _process(_delta: float) -> void:
	if _start_deferred and _pending_timeline != "":
		if dialogic.current_timeline != null:
			return
		_start_deferred   = false
		var tl            := _pending_timeline
		_pending_timeline  = ""
		print("[HomeScene] Starting timeline: %s" % tl)
		dialogic.start(tl)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect our handlers before freeing so Dialogic's autoload
		# doesn't hold stale references that would cause double-firing
		# if a new HomeScene is created later in the same session.
		_disconnect_dialogic_signals()
		_scene_started = false


# ─────────────────────────────────────────────────────────────────
# Signal Connection Management
# ─────────────────────────────────────────────────────────────────

func _connect_dialogic_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true

	# Always disconnect first in case a previous run left orphan connections
	# on the persistent Dialogic autoload node.
	if dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.disconnect(_on_dialogue_finished)
	if dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.disconnect(_on_dialogic_signal)

	dialogic.timeline_ended.connect(_on_dialogue_finished)
	dialogic.signal_event.connect(_on_dialogic_signal)
	print("[HomeScene] Dialogic signals connected.")


func _disconnect_dialogic_signals() -> void:
	if not _signals_connected or not dialogic:
		return
	_signals_connected = false

	if dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.disconnect(_on_dialogue_finished)
	if dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.disconnect(_on_dialogic_signal)
	print("[HomeScene] Dialogic signals disconnected.")


# ─────────────────────────────────────────────────────────────────
# Scene Request
# ─────────────────────────────────────────────────────────────────

func _request_scene(scene_key: String) -> void:
	if dialogic.current_timeline != null:
		push_warning("[HomeScene] Ending current timeline before starting '%s'." % scene_key)
		dialogic.end_timeline()

	match scene_key:
		"morning":
			current_scene     = "morning"
			current_time      = 8
			_pending_timeline = "res://Timelines/scene_01_morning_wakeup.dtl"
			if hud:
				hud.set_time(8)
				hud.stop_time()
		"evening":
			current_scene     = "evening"
			current_time      = 18
			_pending_timeline = "res://Timelines/scene_02_evening_return.dtl"
			if hud:
				hud.set_time(18)
		"doubt":
			if not affection_system.affection_check(5):
				print("[HomeScene] Affection too low for doubt scene (need >= 5, have %d)" % affection_system.current_affection)
				return
			current_scene     = "doubt"
			current_time      = 17
			_pending_timeline = "res://Timelines/scene_03_moment_of_doubt.dtl"
			if hud:
				hud.set_time(17)
		_:
			push_error("[HomeScene] _request_scene: unknown key '%s'" % scene_key)
			return

	_start_deferred = true


# ─────────────────────────────────────────────────────────────────
# Public Scene API
# ─────────────────────────────────────────────────────────────────

func load_morning_scene() -> void:
	_request_scene("morning")

func load_evening_scene() -> void:
	_request_scene("evening")

func load_doubt_scene() -> void:
	_request_scene("doubt")


# ─────────────────────────────────────────────────────────────────
# Coin Gate
# Push affordability flags into Dialogic VAR subsystem so the .dtl
# can condition choices on them.
# Triggered by [signal arg="check_coins"] in the timeline.
# ─────────────────────────────────────────────────────────────────

func _push_coin_vars() -> void:
	var coins: int = meal_system.get_coins()

	# Set to true/false — .dtl conditions use "if variable_name" (truthy check)
	Dialogic.VAR.set("grand_affordable",   coins >= meal_system.MEAL_COSTS["grand"])
	Dialogic.VAR.set("simple_affordable",  coins >= meal_system.MEAL_COSTS["simple"])
	Dialogic.VAR.set("takeout_affordable", coins >= meal_system.MEAL_COSTS["takeout"])

	print("[HomeScene] Coin gate — coins: %d | grand:%s simple:%s takeout:%s" % [
		coins,
		"✓" if coins >= meal_system.MEAL_COSTS["grand"]   else "✗",
		"✓" if coins >= meal_system.MEAL_COSTS["simple"]  else "✗",
		"✓" if coins >= meal_system.MEAL_COSTS["takeout"] else "✗",
	])


# ─────────────────────────────────────────────────────────────────
# Time Advance
# Smoothly ticks the HUD clock forward by `hours`, pausing Dialogic
# input during the animation so the player can't skip ahead.
# ─────────────────────────────────────────────────────────────────

func _advance_time(hours: int) -> void:
	if not hud:
		return
	current_time   += hours
	dialogic.paused = true
	hud.advance_hours(hours)

	# CONNECT_ONE_SHOT ensures this fires exactly once per advance call,
	# even if _advance_time() is called multiple times in a row.
	if not hud.time_advance_finished.is_connected(_on_time_advance_finished):
		hud.time_advance_finished.connect(_on_time_advance_finished, CONNECT_ONE_SHOT)


func _on_time_advance_finished() -> void:
	dialogic.paused = false
	print("[HomeScene] Clock advanced → now %02d:00" % current_time)


# ─────────────────────────────────────────────────────────────────
# Dialogic Signal Handlers
# ─────────────────────────────────────────────────────────────────

func _on_dialogue_finished() -> void:
	print("[HomeScene] Dialogue finished.")
	match current_scene:
		"morning":
			print("[HomeScene] Morning scene complete.")
		"evening":
			print("[HomeScene] Evening scene complete.")
		"doubt":
			print("[HomeScene] Doubt scene complete.")
		_:
			print("[HomeScene] Unknown scene finished: %s" % current_scene)


func _on_dialogic_signal(argument: String) -> void:
	print("[HomeScene] Dialogic signal received: %s" % argument)

	var colon_idx := argument.find(":")

	# ── Signals with no value (e.g. "check_coins") ───────────────
	if colon_idx == -1:
		match argument.strip_edges():
			"check_coins":
				_push_coin_vars()
			_:
				push_warning("[HomeScene] Unknown no-value signal: %s" % argument)
		return

	var event_name := argument.left(colon_idx).strip_edges()
	var value      := argument.right(argument.length() - colon_idx - 1).strip_edges()

	match event_name:

		# ── Time advance ──────────────────────────────────────────
		"time":
			var hours: int = int(value)
			if hours != 0:
				_advance_time(hours)
				print("[HomeScene] Time advance queued: %+d hour(s)" % hours)

		# ── Affection ─────────────────────────────────────────────
		"affection":
			set_affection(int(value))
			print("[HomeScene] Affection %s → now %d" % [value, affection_system.get_affection()])

		# ── Meal (deducts coins + applies affection & health) ─────
		"meal":
			set_meal(value)

		# ── Mood ──────────────────────────────────────────────────
		"mood":
			set_mood(value)

		# ── Direct coin grant (e.g. dungeon loot reward) ──────────
		"coins":
			if meal_system:
				meal_system.add_coins(int(value))
				print("[HomeScene] Coins %s → now %d" % [value, meal_system.get_coins()])
				if hud:
					hud.notify_coins_changed()

		# ── Direct health change ──────────────────────────────────
		"rin_health":
			if health_system:
				health_system.modify_health(int(value))
				print("[HomeScene] Rin health %s → now %d" % [value, health_system.get_health()])
				if hud:
					hud.notify_health_changed()

		_:
			push_warning("[HomeScene] Unknown signal '%s' with value '%s'" % [event_name, value])


# ─────────────────────────────────────────────────────────────────
# System Call Functions
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

		if hud:
			hud.notify_affection_changed()
			hud.notify_health_changed()
			hud.notify_coins_changed()

		print("[HomeScene] Meal '%s' | Affection: %+d | Health: %+d" % [meal_type, aff, health])
	else:
		print("[HomeScene] Meal purchase failed: '%s' (not enough coins)" % meal_type)


func set_mood(mood_name: String) -> void:
	print("[HomeScene] Mood set to: %s" % mood_name)


func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
