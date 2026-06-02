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
static var _instance: Control = null

# ─── Deferred timeline start ─────────────────────────────────────
var _pending_timeline: String = ""
var _start_deferred:   bool   = false

# ─── Signal connection guard ─────────────────────────────────────
var _signals_connected: bool = false

# ─── Per-scene meal guard ─────────────────────────────────────────
var _meal_purchased_this_scene: bool = false

# ─── Title card running guard ────────────────────────────────────
# While true, ALL incoming Dialogic signals are dropped.
# Prevents load_world or any other signal racing the title card coroutine.
var _title_card_running: bool = false

# ─── Meal keywords → cost key mapping ────────────────────────────
const MEAL_CHOICE_MAP: Dictionary = {
	"3000g": "grand",
	"1000g": "simple",
	"1500g": "takeout",
}

# ─── World scenes map ────────────────────────────────────────────
const WORLD_SCENES: Dictionary = {
	1: "res://Scenes/World1.tscn",
	2: "res://Scenes/World2.tscn",
	3: "res://Scenes/World3.tscn",
}

# ─── Location card definitions ───────────────────────────────────
# Each key maps to a Dictionary that becomes a LocationTitleCardConfig.
# Add new locations here — no other code needs to change.
const LOCATION_CARDS: Dictionary = {
	"abyss": {
		"name_en":     "Abyss",
		"name_jp":     "深淵",
		"description": "A vast labyrinth filled with countless mysteries",
		"icon":        "✦",
		"preset":      "gold",
	},
	"ocean_shrine": {
		"name_en":     "Ocean Shrine",
		"name_jp":     "海の祠",
		"description": "The tide speaks in whispers here",
		"icon":        "🌊",
		"preset":      "teal",
	},
	"fire_peak": {
		"name_en":     "Fire Peak",
		"name_jp":     "炎の峰",
		"description": "The mountain that never sleeps",
		"icon":        "🔥",
		"preset":      "crimson",
	},
	"sanctum": {
		"name_en":     "Sanctum",
		"name_jp":     "聖域",
		"description": "A place of ancient, forgotten light",
		"icon":        "⛩",
		"preset":      "silver",
	},
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

	# ── LocationTitleCard check ───────────────────────────────────
	# The card is registered as an autoload named LocationTitle_Card.
	# We just verify it exists here; all calls go through _show_location_card().
	var card := get_node_or_null("/root/LocationTitle_Card")
	if not card:
		push_warning("[HomeScene] LocationTitle_Card autoload not found. Location cards disabled.")

	print("[HomeScene] Systems loaded successfully.")
	print("  - AffectionSystem: affection = %d" % affection_system.current_affection)
	print("  - MealSystem: coins = %d"           % meal_system.coins)
	print("  - HealthSystem: rin_health = %d"    % health_system.rin_health)

	_connect_dialogic_signals()

	# Double check that we only start if absolutely clean
	if dialogic.current_timeline == null and _pending_timeline == "":
		_request_scene("morning")
		
	# Ensure HUD canvas is visible at runtime (it's hidden in editor to prevent
	# Dialogic character editor freeze)
	var canvas := get_node_or_null("CanvasLayer")
	if canvas:
		canvas.visible = true

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
		if _instance == self:
			_instance = null


# ─────────────────────────────────────────────────────────────────
# Signal Connection Management
# ─────────────────────────────────────────────────────────────────

func _connect_dialogic_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true

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
			continue

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
	if not hud or not dialogic:
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
# Location Title Card
# ─────────────────────────────────────────────────────────────────

## Called from _on_dialogic_signal when "show_location_card:KEY" arrives.
## Pauses Dialogic, shows the card using await, then shifts scenes.
func _show_location_card(location_key: String) -> void:
	print("[HomeScene] === LOCATION CARD SEQUENCE START for '%s' ===" % location_key)

	# Raise guard FIRST — drops any further Dialogic signals (including
	# load_world) until we lower it or change scenes.
	_title_card_running = true

	var card: LocationTitleCard = get_node_or_null("/root/LocationTitle_Card")
	if not card or not LOCATION_CARDS.has(location_key):
		push_warning("[HomeScene] Skipping location card sequence.")
		_title_card_running = false
		await _after_location_card(location_key)
		return

	dialogic.paused = true
	print("[HomeScene] Dialogic paused.")

	var data: Dictionary = LOCATION_CARDS[location_key]
	var cfg := _build_card_config(data)

	print("[HomeScene] Displaying location card: %s" % location_key)

	# show_and_wait blocks until full fade-out is done and tweens are cleared.
	# One extra process_frame is included inside show_and_wait — no second await needed.
	await card.show_and_wait(cfg)
	print("[HomeScene] Card animation finished — safe to transition.")

	await _after_location_card(location_key)
	print("[HomeScene] === LOCATION CARD SEQUENCE COMPLETE ===")


## Builds a LocationTitleCardConfig from a LOCATION_CARDS Dictionary entry.
func _build_card_config(data: Dictionary) -> LocationTitleCardConfig:
	var cfg: LocationTitleCardConfig

	match data.get("preset", "gold"):
		"gold":    cfg = LocationTitleCardConfig.gold_preset()
		"silver":  cfg = LocationTitleCardConfig.silver_preset()
		"crimson": cfg = LocationTitleCardConfig.crimson_preset()
		"teal":    cfg = LocationTitleCardConfig.teal_preset()
		_:         cfg = LocationTitleCardConfig.gold_preset()

	cfg.location_name_en = data.get("name_en",     "")
	cfg.location_name_jp = data.get("name_jp",     "")
	cfg.description      = data.get("description", "")
	cfg.icon_symbol      = data.get("icon",        "✦")
	return cfg

## For the morning scene we go to World1; for others we resume Dialogic.
## Runs after show_and_wait() has fully completed — tweens are already dead.
func _after_location_card(location_key: String) -> void:
	print("[HomeScene] _after_location_card() for '%s'" % location_key)

	match location_key:
		"abyss":
			print("[HomeScene] Abyss — transitioning to World1.")
			_disconnect_dialogic_signals()
			_clear_dialogic_layout()
			get_tree().change_scene_to_file.call_deferred(WORLD_SCENES[1])

		_:
			print("[HomeScene] '%s' card done — resuming Dialogic." % location_key)
			_title_card_running = false
			dialogic.paused = false

	print("[HomeScene] _after_location_card() END")

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
	# Drop every signal while the title card owns the transition.
	# This prevents load_world or any stray signal racing the coroutine.
	if _title_card_running:
		print("[HomeScene] Signal dropped (title card running): %s" % argument)
		return

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

		"load_world":
			_load_world(int(value))

		# ── Location card ─────────────────────────────────────────
		# Triggered by: [signal arg="show_location_card:abyss"]
		"show_location_card":
			# IMPORTANT: Must await to allow the card sequence to complete!
			await _show_location_card(value)

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


# ─────────────────────────────────────────────────────────────────
# World Transition
# ─────────────────────────────────────────────────────────────────

func _load_world(world_number: int) -> void:
	if not WORLD_SCENES.has(world_number):
		push_error("[HomeScene] _load_world: no scene mapped for world %d" % world_number)
		return

	print("[HomeScene] Transitioning to World%d..." % world_number)

	_disconnect_dialogic_signals()
	_clear_dialogic_layout()
	get_tree().change_scene_to_file(WORLD_SCENES[world_number])


## Removes every Dialogic layout CanvasLayer from the scene tree.
##
## Dialogic 2 instantiates a layout scene (e.g. DialogicLayout_TextBox) as a
## direct child of /root when a timeline starts. end_timeline() clears the
## timeline STATE but does NOT free those nodes when the timeline has already
## ended naturally (current_timeline == null by then). We must free them
## ourselves before changing scenes, or they render on top of the new scene.
##
## We match on "DialogicLayout" prefix — that covers every built-in and custom
## layout Dialogic creates (TextBox, FullscreenBackground, etc.).
func _clear_dialogic_layout() -> void:
	# Also attempt end_timeline() in case it IS still running (e.g. load_world path).
	if dialogic:
		dialogic.end_timeline()

	# Walk /root's direct children and free anything Dialogic left behind.
	var root := get_tree().root
	for child in root.get_children():
		if child.name.begins_with("DialogicLayout"):
			print("[HomeScene] Freeing lingering Dialogic layout node: %s" % child.name)
			child.queue_free()


func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
