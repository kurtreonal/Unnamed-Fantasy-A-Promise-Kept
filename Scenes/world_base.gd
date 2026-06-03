extends Node2D
# world_base.gd

var day_system: DaySystem

# ─── Clock (1 real second = 1 in-game minute) ─────────────────────
const TICK_RATE: float = 1.0
var _tick_accumulator: float = 0.0
var _clock_running:    bool  = false

# ─── Time HUD ─────────────────────────────────────────────────────
var _world_hud:  CanvasLayer = null
var _time_label: Label        = null

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	day_system = get_node_or_null("/root/DaySystem")
	if not day_system:
		push_error("[WorldBase] DaySystem autoload not found!")
		return

	if not day_system.curfew_triggered.is_connected(_on_curfew_triggered):
		day_system.curfew_triggered.connect(_on_curfew_triggered)

	if not day_system.time_changed.is_connected(_on_time_changed):
		day_system.time_changed.connect(_on_time_changed)

	# Safety: if time wasn't set by home_scene, default to 10:00 AM
	if day_system.current_hour < 10:
		day_system.set_dungeon_start_time()

	_spawn_world_hud()
	_update_time_label()
	_clock_running = true

	print("[WorldBase] Ready — Day %d | Time %s" % [
		day_system.current_day, day_system.get_time_string()
	])


func _process(delta: float) -> void:
	if not _clock_running or not day_system:
		return
	_tick_accumulator += delta
	if _tick_accumulator >= TICK_RATE:
		_tick_accumulator -= TICK_RATE
		day_system.tick_minute()


# ─── Build the HUD entirely in code ───────────────────────────────
func _spawn_world_hud() -> void:
	_world_hud = CanvasLayer.new()
	_world_hud.layer = 15
	add_child(_world_hud)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left   = 10
	panel.offset_top    = 10
	panel.offset_right  = 185
	panel.offset_bottom = 46

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.06, 0.06, 0.10, 0.82)
	style.border_width_left   = 1
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	style.border_color        = Color(0.45, 0.45, 0.55, 1.0)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_world_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     4)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  4)
	panel.add_child(margin)

	_time_label = Label.new()
	_time_label.text = "🕐 --:-- --"
	_time_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_time_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(_time_label)


# ─── Signal handlers ──────────────────────────────────────────────
func _on_time_changed(_hour: int, _minute: int) -> void:
	_update_time_label()

func _update_time_label() -> void:
	if _time_label and day_system:
		_time_label.text = "🕐 " + day_system.get_time_string()

func _on_curfew_triggered() -> void:
	print("[WorldBase] Curfew reached — forcing return to home.")
	_clock_running = false
	# day_system.return_reason is already set to CURFEW by day_system
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/home_scene.tscn")
