extends Control

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

# ─── Singleton guard ─────────────────────────────────────────────
# Instead of a static bool that races with PREDELETE, we store the
# ONE living instance here. Any second instance finds the slot taken
# and kills itself immediately — no race condition possible.
static var _instance: Control = null

# ─── Deferred timeline start ─────────────────────────────────────
var _pending_timeline: String = ""
var _start_deferred:   bool   = false

# ─── Signal connection guard ─────────────────────────────────────
var _signals_connected: bool = false

# ─── Per-scene meal guard ─────────────────────────────────────────
# Flipped to true the moment a meal signal is processed.
# Reset when a new scene is requested.
# Guarantees meal:X only ever fires once per scene, even if Dialogic
# somehow emits the signal twice (e.g. due to a stale second listener).
var _meal_purchased_this_scene: bool = false

# ─── Meal keywords → cost key mapping ────────────────────────────
const MEAL_CHOICE_MAP: Dictionary = {
	"3000g": "grand",
	"1000g": "simple",
	"1500g": "takeout",
}

# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# ── Singleton enforcement ─────────────────────────────────────
	if _instance != null and _instance != self:
		push_warning("[HomeScene] Duplicate instance detected — destroying self.")
		queue_free()
		return
	_instance = self

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
		_disconnect_dialogic_signals()
		# Only clear the singleton slot if WE are the current instance.
		if _instance == self:
			_instance = null


# ─────────────────────────────────────────────────────────────────
# Signal Connection Management
# ─────────────────────────────────────────────────────────────────

func _connect_dialogic_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true

	# Always clean slate first — Dialogic autoload persists across scenes.
	if dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.disconnect(_on_dialogue_finished)
	if dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.disconnect(_on_dialogic_signal)

	dialogic.timeline_ended.connect(_on_dialogue_finished)
	dialogic.signal_event.connect(_on_dialogic_signal)

	if dialogic.has_signal("choice_buttons_shown"):
		if not dialogic.choice_buttons_shown.is_connected(_on_choice_buttons_shown):
			dialogic.choice_buttons_shown.connect(_on_choice_buttons_shown)
	else:
		push_warning("[HomeScene] Dialogic has no 'choice_buttons_shown' signal — grey-out unavailable.")

	print("[HomeScene] Dialogic signals connected.")


func _disconnect_dialogic_signals() -> void:
	if not _signals_connected or not dialogic:
		return
	_signals_connected = false

	if dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.disconnect(_on_dialogue_finished)
	if dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.disconnect(_on_dialogic_signal)
	if dialogic.has_signal("choice_buttons_shown"):
		if dialogic.choice_buttons_shown.is_connected(_on_choice_buttons_shown):
			dialogic.choice_buttons_shown.disconnect(_on_choice_buttons_shown)

	print("[HomeScene] Dialogic signals disconnected.")


# ─────────────────────────────────────────────────────────────────
# Scene Request
# ─────────────────────────────────────────────────────────────────

func _request_scene(scene_key: String) -> void:
	# Reset the meal guard for every new scene.
	_meal_purchased_this_scene = false

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
# Choice Grey-Out
# ─────────────────────────────────────────────────────────────────

func _on_choice_buttons_shown() -> void:
	await get_tree().process_frame
	_apply_choice_greying()


func _apply_choice_greying() -> void:
	if not meal_system:
		return

	var coins: int       = meal_system.get_coins()
	var all_buttons      := _find_dialogic_choice_buttons()

	if all_buttons.is_empty():
		push_warning("[HomeScene] _apply_choice_greying: no choice buttons found.")
		return

	for btn in all_buttons:
		var cost_key: String = _get_meal_cost_key(btn.text)

		if cost_key == "":
			continue  # Not a meal choice — always enabled.

		var can_afford: bool = coins >= meal_system.MEAL_COSTS[cost_key]
		btn.disabled = not can_afford
		btn.modulate = Color.WHITE if can_afford else Color(0.55, 0.55, 0.55, 0.65)

	print("[HomeScene] Choice greying applied — coins: %d" % coins)


func _find_dialogic_choice_buttons() -> Array:
	var result: Array = []

	var grouped := get_tree().get_nodes_in_group("dialogic_choice")
	if not grouped.is_empty():
		for n in grouped:
			if n is Button and n.visible:
				result.append(n)
		return result

	var container := _find_node_by_name(get_tree().root, "ChoiceContainer")
	if container:
		for child in container.get_children():
			if child is Button:
				result.append(child)
		return result

	_collect_visible_buttons(get_tree().root, result)
	return result


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found:
			return found
	return null


func _collect_visible_buttons(node: Node, result: Array) -> void:
	if node is Button and node.visible:
		result.append(node)
	for child in node.get_children():
		_collect_visible_buttons(child, result)


func _get_meal_cost_key(label: String) -> String:
	for marker in MEAL_CHOICE_MAP.keys():
		if label.contains(marker):
			return MEAL_CHOICE_MAP[marker]
	return ""


# ─────────────────────────────────────────────────────────────────
# Time Advance
# ─────────────────────────────────────────────────────────────────

func _advance_time(hours: int) -> void:
	if not hud:
		return
	current_time   += hours
	dialogic.paused = true
	hud.advance_hours(hours)

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

	if colon_idx == -1:
		push_warning("[HomeScene] Unknown no-value signal: %s" % argument)
		return

	var event_name := argument.left(colon_idx).strip_edges()
	var value      := argument.right(argument.length() - colon_idx - 1).strip_edges()

	match event_name:

		"time":
			var hours: int = int(value)
			if hours != 0:
				_advance_time(hours)
				print("[HomeScene] Time advance queued: %+d hour(s)" % hours)

		"affection":
			set_affection(int(value))
			print("[HomeScene] Affection %s → now %d" % [value, affection_system.get_affection()])

		"meal":
			# ── Meal guard: only process once per scene ───────────
			if _meal_purchased_this_scene:
				push_warning("[HomeScene] Duplicate meal signal '%s' ignored." % value)
				return
			_meal_purchased_this_scene = true
			set_meal(value)

		"mood":
			set_mood(value)

		"coins":
			if meal_system:
				meal_system.add_coins(int(value))
				print("[HomeScene] Coins %s → now %d" % [value, meal_system.get_coins()])
				if hud:
					hud.notify_coins_changed()

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
