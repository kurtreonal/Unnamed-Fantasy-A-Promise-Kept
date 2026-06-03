extends Node

class_name Day_System

# ─── Day & Time State ─────────────────────────────────────────────
var current_day:    int = 1
var current_hour:   int = 10   # Game starts at 10:00 AM when leaving house
var current_minute: int = 0

# ─── Constants ────────────────────────────────────────────────────
const CURFEW_HOUR:   int = 23  # 11:00 PM — force return begins
const CURFEW_MINUTE: int = 59  # 11:59 PM — hard cutoff

const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# ─── Signals ──────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
signal day_changed(day: int)
signal curfew_triggered()   # Emitted once at 11:59 PM to force return

# ─── Internal ─────────────────────────────────────────────────────
var _curfew_fired: bool = false   # Prevents double-firing per day

func _ready() -> void:
	print("[DaySystem] Ready — Day %d, Time %02d:%02d" % [current_day, current_hour, current_minute])


# ─────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────

## Called every in-game minute tick (from whoever owns the clock).
func tick_minute() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour  += 1

	time_changed.emit(current_hour, current_minute)
	_check_curfew()


## Set time directly (e.g. when entering the house scene).
func set_time(hour: int, minute: int = 0) -> void:
	current_hour   = clamp(hour,   0, 23)
	current_minute = clamp(minute, 0, 59)
	time_changed.emit(current_hour, current_minute)


## Advance to next day. Resets time to morning and clears curfew guard.
func advance_day() -> void:
	current_day    += 1
	current_hour    = 8
	current_minute  = 0
	_curfew_fired   = false
	day_changed.emit(current_day)
	time_changed.emit(current_hour, current_minute)
	print("[DaySystem] Day advanced → Day %d" % current_day)


## Set time to dungeon entry time (called when leaving the house).
func set_dungeon_start_time() -> void:
	set_time(10, 0)
	_curfew_fired = false
	print("[DaySystem] Dungeon start time set → 10:00 AM")


## Set time to evening return (called when entering home after dungeon).
func set_evening_time() -> void:
	set_time(18, 0)
	print("[DaySystem] Evening time set → 06:00 PM")


## Returns the display name of the current day.
func get_day_name() -> String:
	return DAY_NAMES[(current_day - 1) % 7]


## Returns formatted time string.
func get_time_string() -> String:
	var suffix       := "AM" if current_hour < 12 else "PM"
	var display_hour := current_hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, current_minute, suffix]


## Returns true if time is past or at curfew.
func is_past_curfew() -> bool:
	return current_hour >= CURFEW_HOUR and current_minute >= CURFEW_MINUTE


# ─────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────

func _check_curfew() -> void:
	if _curfew_fired:
		return
	if current_hour >= CURFEW_HOUR and current_minute >= CURFEW_MINUTE:
		_curfew_fired = true
		print("[DaySystem] Curfew reached — 11:59 PM! Forcing return home.")
		curfew_triggered.emit()
