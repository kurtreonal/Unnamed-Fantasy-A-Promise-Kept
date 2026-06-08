extends Control

# ─────────────────────────────────────────────────────────────────
# home_scene.gd  (simplified)
#
# Scene flow:
#   New Game  → Prologue → Scene01 → World1
#   Recall    → Scene02 → Scene01 (next day loop)
#   Curfew    → Scene02 → Scene01 (next day loop)
#   Load Game → resumes at saved_scene (morning or evening)
#
# Grey-screen fix: never touch the layout node manually.
# Just call Dialogic.start() directly — Dialogic 2.0 handles
# its own layout lifecycle. Removing the layout-clear code is
# what stops the grey screen.
# ─────────────────────────────────────────────────────────────────

# ─── Systems ─────────────────────────────────────────────────────
var affection_system: Affection_System
var meal_system:      Meal_System
var health_system:    Health_System
var day_system:       DaySystem
var save_system:      SaveSystem
var game_state:       Node
var dialogic:         Node
var hud:              HUD

# ─── Scene state ─────────────────────────────────────────────────
var current_scene: String = ""

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

const TIMELINES: Dictionary = {
	"prologue": "res://Timelines/prologue.dtl",
	"morning":  "res://Timelines/scene_01_morning_wakeup.dtl",
	"evening":  "res://Timelines/scene_02_evening_return.dtl",
	"doubt":    "res://Timelines/scene_03_moment_of_doubt.dtl",
}


# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	affection_system = get_node_or_null("/root/Affection_System")
	meal_system      = get_node_or_null("/root/Meal_System")
	health_system    = get_node_or_null("/root/Health_System")
	day_system       = get_node_or_null("/root/DaySystem")
	save_system      = get_node_or_null("/root/SaveSystem")
	game_state       = get_node_or_null("/root/GameState")
	dialogic         = get_node_or_null("/root/Dialogic")
	hud              = get_node_or_null("CanvasLayer/HUD")

	if not affection_system: push_error("[HomeScene] Affection_System not found!"); return
	if not meal_system:      push_error("[HomeScene] Meal_System not found!");      return
	if not health_system:    push_error("[HomeScene] Health_System not found!");    return
	if not day_system:       push_error("[HomeScene] DaySystem not found!");        return
	if not dialogic:         push_error("[HomeScene] Dialogic not found!");         return
	if not game_state:       push_error("[HomeScene] GameState not found!");        return

	# Initialize Dialogic variable default so it is never null/empty
	Dialogic.VAR.set("affection_tier", "low")

	print("====================")
	print("HOME READY")
	print("RETURN_REASON = ", day_system.return_reason)
	print("SAVED_SCENE = ", game_state.saved_scene)
	print("IS_NEW_GAME = ", game_state.is_new_game)
	print("CURRENT TIMELINE = ", dialogic.current_timeline)
	print("====================")

	# ── Wire HUD close button ─────────────────────────────────────
	var close_btn := get_node_or_null(
		"CanvasLayer/HUD/HUDContainer/HistoryOverlay/HistoryPanel/HistoryVBox/BtnCloseHistory"
	)
	if close_btn and not close_btn.pressed.is_connected(_on_close_history):
		close_btn.pressed.connect(_on_close_history)

	# ── Wire curfew signal ────────────────────────────────────────
	if not day_system.curfew_triggered.is_connected(_on_curfew_triggered):
		day_system.curfew_triggered.connect(_on_curfew_triggered)

	# ── Wire Dialogic signals ─────────────────────────────────────
	dialogic.timeline_ended.connect(_on_dialogue_finished)
	dialogic.signal_event.connect(_on_dialogic_signal)

	if dialogic.has_signal("choice_buttons_shown"):
		dialogic.choice_buttons_shown.connect(_on_choice_buttons_shown)

	print("[HomeScene] Ready — Day %d | %s | Affection: %d | Health: %d | Coins: %d" % [
		day_system.current_day,
		day_system.get_time_string(),
		affection_system.current_affection,
		health_system.rin_health,
		meal_system.coins,
	])

	# ── Decide which scene to open ────────────────────────────────
	#
	# Priority:
	#   1. is_new_game → prologue
	#   2. saved_scene != "" → resume that scene (load game)
	#   3. return_reason == RECALL or CURFEW → evening
	#   4. anything else (normal world return) → morning
	#
	var canvas := get_node_or_null("CanvasLayer")
	if canvas: canvas.visible = true

	# Defer one frame so the scene tree is fully ready before Dialogic.start()
	await _wait_frame()

	print("============== HOME DEBUG START ==============")
	print("RETURN_REASON = ", day_system.return_reason)
	print("SAVED_SCENE = ", game_state.saved_scene)
	print("IS_NEW_GAME = ", game_state.is_new_game)
	print("CURRENT TIMELINE BEFORE DECISION = ", dialogic.current_timeline)
	print("PAUSED STATE = ", dialogic.paused)
	print("==============================================")

	if game_state.is_new_game:
		print("[HomeScene] → NEW GAME: starting prologue.")
		game_state.prologue_active = true
		if hud: hud.hide_stats()
		_play_scene("prologue")

	elif game_state.saved_scene != "":
		var key: String = game_state.saved_scene
		game_state.saved_scene = ""   # consume immediately
		print("[HomeScene] → LOAD GAME: resuming '%s'." % key)
		if key == "prologue":
			game_state.prologue_active = true
			if hud: hud.hide_stats()
		else:
			if hud: hud.show_stats()
		_play_scene(key)

	elif day_system.return_reason in [DaySystem.ReturnReason.RECALL, DaySystem.ReturnReason.CURFEW]:
		print("[HomeScene] → RETURN (%s): starting evening." % str(day_system.return_reason))
		day_system.set_evening_time()
		if hud: hud.show_stats()
		_play_scene("evening")

	else:
		print("[HomeScene] → NORMAL: starting morning.")
		if hud: hud.show_stats()
		_play_scene("morning")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_all_dialogic()


