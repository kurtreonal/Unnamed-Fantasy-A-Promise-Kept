# ─────────────────────────────────────────────────────────────────
# ROOT NODE TYPE : CanvasLayer (layer = 10)
# Place hud.tscn as a child of your World/Game scene (not character).
#
# WORLD SCENE _ready():
#   $HUD.setup($Character)
#
# FEATURES:
#   • Weapon switch bound to E — WEAPON_SWITCH_COOLDOWN must expire
#     before switching again. The weapon border flashes red when locked.
#   • Skill switch bound to R — SKILL_SWITCH_COOLDOWN guards cycling.
#     The skill border flashes red when locked.
#   • WeaponName / WeaponIcon and SpellName / SpellIcon update live
#     whenever the weapon or skill changes.
#   • HUD panels follow the character via screen-space offsets.
#     Press F2 to drag panels and adjust offsets live.
#
# NOTE: hud.tscn is NOT modified — all behaviour is driven from this script.
# ─────────────────────────────────────────────────────────────────
extends CanvasLayer

# ── Constants ──────────────────────────────────────────────────
const EDIT_KEY  : Key   = KEY_F2
const HUD_SCALE : float = 1.0

## Seconds the player must wait before switching weapon again (E key).
const WEAPON_SWITCH_COOLDOWN : float = 1.0
## Seconds the player must wait before switching skill  again (R key).
const SKILL_SWITCH_COOLDOWN  : float = 0.75

# ── Weapon display data ────────────────────────────────────────
const WEAPON_NAMES : Dictionary = {
	0: "Sword",
	1: "Lance",
	2: "Bow",
	3: "Staff",
}
# Replace these paths with the correct icon for each weapon.
const WEAPON_ICONS : Dictionary = {
	0: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc155.png"),
	1: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc1742.png"),
	2: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc1484.png"),
	3: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc1652.png"),
}

# ── Skill display data ─────────────────────────────────────────
const SKILL_NAMES : Dictionary = {
	0: "Fireball",
	1: "Lightning",
}
const SKILL_ICONS : Dictionary = {
	0: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc1352.png"),
	1: preload("res://Sprite Assest/Free - Raven Fantasy Icons/Separated Files/64x64/fc1035.png"),
}

# ── Element colours (tint on the Weapon_Sword border) ────────────
const ELEMENT_COLORS : Array[Color] = [
	Color(1.0, 0.083, 0.0, 1.0),   # 0 Fire      — orange-red
	Color(0.943, 0.67, 0.0, 1.0),    # 1 Lightning — electric blue
	Color(0.185, 0.0, 0.878, 1.0),    # 2 Water     — cyan-blue
]

# ── Scene references ───────────────────────────────────────────
@onready var _scene       : Control = $Scene
@onready var _hp_bar_root : Control = $Scene/TopRight_Hp
@onready var _weapon_root : Control = $Scene/BottomLeft_Weapon_Skill
@onready var _item_root   : Control = $Scene/MiddleBar_Items

# HP progress bar (child of TopRight_Hp/HPBar/HPBar_BG)
@onready var _hp_bar : ProgressBar = $Scene/TopRight_Hp/HPBar/HPBar_BG/HPBar_BG

# Weapon name + icon display
@onready var _weapon_icon : TextureRect = $Scene/BottomLeft_Weapon_Skill/WeaponName_Holder/WeaponIcon
@onready var _weapon_name : Label       = $Scene/BottomLeft_Weapon_Skill/WeaponName_Holder/WeaponName

# Skill name + icon display
@onready var _skill_icon  : TextureRect = $Scene/BottomLeft_Weapon_Skill/Staff_SpellHolder/SpellIcon
@onready var _skill_name  : Label       = $Scene/BottomLeft_Weapon_Skill/Staff_SpellHolder/SpellName

# Borders used for locked-flash feedback
@onready var _weapon_border : NinePatchRect = $Scene/BottomLeft_Weapon_Skill/Weapon_Sword
@onready var _skill_border  : NinePatchRect = $Scene/BottomLeft_Weapon_Skill/Staff_Skill

# ── Runtime state ──────────────────────────────────────────────
var _character       : CharacterBody2D = null

var _weapon_cooldown : float = 0.0
var _skill_cooldown  : float = 0.0

var _edit_mode      : bool    = false
var _drag_node      : Control = null
var _drag_offset    : Vector2 = Vector2.ZERO
var _edit_label     : Label   = null

# ── Ready ──────────────────────────────────────────────────────
func _ready() -> void:
	# Edit-mode banner
	_edit_label = Label.new()
	_edit_label.text = "[ HUD EDIT — drag panels — F2 to lock ]"
	_edit_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	_edit_label.add_theme_font_size_override("font_size", 13)
	_edit_label.position = Vector2(8, 2)
	_edit_label.visible  = false
	_scene.add_child(_edit_label)

	# Auto-find the character via the "player" group.
	# Add your Character node to the "player" group in the Inspector (Scene tab).
	# Deferred so every node in the scene finishes _ready() first.
	call_deferred("_find_character")

func _find_character() -> void:
	# First try the "player" group, then fall back to scanning for any CharacterBody2D.
	var character := get_tree().get_first_node_in_group("player")
	if character is CharacterBody2D:
		setup(character)
		return
	var root := get_tree().current_scene
	if root:
		character = _find_character_body(root)
	if character is CharacterBody2D:
		setup(character)
	else:
		push_warning("HUD: could not find a CharacterBody2D — call setup() manually.")

func _find_character_body(node: Node) -> CharacterBody2D:
	if node is CharacterBody2D:
		return node
	for child in node.get_children():
		var result := _find_character_body(child)
		if result:
			return result
	return null

