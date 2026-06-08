extends Control

# ─────────────────────────────────────────────────────────────────
# save_slots_ui.gd
# Attach to the root node of save_slots_ui.tscn
#
# Operates in two modes set before add_child / show:
#   mode = "save"  → clicking a slot writes to it
#   mode = "load"  → clicking a slot restores from it
#
# Usage from HUD or home_scene:
#   var ui = preload("res://UI/SaveSlots/save_slots_ui.tscn").instantiate()
#   ui.mode = "save"                       # or "load"
#   ui.current_scene_name = scene_file_path
#   ui.current_player_pos = player.global_position
#   get_tree().root.add_child(ui)
#   ui.closed.connect(ui.queue_free)
# ─────────────────────────────────────────────────────────────────

signal closed()

## "save" or "load"
var mode: String = "load"

## Passed in by the caller so save_manager has scene context
var current_scene_name: String  = ""
var current_player_pos: Vector2 = Vector2.ZERO

# ─── Internal ─────────────────────────────────────────────────────
var _save_manager: Node
var _slot_buttons: Array = []   # Array[Button]

# Node references — wire these in the .tscn or rename to match yours
@onready var title_label:   Label         = $Panel/OuterMargin/VBox/TitleLabel
@onready var slots_grid:    GridContainer = $Panel/OuterMargin/VBox/ScrollContainer/SlotsGrid
@onready var btn_close:     Button        = $Panel/OuterMargin/VBox/BtnClose
@onready var confirm_panel: Control       = $ConfirmPanel
@onready var confirm_label: Label         = $ConfirmPanel/ConfirmMargin/VBox/ConfirmLabel
@onready var btn_confirm:   Button        = $ConfirmPanel/ConfirmMargin/VBox/HBox/BtnConfirm
@onready var btn_cancel:    Button        = $ConfirmPanel/ConfirmMargin/VBox/HBox/BtnCancel

var _pending_slot: int = -1


func _ready() -> void:
	# Wrap self in a high-layer CanvasLayer so we render above Dialogic
	var canvas := CanvasLayer.new()
	canvas.layer = 200          # Dialogic sits around 10-100; 200 guarantees top
	canvas.name  = "SaveSlotsLayer"
	get_parent().add_child(canvas)
	get_parent().remove_child(self)
	canvas.add_child(self)

	# Now fill the viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_save_manager = get_node_or_null("/root/SaveManager")
	if not _save_manager:
		push_error("[SaveSlotsUI] SaveManager autoload not found.")
		return

	title_label.text = "Save Game" if mode == "save" else "Load Game"

	if confirm_panel:
		confirm_panel.visible = false

	_build_slot_buttons()
	_refresh_slots()

	if btn_close:
		btn_close.pressed.connect(_on_close)
	if btn_confirm:
		btn_confirm.pressed.connect(_on_confirm)
	if btn_cancel:
		btn_cancel.pressed.connect(func(): confirm_panel.visible = false)

	if _save_manager.slots_changed.is_connected(_refresh_slots) == false:
		_save_manager.slots_changed.connect(_refresh_slots)


# ─── Build the slot button grid ────────────────────────────────────
func _build_slot_buttons() -> void:
	for child in slots_grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	for i in range(1, _save_manager.SLOT_COUNT + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 64)
		btn.alignment           = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slots_grid.add_child(btn)
		_slot_buttons.append(btn)


# ─── Refresh displayed info for every slot ─────────────────────────
func _refresh_slots() -> void:
	if not _save_manager:
		return
	var all_slots: Array = _save_manager.get_all_slots()

	for idx in range(all_slots.size()):
		var btn:  Button  = _slot_buttons[idx]
		var info: Variant = all_slots[idx]

		if info == null:
			btn.text     = "Slot %d   [ Empty ]" % (idx + 1)
			btn.disabled = (mode == "load")
		else:
			var day_str  := "Day %d" % info["day"]
			var time_str := "%02d:%02d" % [info["hour"], info["minute"]]
			var aff: int = int(info["affection"])
			var hp:  int = int(info["health"])
			btn.text     = "Slot %d   %s  |  %s  %s  |  Aff: %d  HP: %d" % [
				idx + 1, info["timestamp"], day_str, time_str, aff, hp
			]
			btn.disabled = false


# ─── Slot press handler ────────────────────────────────────────────
func _on_slot_pressed(slot_index: int) -> void:
	_pending_slot = slot_index

	if mode == "save":
		# Ask for confirmation before overwriting
		if _save_manager.slot_exists(slot_index):
			confirm_label.text  = "Overwrite Slot %d?" % slot_index
			confirm_panel.visible = true
		else:
			_do_save(slot_index)

	elif mode == "load":
		confirm_label.text    = "Load Slot %d?\nUnsaved progress will be lost." % slot_index
		confirm_panel.visible = true


func _on_confirm() -> void:
	confirm_panel.visible = false
	if _pending_slot < 1:
		return

	if mode == "save":
		_do_save(_pending_slot)
	elif mode == "load":
		_do_load(_pending_slot)

	_pending_slot = -1


func _do_save(slot_index: int) -> void:
	_save_manager.save_slot(slot_index, current_scene_name, current_player_pos)
	# _refresh_slots() fires automatically via slots_changed signal


func _do_load(slot_index: int) -> void:
	_on_close()
	_save_manager.load_slot(slot_index)


func _on_close() -> void:
	if _save_manager and _save_manager.slots_changed.is_connected(_refresh_slots):
		_save_manager.slots_changed.disconnect(_refresh_slots)
	closed.emit()
	# The UI reparented itself into a CanvasLayer named "SaveSlotsLayer".
	# Freeing only `self` would leave that wrapper node in the tree,
	# causing _open_slots_ui()'s duplicate-guard to block every future open.
	# Free the wrapper (our parent) instead — it takes us with it.
	var wrapper := get_parent()
	if wrapper and wrapper.name == "SaveSlotsLayer":
		wrapper.queue_free()
	else:
		queue_free()
