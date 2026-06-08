# ─────────────────────────────────────────────────────────────────
# CharacterBody2D — weapons, movement, animation, and combat effects.
#
# KEY BINDINGS (owned here):
#   WASD / Arrow keys  — movement          (Input Map: Up/Down/Left/Right)
#   Left Mouse Button  — attack            (Input Map: Sword_Attack)
#   Q key              — cycle sword element
#   E key              — cycle weapon      (with cooldown gated by hud.gd)
#   R key              — cycle staff skill (with cooldown gated by hud.gd)
#
# NOTE: E and R calls are forwarded to hud.gd which owns the cooldown
# logic. hud.gd then calls cycle_weapon() / cycle_staff_skill() back
# on this node and listens to the signals below to stay in sync.
#
# SIGNALS emitted for the HUD:
#   weapon_changed(weapon: int)
#   staff_skill_changed(skill: int)
#   element_changed(element: int)
#   element_cooldown_tick(remaining: float, total: float)
#   cast_started(duration: float)
#   cast_finished()
#   hp_changed(current: int, maximum: int)
# ─────────────────────────────────────────────────────────────────
extends CharacterBody2D

# ── Signals ───────────────────────────────────────────────────
signal weapon_changed(weapon: int)
signal staff_skill_changed(skill: int)
signal element_changed(element: int)
signal element_cooldown_tick(remaining: float, total: float)
signal cast_started(duration: float)
signal cast_finished()
signal hp_changed(current: int, maximum: int)

# ── Core stats ────────────────────────────────────────────────
const SPEED           : float = 200.0
var   hp              : int   = 100
var   max_hp          : int   = 100

## Invincibility window after taking damage (seconds).
const INVINCIBILITY_DURATION : float = 0.8
var   _invincible            : bool  = false
var   _is_dead               : bool  = false

var last_direction : Vector2 = Vector2.RIGHT
var aim_direction  : Vector2 = Vector2.RIGHT
var is_attacking   : bool    = false
var is_aiming      : bool    = false

const SlashEffect = preload("res://effect_combat.tscn")

# ── Aiming ────────────────────────────────────────────────────
# Bow: only fire if mouse aim is within 35° of last_direction (facing).
const AIM_CONE_DEGREES : float = 35.0

# ── Weapon System ─────────────────────────────────────────────
enum Weapon { SWORD, LANCE, BOW, STAFF }
var current_weapon : Weapon = Weapon.SWORD

const WEAPON_WALK_PREFIX := {
	Weapon.SWORD: "Walk_Sword",
	Weapon.LANCE: "Walk_Spear",
	Weapon.BOW:   "Walk_Bow",
	Weapon.STAFF: "Walk_Staff",
}
const WEAPON_IDLE_PREFIX := {
	Weapon.SWORD: "Idle_Sword",
	Weapon.LANCE: "Idle_Spear",
	Weapon.BOW:   "Idle_Bow",
	Weapon.STAFF: "Idle_Staff",
}
const WEAPON_ATTACK_PREFIX := {
	Weapon.SWORD: "Slash_Sword",
	Weapon.LANCE: "Poke_Spear",
	Weapon.BOW:   "Aim_Bow",
	Weapon.STAFF: "Casting_Staff",
}

# ── Effect spawn distances ─────────────────────────────────────
const WEAPON_EFFECT_OFFSET := {
	Weapon.SWORD: 18.0,
	Weapon.LANCE: 90.0,
	Weapon.BOW:   48.0,
	Weapon.STAFF: 10.0,
}

const STAFF_SHOOT_OFFSET : float = 110.0
const BOW_ARROW_OFFSET   : float = 48.0

# ── Element System ────────────────────────────────────────────
enum SwordElement { FIRE, LIGHTNING, WATER }
var sword_element : SwordElement = SwordElement.FIRE

const SWORD_ELEMENT_NAME := {
	SwordElement.FIRE:      "Fire",
	SwordElement.LIGHTNING: "Lightning",
	SwordElement.WATER:     "Water",
}

# ── Staff Skill System ────────────────────────────────────────
enum StaffSkill { FIREBALL, LIGHTNING }
var staff_skill : StaffSkill = StaffSkill.FIREBALL

const STAFF_SKILL_CAST_ANIM := {
	StaffSkill.FIREBALL:  "Casting_FireBall",
	StaffSkill.LIGHTNING: "Casting_Lightning",
}
const STAFF_SKILL_SHOOT_ANIM := {
	StaffSkill.FIREBALL:  "Shoot_FireBall",
	StaffSkill.LIGHTNING: "Shoot_Lightning",
}

