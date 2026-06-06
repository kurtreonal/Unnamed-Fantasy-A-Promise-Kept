# hp_bar.gd — HP display panel (top-left)
# Attach to the HPBar MarginContainer in hud.tscn.
extends MarginContainer

@onready var bar       : ProgressBar = $VBox/Bar
@onready var label     : Label       = $VBox/Label

func set_hp(current: int, maximum: int) -> void:
	bar.max_value = maximum
	bar.value     = current
	label.text    = "%d / %d" % [current, maximum]
