extends Node2D

# ── Projectile velocities ─────────────────────────────────────
var _arrow_velocity: Vector2 = Vector2.ZERO
var _staff_velocity: Vector2 = Vector2.ZERO

const ARROW_SPEED: float = 500.0
const STAFF_SPEED: float = 350.0

# ── Consistent audio volume across all weapons ────────────────
const AUDIO_VOLUME_DB: float = 0.0


func _process(delta: float) -> void:
	# Arrow follows its own node position (hitbox is a child → moves with it)
	if _arrow_velocity != Vector2.ZERO:
		$Arrow_Projectile.position += _arrow_velocity * delta

	# Staff projectile moves in shoot direction (hitboxes are children → follow)
	if _staff_velocity != Vector2.ZERO:
		$Staff_Magic.position += _staff_velocity * delta


func play(effect_key: String, anim_or_element: String,
		shoot_direction: Vector2 = Vector2.ZERO) -> void:
	# Hide everything and reset rotations before playing a new effect
	for child in get_children():
		child.visible  = false
		child.rotation = 0.0

	match effect_key:
		"Sword":         _play_sword(anim_or_element)
		"Lance_Pierce":  _play_lance("Pierce")
		"Lance_Thrust":  _play_lance("Thrust")
		"Bow_Arrow_Fly": _play_bow_arrow_fly(shoot_direction)
		"Staff_Cast":    _play_staff_cast(anim_or_element)
		"Staff_Shoot":   _play_staff_shoot(anim_or_element, shoot_direction)


# ── Damage callback — called by every weapon Area2D.body_entered ──────
func _on_hit_body(hit_body: Node2D) -> void:
	if hit_body.has_method("take_damage"):
		hit_body.take_damage(1)


# ── Hitbox helper ─────────────────────────────────────────────────────
# Enables/disables an Area2D, its CollisionShape, and wires body_entered.
func _enable_hitbox(hb: Area2D, enabled: bool) -> void:
	hb.monitoring  = enabled
	hb.monitorable = enabled
	hb.get_child(0).set_deferred("disabled", not enabled)
	if enabled and not hb.body_entered.is_connected(_on_hit_body):
		hb.body_entered.connect(_on_hit_body)


# ── Sword ─────────────────────────────────────────────────────────────
# SwordHitBox lives on Character → Sword → SwordHitBox.
# Its CollisionShape2D position must be set to face last_direction so the
# hit registers in front of the player, not always below them.
func _play_sword(element: String) -> void:
	var node = $Sword_Slash
	node.visible = true
	node.play(element)
	_play_audio($Sword_Slash/AudioStreamPlayer2D)

	var hb = _get_character_hitbox("SwordHitBox")
	if hb:
		# Reposition the collision shape to sit in front of the player
		# based on the direction passed via Effect_Combat.rotation
		# (character.gd sets effect.rotation = direction.angle() for sword).
		_orient_character_hitbox(hb, rotation, 36.0)
		_enable_hitbox(hb, true)
		node.animation_finished.connect(func():
			_enable_hitbox(hb, false)
			_on_effect_finished(node)
		, CONNECT_ONE_SHOT)
	else:
		node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)


# ── Lance ─────────────────────────────────────────────────────────────
func _play_lance(mode: String) -> void:
	var node = $Lance_Poke
	node.visible = true
	node.play(mode)
	_play_audio($Lance_Poke/AudioStreamPlayer2D)

	var hb = _get_character_hitbox("LanceHitBox")
	if hb:
		# Lance reaches further — offset 56 px in attack direction
		_orient_character_hitbox(hb, rotation, 56.0)
		_enable_hitbox(hb, true)
		node.animation_finished.connect(func():
			_enable_hitbox(hb, false)
			_on_effect_finished(node)
		, CONNECT_ONE_SHOT)
	else:
		node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)


# ── Orient a character hitbox's CollisionShape2D to face attack direction ──
# attack_angle : Effect_Combat.rotation (set by character.gd via direction.angle())
# reach        : how far from character origin the shape sits (px)
func _orient_character_hitbox(hb: Area2D, attack_angle: float, reach: float) -> void:
	var shape_node = hb.get_child(0) as CollisionShape2D
	if shape_node == null:
		return
	# Convert the world-space angle back to local space relative to the
	# Character node (parent of Sword/Lance sprites).
	# hb is a child of the sprite which is a child of Character —
	# both sprites sit at Character's origin so the local angle equals
	# the world angle minus Character's own rotation (usually 0).
	var dir = Vector2.RIGHT.rotated(attack_angle)
	shape_node.position = dir * reach


# ── Character hitbox finder ───────────────────────────────────────────
func _get_character_hitbox(hitbox_name: String) -> Area2D:
	var root = get_parent()
	if root == null:
		return null
	for child in root.get_children():
		var found = _find_area_by_name(child, hitbox_name)
		if found:
			return found
	return null


