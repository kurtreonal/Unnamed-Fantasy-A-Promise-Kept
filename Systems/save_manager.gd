extends Node

# ─────────────────────────────────────────────────────────────────
# save_manager.gd
# Autoload name: SaveManager
#
# TyranoBuilder-style multi-slot save system.
# Each slot is a full snapshot of game state at the moment of save.
# Slots are independent — loading one never affects another.
# ─────────────────────────────────────────────────────────────────

const SAVE_DIR     := "user://saves/"
const SLOT_COUNT   := 9
const VERSION      := 2

# Emitted after a slot is written or deleted so the UI can refresh
signal slots_changed()

# ─── System references ────────────────────────────────────────────
var _affection: Node
var _health:    Node
var _meal:      Node
var _day:       Node
var _game_state: Node


func _ready() -> void:
	_resolve_systems()
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	print("[SaveManager] Ready — %d slots available." % SLOT_COUNT)


# ─────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────

## Write a full snapshot to slot_index (1-based).
func save_slot(slot_index: int, scene_name: String = "", player_pos: Vector2 = Vector2.ZERO) -> void:
	_resolve_systems()

	var now     := Time.get_datetime_dict_from_system()
	var ts      := "%04d-%02d-%02d %02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute]

	var data := {
		"version":    VERSION,
		"timestamp":  ts,
		"slot":       slot_index,

		# ── Scene & world ──────────────────────────────────────
		"scene": {
			"name":       scene_name,
			"player_x":   player_pos.x,
			"player_y":   player_pos.y,
		},

		# ── Affection ─────────────────────────────────────────
		"affection": {
			"current_affection": _affection.current_affection if _affection else 0,
			"current_mood":      _affection.current_mood      if _affection else 0,
		},

		# ── Health ────────────────────────────────────────────
		"health": {
			"rin_health": _health.rin_health if _health else 50,
		},

		# ── Meal / Economy ────────────────────────────────────
		"meal": {
			"coins":     _meal.coins     if _meal else 5000,
			"last_meal": _meal.last_meal if _meal else "",
		},

		# ── Day & Time ────────────────────────────────────────
		"day": {
			"current_day":    _day.current_day    if _day else 1,
			"current_hour":   _day.current_hour   if _day else 8,
			"current_minute": _day.current_minute if _day else 0,
		},

		# ── Story flags ───────────────────────────────────────
		# Save the active home-scene timeline key so a mid-scene save
		# restarts from the correct scene rather than jumping to morning.
		# home_scene keys: "prologue", "morning", "evening", "doubt".
		# When saved from a world/dungeon scene the key is "" (empty).
		"flags": {
			"prologue_active": _game_state.prologue_active if _game_state else false,
			"saved_scene":     _get_active_home_scene(),
		},
	}

	var path := _slot_path(slot_index)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Cannot write slot %d at: %s" % [slot_index, path])
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Record checkpoint so WorldBase restores the exact saved time
	if _day and _day.has_method("record_save_checkpoint"):
		_day.record_save_checkpoint()

	slots_changed.emit()
	print("[SaveManager] Slot %d saved — Day %d | %02d:%02d | Scene: %s" % [
		slot_index,
		data["day"]["current_day"],
		data["day"]["current_hour"],
		data["day"]["current_minute"],
		scene_name,
	])


## Load a slot and restore all systems. Returns true on success.
func load_slot(slot_index: int) -> bool:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] Slot %d does not exist." % slot_index)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Cannot read slot %d." % slot_index)
		return false

	var raw    := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveManager] Slot %d is corrupt." % slot_index)
		return false

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

	# ── Day & Time (use restore_time to guard against curfew instant-fire) ──
	if data.has("day") and _day:
		var d: Dictionary = data["day"]
		_day.current_day = int(d.get("current_day", 1))
		var h: int = int(d.get("current_hour",   8))
		var m: int = int(d.get("current_minute", 0))
		if _day.has_method("restore_time"):
			_day.restore_time(h, m)
		else:
			_day.current_hour   = h
			_day.current_minute = m

	# ── Story flags ───────────────────────────────────────────────
	# Restore story flags.
	# is_new_game is ALWAYS false on load — we never re-trigger the new-game
	# branch from a loaded slot.
	# saved_scene tells home_scene which timeline to restart from the top.
	if _game_state:
		_game_state.is_new_game     = false
		_game_state.prologue_active = false
		_game_state.saved_scene     = ""
		if data.has("flags"):
			var f: Dictionary = data["flags"]
			# Restore prologue_active so the HUD stays hidden if the save
			# was made during the prologue.
			_game_state.prologue_active = bool(f.get("prologue_active", false))
			# saved_scene is the home_scene key to restart from the top.
			_game_state.saved_scene = str(f.get("saved_scene", ""))

	# ── Scene transition ──────────────────────────────────────────
	if data.has("scene"):
		var s:          Dictionary = data["scene"]
		var scene_name: String     = str(s.get("name", ""))
		var px: float              = float(s.get("player_x", 0.0))
		var py: float              = float(s.get("player_y", 0.0))
		_restore_scene(scene_name, Vector2(px, py))

	print("[SaveManager] Slot %d loaded — Day %d | %02d:%02d" % [
		slot_index,
		_day.current_day    if _day else 1,
		_day.current_hour   if _day else 8,
		_day.current_minute if _day else 0,
	])
	return true


