extends CanvasLayer

class_name HUD

# ─── System References ───────────────────────────────────────────
var affection_system: Affection_System
var health_system:    Health_System
var meal_system:      Meal_System
var day_system:       DaySystem

# ─── Smooth advance state ─────────────────────────────────────────
const ADVANCE_TICK_RATE: float = 0.03
var _advance_minutes_remaining: int = 0
var _advance_accumulator:       float = 0.0
var _is_advancing:              bool  = false

# ─── Live clock tick (1 real second = 1 in-game minute) ──────────
const TICK_RATE:      float = 1.0
var _tick_accumulator: float = 0.0
var time_running:      bool  = false

# ─── Cached values ────────────────────────────────────────────────
var _last_affection: int = -999
var _last_health:    int = -999
var _last_coins:     int = -999

# ─── Shake guard ─────────────────────────────────────────────────
var _is_shaking: bool = false

# ─── Cached StyleBox ─────────────────────────────────────────────
var _health_fill_style: StyleBoxFlat = null

# ─── UI Node References ──────────────────────────────────────────
@onready var time_label:      Label       = $HUDContainer/TopBar/TopBarMargin/TopBarHBox/TimeLabel
@onready var day_label:       Label       = $HUDContainer/TopBar/TopBarMargin/TopBarHBox/DayLabel
@onready var affection_bar:   ProgressBar = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/AffectionRow/AffectionBar
@onready var affection_label: Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/AffectionRow/AffectionValue
@onready var health_bar:      ProgressBar = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/HealthRow/HealthBar
@onready var health_label:    Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/HealthRow/HealthValue
@onready var coins_label:     Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/CoinsRow/CoinsValue
@onready var top_bar:         Control     = $HUDContainer/TopBar
@onready var stats_panel:     Control     = $HUDContainer/StatsPanel
@onready var hud_container:   Control     = $HUDContainer
@onready var popup_layer:     Control     = $HUDContainer/PopupLayer

# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	affection_system = get_node_or_null("/root/Affection_System")
	health_system    = get_node_or_null("/root/Health_System")
	meal_system      = get_node_or_null("/root/Meal_System")
	day_system       = get_node_or_null("/root/DaySystem")

	if not affection_system: push_warning("[HUD] AffectionSystem autoload not found.")
	if not health_system:    push_warning("[HUD] HealthSystem autoload not found.")
	if not meal_system:      push_warning("[HUD] MealSystem autoload not found.")
	if not day_system:       push_warning("[HUD] DaySystem autoload not found.")

	# Listen to DaySystem for time & day changes
	if day_system:
		if not day_system.time_changed.is_connected(_on_time_changed):
			day_system.time_changed.connect(_on_time_changed)
		if not day_system.day_changed.is_connected(_on_day_changed):
			day_system.day_changed.connect(_on_day_changed)

	_last_affection = -999
	_last_health    = -999
	_last_coins     = -999

	_apply_bar_styles()
	_refresh_all()


func _process(delta: float) -> void:
	# ── Smooth fast-forward advance (used by home_scene.gd) ──────
	if _is_advancing:
		_advance_accumulator += delta
		while _advance_accumulator >= ADVANCE_TICK_RATE and _advance_minutes_remaining > 0:
			_advance_accumulator       -= ADVANCE_TICK_RATE
			_advance_minutes_remaining -= 1
			if day_system:
				day_system.tick_minute()
		if _advance_minutes_remaining <= 0:
			_is_advancing        = false
			_advance_accumulator = 0.0
			time_advance_finished.emit()

	# ── Live clock tick (1 real second = 1 in-game minute) ───────
	elif time_running:
		_tick_accumulator += delta
		if _tick_accumulator >= TICK_RATE:
			_tick_accumulator -= TICK_RATE
			if day_system:
				day_system.tick_minute()


# ─────────────────────────────────────────────────────────────────
# Bar Styling
# ─────────────────────────────────────────────────────────────────

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


# ─────────────────────────────────────────────────────────────────
# Time — Public API (delegates to DaySystem)
# ─────────────────────────────────────────────────────────────────

func start_time() -> void:
	time_running = true

func stop_time() -> void:
	time_running = false

func set_time(hour: int, minute: int = 0) -> void:
	if day_system:
		day_system.set_time(hour, minute)

func set_day(day_index: int) -> void:
	if day_system:
		day_system.current_day = clamp(day_index, 1, 9999)
		_update_time()

func advance_hours(hours: int) -> void:
	_advance_minutes_remaining += hours * 60
	_is_advancing               = true

func advance_minutes(minutes: int) -> void:
	_advance_minutes_remaining += minutes
	_is_advancing               = true

func is_advancing() -> bool:
	return _is_advancing


# ─────────────────────────────────────────────────────────────────
# DaySystem Signal Handlers
# ─────────────────────────────────────────────────────────────────

func _on_time_changed(_hour: int, _minute: int) -> void:
	_update_time()

