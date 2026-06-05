extends Control

# ─── Systems ─────────────────────────────────────────────────────
var affection_system: Affection_System
var meal_system:      Meal_System
var health_system:    Health_System
var day_system:       DaySystem

# ─── Dialogic ────────────────────────────────────────────────────
var dialogic: Node

# ─── HUD reference ───────────────────────────────────────────────
var hud: HUD

# ─── Scene state ─────────────────────────────────────────────────
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
	day_system       = get_node_or_null("/root/DaySystem")
	dialogic         = get_node_or_null("/root/Dialogic")

	if not affection_system: push_error("[HomeScene] Affection_System not found in autoload!"); return
	if not meal_system:      push_error("[HomeScene] Meal_System not found in autoload!"); return
	if not health_system:    push_error("[HomeScene] Health_System not found in autoload!"); return
	if not day_system:       push_error("[HomeScene] DaySystem not found in autoload!"); return
	if not dialogic:         push_error("[HomeScene] Dialogic not found in autoload!"); return

	hud = get_node_or_null("CanvasLayer/HUD")
	if not hud:
		push_warning("[HomeScene] HUD not found at CanvasLayer/HUD.")

	var card := get_node_or_null("/root/LocationTitle_Card")
	if not card:
		push_warning("[HomeScene] LocationTitle_Card autoload not found. Location cards disabled.")

	# ── Connect DaySystem curfew signal ──────────────────────────
	if not day_system.curfew_triggered.is_connected(_on_curfew_triggered):
		day_system.curfew_triggered.connect(_on_curfew_triggered)

	print("[HomeScene] Systems loaded successfully.")
	print("  - Day: %d | Time: %s" % [day_system.current_day, day_system.get_time_string()])
	print("  - Affection: %d | Coins: %d | Health: %d" % [
		affection_system.current_affection,
		meal_system.coins,
		health_system.rin_health
	])

	_connect_dialogic_signals()

	# ── Decide which scene to play based on how we got here ─────
	if dialogic.current_timeline == null and _pending_timeline == "":
		if day_system.return_reason == DaySystem.ReturnReason.CURFEW:
			print("[HomeScene] Curfew return detected — loading evening scene.")
			_request_scene("evening")
		else:
			_request_scene("morning")

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
			_pending_timeline = "res://Timelines/scene_01_morning_wakeup.dtl"
			# Set time to morning, clock stops during dialogue
			day_system.set_time(8, 0)
			if hud:
				hud.stop_time()

		"evening":
			current_scene     = "evening"
			_pending_timeline = "res://Timelines/scene_02_evening_return.dtl"
			# Snap time to 6 PM for the evening scene
			day_system.set_evening_time()
			if hud:
				hud.stop_time()

		"doubt":
			if not affection_system.affection_check(5):
				print("[HomeScene] Affection too low for doubt scene.")
				return
			current_scene     = "doubt"
			_pending_timeline = "res://Timelines/scene_03_moment_of_doubt.dtl"
			day_system.set_time(17, 0)
			if hud:
				hud.stop_time()

		_:
			push_error("[HomeScene] _request_scene: unknown key '%s'" % scene_key)
			return

	_start_deferred = true


# ─────────────────────────────────────────────────────────────────
# Public Scene API
# ─────────────────────────────────────────────────────────────────

func load_morning_scene() -> void: _request_scene("morning")
func load_evening_scene() -> void: _request_scene("evening")
func load_doubt_scene()   -> void: _request_scene("doubt")


# ─────────────────────────────────────────────────────────────────
# Curfew Handler — Called by DaySystem at 11:59 PM
# ─────────────────────────────────────────────────────────────────

func _on_curfew_triggered() -> void:
	print("[HomeScene] Curfew triggered — forcing return home from world.")

	# If we're in a world scene, this signal fires there too.
	# The world scene calls HomeScene via autoload, so we handle it centrally.
	_disconnect_dialogic_signals()
	_clear_dialogic_layout()

	# Small delay so the player sees the screen before we cut.
	await get_tree().create_timer(0.5).timeout

	# Return to home and load the evening scene.
	get_tree().change_scene_to_file.call_deferred("res://Scenes/home_scene.tscn")


