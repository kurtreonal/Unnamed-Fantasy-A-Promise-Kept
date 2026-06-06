# ════════════════════════════════════════════════════════════════
# character_hud_patch.gd
#
# This file shows ONLY the additions you need to make to your
# existing character.gd.  It is NOT a standalone script.
# Copy each section into character.gd at the marked positions.
# ════════════════════════════════════════════════════════════════

# ── 1. ADD THESE SIGNALS at the top, after your existing vars ──

signal weapon_changed(weapon: int)
signal element_changed(element: int)
signal element_cooldown_tick(remaining: float, total: float)
signal staff_skill_changed(skill: int)
signal cast_started(duration: float)
signal cast_finished()
signal hp_changed(current: int, maximum: int)

# ── 2. ADD THESE VARS after existing vars ─────────────────────

var hp     : int = 100
var max_hp : int = 100

# Duration the player must wait before switching sword element again.
# Set to 0.0 if you want instant switching.
const ELEMENT_SWITCH_COOLDOWN : float = 2.0
var _element_cooldown_timer   : float = 0.0

# Cast animation duration in seconds: 8 frames / 10 fps (from tscn)
const CAST_DURATION : float = 0.8

# ── 3. ADD THESE LINES to _physics_process, inside the
#       existing "if Input.is_action_just_pressed('Switch_Element')" block ──
#       Replace the existing cycle_sword_element() call with: ──

#   OLD:
#       if Input.is_action_just_pressed("Switch_Element"):
#           cycle_sword_element()
#
#   NEW:
	if Input.is_action_just_pressed("Switch_Element"):
		if _element_cooldown_timer <= 0.0:
			cycle_sword_element()

#   AND add this block below the match/input section, still inside _physics_process:
	if _element_cooldown_timer > 0.0:
		_element_cooldown_timer -= delta
		emit_signal("element_cooldown_tick",
			maxf(_element_cooldown_timer, 0.0),
			ELEMENT_SWITCH_COOLDOWN)

# ── 4. REPLACE cycle_sword_element() with this version ────────

func cycle_sword_element() -> void:
	if _element_cooldown_timer > 0.0:
		return   # guard: already on cooldown
	sword_element = (sword_element + 1) % 3 as SwordElement
	_element_cooldown_timer = ELEMENT_SWITCH_COOLDOWN
	emit_signal("element_changed", sword_element)
	print("Sword Element: ", SWORD_ELEMENT_NAME[sword_element])

# ── 5. REPLACE cycle_weapon() with this version ───────────────

func cycle_weapon() -> void:
	current_weapon = (current_weapon + 1) % 4 as Weapon
	switch_weapon_visibility()
	play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)
	emit_signal("weapon_changed", current_weapon)

# ── 6. REPLACE cycle_staff_skill() with this version ──────────

func cycle_staff_skill() -> void:
	staff_skill = (staff_skill + 1) % 2 as StaffSkill
	emit_signal("staff_skill_changed", staff_skill)
	print("Staff Skill: ", STAFF_SKILL_CAST_ANIM[staff_skill])

# ── 7. REPLACE _staff_start_casting() with this version ───────

func _staff_start_casting() -> void:
	is_attacking     = true
	is_staff_casting = true
	is_aiming        = true
	aim_direction    = last_direction
	sprite_staff.play(_get_directional_anim("Casting_Staff", last_direction))
	_spawn_effect("Staff_Cast", STAFF_SKILL_CAST_ANIM[staff_skill],
		WEAPON_EFFECT_OFFSET[Weapon.STAFF], last_direction,
		false, false)
	emit_signal("cast_started", CAST_DURATION)   # ← NEW

# ── 8. REPLACE _staff_start_shooting() with this version ──────

func _staff_start_shooting() -> void:
	is_staff_casting = false
	is_aiming        = false
	emit_signal("cast_finished")                  # ← NEW
	_spawn_effect("Staff_Shoot", STAFF_SKILL_SHOOT_ANIM[staff_skill],
		STAFF_SHOOT_OFFSET, aim_direction,
		false, true)
	var timer = get_tree().create_timer(0.65)
	timer.timeout.connect(func():
		is_attacking = false
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)
	)

# ── 9. ADD a take_damage() method (used by hitboxes) ──────────

func take_damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0:
		_on_death()

func _on_death() -> void:
	# Placeholder — add your game-over logic here
	print("Character died")
