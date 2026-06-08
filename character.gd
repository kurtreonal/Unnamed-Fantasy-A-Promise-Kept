extends CharacterBody2D

const speed = 200
var last_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var is_aiming: bool = false
const SlashEffect = preload("res://effect_combat.tscn")

# ── Aiming ────────────────────────────────────────────────────
# Bow: only fire if mouse aim is within 35° of last_direction (facing)
const AIM_CONE_DEGREES: float = 35.0

# ── Weapon System ────────────────────────────────────────────
enum Weapon { SWORD, LANCE, BOW, STAFF }
var current_weapon: Weapon = Weapon.SWORD

const WEAPON_WALK_PREFIX = {
	Weapon.SWORD: "Walk_Sword",
	Weapon.LANCE: "Walk_Spear",
	Weapon.BOW:   "Walk_Bow",
	Weapon.STAFF: "Walk_Staff",
}
const WEAPON_IDLE_PREFIX = {
	Weapon.SWORD: "Idle_Sword",
	Weapon.LANCE: "Idle_Spear",
	Weapon.BOW:   "Idle_Bow",
	Weapon.STAFF: "Idle_Staff"
}
const WEAPON_ATTACK_PREFIX = {
	Weapon.SWORD: "Slash_Sword",
	Weapon.LANCE: "Poke_Spear",
	Weapon.BOW:   "Aim_Bow",
	Weapon.STAFF: "Casting_Staff"
}
const WEAPON_EFFECT_OFFSET = {
	Weapon.SWORD: 15.0,
	Weapon.LANCE: 100.0,
	Weapon.BOW:   50.0,
	Weapon.STAFF: 10.0,
}

# Staff shoot spawns far ahead in the aimed direction
const STAFF_SHOOT_OFFSET: float = 150.0
const BOW_ARROW_OFFSET:   float = 50.0

# ── Sword Element System ──────────────────────────────────────
enum SwordElement { FIRE, LIGHTNING, WATER }
var sword_element: SwordElement = SwordElement.FIRE

const SWORD_ELEMENT_NAME = {
	SwordElement.FIRE:      "Fire",
	SwordElement.LIGHTNING: "Lightning",
	SwordElement.WATER:     "Water",
}

# ── Staff Skill System ────────────────────────────────────────
enum StaffSkill { FIREBALL, LIGHTNING }
var staff_skill: StaffSkill = StaffSkill.FIREBALL

const STAFF_SKILL_CAST_ANIM = {
	StaffSkill.FIREBALL:  "Casting_FireBall",
	StaffSkill.LIGHTNING: "Casting_Lightning",
}
const STAFF_SKILL_SHOOT_ANIM = {
	StaffSkill.FIREBALL:  "Shoot_FireBall",
	StaffSkill.LIGHTNING: "Shoot_Lightning",
}

# ── Staff State ───────────────────────────────────────────────
var is_staff_casting: bool = false

# ── Recall / Input Lock ────────────────────────────────────────
var _input_locked: bool = false

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity          = Vector2.ZERO
		is_attacking      = false
		is_aiming         = false
		is_staff_casting  = false
		lance_button_held = false
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

# ── Lance State ───────────────────────────────────────────────
const LANCE_HOLD_THRESHOLD: float = 0.25
var lance_hold_timer: float = 0.0
var lance_button_held: bool = false

# ── Sprite References ────────────────────────────────────────
@onready var sprite_sword = $Sword
@onready var sprite_lance = $Lance
@onready var sprite_bow   = $Bow
@onready var sprite_staff = $Staff

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

# ── R key — toggles Staff skill only, blocked during attack ──
func _input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not is_attacking:
			cycle_staff_skill()
			get_viewport().set_input_as_handled()

