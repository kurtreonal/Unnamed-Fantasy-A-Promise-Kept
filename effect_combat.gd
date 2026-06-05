extends Node2D

# play(effect_key, anim_or_element, shoot_direction)
#
# shoot_direction is Vector2.ZERO for everything EXCEPT Staff_Shoot and
# Bow_Arrow_Fly, where it carries the aim direction so the projectile
# can travel and rotate correctly.

# ── Arrow movement ────────────────────────────────────────────
var _arrow_velocity: Vector2 = Vector2.ZERO
const ARROW_SPEED: float = 500.0  # pixels per second — tweak to taste

func _process(delta: float) -> void:
	if _arrow_velocity != Vector2.ZERO:
		$Arrow_Projectile.position += _arrow_velocity * delta

func play(effect_key: String, anim_or_element: String,
		shoot_direction: Vector2 = Vector2.ZERO) -> void:
	for child in get_children():
		child.visible = false
		child.rotation = 0.0  # reset rotation on every play

	match effect_key:
		"Sword":         _play_sword(anim_or_element)
		"Lance_Pierce":  _play_lance("Pierce")
		"Lance_Thrust":  _play_lance("Thrust")
		"Bow_Arrow_Fly": _play_bow_arrow_fly(shoot_direction)  # direction forwarded
		"Staff_Cast":    _play_staff_cast(anim_or_element)
		"Staff_Shoot":   _play_staff_shoot(anim_or_element, shoot_direction)

# ── Sword ─────────────────────────────────────────────────────
func _play_sword(element: String) -> void:
	var node = $Sword_Slash
	node.visible = true
	node.play(element)  # "Fire" | "Lightning" | "Water"
	$Sword_Slash/AudioStreamPlayer2D.play()
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

# ── Lance ─────────────────────────────────────────────────────
func _play_lance(mode: String) -> void:
	var node = $Lance_Poke
	node.visible = true
	node.play(mode)     # "Pierce" | "Thrust"
	$Lance_Poke/AudioStreamPlayer2D.play()
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

# ── Bow: Arrow Fly ────────────────────────────────────────────
# Effect_Combat parent is NOT rotated (apply_rotation=false in character.gd).
# Keeping the parent at rotation=0 means Arrow_Projectile.position moves in
# world space, so velocity is always correct regardless of facing direction.
# We rotate the Arrow_Projectile CHILD sprite here to face aim_direction.
func _play_bow_arrow_fly(direction: Vector2) -> void:
	var node = $Arrow_Projectile
	node.visible = true
	# Rotate the arrow SPRITE to face the travel direction.
	# The sprite sheet points RIGHT (0°) by default, so rotation=direction.angle()
	# is all that is needed — no parent rotation to fight against.
	node.rotation = direction.angle()
	node.play("Arrow")
	$Arrow_Projectile/AudioStreamPlayer2D.play()
	# Velocity is in world space (parent unrotated), so this is always correct.
	_arrow_velocity = direction.normalized() * ARROW_SPEED
	# Timer cleans up sprite, sound, and velocity after 2s
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(node):
			node.visible = false
			node.stop()
			node.rotation = 0.0
			_arrow_velocity = Vector2.ZERO
			$Arrow_Projectile/AudioStreamPlayer2D.stop()
	)

# ── Staff Phase 1: Casting ────────────────────────────────────
# Cast orb appears at the hands — stays upright (no rotation).
# No animation_finished here; the CHARACTER sprite's finished signal
# triggers the shoot phase in character.gd.
func _play_staff_cast(anim_name: String) -> void:
	var node = $Staff_Magic
	node.visible  = true
	node.rotation = 0.0
	node.play(anim_name)  # "Casting_FireBall" | "Casting_Lightning"
	$Staff_Magic/AudioStreamPlayer2D.play()

# ── Staff Phase 2: Shooting ───────────────────────────────────
func _play_staff_shoot(anim_name: String, shoot_dir: Vector2) -> void:
	var node = $Staff_Magic
	node.visible = true
	if shoot_dir != Vector2.ZERO:
		node.rotation = shoot_dir.angle()
	else:
		node.rotation = 0.0
	node.play(anim_name)  # "Shoot_FireBall" | "Shoot_Lightning"
	# Stop cast sound before starting shoot sound to avoid double-audio
	$Staff_Magic/AudioStreamPlayer2D.stop()
	$Staff_Magic/AudioStreamPlayer2D.play()

	# Enable only the hitbox matching the current skill; disable the other
	var fb_box = $Staff_Magic/FireBallHitBox
	var lt_box = $Staff_Magic/LightningHitBox
	if anim_name == "Shoot_FireBall":
		fb_box.monitoring            = true
		fb_box.monitorable           = true
		fb_box.get_child(0).disabled = false
		lt_box.monitoring            = false
		lt_box.monitorable           = false
		lt_box.get_child(0).disabled = true
	elif anim_name == "Shoot_Lightning":
		lt_box.monitoring            = true
		lt_box.monitorable           = true
		lt_box.get_child(0).disabled = false
		fb_box.monitoring            = false
		fb_box.monitorable           = false
		fb_box.get_child(0).disabled = true

	node.animation_finished.connect(_on_staff_shoot_finished.bind(node), CONNECT_ONE_SHOT)

# ── Cleanup ───────────────────────────────────────────────────
func _on_effect_finished(node: AnimatedSprite2D) -> void:
	node.visible  = false
	node.rotation = 0.0
	node.stop()

# ── Staff Shoot Cleanup — also disables both hitboxes ─────────
func _on_staff_shoot_finished(node: AnimatedSprite2D) -> void:
	node.visible  = false
	node.rotation = 0.0
	node.stop()
	for hb in [$Staff_Magic/FireBallHitBox, $Staff_Magic/LightningHitBox]:
		hb.monitoring            = false
		hb.monitorable           = false
		hb.get_child(0).disabled = true
