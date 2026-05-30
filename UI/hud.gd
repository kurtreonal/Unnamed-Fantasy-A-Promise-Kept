extends CanvasLayer

class_name HUD

# ─── System References ───────────────────────────────────────────
var affection_system: Affection_System
var health_system: Health_System
var meal_system: Meal_System

# ─── Time State ──────────────────────────────────────────────────
var current_hour:   int = 8
var current_minute: int = 0
var day_of_week:    int = 4  # 0=Mon … 6=Sun, default Friday
const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

const TICK_RATE: float = 1.0
var _tick_accumulator: float = 0.0
var time_running: bool = false

# ─── Cached values to detect changes ────────────────────────────
var _last_affection: int = -999
var _last_health:    int = -999
var _last_coins:     int = -999

# ─── Shake guard — prevents spawning a new shake tween every frame ──
var _is_shaking: bool = false

# ─── Cached StyleBox objects ────────────────────────────────────
var _health_fill_style: StyleBoxFlat = null

# ─── UI Node References ──────────────────────────────────────────
@onready var time_label:      Label          = $HUDContainer/TopBar/TopBarHBox/TimeLabel
@onready var day_label:       Label          = $HUDContainer/TopBar/TopBarHBox/DayLabel
@onready var affection_bar:   ProgressBar    = $HUDContainer/StatsPanel/StatsVBox/AffectionRow/AffectionBar
@onready var affection_label: Label          = $HUDContainer/StatsPanel/StatsVBox/AffectionRow/AffectionValue
@onready var health_bar:      ProgressBar    = $HUDContainer/StatsPanel/StatsVBox/HealthRow/HealthBar
@onready var health_label:    Label          = $HUDContainer/StatsPanel/StatsVBox/HealthRow/HealthValue
@onready var coins_label:     Label          = $HUDContainer/StatsPanel/StatsVBox/CoinsRow/CoinsValue
@onready var top_bar:         PanelContainer = $HUDContainer/TopBar
@onready var stats_panel:     PanelContainer = $HUDContainer/StatsPanel
@onready var hud_container:   Control        = $HUDContainer

# ─── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	affection_system = get_node_or_null("/root/Affection_System")
	health_system    = get_node_or_null("/root/Health_System")
	meal_system      = get_node_or_null("/root/Meal_System")

	if not affection_system:
		push_warning("[HUD] AffectionSystem autoload not found.")
	if not health_system:
		push_warning("[HUD] HealthSystem autoload not found.")
	if not meal_system:
		push_warning("[HUD] MealSystem autoload not found.")

	_apply_panel_styles()
	_apply_bar_styles()
	_refresh_all()
	_animate_intro()

func _process(delta: float) -> void:
	if time_running:
		_tick_accumulator += delta
		if _tick_accumulator >= TICK_RATE:
			_tick_accumulator -= TICK_RATE
			_advance_minute()

	# BUGFIX: Only update time every frame (cheap).
	# Stats are only refreshed when values actually change — NOT every frame.
	# Previously _refresh_all() here called _shake() 60x/sec when health was critical.
	_update_time()

# ─── Intro Animation ─────────────────────────────────────────────

func _animate_intro() -> void:
	if not top_bar or not stats_panel:
		return

	var original_top_pos   := top_bar.position
	var original_stats_pos := stats_panel.position

	top_bar.position.y     -= 60
	stats_panel.position.y -= 60
	top_bar.modulate.a      = 0.0
	stats_panel.modulate.a  = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(top_bar,     "position",    original_top_pos,   0.55).set_delay(0.1)
	tween.tween_property(top_bar,     "modulate:a",  1.0,                0.35).set_delay(0.1)
	tween.tween_property(stats_panel, "position",    original_stats_pos, 0.55).set_delay(0.22)
	tween.tween_property(stats_panel, "modulate:a",  1.0,                0.35).set_delay(0.22)

# ─── Styling ─────────────────────────────────────────────────────

func _apply_panel_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color            = Color(0.04, 0.04, 0.06, 0.88)
	panel_style.border_width_left   = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color        = Color(0.78, 0.78, 0.82, 1.0)
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left   = 10
	panel_style.content_margin_right  = 10
	panel_style.content_margin_top    = 6
	panel_style.content_margin_bottom = 6
	panel_style.shadow_color  = Color(0, 0, 0, 0.45)
	panel_style.shadow_size   = 6
	panel_style.shadow_offset = Vector2(2, 3)

	if top_bar:
		top_bar.add_theme_stylebox_override("panel", panel_style)
	if stats_panel:
		stats_panel.add_theme_stylebox_override("panel", panel_style.duplicate())