# ── Staff State ───────────────────────────────────────────────
var is_staff_casting : bool = false

# ── Lance State ───────────────────────────────────────────────
const LANCE_HOLD_THRESHOLD : float = 0.25
var lance_hold_timer  : float = 0.0
var lance_button_held : bool  = false

# ── HUD reference (set by world scene or auto-found) ──────────
# hud.gd owns the E / R cooldown gates; we forward those key presses
# to it so the cooldown logic stays in one place.
var _hud : CanvasLayer = null

# ── Sprite References ─────────────────────────────────────────
@onready var sprite_sword  : AnimatedSprite2D = $Sword
@onready var sprite_lance  : AnimatedSprite2D = $Lance
@onready var sprite_bow    : AnimatedSprite2D = $Bow
@onready var sprite_staff  : AnimatedSprite2D = $Staff
@onready var sprite_death  : AnimatedSprite2D = $DeathAnimation

# Weapon hitbox Area2Ds — used to detect enemies during attacks.
# Collision layer 3 = player weapons; enemy collision_layer = 2.
@onready var _sword_hitbox : Area2D = $Sword/SwordHitBox
@onready var _lance_hitbox : Area2D = $Lance/LanceHitBox

func get_active_sprite() -> AnimatedSprite2D:
	match current_weapon:
		Weapon.SWORD: return sprite_sword
		Weapon.LANCE: return sprite_lance
		Weapon.BOW:   return sprite_bow
		Weapon.STAFF: return sprite_staff
	return sprite_sword

func switch_weapon_visibility() -> void:
	sprite_sword.visible = current_weapon == Weapon.SWORD
	sprite_lance.visible = current_weapon == Weapon.LANCE
	sprite_bow.visible   = current_weapon == Weapon.BOW
	sprite_staff.visible = current_weapon == Weapon.STAFF

# ── Ready ─────────────────────────────────────────────────────
# ── Ready ─────────────────────────────────────────────────────
func _ready() -> void:
	# Player body is on layer 1. Weapon hitboxes use layer 3 so they
	# can scan for enemies (layer 2) without ever overlapping the player body.
	collision_layer = 1
	collision_mask  = 1   # collide with world tiles

	_setup_hitbox(_sword_hitbox)
	_setup_hitbox(_lance_hitbox)

	# Deferred so all nodes finish _ready() before we search the group.
	call_deferred("_find_hud")

func _setup_hitbox(area: Area2D) -> void:
	# Layer 3 = player weapons.  Mask 2 = enemy bodies.
	# This means the hitbox ONLY detects enemies, never the player itself.
	# effect_combat.gd connects its own body_entered callbacks when it arms
	# the hitbox, so we do NOT connect anything here.
	area.collision_layer = 3
	area.collision_mask  = 2
	area.monitoring      = false
	area.monitorable     = false

func _find_hud() -> void:
	_hud = get_tree().get_first_node_in_group("hud")

## Can also be set explicitly by the world scene if needed.
func set_hud(hud: CanvasLayer) -> void:
	_hud = hud

# ── Input ─────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		# Q — cycle sword element (no cooldown, owned here)
		KEY_Q:
			if not is_attacking:
				cycle_sword_element()
				get_viewport().set_input_as_handled()

		# E — cycle weapon; HUD owns the cooldown gate
		KEY_E:
			if _hud != null:
				_hud.request_cycle_weapon()
			elif not is_attacking:
				cycle_weapon()
			get_viewport().set_input_as_handled()

		# R — cycle staff skill; HUD owns the cooldown gate
		KEY_R:
			if _hud != null:
				_hud.request_cycle_skill()
			elif not is_attacking:
				cycle_staff_skill()
			get_viewport().set_input_as_handled()

# ── Physics ───────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Update mouse aim while aiming (Bow draw or Staff cast)
	if is_aiming:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 5.0:
			aim_direction = to_mouse.normalized()

	# Switch_Element action (can be gamepad / remap)
	if Input.is_action_just_pressed("Switch_Element"):
		cycle_sword_element()

	# Dispatch per-weapon attack input
	match current_weapon:
		Weapon.SWORD: _handle_sword_input()
		Weapon.LANCE: _handle_lance_input(delta)
		Weapon.BOW:   _handle_bow_input()
		Weapon.STAFF: _handle_staff_input()

	if is_attacking:
		velocity = Vector2.ZERO
		return

	process_movement()
	move_and_slide()

# ── Per-weapon input handlers ─────────────────────────────────
func _handle_sword_input() -> void:
	if Input.is_action_just_pressed("Sword_Attack") and not is_attacking:
		_attack_sword()

