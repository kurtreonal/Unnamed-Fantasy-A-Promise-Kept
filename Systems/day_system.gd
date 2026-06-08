extends Node

class_name Day_System

# ─── Day & Time State ─────────────────────────────────────────────
var current_day:    int = 1
var current_hour:   int = 10
var current_minute: int = 0

# ─── Save-checkpoint time ─────────────────────────────────────────
# Set by SaveSystem when a real save is written.
# WorldBase uses this to restore the clock to the exact moment
# the player was saved — not a hardcoded 08:00.
var saved_hour:   int = 10
var saved_minute: int = 0

# ─── Constants ────────────────────────────────────────────────────
const CURFEW_HOUR:   int = 18
const CURFEW_MINUTE: int = 0

const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# ─── Return reason ────────────────────────────────────────────────
# Set before changing scene so home_scene knows what happened.
enum ReturnReason { NONE, CURFEW, RECALL }
var return_reason: ReturnReason = ReturnReason.NONE

# ─── Signals ──────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
signal day_changed(day: int)
signal curfew_triggered()

# ─── Internal ─────────────────────────────────────────────────────
# IMPORTANT: _curfew_fired must survive scene changes.
# It is only reset by advance_day() so a curfew at 18:00 cannot
# re-fire when WorldBase or HomeScene reload at the same time.
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
	saved_hour      = 8
	saved_minute    = 0
	_curfew_fired   = false
	return_reason   = ReturnReason.NONE
	day_changed.emit(current_day)
	time_changed.emit(current_hour, current_minute)
	print("[DaySystem] Day advanced → Day %d" % current_day)


# Called by SaveSystem after writing a save so the world can
# resume from the exact saved moment rather than a hardcoded time.
func record_save_checkpoint() -> void:
	saved_hour   = current_hour
	saved_minute = current_minute
	print("[DaySystem] Save checkpoint recorded → %02d:%02d" % [saved_hour, saved_minute])


# WorldBase calls this on _ready instead of set_dungeon_start_time().
# Restores the clock to whatever time was saved.
func restore_to_save_checkpoint() -> void:
	set_time(saved_hour, saved_minute)
	# If the saved time is already at or past curfew (shouldn't happen
	# in normal play, but guard against corrupted saves), mark curfew
	# as already fired so it doesn't immediately trigger again.
	if saved_hour >= CURFEW_HOUR:
		_curfew_fired = true
	print("[DaySystem] Restored to save checkpoint → %s" % get_time_string())


func set_evening_time() -> void:
	# Mark curfew fired BEFORE setting 18:00 so _check_curfew()
	# cannot re-trigger when home_scene sets the evening time.
	_curfew_fired = true
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
		print("[DaySystem] Curfew reached — 06:00 PM! Forcing return home.")
		curfew_triggered.emit()
