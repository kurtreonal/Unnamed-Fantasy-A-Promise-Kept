extends Node

# ─────────────────────────────────────────────────────────────────
# save_system.gd
# Autoload name: SaveSystem
#
# Saves and loads all game state to/from a JSON file.
# Called automatically on scene change and on game exit.
# All systems (Affection, Health, Meal, Day) write into one file.
# ─────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://savegame.json"

# ─── System references ────────────────────────────────────────────
var _affection: AffectionSystem
var _health:    HealthSystem
var _meal:      MealSystem
var _day:       DaySystem

# ─── Whether a save exists on disk ────────────────────────────────
var save_exists: bool = false

# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_affection = get_node_or_null("/root/AffectionSystem")
	_health    = get_node_or_null("/root/HealthSystem")
	_meal      = get_node_or_null("/root/MealSystem")
	_day       = get_node_or_null("/root/DaySystem")

	save_exists = FileAccess.file_exists(SAVE_PATH)

	if save_exists:
		print("[SaveSystem] Save file found — loading.")
		load_game()
	else:
		print("[SaveSystem] No save file — using defaults.")

	# Auto-save on quit
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


# ─────────────────────────────────────────────────────────────────
# Save
# ─────────────────────────────────────────────────────────────────

func save_game() -> void:
	_resolve_systems()

	var data := {
		"version": 1,

		# ── Affection ─────────────────────────────────────────────
		"affection": {
			"current_affection": _affection.current_affection if _affection else 0,
			"current_mood":      _affection.current_mood      if _affection else 0,
		},

		# ── Health ────────────────────────────────────────────────
		"health": {
			"rin_health": _health.rin_health if _health else 50,
		},

		# ── Meal / Economy ────────────────────────────────────────
		"meal": {
			"coins":     _meal.coins     if _meal else 5000,
			"last_meal": _meal.last_meal if _meal else "",
		},

		# ── Day & Time ────────────────────────────────────────────
		"day": {
			"current_day":    _day.current_day    if _day else 1,
			"current_hour":   _day.current_hour   if _day else 8,
			"current_minute": _day.current_minute if _day else 0,
		},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveSystem] Could not open save file for writing: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_exists = true
	print("[SaveSystem] Game saved → Day %d | %s | Affection: %d | Health: %d | Coins: %d" % [
		data["day"]["current_day"],
		"%02d:%02d" % [data["day"]["current_hour"], data["day"]["current_minute"]],
		data["affection"]["current_affection"],
		data["health"]["rin_health"],
		data["meal"]["coins"],
	])


# ─────────────────────────────────────────────────────────────────
# Load
# ─────────────────────────────────────────────────────────────────

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveSystem] No save file found at: %s" % SAVE_PATH)
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] Could not open save file for reading: %s" % SAVE_PATH)
		return

	var raw    := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveSystem] Save file corrupt or unreadable.")
		return

	var data: Dictionary = parsed
	_resolve_systems()

	# ── Affection ─────────────────────────────────────────────────
	if data.has("affection") and _affection:
		var a: Dictionary = data["affection"]
		_affection.current_affection = int(a.get("current_affection", 0))
		_affection.current_mood      = int(a.get("current_mood",      0))

	# ── Health ────────────────────────────────────────────────────
	if data.has("health") and _health:
		var h: Dictionary = data["health"]
		_health.rin_health = int(h.get("rin_health", 50))

	# ── Meal / Economy ────────────────────────────────────────────
	if data.has("meal") and _meal:
		var m: Dictionary = data["meal"]
		_meal.coins     = int(m.get("coins",     5000))
		_meal.last_meal = str(m.get("last_meal", ""))

	# ── Day & Time ────────────────────────────────────────────────
	if data.has("day") and _day:
		var d: Dictionary = data["day"]
		_day.current_day    = int(d.get("current_day",    1))
		_day.current_hour   = int(d.get("current_hour",   8))
		_day.current_minute = int(d.get("current_minute", 0))

	print("[SaveSystem] Game loaded → Day %d | %02d:%02d | Affection: %d | Health: %d | Coins: %d" % [
		_day.current_day    if _day       else 1,
		_day.current_hour   if _day       else 8,
		_day.current_minute if _day       else 0,
		_affection.current_affection if _affection else 0,
		_health.rin_health           if _health    else 50,
		_meal.coins                  if _meal      else 5000,
	])


# ─────────────────────────────────────────────────────────────────
# Delete save (for new game)
# ─────────────────────────────────────────────────────────────────

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		save_exists = false
		print("[SaveSystem] Save file deleted.")


# ─────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────

func _resolve_systems() -> void:
	if not _affection: _affection = get_node_or_null("/root/AffectionSystem")
	if not _health:    _health    = get_node_or_null("/root/HealthSystem")
	if not _meal:      _meal      = get_node_or_null("/root/MealSystem")
	if not _day:       _day       = get_node_or_null("/root/DaySystem")