func _handle_bow_input() -> void:
	if Input.is_action_just_pressed("Sword_Attack") and not is_attacking:
		_attack_bow()

func _handle_lance_input(delta: float) -> void:
	if is_attacking:
		lance_button_held = false
		lance_hold_timer  = 0.0
		return
	if Input.is_action_just_pressed("Sword_Attack"):
		lance_button_held = true
		lance_hold_timer  = 0.0
	if lance_button_held:
		if Input.is_action_pressed("Sword_Attack"):
			lance_hold_timer += delta
		else:
			lance_button_held = false
			if lance_hold_timer >= LANCE_HOLD_THRESHOLD:
				_attack_lance("Thrust")
			else:
				_attack_lance("Pierce")
			lance_hold_timer = 0.0

func _handle_staff_input() -> void:
	if Input.is_action_just_pressed("Sword_Attack") and not is_attacking:
		_staff_start_casting()

# ── Attacks ───────────────────────────────────────────────────
func _attack_sword() -> void:
	is_attacking = true
	sprite_sword.play(_get_directional_anim("Slash_Sword", last_direction))
	_spawn_effect("Sword", SWORD_ELEMENT_NAME[sword_element],
		WEAPON_EFFECT_OFFSET[Weapon.SWORD], last_direction, true, false)

func _attack_bow() -> void:
	is_attacking  = true
	is_aiming     = true
	aim_direction = last_direction
	sprite_bow.play(_get_directional_anim("Aim_Bow", last_direction))
	var draw_audio := sprite_bow.get_node("AudioStreamPlayer2D")
	draw_audio.stop()
	draw_audio.play()

func _attack_lance(mode: String) -> void:
	is_attacking = true
	sprite_lance.play(_get_directional_anim("Poke_Spear", last_direction))
	_spawn_effect("Lance_" + mode, SWORD_ELEMENT_NAME[sword_element],
		WEAPON_EFFECT_OFFSET[Weapon.LANCE], last_direction, true, false)

func _staff_start_casting() -> void:
	is_attacking     = true
	is_staff_casting = true
	is_aiming        = true
	aim_direction    = last_direction
	sprite_staff.play(_get_directional_anim("Casting_Staff", last_direction))
	_spawn_effect("Staff_Cast", STAFF_SKILL_CAST_ANIM[staff_skill],
		WEAPON_EFFECT_OFFSET[Weapon.STAFF], last_direction, false, false)
	cast_started.emit(0.65)

func _staff_start_shooting() -> void:
	is_staff_casting = false
	is_aiming        = false
	_spawn_effect("Staff_Shoot", STAFF_SKILL_SHOOT_ANIM[staff_skill],
		STAFF_SHOOT_OFFSET, aim_direction, false, true)
	get_tree().create_timer(0.65).timeout.connect(func():
		is_attacking = false
		cast_finished.emit()
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)
	)

# ── Effect spawning ───────────────────────────────────────────
func _spawn_effect(effect_key: String, element: String,
		offset_dist: float, direction: Vector2,
		apply_rotation: bool, is_staff_shoot: bool) -> void:
	var effect := SlashEffect.instantiate()
	effect.position = position + direction.normalized() * offset_dist
	effect.rotation = direction.angle() if apply_rotation else 0.0
	get_parent().add_child(effect)
	effect.z_index      = 10
	effect.z_as_relative = false
	effect.play(effect_key, element,
		direction if is_staff_shoot else Vector2.ZERO)
	_auto_free_effect(effect)

func _auto_free_effect(effect: Node2D) -> void:
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)

# ── Direction helpers ─────────────────────────────────────────
func _get_directional_anim(prefix: String, dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return prefix + ("_Right" if dir.x > 0 else "_Left")
	else:
		return prefix + ("_Up" if dir.y < 0 else "_Down")

func _is_aim_valid(aim_dir: Vector2, forward_dir: Vector2) -> bool:
	if aim_dir == Vector2.ZERO or forward_dir == Vector2.ZERO:
		return false
	return abs(rad_to_deg(aim_dir.angle_to(forward_dir))) <= AIM_CONE_DEGREES

# ── Movement ──────────────────────────────────────────────────
func process_movement() -> void:
	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	if direction != Vector2.ZERO:
		velocity       = direction * SPEED
		last_direction = direction
	else:
		velocity = Vector2.ZERO
	process_animation(last_direction)

func process_animation(dir: Vector2) -> void:
	if is_attacking:
		return
	if velocity != Vector2.ZERO:
		play_animation(WEAPON_WALK_PREFIX[current_weapon], dir)
	else:
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], dir)