func _on_day_changed(_day: int) -> void:
	_update_time()


# ─────────────────────────────────────────────────────────────────
# Stat Refresh — public notify hooks
# ─────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_update_time()
	_update_affection()
	_update_health()
	_update_coins()

func notify_affection_changed() -> void: _update_affection()
func notify_health_changed()    -> void: _update_health()
func notify_coins_changed()     -> void: _update_coins()


# ─────────────────────────────────────────────────────────────────
# Individual Update Functions
# ─────────────────────────────────────────────────────────────────

func _update_time() -> void:
	if not time_label or not day_label:
		return
	if day_system:
		time_label.text = day_system.get_time_string()
		day_label.text  = "Day %d  %s" % [day_system.current_day, day_system.get_day_name()]
	else:
		time_label.text = "--:-- --"
		day_label.text  = "---"


func _update_affection() -> void:
	if not affection_system or not affection_bar or not affection_label:
		return
	var val: int = affection_system.get_affection()
	if val == _last_affection:
		return
	var delta_val: int  = val - _last_affection
	_last_affection         = val
	affection_bar.max_value = affection_system.affection_max
	affection_bar.min_value = affection_system.affection_min
	affection_label.text    = str(val)
	_tween_bar(affection_bar, val)
	_pulse_label(affection_label)
	if delta_val != 0 and affection_label:
		_spawn_popup(delta_val, affection_label, Color(1.0, 0.55, 0.75, 1.0))


func _update_health() -> void:
	if not health_system or not health_bar or not health_label:
		return
	var val: int = health_system.get_health()
	if val == _last_health:
		return
	var delta_val: int  = val - _last_health
	_last_health         = val
	health_bar.max_value = health_system.rin_health_max
	health_label.text    = str(val)
	_tween_bar(health_bar, val)
	_pulse_label(health_label)

	var ratio    := float(val) / float(health_system.rin_health_max)
	var fill_col := Color()
	if ratio > 0.5:
		fill_col = Color(0.75, 0.90, 0.75).lerp(Color(0.95, 0.88, 0.35), 1.0 - ((ratio - 0.5) * 2.0))
	else:
		fill_col = Color(0.95, 0.88, 0.35).lerp(Color(0.85, 0.20, 0.20), 1.0 - (ratio * 2.0))

	if _health_fill_style == null or _health_fill_style.bg_color != fill_col:
		_health_fill_style          = StyleBoxFlat.new()
		_health_fill_style.bg_color = fill_col
		_health_fill_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("fill", _health_fill_style)

	if health_system.is_critical():
		_shake(health_bar)

	if delta_val != 0 and health_label:
		_spawn_popup(delta_val, health_label, Color(0.55, 0.95, 0.55, 1.0))


func _update_coins() -> void:
	if not meal_system or not coins_label:
		return
	var val: int = meal_system.get_coins()
	if val == _last_coins:
		return
	var delta_val: int = val - _last_coins
	_last_coins      = val
	coins_label.text = "%d g" % val
	_pulse_label(coins_label)
	if delta_val != 0 and coins_label:
		_spawn_popup(delta_val, coins_label, Color(1.0, 0.90, 0.40, 1.0))


# ─────────────────────────────────────────────────────────────────
# Floating +N Popup Animation
# ─────────────────────────────────────────────────────────────────

func _spawn_popup(amount: int, anchor: Label, color: Color) -> void:
	if not popup_layer:
		return
	var lbl        := Label.new()
	lbl.text        = ("+%d" % amount) if amount > 0 else str(amount)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.z_index     = 10
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(lbl)
	await get_tree().process_frame
	var anchor_pos: Vector2 = anchor.get_global_rect().get_center()
	lbl.position = anchor_pos - Vector2(lbl.size.x * 0.5, lbl.size.y)
	var t1 := create_tween()
	t1.set_parallel(true)
	t1.set_ease(Tween.EASE_OUT)
	t1.set_trans(Tween.TRANS_QUART)
	t1.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.35)
	t1.tween_property(lbl, "scale",      Vector2(1.3, 1.3),      0.18)
	await t1.finished
	var target_pos: Vector2 = anchor.get_global_rect().get_center()
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.set_ease(Tween.EASE_IN)
	t2.set_trans(Tween.TRANS_QUART)
	t2.tween_property(lbl, "position",   target_pos,        0.30)
	t2.tween_property(lbl, "scale",      Vector2(0.3, 0.3), 0.30)
	t2.tween_property(lbl, "modulate:a", 0.0,               0.25)
	await t2.finished
	lbl.queue_free()


# ─────────────────────────────────────────────────────────────────
# Animation Helpers
# ─────────────────────────────────────────────────────────────────

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
	t.tween_property(node, "position:x", origin,       0.05)
	t.tween_callback(func(): _is_shaking = false)


# ─────────────────────────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
signal time_advance_finished()