# ── Physics ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# ── MOUSE AIM: updates aim_direction from mouse while aiming ──
	# Both Bow and Staff use this during their aim/cast phase.
	# aim_direction = vector from character toward the mouse cursor.
	if is_aiming:
		var mouse_pos = get_global_mouse_position()
		var to_mouse  = mouse_pos - global_position
		if to_mouse.length() > 5.0:  # ignore micro-movements near character
			aim_direction = to_mouse.normalized()

	if Input.is_action_just_pressed("Switch_Element"):
		cycle_sword_element()
	if Input.is_action_just_pressed("Switch_Weapon"):
		cycle_weapon()

	match current_weapon:
		Weapon.SWORD:  _handle_sword_input()
		Weapon.LANCE:  _handle_lance_input(delta)
		Weapon.BOW:    _handle_bow_input()
		Weapon.STAFF:  _handle_staff_input()

	if is_attacking:
		velocity = Vector2.ZERO
		return

	process_movement()
	move_and_slide()

# ── Input Handlers per Weapon ────────────────────────────────

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

# ── Attack: Sword ─────────────────────────────────────────────
func _attack_sword() -> void:
	is_attacking = true
	sprite_sword.play(_get_directional_anim("Slash_Sword", last_direction))
	_spawn_effect("Sword", SWORD_ELEMENT_NAME[sword_element],
		WEAPON_EFFECT_OFFSET[Weapon.SWORD], last_direction,
		true,   # rotate effect to face direction
		false)  # not a staff shoot

# ── Attack: Bow — mouse-aimed ─────────────────────────────────
# Draw animation plays in last_direction. When it finishes,
# we check if aim_direction (mouse) is within the 35° cone
# of last_direction before spawning the arrow.
func _attack_bow() -> void:
	is_attacking  = true
	is_aiming     = true
	aim_direction = last_direction  # start aim at current facing
	sprite_bow.play(_get_directional_anim("Aim_Bow", last_direction))
	# Play the bow draw sound in sync with the aim animation start.
	# The node lives on $Bow in character.tscn (Long Bow Draw Sound Effect.mp3).
	var draw_audio = sprite_bow.get_node("AudioStreamPlayer2D")
	draw_audio.stop()
	draw_audio.play()

# ── Attack: Lance ─────────────────────────────────────────────
func _attack_lance(mode: String) -> void:
	is_attacking = true
	sprite_lance.play(_get_directional_anim("Poke_Spear", last_direction))
	_spawn_effect("Lance_" + mode, SWORD_ELEMENT_NAME[sword_element],
		WEAPON_EFFECT_OFFSET[Weapon.LANCE], last_direction,
		true, false)

# ── Attack: Staff Phase 1 — Casting (mouse-aimed) ────────────
# Casting animation plays. Mouse controls where the projectile
# will go. When the cast anim finishes, shoot fires in aim_direction.
func _staff_start_casting() -> void:
	is_attacking     = true
	is_staff_casting = true
	is_aiming        = true
	aim_direction    = last_direction  # default aim, mouse overrides per-frame
	sprite_staff.play(_get_directional_anim("Casting_Staff", last_direction))
	# Cast orb at hands — no directional rotation, stays upright
	_spawn_effect("Staff_Cast", STAFF_SKILL_CAST_ANIM[staff_skill],
		WEAPON_EFFECT_OFFSET[Weapon.STAFF], last_direction,
		false, false)

# ── Attack: Staff Phase 2 — Shooting (fires in aim_direction) ─
# Projectile spawns STAFF_SHOOT_OFFSET pixels away from character
# in the direction the mouse was pointing at cast-end.
# The Staff_Magic sprite is ROTATED to match the fireball travel direction
# because the sprite sheet points left→right (0°) by default.
func _staff_start_shooting() -> void:
	is_staff_casting = false
	is_aiming        = false
	_spawn_effect("Staff_Shoot", STAFF_SKILL_SHOOT_ANIM[staff_skill],
		STAFF_SHOOT_OFFSET, aim_direction,
		false,   # don't use generic rotation — staff_shoot handles its own
		true)    # IS a staff shoot → rotate the Staff_Magic node
	var timer = get_tree().create_timer(0.65)
	timer.timeout.connect(func():
		is_attacking = false
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)
	)

