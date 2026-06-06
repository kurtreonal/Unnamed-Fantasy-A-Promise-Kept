extends CanvasLayer

class_name HUD

# ─────────────────────────────────────────────────────────────────
# hud.gd
#
# Manages two distinct display modes:
#   • Prologue mode  — TopBar + StatsPanel hidden, BottomBar shown
#   • Gameplay mode  — everything shown, stats update normally
#
# @onready paths all use the corrected scene hierarchy in hud.tscn:
#   HUD (CanvasLayer)
#   └── HUDContainer (Control, full-screen)
#       ├── TopBar          (top-left,  time + day)
#       ├── StatsPanel      (top-right, affection / health / coins)
#       ├── BottomBar       (bottom, always visible: History/Save/Load)
#       ├── HistoryOverlay  (full-screen overlay, hidden by default)
#       └── PopupLayer      (floating +/- popups, mouse-ignore)
# ─────────────────────────────────────────────────────────────────

# ─── System References ───────────────────────────────────────────
var affection_system: Affection_System
var health_system:    Health_System
var meal_system:      Meal_System
var day_system:       DaySystem
var game_state:       Node

# ─── Smooth advance state ─────────────────────────────────────────
const ADVANCE_TICK_RATE: float = 0.03
var _advance_minutes_remaining: int   = 0
var _advance_accumulator:       float = 0.0
var _is_advancing:              bool  = false

# ─── Live clock (1 real second = 1 in-game minute) ───────────────
const TICK_RATE:      float = 1.0
var _tick_accumulator: float = 0.0
var time_running:      bool  = false

# ─── Cached values (prevent redundant redraws) ────────────────────
var _last_affection: int = -999
var _last_health:    int = -999
var _last_coins:     int = -999

# ─── Shake guard ─────────────────────────────────────────────────
var _is_shaking: bool = false

# ─── Cached health StyleBox ──────────────────────────────────────
var _health_fill_style: StyleBoxFlat = null

# ─── HUD visibility mode ─────────────────────────────────────────
## true while the prologue is running — TopBar + StatsPanel stay hidden.
var _stats_hidden: bool = false

# ─────────────────────────────────────────────────────────────────
# @onready — all paths rooted at the HUD CanvasLayer node
# ─────────────────────────────────────────────────────────────────

# TopBar (top-left)
@onready var top_bar:         Control     = $HUDContainer/TopBar
@onready var time_label:      Label       = $HUDContainer/TopBar/TopBarMargin/TopBarHBox/TimeLabel
@onready var day_label:       Label       = $HUDContainer/TopBar/TopBarMargin/TopBarHBox/DayLabel

# StatsPanel (top-right)
@onready var stats_panel:     Control     = $HUDContainer/StatsPanel
@onready var affection_bar:   ProgressBar = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/AffectionRow/AffectionBar
@onready var affection_label: Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/AffectionRow/AffectionValue
@onready var health_bar:      ProgressBar = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/HealthRow/HealthBar
@onready var health_label:    Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/HealthRow/HealthValue
@onready var coins_label:     Label       = $HUDContainer/StatsPanel/StatsPanelMargin/StatsVBox/CoinsRow/CoinsValue

# BottomBar (always visible — History / Save / Load)
@onready var bottom_bar:  Control = $HUDContainer/BottomBar
@onready var btn_history: Button  = $HUDContainer/BottomBar/BottomBarMargin/BottomBarHBox/BtnHistory
@onready var btn_save:    Button  = $HUDContainer/BottomBar/BottomBarMargin/BottomBarHBox/BtnSave
@onready var btn_load:    Button  = $HUDContainer/BottomBar/BottomBarMargin/BottomBarHBox/BtnLoad

# HistoryOverlay (full-screen, toggled by BtnHistory)
@onready var history_overlay: Control = $HUDContainer/HistoryOverlay

# PopupLayer (floating +N / -N labels)
@onready var popup_layer: Control = $HUDContainer/PopupLayer


