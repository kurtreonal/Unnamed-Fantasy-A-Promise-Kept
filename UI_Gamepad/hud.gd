# hud.gd — master HUD controller (Node2D version)
# ─────────────────────────────────────────────────────────────────────────────
# SETUP
#   1. In hud.tscn: change the root node type from CanvasLayer → Node2D.
#      Remove the "layer = 10" property line from the tscn if present.
#   2. In character.tscn: add hud.tscn as a child of your Character node.
#   3. In character.gd _ready(): call $HUD.setup(self)
#
# The HUD will now move with the character in world space and scale with
# the camera zoom automatically — no manual position tracking needed.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

# ── Layout offsets (world-space pixels, relative to character origin) ─────────
# Adjust these until the panels sit where you want them on screen.
# Positive Y = down, negative Y = up. Character feet are at origin (0, 0).

const OFFSET_HP_BAR      : Vector2 = Vector2(-80.0, -90.0)   # above the character
const OFFSET_WEAPON_BAR  : Vector2 = Vector2(-120.0, 20.0)   # left side
const OFFSET_ITEM_BAR    : Vector2 = Vector2(-110.0, 55.0)   # below weapon bar
const OFFSET_STAFF_PANEL : Vector2 = Vector2(25.0,  20.0)    # right side

# Global scale applied to the entire HUD.
# 1.0 = native size. Lower values (e.g. 0.7) shrink everything uniformly.
const HUD_SCALE : float = 0.75

# ── Sub-panel references ──────────────────────────────────────────────────────
@onready var hp_bar      : Node = $HPBar
@onready var weapon_bar  : Node = $WeaponBar
@onready var staff_panel : Node = $StaffPanel
@onready var item_bar    : Node = $ItemBar

var _character : CharacterBody2D = null

# ── Initialise ────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Apply global scale to the whole HUD node.
	scale = Vector2(HUD_SCALE, HUD_SCALE)

	# Position each sub-panel at its world-space offset.
	# Because this node is a child of the character, position (0,0) IS the
	# character's origin — so these offsets are relative to the character.
	hp_bar.position      = OFFSET_HP_BAR
	weapon_bar.position  = OFFSET_WEAPON_BAR
	item_bar.position    = OFFSET_ITEM_BAR
	staff_panel.position = OFFSET_STAFF_PANEL

# ── Public entry point ────────────────────────────────────────────────────────
# Call this from character.gd _ready():
#   $HUD.setup(self)
func setup(character: CharacterBody2D) -> void:
	_character = character

	# Connect character signals → HUD update methods.
	# Guard against double-connection if setup() is ever called more than once.
	if not character.weapon_changed.is_connected(_on_weapon_changed):
		character.weapon_changed.connect(_on_weapon_changed)
	if not character.element_changed.is_connected(_on_element_changed):
		character.element_changed.connect(_on_element_changed)
	if not character.element_cooldown_tick.is_connected(_on_element_cooldown_tick):
		character.element_cooldown_tick.connect(_on_element_cooldown_tick)
	if not character.staff_skill_changed.is_connected(_on_staff_skill_changed):
		character.staff_skill_changed.connect(_on_staff_skill_changed)
	if not character.cast_started.is_connected(_on_cast_started):
		character.cast_started.connect(_on_cast_started)
	if not character.cast_finished.is_connected(_on_cast_finished):
		character.cast_finished.connect(_on_cast_finished)
	if not character.hp_changed.is_connected(_on_hp_changed):
		character.hp_changed.connect(_on_hp_changed)

	# Initial paint — set all panels to the character's current state.
	weapon_bar.set_weapon(character.current_weapon)
	weapon_bar.set_element(character.sword_element)
	staff_panel.set_skill(character.staff_skill)
	hp_bar.set_hp(character.hp, character.max_hp)

# ── Keep HUD upright when the character sprite flips ─────────────────────────
# If your character node itself rotates (e.g. leaning on slopes), uncomment
# this to counter-rotate the HUD so it stays level.
#
# func _process(_delta: float) -> void:
#     global_rotation = 0.0

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_weapon_changed(weapon: int) -> void:
	weapon_bar.set_weapon(weapon)

func _on_element_changed(element: int) -> void:
	weapon_bar.set_element(element)

func _on_element_cooldown_tick(remaining: float, total: float) -> void:
	weapon_bar.set_element_cooldown(remaining, total)

func _on_staff_skill_changed(skill: int) -> void:
	staff_panel.set_skill(skill)

func _on_cast_started(duration: float) -> void:
	staff_panel.start_cast_timer(duration)

func _on_cast_finished() -> void:
	staff_panel.stop_cast_timer()

func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.set_hp(current, maximum)

# ── Item bar helper (call from your inventory system) ─────────────────────────
func set_item(slot: int, icon_text: String, count: int) -> void:
	item_bar.set_item(slot, icon_text, count)
