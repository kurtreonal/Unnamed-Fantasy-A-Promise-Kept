extends Node
# coin_system.gd
# Autoload singleton — add to Project > Autoloads as "CoinSystem"
#
# Mirrors the pattern used by AffectionSystem, HealthSystem, and DaySystem.
# Coins are saved in their own JSON file so they persist independently
# of any other system's save slot.
#
# Public API
#   add_coins(amount: int)          — grant coins (clamped to 0+)
#   spend_coins(amount: int) -> bool — deduct coins; returns false if insufficient
#   get_coins() -> int              — read current total
#   save_data()                     — write to disk
#   load_data()                     — read from disk (called in _ready)
#
# Dialogic integration
#   Set Dialogic variable "player_coins" before any timeline that needs it:
#       Dialogic.VAR.set("player_coins", CoinSystem.get_coins())
#   Or call CoinSystem.sync_dialogic() from home_scene.gd after loading.

# ─── Signal ──────────────────────────────────────────────────────
signal coins_changed(new_total: int)

# ─── State ───────────────────────────────────────────────────────
var _coins: int = 0

const SAVE_PATH := "user://coin_data.json"

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	load_data()
	print("[CoinSystem] Ready — Coins: %d" % _coins)


# ─── Public API ──────────────────────────────────────────────────

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount
	print("[CoinSystem] +%d coins → total: %d" % [amount, _coins])
	coins_changed.emit(_coins)
	save_data()


func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if _coins < amount:
		print("[CoinSystem] Not enough coins (have %d, need %d)" % [_coins, amount])
		return false
	_coins -= amount
	print("[CoinSystem] -%d coins → total: %d" % [amount, _coins])
	coins_changed.emit(_coins)
	save_data()
	return true


func get_coins() -> int:
	return _coins


# Convenience: push current total into Dialogic so timelines can read it.
func sync_dialogic() -> void:
	if Engine.has_singleton("Dialogic") or get_node_or_null("/root/Dialogic"):
		Dialogic.VAR.set("player_coins", _coins)
		print("[CoinSystem] Dialogic player_coins synced → %d" % _coins)


# ─── Persistence ─────────────────────────────────────────────────

func save_data() -> void:
	var data := {"coins": _coins}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[CoinSystem] Saved — coins: %d" % _coins)
	else:
		push_error("[CoinSystem] Could not open '%s' for writing." % SAVE_PATH)


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_coins = 0
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[CoinSystem] Could not open '%s' for reading." % SAVE_PATH)
		return
	var text   := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("coins"):
		_coins = int((parsed as Dictionary)["coins"])
	else:
		push_warning("[CoinSystem] Corrupt save — resetting to 0.")
		_coins = 0
	print("[CoinSystem] Loaded — coins: %d" % _coins)