# ─────────────────────────────────────────────────────────────────
# Safe frame wait helper
# ─────────────────────────────────────────────────────────────────

func _wait_frame() -> void:
	await Engine.get_main_loop().process_frame


# ─────────────────────────────────────────────────────────────────
# Core: play a scene
# ─────────────────────────────────────────────────────────────────

func _play_scene(key: String) -> void:
	if not TIMELINES.has(key):
		push_error("[HomeScene] Unknown scene key: '%s'" % key)
		return

	_meal_purchased_this_scene = false
	current_scene = key

	if key == "morning" or key == "prologue":
		if hud: hud.stop_time()

	# end_timeline() in _disconnect_all_dialogic() already cleared
	# current_timeline and reset Dialogic's background state, so no
	# manual background clearing is needed here.

	print("---- PLAY SCENE DEBUG ----" )
	print("KEY = ", key)
	print("TIMELINE = ", TIMELINES[key])
	print("CURRENT TIMELINE BEFORE CLEAR = ", dialogic.current_timeline)
	print("PAUSED = ", dialogic.paused)
	print("--------------------------")

	# Hard reset before starting new timeline
	await _hard_reset_dialogic()

	print("[HomeScene] Starting timeline: ", TIMELINES[key])
	dialogic.start(TIMELINES[key])


# ─────────────────────────────────────────────────────────────────
# Dialogic signal cleanup (on scene exit)
# ─────────────────────────────────────────────────────────────────

func _hard_reset_dialogic() -> void:
	"""Force a complete Dialogic reset before starting a new timeline.
	This prevents ghost states where Dialogic thinks it's still running."""
	if not dialogic:
		return
	dialogic.paused = false
	if dialogic.current_timeline != null:
		dialogic.end_timeline()
	await _wait_frame()
	await _wait_frame()
	print("[HomeScene] Dialogic hard reset complete.")