# ── Setup (called automatically via group, or manually from World scene) ──
func setup(character: CharacterBody2D) -> void:
	_character = character

	# Wire up signals emitted by character.gd
	var sigs := {
		"weapon_changed":        _on_weapon_changed,
		"element_changed":       _on_element_changed,
		"element_cooldown_tick": _on_element_cooldown_tick,
		"staff_skill_changed":   _on_staff_skill_changed,
		"cast_started":          _on_cast_started,
		"cast_finished":         _on_cast_finished,
		"hp_changed":            _on_hp_changed,
	}
	for sig in sigs:
		if character.has_signal(sig) and not character.get(sig).is_connected(sigs[sig]):
			character.get(sig).connect(sigs[sig])

	# Sync initial display from character state
	_refresh_weapon_display(character.current_weapon)
	_refresh_skill_display(character.staff_skill)
	_on_element_changed(character.sword_element)
	_on_hp_changed(character.hp, character.max_hp)

# ── Per-frame: tick cooldowns ────────────────────────────────
func _process(delta: float) -> void:
	_tick_cooldowns(delta)

# ── Cooldown tick ──────────────────────────────────────────────
func _tick_cooldowns(delta: float) -> void:
	if _weapon_cooldown > 0.0:
		_weapon_cooldown = maxf(_weapon_cooldown - delta, 0.0)
	if _skill_cooldown > 0.0:
		_skill_cooldown = maxf(_skill_cooldown - delta, 0.0)

# ── Input ──────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# ── F2: toggle HUD edit / drag mode ──────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == EDIT_KEY:
			_edit_mode = not _edit_mode
			_edit_label.visible = _edit_mode
			_drag_node      = null
			for p in _all_panels():
				p.modulate = Color(1.0, 1.0, 0.5) if _edit_mode else Color.WHITE
			get_viewport().set_input_as_handled()
			return


	# ── Edit-mode drag ────────────────────────────────────────
	if not _edit_mode:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_node = null
			for p in _all_panels():
				var r := Rect2(p.position, p.size * HUD_SCALE)
				if r.has_point(event.position):
					_drag_node   = p
					_drag_offset = p.position - event.position
					break
		else:
			_drag_node      = null

	if event is InputEventMouseMotion and _drag_node != null:
		var new_pos : Vector2 = event.position + _drag_offset
		_drag_node.position = new_pos

# ── Public cycle requests (called by character._input) ────────
# Single authoritative entry point for both character key presses
# and the HUD's own _input(). Cooldown gate lives here once.
func request_cycle_weapon() -> void:
	if _character == null or _character.is_attacking:
		return
	if _weapon_cooldown > 0.0:
		_flash_border(_weapon_border)
		return
	_character.cycle_weapon()
	_weapon_cooldown = WEAPON_SWITCH_COOLDOWN

func request_cycle_skill() -> void:
	if _character == null or _character.is_attacking:
		return
	if _skill_cooldown > 0.0:
		_flash_border(_skill_border)
		return
	_character.cycle_staff_skill()
	_skill_cooldown = SKILL_SWITCH_COOLDOWN

# ── Display refresh ────────────────────────────────────────────
func _refresh_weapon_display(weapon: int) -> void:
	_weapon_icon.texture = WEAPON_ICONS.get(weapon, WEAPON_ICONS[0])
	_weapon_name.text    = WEAPON_NAMES.get(weapon, "???")

func _refresh_skill_display(skill: int) -> void:
	_skill_icon.texture = SKILL_ICONS.get(skill, SKILL_ICONS[0])
	_skill_name.text    = SKILL_NAMES.get(skill, "???")

# ── Locked-state border flash ──────────────────────────────────
func _flash_border(border: NinePatchRect) -> void:
	var original_modulate : Color = border.modulate
	border.modulate = Color(1.0, 0.15, 0.15)
	get_tree().create_timer(0.12).timeout.connect(
		func(): if is_instance_valid(border): border.modulate = original_modulate
	)

# ── Panel helpers ──────────────────────────────────────────────
func _all_panels() -> Array:
	return [_hp_bar_root, _weapon_root, _item_root]

# ── Signal handlers (from character.gd) ────────────────────────
func _on_weapon_changed(weapon: int)                             -> void: _refresh_weapon_display(weapon)
func _on_element_changed(element: int) -> void:
	var col := ELEMENT_COLORS[element] if element < ELEMENT_COLORS.size() else Color.WHITE
	_weapon_border.modulate = col
func _on_element_cooldown_tick(_remaining: float, _total: float) -> void: pass
func _on_staff_skill_changed(skill: int)                         -> void: _refresh_skill_display(skill)
func _on_cast_started(_duration: float)                          -> void: pass
func _on_cast_finished()                                         -> void: pass
func _on_hp_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(_hp_bar):
		return
	_hp_bar.max_value = float(maximum)
	_hp_bar.value     = float(current)
	# Brief red tint on the bar when damage is taken.
	_hp_bar.add_theme_stylebox_override(
		"fill",
		_make_fill_style(Color(0.85, 0.1, 0.1))
	)
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(_hp_bar):
			_hp_bar.add_theme_stylebox_override(
				"fill",
				_make_fill_style(Color(0.2, 0.75, 0.2))
			)
	)

## Helper: build a simple flat StyleBoxFlat fill colour for the HP bar.
func _make_fill_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                  = color
	s.corner_radius_top_left    = 2
	s.corner_radius_top_right   = 2
	s.corner_radius_bottom_right = 2
	s.corner_radius_bottom_left = 2
	return s

func set_item(_slot: int, _icon: String, _count: int)            -> void: pass
