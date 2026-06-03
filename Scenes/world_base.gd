extends Node2D
# world_base.gd

var day_system: DaySystem

func _ready() -> void:
	day_system = get_node_or_null("/root/DaySystem")
	if not day_system:
		push_error("[WorldBase] DaySystem autoload not found!")
		return

	# Connect curfew signal — fires at 11:59 PM
	if not day_system.curfew_triggered.is_connected(_on_curfew_triggered):
		day_system.curfew_triggered.connect(_on_curfew_triggered)

	# Safety: if time wasn't set by home_scene, default to 10:00 AM
	if day_system.current_hour < 10:
		day_system.set_dungeon_start_time()

	print("[WorldBase] Ready — Day %d | Time %s" % [
		day_system.current_day, day_system.get_time_string()
	])


func _on_curfew_triggered() -> void:
	print("[WorldBase] Curfew reached — forcing return to home.")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/home_scene.tscn")