func play_animation(prefix: String, dir: Vector2) -> void:
	var sprite   := get_active_sprite()
	sprite.flip_h = false
	var anim_name := _get_directional_anim(prefix, dir)
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)

# ── Animation finished callbacks ──────────────────────────────
func _on_sword_animation_finished() -> void:
	if is_attacking and current_weapon == Weapon.SWORD:
		is_attacking = false
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

func _on_lance_animation_finished() -> void:
	if is_attacking and current_weapon == Weapon.LANCE:
		is_attacking = false
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

func _on_bow_animation_finished() -> void:
	if not is_attacking or current_weapon != Weapon.BOW:
		return
	is_aiming = false
	sprite_bow.get_node("AudioStreamPlayer2D").stop()
	if _is_aim_valid(aim_direction, last_direction):
		_spawn_effect("Bow_Arrow_Fly", SWORD_ELEMENT_NAME[sword_element],
			BOW_ARROW_OFFSET, aim_direction, false, true)
	is_attacking = false
	play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

func _on_staff_animation_finished() -> void:
	if current_weapon != Weapon.STAFF:
		return
	if is_staff_casting:
		_staff_start_shooting()
	elif is_attacking:
		is_aiming    = false
		is_attacking = false
		cast_finished.emit()
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

# ── Cycling (called by hud.gd via cooldown gate) ──────────────
func cycle_weapon() -> void:
	current_weapon = (current_weapon + 1) % 4 as Weapon
	switch_weapon_visibility()
	play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)
	weapon_changed.emit(current_weapon)

func cycle_sword_element() -> void:
	sword_element = (sword_element + 1) % 3 as SwordElement
	element_changed.emit(sword_element)
	print("Sword Element: ", SWORD_ELEMENT_NAME[sword_element])

func cycle_staff_skill() -> void:
	staff_skill = (staff_skill + 1) % 2 as StaffSkill
	staff_skill_changed.emit(staff_skill)
	print("Staff Skill: ", STAFF_SKILL_CAST_ANIM[staff_skill])

# ── Damage ────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _invincible or _is_dead:
		return
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		_die()
		return

	# Start invincibility window so one touch doesn't chain-drain HP.
	_invincible = true
	get_tree().create_timer(INVINCIBILITY_DURATION).timeout.connect(
		func(): _invincible = false
	)

	# Visual hit flash: blink the active sprite red a few times.
	_flash_hit()

# ── Death ─────────────────────────────────────────────────────
## Maps each weapon to its animation name on the DeathAnimation sprite.
const WEAPON_DEATH_ANIM := {
	Weapon.SWORD: "Death_Sword",
	Weapon.LANCE: "Death_Lance",
	Weapon.BOW:   "Death_Bow",
	Weapon.STAFF: "Death_Staff",
}

func _die() -> void:
	_is_dead     = true
	_invincible  = true   # no further damage callbacks
	is_attacking = false
	velocity     = Vector2.ZERO
	set_physics_process(false)

	# Disarm weapon hitboxes.
	_sword_hitbox.monitoring = false
	_lance_hitbox.monitoring = false

	# Hide all weapon sprites; show and play the death sprite.
	sprite_sword.visible = false
	sprite_lance.visible = false
	sprite_bow.visible   = false
	sprite_staff.visible = false

	sprite_death.visible = true
	sprite_death.play(WEAPON_DEATH_ANIM[current_weapon])
	sprite_death.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)

func _flash_hit() -> void:
	## Blink the active sprite red during the invincibility window.
	var sprite := get_active_sprite()
	var blinks  : int   = 4
	var interval: float = INVINCIBILITY_DURATION / (blinks * 2.0)
	for i in range(blinks * 2):
		await get_tree().create_timer(interval).timeout
		if not is_instance_valid(self):
			return
		sprite.modulate = Color(1.5, 0.2, 0.2) if i % 2 == 0 else Color.WHITE
	sprite.modulate = Color.WHITE

func _on_death_animation_finished() -> void:
	## Called when the death animation ends.
	## Add your game-over / respawn logic here (e.g. reload scene, show screen).
	# Example: get_tree().reload_current_scene()
	queue_free()

func get_element_damage() -> float:
	match sword_element:
		SwordElement.FIRE:      return 15.0
		SwordElement.LIGHTNING: return 20.0
		SwordElement.WATER:     return 25.0
	return 10.0

func get_staff_damage() -> float:
	match staff_skill:
		StaffSkill.FIREBALL:  return 20.0
		StaffSkill.LIGHTNING: return 25.0
	return 15.0