func _apply_bar_styles() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color            = Color(0.12, 0.12, 0.15, 1.0)
	bg_style.border_width_left   = 1
	bg_style.border_width_top    = 1
	bg_style.border_width_right  = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color        = Color(0.45, 0.45, 0.5, 1.0)
	bg_style.set_corner_radius_all(2)

	var aff_fill := StyleBoxFlat.new()
	aff_fill.bg_color = Color(0.85, 0.55, 0.70, 1.0)
	aff_fill.set_corner_radius_all(2)

	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.75, 0.90, 0.75, 1.0)
	hp_fill.set_corner_radius_all(2)

	if affection_bar:
		affection_bar.add_theme_stylebox_override("background", bg_style.duplicate())
		affection_bar.add_theme_stylebox_override("fill", aff_fill)

	if health_bar:
		health_bar.add_theme_stylebox_override("background", bg_style.duplicate())
		health_bar.add_theme_stylebox_override("fill", hp_fill)

# ─── Time Logic ──────────────────────────────────────────────────

func _advance_minute() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour  += 1
		if current_hour >= 24:
			current_hour = 0
			day_of_week  = (day_of_week + 1) % 7
	time_changed.emit(current_hour, current_minute)

func start_time() -> void:
	time_running = true

func stop_time() -> void:
	time_running = false

func set_time(hour: int, minute: int = 0) -> void:
	current_hour   = clamp(hour, 0, 23)
	current_minute = clamp(minute, 0, 59)
	_update_time()

func set_day(day_index: int) -> void:
	day_of_week = clamp(day_index, 0, 6)
	_update_time()

# ─── Refresh — called ONLY when a stat actually changes ──────────
# Call these from outside (e.g. HomeScene) after modifying a system,
# OR connect each system's changed signal to the matching update fn.

func _refresh_all() -> void:
	_update_time()
	_update_affection()
	_update_health()
	_update_coins()

func notify_affection_changed() -> void:
	_update_affection()

func notify_health_changed() -> void:
	_update_health()

func notify_coins_changed() -> void:
	_update_coins()

# ─── Individual Update Functions ─────────────────────────────────

func _update_time() -> void:
	if not time_label or not day_label:
		return
	var suffix       := "AM" if current_hour < 12 else "PM"
	var display_hour := current_hour % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "%02d:%02d %s" % [display_hour, current_minute, suffix]
	day_label.text  = DAY_NAMES[day_of_week]

func _update_affection() -> void:
	if not affection_system or not affection_bar or not affection_label:
		return
	var val: int = affection_system.get_affection()
	if val == _last_affection:
		return
	_last_affection = val

	affection_bar.max_value = affection_system.affection_max
	affection_bar.min_value = affection_system.affection_min
	affection_label.text    = str(val)
	_tween_bar(affection_bar, val)
	_pulse_label(affection_label)

func _update_health() -> void:
	if not health_system or not health_bar or not health_label:
		return
	var val: int = health_system.get_health()
	if val == _last_health:
		return
	_last_health = val

	health_bar.max_value = health_system.rin_health_max
	health_label.text    = str(val)
	_tween_bar(health_bar, val)
	_pulse_label(health_label)

	# Update fill color based on health ratio
	var ratio    := float(val) / float(health_system.rin_health_max)
	var fill_col := Color()
	if ratio > 0.5:
		fill_col = Color(0.75, 0.90, 0.75).lerp(Color(0.95, 0.88, 0.35), 1.0 - ((ratio - 0.5) * 2.0))
	else:
		fill_col = Color(0.95, 0.88, 0.35).lerp(Color(0.85, 0.20, 0.20), 1.0 - (ratio * 2.0))

	if _health_fill_style == null or _health_fill_style.bg_color != fill_col:
		_health_fill_style = StyleBoxFlat.new()
		_health_fill_style.bg_color = fill_col
		_health_fill_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("fill", _health_fill_style)

	# BUGFIX: _shake() is now guarded by _is_shaking so it only fires once per
	# critical event, not 60 times per second in _process().
	if health_system.is_critical():
		_shake(health_bar)

func _update_coins() -> void:
	if not meal_system or not coins_label:
		return
	var val: int = meal_system.get_coins()
	if val == _last_coins:
		return
	_last_coins = val
	coins_label.text = "%d g" % val
	_pulse_label(coins_label)

# ─── Animation Helpers ───────────────────────────────────────────

func _tween_bar(bar: ProgressBar, target: float) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property(bar, "value", target, 0.4)

func _pulse_label(label: Label) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(1.25, 1.25), 0.10)
	t.tween_property(label, "scale", Vector2(1.0,  1.0),  0.18)

# BUGFIX: _is_shaking flag ensures only ONE shake tween runs at a time.
# Previously this was called every frame from _process() when health was
# critical — spawning ~60 competing tweens per second, causing jitter and crash.
func _shake(node: Control) -> void:
	if _is_shaking:
		return
	_is_shaking = true

	var origin := node.position.x
	var t      := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position:x", origin + 5.0, 0.05)
	t.tween_property(node, "position:x", origin - 5.0, 0.05)
	t.tween_property(node, "position:x", origin + 3.0, 0.05)
	t.tween_property(node, "position:x", origin - 3.0, 0.05)
	t.tween_property(node, "position:x", origin,        0.05)
	# Release the guard once the shake animation finishes
	t.tween_callback(func(): _is_shaking = false)

# ─── Signal ──────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
