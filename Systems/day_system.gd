extends Node

class_name Day_System

# ─── Day & Time State ─────────────────────────────────────────────
var current_day:    int = 1
var current_hour:   int = 10
var current_minute: int = 0

# ─── Constants ────────────────────────────────────────────────────
const CURFEW_HOUR:   int = 23
const CURFEW_MINUTE: int = 59

const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# ─── Return reason ────────────────────────────────────────────────
# Set before changing scene so home_scene knows what happened.
enum ReturnReason { NONE, CURFEW }
var return_reason: ReturnReason = ReturnReason.NONE

# ─── Signals ──────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
signal day_changed(day: int)
signal curfew_triggered()

# ─── Internal ─────────────────────────────────────────────────────
var _curfew_fired: bool = false

func _ready() -> void:
	print("[DaySystem] Ready — Day %d, Time %02d:%02d" % [current_day, current_hour, current_minute])


# ─────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────

func tick_minute() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour  += 1
	time_changed.emit(current_hour, current_minute)
	_check_curfew()


func set_time(hour: int, minute: int = 0) -> void:
	current_hour   = clamp(hour,   0, 23)
	current_minute = clamp(minute, 0, 59)
	time_changed.emit(current_hour, current_minute)


func advance_day() -> void:
	current_day    += 1
	current_hour    = 8
	current_minute  = 0
	_curfew_fired   = false
	return_reason   = ReturnReason.NONE
	day_changed.emit(current_day)
	time_changed.emit(current_hour, current_minute)
	print("[DaySystem] Day advanced → Day %d" % current_day)


func set_dungeon_start_time() -> void:
	set_time(10, 0)
	_curfew_fired = false
	print("[DaySystem] Dungeon start time set → 10:00 AM")


func set_evening_time() -> void:
	set_time(18, 0)
	print("[DaySystem] Evening time set → 06:00 PM")


func get_day_name() -> String:
	return DAY_NAMES[(current_day - 1) % 7]


func get_time_string() -> String:
	var suffix       := "AM" if current_hour < 12 else "PM"
	var display_hour := current_hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, current_minute, suffix]


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
		return_reason = ReturnReason.CURFEW
		print("[DaySystem] Curfew reached — 11:59 PM! Forcing return home.")
		curfew_triggered.emit()