# ─────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	affection_system = get_node_or_null("/root/Affection_System")
	health_system    = get_node_or_null("/root/Health_System")
	meal_system      = get_node_or_null("/root/Meal_System")
	day_system       = get_node_or_null("/root/DaySystem")
	game_state       = get_node_or_null("/root/GameState")

	if not affection_system: push_warning("[HUD] Affection_System autoload not found.")
	if not health_system:    push_warning("[HUD] Health_System autoload not found.")
	if not meal_system:      push_warning("[HUD] Meal_System autoload not found.")
	if not day_system:       push_warning("[HUD] DaySystem autoload not found.")

	# Subscribe to DaySystem signals for live clock
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

	# Wire bottom-bar buttons
	if btn_history: btn_history.pressed.connect(_on_btn_history)
	if btn_save:    btn_save.pressed.connect(_on_btn_save)
	if btn_load:    btn_load.pressed.connect(_on_btn_load)

	# History overlay starts hidden
	if history_overlay:
		history_overlay.visible = false

	# Start with stats hidden — home_scene._ready() is the single authority
	# that calls hide_stats() or show_stats() once it knows the game state.
	# Hiding here prevents any flash of stats before home_scene decides.
	if top_bar:    top_bar.visible    = false
	if stats_panel: stats_panel.visible = false
	_stats_hidden = true


func _process(delta: float) -> void:
	# ── Smooth fast-forward (used by home_scene.gd) ──────────────
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

	# ── Live clock tick ──────────────────────────────────────────
	elif time_running:
		_tick_accumulator += delta
		if _tick_accumulator >= TICK_RATE:
			_tick_accumulator -= TICK_RATE
			if day_system:
				day_system.tick_minute()


# ─────────────────────────────────────────────────────────────────
# Prologue: Stats Visibility Control
# ─────────────────────────────────────────────────────────────────

## Hides TopBar + StatsPanel for the duration of the prologue.
## BottomBar (History/Save/Load) remains visible at all times.
func hide_stats() -> void:
	_stats_hidden = true
	if top_bar:    top_bar.visible    = false
	if stats_panel: stats_panel.visible = false
	print("[HUD] Stats hidden — prologue mode.")


## Reveals TopBar + StatsPanel with a gentle fade-in.
## Called by home_scene when scene_01_morning begins.
func show_stats() -> void:
	_stats_hidden = false

	if top_bar:
		top_bar.visible    = true
		top_bar.modulate.a = 0.0
	if stats_panel:
		stats_panel.visible    = true
		stats_panel.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(top_bar,    "modulate:a", 1.0, 0.8)
	t.tween_property(stats_panel, "modulate:a", 1.0, 0.8)

	_refresh_all()
	print("[HUD] Stats shown — gameplay mode.")


# ─────────────────────────────────────────────────────────────────
# Bottom Bar: History / Save / Load
# ─────────────────────────────────────────────────────────────────

func _on_btn_history() -> void:
	if not history_overlay:
		return
	history_overlay.visible = not history_overlay.visible
	print("[HUD] History overlay: %s" % history_overlay.visible)


func _on_btn_save() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.save_game()
		print("[HUD] Quick-save triggered.")
		_flash_button(btn_save, Color(0.3, 0.9, 0.5, 1.0))
	else:
		push_warning("[HUD] SaveSystem not found — cannot save.")


func _on_btn_load() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.save_exists:
		save_sys.load_game()
		_refresh_all()
		print("[HUD] Quick-load triggered.")
		_flash_button(btn_load, Color(0.4, 0.7, 1.0, 1.0))
	else:
		push_warning("[HUD] No save file to load.")


## Brief colour flash on a button to confirm the action.
func _flash_button(btn: Button, flash_color: Color) -> void:
	if not btn:
		return
	var orig := btn.modulate
	var t := create_tween()
	t.tween_property(btn, "modulate", flash_color, 0.12)
	t.tween_property(btn, "modulate", orig,        0.25)


## Appended by home_scene.gd whenever a dialogue line fires.
func append_history(line: String) -> void:
	var log_label: RichTextLabel = get_node_or_null(
		"HUDContainer/HistoryOverlay/HistoryPanel/HistoryVBox/HistoryScroll/HistoryLog"
	)
	if log_label:
		log_label.append_text(line + "\n")


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
# Time — Public API
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