## Delete a slot by index.
func delete_slot(slot_index: int) -> void:
	var path := _slot_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		slots_changed.emit()
		print("[SaveManager] Slot %d deleted." % slot_index)


## Returns slot metadata dict or null if the slot is empty.
## Keys: slot, timestamp, scene_name, day, hour, minute, affection, health, coins
func get_slot_info(slot_index: int) -> Variant:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var raw    := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = parsed
	return {
		"slot":        slot_index,
		"timestamp":   str(data.get("timestamp", "Unknown")),
		"scene_name":  str(data.get("scene",     {}).get("name", "")),
		"day":         int(data.get("day",        {}).get("current_day",  1)),
		"hour":        int(data.get("day",        {}).get("current_hour", 8)),
		"minute":      int(data.get("day",        {}).get("current_minute", 0)),
		"affection":   int(data.get("affection",  {}).get("current_affection", 0)),
		"health":      int(data.get("health",     {}).get("rin_health",        50)),
		"coins":       int(data.get("meal",       {}).get("coins",           5000)),
	}


## Returns an Array of slot info dicts (null entries = empty slots).
## Index 0 = slot 1.
func get_all_slots() -> Array:
	var result := []
	for i in range(1, SLOT_COUNT + 1):
		result.append(get_slot_info(i))
	return result


## True if slot_index has a save file.
func slot_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_index))


## Convenience: save to slot using the current scene tree's scene file name.
func quick_save(slot_index: int) -> void:
	var scene_name := ""
	var tree       := get_tree()
	if tree and tree.current_scene:
		scene_name = tree.current_scene.scene_file_path

	var player_pos := Vector2.ZERO
	var player     := _find_player()
	if player:
		player_pos = player.global_position

	save_slot(slot_index, scene_name, player_pos)


# ─────────────────────────────────────────────────────────────────
# Scene Restoration
# ─────────────────────────────────────────────────────────────────

# Maps saved scene name strings to their file paths
const SCENE_MAP := {
	"home_scene":              "res://Scenes/home_scene.tscn",
	"res://Scenes/home_scene.tscn": "res://Scenes/home_scene.tscn",
	"World1":                  "res://Scenes/World1.tscn",
	"res://Scenes/World1.tscn": "res://Scenes/World1.tscn",
	"World2":                   "res://Scenes/World2.tscn",
	"res://Scenes/World2.tscn": "res://Scenes/World2.tscn",
	"World3":                   "res://Scenes/World3.tscn",
	"res://Scenes/World3.tscn": "res://Scenes/World3.tscn",
	"dungeon_world1.tscn":                   "res://Scenes/World2.tscn",
	"res://Scenes/dungeon_world1.tscn": "res://Scenes/dungeon_world1.tscn",
	
}

func _restore_scene(scene_name: String, player_pos: Vector2) -> void:
	if scene_name == "":
		return

	var path: String = SCENE_MAP.get(scene_name, scene_name)
	if not ResourceLoader.exists(path):
		push_warning("[SaveManager] Scene path not found: %s" % path)
		return

	# Stash spawn position so WorldBase/HomeScene can pick it up on _ready
	if _game_state and "spawn_position" in _game_state:
		_game_state.spawn_position = player_pos

	# Do NOT hide the Dialogic layout here. Hiding it before change_scene_to_file
	# causes a grey screen because the layout node survives the scene change but
	# remains invisible — dialogic.start() then plays into a hidden node.
	# Dialogic 2.0 reuses its layout automatically; just let it be.
	get_tree().change_scene_to_file(path)


# ─────────────────────────────────────────────────────────────────
# Internal Helpers
# ─────────────────────────────────────────────────────────────────

func _slot_path(slot_index: int) -> String:
	return SAVE_DIR + "slot_%02d.json" % slot_index


func _find_player() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	# Try unique name first, then plain name
	var player := tree.get_first_node_in_group("player")
	if player:
		return player
	var scene := tree.current_scene
	if scene:
		var c := scene.get_node_or_null("%Character")
		if c:
			return c
		c = scene.get_node_or_null("Character")
		if c:
			return c
	return null


func _resolve_systems() -> void:
	if not _affection:  _affection  = get_node_or_null("/root/Affection_System")
	if not _health:     _health     = get_node_or_null("/root/Health_System")
	if not _meal:       _meal       = get_node_or_null("/root/Meal_System")
	if not _day:        _day        = get_node_or_null("/root/DaySystem")
	if not _game_state: _game_state = get_node_or_null("/root/GameState")


## Returns the current home_scene timeline key ("prologue", "morning",
## "evening", "doubt") or "" if the current scene is not home_scene.
func _get_active_home_scene() -> String:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return ""
	# Only meaningful when we are actually in home_scene
	if not tree.current_scene.scene_file_path.ends_with("home_scene.tscn"):
		return ""
	# HomeScene exposes current_scene as a String property
	var home: Node = tree.current_scene
	if home and "current_scene" in home:
		return str(home.current_scene)
	return ""
