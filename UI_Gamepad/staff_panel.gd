# staff_panel.gd — Staff skill selector + cast-phase progress bar
# Attach to the StaffPanel PanelContainer in hud.tscn.
extends PanelContainer

const SKILL_ICONS  : Array[String] = ["🔥", "⚡"]
const SKILL_NAMES  : Array[String] = ["Fireball", "Lightning"]
const SKILL_COLOURS: Array[Color]  = [
	Color(1.0, 0.45, 0.1),    # Fireball — orange
	Color(1.0, 1.0, 0.0, 1.0),     # Lightning — lavender
]

@onready var slots         : Array[Control] = [$HBox/Skill0, $HBox/Skill1]
@onready var cast_bar      : ProgressBar    = $CastBar
@onready var cast_label    : Label          = $CastLabel
@onready var cast_row      : Control        = $CastRow   # HBox wrapping bar + label

# Internal timer
var _cast_total   : float = 0.0
var _cast_elapsed : float = 0.0
var _casting      : bool  = false

func set_skill(skill: int) -> void:
	for i in slots.size():
		var icon_lbl : Label = slots[i].get_node("IconLabel")
		var name_lbl : Label = slots[i].get_node("NameLabel")
		var active   : bool  = i == skill
		icon_lbl.modulate = SKILL_COLOURS[i] if active else Color(0.35, 0.35, 0.35)
		name_lbl.modulate = Color.WHITE       if active else Color(0.35, 0.35, 0.35)

# Call when Staff casting animation begins (character.gd: _staff_start_casting)
# duration: the Casting_Staff animation length in seconds (8 frames / 10 fps = 0.8 s)
func start_cast_timer(duration: float) -> void:
	_cast_total   = duration
	_cast_elapsed = 0.0
	_casting      = true
	cast_row.visible  = true
	cast_bar.max_value = duration
	cast_bar.value     = 0.0
	cast_label.text    = "0.0s"

# Call when casting finishes or is interrupted
func stop_cast_timer() -> void:
	_casting         = false
	cast_row.visible = false

func _process(delta: float) -> void:
	if not _casting:
		return
	_cast_elapsed = min(_cast_elapsed + delta, _cast_total)
	cast_bar.value  = _cast_elapsed
	cast_label.text = "%.2fs" % _cast_elapsed
	if _cast_elapsed >= _cast_total:
		stop_cast_timer()