# ── Effect Spawning ───────────────────────────────────────────
# effect_key      : routing key for Effect_Combat
# element         : animation name or element string
# offset_dist     : px from character center to spawn
# direction       : spawn offset direction
# apply_rotation  : rotate the Effect_Combat node itself
# is_staff_shoot  : if true, rotate Staff_Magic child node instead
func _spawn_effect(effect_key: String, element: String,
		offset_dist: float, direction: Vector2,
		apply_rotation: bool, is_staff_shoot: bool) -> void:
	var effect = SlashEffect.instantiate()
	effect.position = position + direction.normalized() * offset_dist

	if apply_rotation:
		effect.rotation = direction.angle()
	else:
		effect.rotation = 0.0

	# add_child FIRST so AudioStreamPlayer2D nodes are in the scene tree
	# before effect.play() calls .play() on them — otherwise sound is silent
	get_parent().add_child(effect)
	effect.z_index = 10          # always render above characters and terrain
	effect.z_as_relative = false # absolute z, not relative to parent
	# Pass aim_direction to effect so Staff_Magic can self-rotate
	effect.play(effect_key, element, direction if is_staff_shoot else Vector2.ZERO)
	_auto_free_effect(effect)

func _auto_free_effect(effect: Node2D) -> void:
	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)

# ── Direction Helper ──────────────────────────────────────────
func _get_directional_anim(prefix: String, dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return prefix + ("_Right" if dir.x > 0 else "_Left")
	else:
		return prefix + ("_Up" if dir.y < 0 else "_Down")

# ── Aim Validation ─────────────────────────────────────────────
# Returns true if aim_dir is within AIM_CONE_DEGREES of forward_dir.
func _is_aim_valid(aim_dir: Vector2, forward_dir: Vector2) -> bool:
	if aim_dir == Vector2.ZERO or forward_dir == Vector2.ZERO:
		return false
	return abs(rad_to_deg(aim_dir.angle_to(forward_dir))) <= AIM_CONE_DEGREES
#comment
# ── Movement ─────────────────────────────────────────────────
func process_movement() -> void:
	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	if direction != Vector2.ZERO:
		velocity       = direction * speed
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
	var sprite    = get_active_sprite()
	sprite.flip_h = false
	var anim_name = _get_directional_anim(prefix, dir)
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)

# ── Animation Finished ────────────────────────────────────────
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
	# Draw phase is over — stop the draw sound regardless of whether the
	# shot is valid. Arrow_pierce.mp3 takes over in effect_combat.gd.
	sprite_bow.get_node("AudioStreamPlayer2D").stop()
	# ── Facing cone check: only fire if mouse aim is within AIM_CONE_DEGREES
	# of the direction the character is facing. Prevents shooting
	# backwards or sideways relative to the bow draw animation.
	if _is_aim_valid(aim_direction, last_direction):
		# apply_rotation=False — do NOT rotate the Effect_Combat parent node.
		# Rotating the parent causes Arrow_Projectile.position to move in local
		# (rotated) space, making the arrow travel backwards for LEFT/UP/DOWN.
		# The arrow sprite and velocity are both handled inside effect_combat.gd.
		_spawn_effect("Bow_Arrow_Fly", SWORD_ELEMENT_NAME[sword_element],
			BOW_ARROW_OFFSET, aim_direction,
			false, true)
	# else: aim was outside the cone — arrow is cancelled silently
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
		play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

# ── Cycling ───────────────────────────────────────────────────
func cycle_weapon() -> void:
	current_weapon = (current_weapon + 1) % 4 as Weapon
	switch_weapon_visibility()
	play_animation(WEAPON_IDLE_PREFIX[current_weapon], last_direction)

func cycle_sword_element() -> void:
	sword_element = (sword_element + 1) % 3 as SwordElement
	print("Sword Element: ", SWORD_ELEMENT_NAME[sword_element])

func cycle_staff_skill() -> void:
	staff_skill = (staff_skill + 1) % 2 as StaffSkill
	print("Staff Skill: ", STAFF_SKILL_CAST_ANIM[staff_skill])

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
