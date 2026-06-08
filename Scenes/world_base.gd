extends Node2D
# world_base.gd

var day_system: DaySystem

# ─── Clock (1 real second = 1 in-game minute) ─────────────────────
const TICK_RATE:      float = 1.0
var _tick_accumulator: float = 0.0
var _clock_running:    bool  = false

# ─── Time HUD ─────────────────────────────────────────────────────
var _world_hud:  CanvasLayer = null
var _time_label: Label       = null

# ─── Recall ───────────────────────────────────────────────────────
const RECALL_DURATION: float = 4.0
const RECALL_KEY:      int   = KEY_B

var _recall_active:    bool    = false
var _recall_timer:     float   = 0.0
var _player_pos_cache: Vector2 = Vector2.ZERO

var _recall_layer:       CanvasLayer  = null
var _recall_bar:         ProgressBar  = null
var _recall_cancel_label: Label       = null
var _fade_rect:          ColorRect    = null


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

	# If the loaded time is at or past curfew, reset to the save checkpoint.
	# This prevents a saved 18:00 time from firing curfew the instant
	# world_base connects the signal and the first tick_minute() runs.
	if day_system.is_past_curfew() or day_system.current_hour < 8:
		day_system.restore_to_save_checkpoint()

	_spawn_world_hud()
	_spawn_recall_hud()
	_spawn_fade_rect()
	_update_time_label()
	_clock_running = true

	# Apply saved spawn position if SaveManager set one
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.spawn_position != Vector2.ZERO:
		var player := _get_player()
		if player:
			player.global_position  = game_state.spawn_position
			game_state.spawn_position = Vector2.ZERO
			print("[WorldBase] Player spawned at saved position: %s" % player.global_position)

	print("[WorldBase] Ready — Day %d | Time %s" % [
		day_system.current_day, day_system.get_time_string()
	])


# ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# ── Clock tick ──────────────────────────────────────────────
	if _clock_running and day_system:
		_tick_accumulator += delta
		if _tick_accumulator >= TICK_RATE:
			_tick_accumulator -= TICK_RATE
			day_system.tick_minute()

	# ── Recall logic ────────────────────────────────────────────
	if not _recall_active:
		return

	_recall_timer += delta

	# Cancel if player moved
	var player := _get_player()
	if player and player.global_position.distance_to(_player_pos_cache) > 4.0:
		_cancel_recall()
		return

	# Update bar
	if _recall_bar:
		_recall_bar.value = (_recall_timer / RECALL_DURATION) * 100.0

	if _recall_timer >= RECALL_DURATION:
		_complete_recall()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == RECALL_KEY:
			if _recall_active:
				_cancel_recall()
			else:
				_start_recall()


# ─── Recall core ──────────────────────────────────────────────────
func _start_recall() -> void:
	var player := _get_player()
	if not player:
		return

	_recall_active    = true
	_recall_timer     = 0.0
	_player_pos_cache = player.global_position

	if player.has_method("set_input_locked"):
		player.set_input_locked(true)

	if _recall_bar:
		_recall_bar.value = 0.0
	_set_recall_hud_visible(true)

	print("[WorldBase] Recall started.")


func _cancel_recall() -> void:
	_recall_active = false
	_recall_timer  = 0.0

	var player := _get_player()
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(false)

	_set_recall_hud_visible(false)
	print("[WorldBase] Recall cancelled.")


func _complete_recall() -> void:
	_recall_active = false
	_clock_running = false

	var player := _get_player()
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(true)

	_set_recall_hud_visible(false)

	# RECALL reason → home_scene plays scene_02_evening_return
	day_system.return_reason = day_system.ReturnReason.RECALL
	print("RETURN_REASON = ", day_system.return_reason)
	print("[WorldBase] Recall complete — loading Scene02.")
	await _fade_out(1.0)
	get_tree().change_scene_to_file("res://Scenes/home_scene.tscn")


# ─── Recall HUD — bar + cancel hint only, no panels or colors ─────
func _spawn_recall_hud() -> void:
	_recall_layer       = CanvasLayer.new()
	_recall_layer.layer = 20
	add_child(_recall_layer)

	# VBox anchored to bottom-center
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.offset_left   = -110
	vbox.offset_top    = -60
	vbox.offset_right  =  110
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 6)
	_recall_layer.add_child(vbox)

	# Progress bar — plain, no extra styling
	_recall_bar                     = ProgressBar.new()
	_recall_bar.min_value           = 0.0
	_recall_bar.max_value           = 100.0
	_recall_bar.value               = 0.0
	_recall_bar.show_percentage     = false
	_recall_bar.custom_minimum_size = Vector2(220, 14)
	vbox.add_child(_recall_bar)

	# Cancel hint label — plain white text, no color overrides
	_recall_cancel_label = Label.new()
	_recall_cancel_label.text                  = "Move or press B to cancel"
	_recall_cancel_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_recall_cancel_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_recall_cancel_label)

	_set_recall_hud_visible(false)


func _set_recall_hud_visible(v: bool) -> void:
	if _recall_layer:
		_recall_layer.visible = v


# ─── Fade ─────────────────────────────────────────────────────────
func _spawn_fade_rect() -> void:
	var layer      := CanvasLayer.new()
	layer.layer     = 100
	add_child(layer)

	_fade_rect              = ColorRect.new()
	_fade_rect.color        = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


func _fade_out(duration: float) -> void:
	if not _fade_rect:
		await get_tree().create_timer(duration).timeout
		return
	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		_fade_rect.color.a = clamp(t / duration, 0.0, 1.0)
		await get_tree().process_frame
	_fade_rect.color.a = 1.0


# ─── Time HUD ─────────────────────────────────────────────────────
func _spawn_world_hud() -> void:
	_world_hud       = CanvasLayer.new()
	_world_hud.layer = 15
	add_child(_world_hud)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left   = 10
	panel.offset_top    = 10
	panel.offset_right  = 160
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
	_time_label.text = "--:-- --"
	_time_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_time_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(_time_label)


# ─── Helpers ──────────────────────────────────────────────────────
func _get_player() -> Node:
	return get_node_or_null("%Character") \
		if has_node("%Character") \
		else get_node_or_null("Character")


func _on_time_changed(_hour: int, _minute: int) -> void:
	_update_time_label()

func _update_time_label() -> void:
	if _time_label and day_system:
		_time_label.text = day_system.get_time_string()

func _on_curfew_triggered() -> void:
	print("[WorldBase] Curfew reached — forcing return to Scene02.")
	_clock_running = false
	if _recall_active:
		_cancel_recall()
	day_system.return_reason = day_system.ReturnReason.CURFEW
	await _fade_out(0.8)
	get_tree().change_scene_to_file("res://Scenes/home_scene.tscn")
