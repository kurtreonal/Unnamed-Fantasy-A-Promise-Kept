# item_bar.gd — Consumable item hotbar (bottom-center)
# Attach to the ItemBar HBoxContainer in hud.tscn.
extends PanelContainer

const SLOT_COUNT : int = 5

@onready var slots : Array[Control] = [
	$HBox/Item0, $HBox/Item1, $HBox/Item2, $HBox/Item3, $HBox/Item4
]

# slot   : 0-4
# icon   : emoji or texture name string shown in the IconLabel
# count  : stack count (0 = grayed out, shown as "x0")
func set_item(slot: int, icon: String, count: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	var s          : Control = slots[slot]
	var icon_lbl   : Label   = s.get_node("IconLabel")
	var count_lbl  : Label   = s.get_node("CountLabel")
	icon_lbl.text  = icon
	count_lbl.text = "x%d" % count
	# Gray out empty slots
	s.modulate     = Color.WHITE if count > 0 else Color(0.4, 0.4, 0.4, 0.6)

# Use this from your inventory / pickup system:
#   $HUD/ItemBar.set_item(0, "⚗", 3)
#   $HUD/ItemBar.set_item(1, "🍎", 0)
