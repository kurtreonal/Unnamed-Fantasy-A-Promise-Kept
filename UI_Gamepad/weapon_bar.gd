# weapon_bar.gd — Weapon selector + element badge + element-switch cooldown
# Attach to the WeaponBar HBoxContainer in hud.tscn.
extends PanelContainer

# ── Weapon slot data (icon label text + display name) ────────
# Replace the emoji strings with TextureRect references if you
# add real icon textures later — the layout wiring stays the same.
const WEAPON_ICONS : Array[String] = ["⚔", "🏹", "🗡", "🪄"]
const WEAPON_NAMES : Array[String] = ["Sword", "Bow", "Lance", "Staff"]

# Element badge colours (modulate the badge panel)
const ELEMENT_COLOURS : Dictionary = {
	0: Color(0.85, 0.25, 0.10),   # Fire    — red-orange
	1: Color(0.95, 0.80, 0.10),   # Lightning — gold
	2: Color(0.15, 0.55, 0.90),   # Water   — blue
}
const ELEMENT_NAMES : Array[String] = ["Fire", "Lightning", "Water"]

# ── Node refs — adjust paths to match your exact scene tree ──
@onready var slots          : Array[Control] = [
	$HBox/Slot0, $HBox/Slot1, $HBox/Slot2, $HBox/Slot3
]
@onready var element_badge  : PanelContainer = $ElementBadge
@onready var element_label  : Label          = $ElementBadge/Label
@onready var cooldown_bar   : ProgressBar    = $CooldownBar
@onready var cooldown_label : Label          = $CooldownLabel

var _current_weapon : int = 0

func set_weapon(weapon: int) -> void:
	_current_weapon = weapon
	for i in slots.size():
		var slot : Control = slots[i]
		# Highlight active slot with a custom style
		slot.get_node("IconLabel").modulate = Color.WHITE if i == weapon else Color(0.4, 0.4, 0.4)
		slot.get_node("NameLabel").modulate = Color.WHITE if i == weapon else Color(0.4, 0.4, 0.4)

func set_element(element: int) -> void:
	element_badge.modulate = ELEMENT_COLOURS.get(element, Color.WHITE)
	element_label.text     = ELEMENT_NAMES[element]

# remaining: seconds left on cooldown, total: full cooldown duration
func set_element_cooldown(remaining: float, total: float) -> void:
	if remaining <= 0.0:
		cooldown_bar.visible   = false
		cooldown_label.visible = false
		return
	cooldown_bar.visible     = true
	cooldown_label.visible   = true
	cooldown_bar.max_value   = total
	cooldown_bar.value       = remaining
	cooldown_label.text      = "%.1fs" % remaining