func _disconnect_all_dialogic() -> void:
	if not dialogic: return
	# Disconnect signals FIRST so the timeline_ended signal from end_timeline()
	# below does not re-trigger _on_dialogue_finished() mid-transition.
	if dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		dialogic.timeline_ended.disconnect(_on_dialogue_finished)
	if dialogic.signal_event.is_connected(_on_dialogic_signal):
		dialogic.signal_event.disconnect(_on_dialogic_signal)
	if dialogic.has_signal("choice_buttons_shown"):
		if dialogic.choice_buttons_shown.is_connected(_on_choice_buttons_shown):
			dialogic.choice_buttons_shown.disconnect(_on_choice_buttons_shown)
	# CRITICAL: clear current_timeline so the next dialogic.start() is not
	# silently ignored. Dialogic 2.0 refuses start() when current_timeline != null.
	if dialogic.current_timeline != null:
		dialogic.end_timeline()


# ─────────────────────────────────────────────────────────────────
# Dialogic: timeline ended
# ─────────────────────────────────────────────────────────────────

func _on_dialogue_finished() -> void:
	print("[HomeScene] Timeline ended — scene: '%s'" % current_scene)

	match current_scene:

		"prologue":
			# Prologue done → clear flags, reveal HUD, start morning
			game_state.is_new_game     = false
			game_state.prologue_active = false
			day_system.set_time(8, 0)
			day_system.record_save_checkpoint()
			if hud:
				hud.show_stats()
				hud.stop_time()
			_play_scene("morning")

		"morning":
			# Morning (Scene01) done → go to World1
			# World scene will return here via RECALL or CURFEW → evening
			print("[HomeScene] Morning complete → entering World1.")
			if day_system: day_system.record_save_checkpoint()
			if save_system: save_system.save_game()
			_go_to_world(1)

		"evening":
			# Evening (Scene02) done → advance day, start next morning
			day_system.advance_day()
			health_system.daily_health_decay()
			print("[HomeScene] Day advanced → Day %d | Health: %d" % [
				day_system.current_day, health_system.get_health()
			])
			day_system.record_save_checkpoint()
			if save_system: save_system.save_game()
			if hud:
				hud.notify_health_changed()
				hud.notify_affection_changed()
				hud.notify_coins_changed()
				hud.stop_time()
			_play_scene("morning")

		"doubt":
			if save_system: save_system.save_game()
			print("[HomeScene] Doubt scene complete.")

		_:
			print("[HomeScene] Unhandled scene end: '%s'" % current_scene)


# ─────────────────────────────────────────────────────────────────
# Dialogic: signal events from timelines
# ─────────────────────────────────────────────────────────────────

func _on_dialogic_signal(argument: String) -> void:
	if _title_card_running:
		return

	# Feed dialogue lines without ":" into history
	if hud and not argument.contains(":"):
		hud.append_history(argument)
		return

	print("[HomeScene] Signal: %s" % argument)

	var colon_idx := argument.find(":")
	if colon_idx == -1:
		push_warning("[HomeScene] Signal has no value: %s" % argument)
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
				push_warning("[HomeScene] Duplicate meal signal ignored: '%s'" % value)
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

		"check_affection_tier":
			var aff := affection_system.current_affection if affection_system else 0
			var tier := "low"
			if aff >= 8:
				tier = "high"
			elif aff >= 3:
				tier = "mid"
			Dialogic.VAR.set("affection_tier", tier)
			print("[HomeScene] affection_tier set → %s (aff: %d)" % [tier, aff])

		"day":
			# No-op: day advance happens only in _on_dialogue_finished("evening").
			push_warning("[HomeScene] 'day' signal mid-timeline ignored. Remove [signal arg=\"day:+1\"] from the timeline.")

		"load_world":
			_go_to_world(int(value))

		"show_location_card":
			await _show_location_card(value)

		_:
			push_warning("[HomeScene] Unknown signal '%s:%s'" % [event_name, value])


# ─────────────────────────────────────────────────────────────────
# Choice grey-out
# ─────────────────────────────────────────────────────────────────

func _on_choice_buttons_shown() -> void:
	await _wait_frame()
	_apply_choice_greying()


