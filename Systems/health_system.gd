extends Node

class_name HealthSystem

# ─── State ────────────────────────────────────────────────────────
var rin_health:     int = 50
var rin_health_max: int = 100

# NOTE: _ready() intentionally does NOT reset values.
# SaveSystem loads saved values after all autoloads are ready.
func _ready() -> void:
	print("[HealthSystem] Ready — rin_health: %d" % rin_health)


func modify_health(amount: int) -> void:
	rin_health = clamp(rin_health + amount, 0, rin_health_max)
	print("[HealthSystem] Health %+d → %d" % [amount, rin_health])


func set_health(value: int) -> void:
	rin_health = clamp(value, 0, rin_health_max)


func get_health() -> int:
	return rin_health


func is_critical() -> bool:
	return rin_health < 30


func is_healthy() -> bool:
	return rin_health > 70


func daily_health_decay(amount: int = 5) -> void:
	modify_health(-amount)
	print("[HealthSystem] Daily decay applied.")


func reset() -> void:
	rin_health = 50
	print("[HealthSystem] Reset to defaults.")