func _find_area_by_name(node: Node, target: String) -> Area2D:
	if node.name == target and node is Area2D:
		return node
	for child in node.get_children():
		var result = _find_area_by_name(child, target)
		if result:
			return result
	return null


# ── Bow: Arrow Fly ────────────────────────────────────────────────────
# Arrow_Projectile is an AnimatedSprite2D.
# ArrowHitbox is its child → it moves with Arrow_Projectile automatically.
# ArrowHitbox/CollisionShape2D is at local (20, 2) which already sits at
# the arrow tip once the sprite is rotated to face direction.
func _play_bow_arrow_fly(direction: Vector2) -> void:
	var node = $Arrow_Projectile
	node.visible  = true
	node.rotation = direction.angle()   # sprite faces travel direction
	node.play("Arrow")
	_play_audio($Arrow_Projectile/AudioStreamPlayer2D)

	var hb: Area2D = $Arrow_Projectile/ArrowHitbox
	_enable_hitbox(hb, true)

	_arrow_velocity = direction.normalized() * ARROW_SPEED

	# After 2 s the arrow expires — stop everything cleanly
	get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(node):
			return
		_arrow_velocity = Vector2.ZERO
		_enable_hitbox(hb, false)
		node.visible  = false
		node.rotation = 0.0
		node.stop()
		$Arrow_Projectile/AudioStreamPlayer2D.stop()
	)


# ── Staff Phase 1: Casting ────────────────────────────────────────────
# The cast orb sits at the character's hands (no movement, no rotation).
# The character.gd animation_finished callback triggers _staff_start_shooting().
func _play_staff_cast(anim_name: String) -> void:
	var node      = $Staff_Magic
	node.visible  = true
	node.rotation = 0.0
	node.position = Vector2.ZERO   # reset any leftover position from last cast
	node.play(anim_name)
	# Stop any leftover shoot audio before playing cast audio
	var audio = $Staff_Magic/AudioStreamPlayer2D
	audio.stop()
	_play_audio(audio)


# ── Staff Phase 2: Shooting ───────────────────────────────────────────
# Staff_Magic node rotates to face shoot_dir and then travels in that
# direction. FireBallHitBox / LightningHitBox are children of Staff_Magic
# so they ride along automatically — no manual position updates needed.
func _play_staff_shoot(anim_name: String, shoot_dir: Vector2) -> void:
	var node      = $Staff_Magic
	node.visible  = true

	# Rotate sprite to face travel direction (sprite sheet points RIGHT at 0°)
	node.rotation = shoot_dir.angle() if shoot_dir != Vector2.ZERO else 0.0

	# Reset position to where Effect_Combat was spawned (character.gd already
	# placed Effect_Combat at position + direction * STAFF_SHOOT_OFFSET)
	node.position = Vector2.ZERO

	node.play(anim_name)

	# Cross-fade audio: stop cast sound → play shoot sound
	var audio = $Staff_Magic/AudioStreamPlayer2D
	audio.stop()
	_play_audio(audio)

	# Enable the matching hitbox; disable the other
	var fb_box: Area2D = $Staff_Magic/FireBallHitBox
	var lt_box: Area2D = $Staff_Magic/LightningHitBox
	match anim_name:
		"Shoot_FireBall":
			_enable_hitbox(fb_box, true)
			_enable_hitbox(lt_box, false)
		"Shoot_Lightning":
			_enable_hitbox(lt_box, true)
			_enable_hitbox(fb_box, false)

	# Start moving the projectile
	_staff_velocity = shoot_dir.normalized() * STAFF_SPEED if shoot_dir != Vector2.ZERO else Vector2.ZERO

	node.animation_finished.connect(_on_staff_shoot_finished.bind(node), CONNECT_ONE_SHOT)


# ── Audio helper ──────────────────────────────────────────────────────
# Stop any leftover playback first so the sound always fires in sync
# with the animation that just started, even if a previous instance
# of the same effect hadn't finished yet.
func _play_audio(player: AudioStreamPlayer2D) -> void:
	player.volume_db = AUDIO_VOLUME_DB
	player.stop()
	player.play()


# ── Cleanup ───────────────────────────────────────────────────────────
func _on_effect_finished(node: AnimatedSprite2D) -> void:
	node.visible  = false
	node.rotation = 0.0
	node.stop()


func _on_staff_shoot_finished(node: AnimatedSprite2D) -> void:
	_staff_velocity = Vector2.ZERO
	node.visible    = false
	node.rotation   = 0.0
	node.position   = Vector2.ZERO
	node.stop()
	_enable_hitbox($Staff_Magic/FireBallHitBox,  false)
	_enable_hitbox($Staff_Magic/LightningHitBox, false)
	$Staff_Magic/AudioStreamPlayer2D.stop()
