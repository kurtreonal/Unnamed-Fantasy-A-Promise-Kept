extends Node

class_name HealthSystem

# Rin's health tracking
var rin_health: int = 50  # 0-100 scale
var rin_health_max: int = 100

func _ready() -> void:
	rin_health = 50

# Modify Rin's health
func modify_health(amount: int) -> void:
	rin_health = clamp(rin_health + amount, 0, rin_health_max)
	print("Rin's Health: %d" % rin_health)

# Get Rin's health
func get_health() -> int:
	return rin_health

# Set health directly
func set_health(value: int) -> void:
	rin_health = clamp(value, 0, rin_health_max)

# Check if Rin is in critical condition
func is_critical() -> bool:
	return rin_health < 30

# Check if Rin is healthy
func is_healthy() -> bool:
	return rin_health > 70

# Health deteriorates over time (passive)
func daily_health_decay(amount: int = 5) -> void:
	modify_health(-amount)