func _apply_choice_greying() -> void:
	if not meal_system:
		return
	var coins: int  = meal_system.get_coins()
	var all_buttons := _find_dialogic_choice_buttons()
	for btn in all_buttons:
		var cost_key: String = _get_meal_cost_key(btn.text)
		if cost_key == "":
			continue
		var can_afford: bool = coins >= meal_system.MEAL_COSTS[cost_key]
		btn.disabled = not can_afford
		btn.modulate = Color.WHITE if can_afford else Color(0.55, 0.55, 0.55, 0.65)


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
# Time advance
# ─────────────────────────────────────────────────────────────────

func _advance_time(hours: int) -> void:
	if not hud: return
	hud.advance_hours(hours)
	if not hud.time_advance_finished.is_connected(_on_time_advance_finished):
		hud.time_advance_finished.connect(_on_time_advance_finished, CONNECT_ONE_SHOT)


func _on_time_advance_finished() -> void:
	print("[HomeScene] Time advanced → %s" % day_system.get_time_string())


# ─────────────────────────────────────────────────────────────────
# Location title card
# ─────────────────────────────────────────────────────────────────

func _show_location_card(location_key: String) -> void:
	print("[HomeScene] Location card: '%s'" % location_key)
	_title_card_running = true

	var card: LocationTitleCard = get_node_or_null("/root/LocationTitle_Card")
	if not card or not LOCATION_CARDS.has(location_key):
		push_warning("[HomeScene] Skipping location card — not found.")
		_title_card_running = false
		_after_location_card(location_key)
		return

	dialogic.paused = true
	var cfg := _build_card_config(LOCATION_CARDS[location_key])
	await card.show_and_wait(cfg)
	_after_location_card(location_key)


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
	_title_card_running = false
	match location_key:
		"abyss":
			# Save checkpoint then go to World1
			if day_system: day_system.record_save_checkpoint()
			if hud: hud.start_time()
			if save_system: save_system.save_game()
			_disconnect_all_dialogic()
			get_tree().change_scene_to_file.call_deferred(WORLD_SCENES[1])
		_:
			dialogic.paused = false


# ─────────────────────────────────────────────────────────────────
# World transition
# ─────────────────────────────────────────────────────────────────

func _go_to_world(world_number: int) -> void:
	if not WORLD_SCENES.has(world_number):
		push_error("[HomeScene] No world mapped for: %d" % world_number)
		return
	if day_system: day_system.record_save_checkpoint()
	if save_system: save_system.save_game()
	_disconnect_all_dialogic()
	get_tree().change_scene_to_file(WORLD_SCENES[world_number])


# ─────────────────────────────────────────────────────────────────
# Curfew handler
# ─────────────────────────────────────────────────────────────────

func _on_curfew_triggered() -> void:
	print("[HomeScene] Curfew triggered — returning home.")
	if save_system: save_system.save_game()
	_disconnect_all_dialogic()
	get_tree().change_scene_to_file.call_deferred("res://Scenes/home_scene.tscn")


# ─────────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────────

func _on_close_history() -> void:
	var overlay := get_node_or_null(
		"CanvasLayer/HUD/HUDContainer/HistoryOverlay"
	)
	if overlay:
		overlay.visible = false


# ─────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────

func load_morning_scene() -> void: _play_scene("morning")
func load_evening_scene() -> void: _play_scene("evening")
func load_doubt_scene()   -> void: _play_scene("doubt")


# ─────────────────────────────────────────────────────────────────
# Stat helpers
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
		print("[HomeScene] Meal '%s' | Affection %+d | Health %+d" % [meal_type, aff, health])
	else:
		print("[HomeScene] Meal failed — not enough coins.")


func set_mood(mood_name: String) -> void:
	if affection_system:
		affection_system.set_mood(mood_name)
	print("[HomeScene] Mood → %s" % mood_name)


func check_affection(required: int) -> bool:
	if affection_system:
		return affection_system.affection_check(required)
	return false