# ─────────────────────────────────────────────────────────────────
# Choice Grey-Out
# ─────────────────────────────────────────────────────────────────

func _on_choice_buttons_shown() -> void:
	await get_tree().process_frame
	_apply_choice_greying()


func _apply_choice_greying() -> void:
	if not meal_system:
		return
	var coins: int  = meal_system.get_coins()
	var all_buttons := _find_dialogic_choice_buttons()

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
# Time Advance (dialogue-triggered fast-forward)
# ─────────────────────────────────────────────────────────────────

func _advance_time(hours: int) -> void:
	if not hud or not dialogic:
		return
	dialogic.paused = true
	hud.advance_hours(hours)

	if not hud.time_advance_finished.is_connected(_on_time_advance_finished):
		hud.time_advance_finished.connect(_on_time_advance_finished, CONNECT_ONE_SHOT)


func _on_time_advance_finished() -> void:
	dialogic.paused = false
	print("[HomeScene] Clock advanced → now %s" % day_system.get_time_string())


# ─────────────────────────────────────────────────────────────────
# Location Title Card
# ─────────────────────────────────────────────────────────────────

func _show_location_card(location_key: String) -> void:
	print("[HomeScene] === LOCATION CARD SEQUENCE START for '%s' ===" % location_key)
	_title_card_running = true

	var card: LocationTitleCard = get_node_or_null("/root/LocationTitle_Card")
	if not card or not LOCATION_CARDS.has(location_key):
		push_warning("[HomeScene] Skipping location card sequence.")
		_title_card_running = false
		await _after_location_card(location_key)
		return

	dialogic.paused = true
	var data: Dictionary = LOCATION_CARDS[location_key]
	var cfg := _build_card_config(data)
	await card.show_and_wait(cfg)
	await _after_location_card(location_key)
	print("[HomeScene] === LOCATION CARD SEQUENCE COMPLETE ===")


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


func _after_location_card(location_key: String) -> void:
	print("[HomeScene] _after_location_card() for '%s'" % location_key)
	match location_key:
		"abyss":
			print("[HomeScene] Abyss — setting dungeon start time and transitioning to World1.")
			# Set time to 10:00 AM and start the clock when entering the dungeon
			day_system.set_dungeon_start_time()
			if hud:
				hud.start_time()
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
	print("[HomeScene] Dialogue finished — scene: %s | Day: %d | Time: %s" % [
		current_scene, day_system.current_day, day_system.get_time_string()
	])
	match current_scene:
		"evening":
			# Day is done — advance and loop back to morning
			day_system.advance_day()
			health_system.daily_health_decay()
			print("[HomeScene] New day: %d | Rin health after decay: %d" % [
				day_system.current_day, health_system.get_health()
			])
			_request_scene("morning")
		"morning":
			print("[HomeScene] Morning scene complete.")
		"doubt":
			print("[HomeScene] Doubt scene complete.")
		_:
			print("[HomeScene] Unknown scene finished: %s" % current_scene)


func _on_dialogic_signal(argument: String) -> void:
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

		"affection":
			set_affection(int(value))

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
				if hud: hud.notify_coins_changed()

		"rin_health":
			if health_system:
				health_system.modify_health(int(value))
				if hud: hud.notify_health_changed()

		"day":
			# Manual day signal from dialogue (optional override)
			day_system.advance_day()
			health_system.daily_health_decay()
			if hud:
				hud.notify_health_changed()

		"load_world":
			_load_world(int(value))

		"show_location_card":
			await _show_location_card(value)

		_:
			push_warning("[HomeScene] Unknown signal '%s' with value '%s'" % [event_name, value])


# ─────────────────────────────────────────────────────────────────
# System Call Functions
# ─────────────────────────────────────────────────────────────────

func set_affection(amount: int) -> void:
	if affection_system:
		affection_system.modify_affection(amount)
		if hud: hud.notify_affection_changed()


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


func _clear_dialogic_layout() -> void:
	if dialogic:
		dialogic.end_timeline()
	var root := get_tree().root
	for child in root.get_children():
		if child.name.begins_with("DialogicLayout"):
			print("[HomeScene] Freeing lingering Dialogic layout node: %s" % child.name)
			child.queue_free()


func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
