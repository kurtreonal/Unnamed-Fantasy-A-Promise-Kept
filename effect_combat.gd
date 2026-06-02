extends Node2D

# play(effect_key, anim_or_element, shoot_direction)
#
# shoot_direction is Vector2.ZERO for everything EXCEPT Staff_Shoot,
# where it carries the mouse aim direction so Staff_Magic can rotate
# to match the fireball travel direction (sprite default = left→right = 0°).

func play(effect_key: String, anim_or_element: String,
		shoot_direction: Vector2 = Vector2.ZERO) -> void:
	for child in get_children():
		child.visible = false
		child.rotation = 0.0  # reset rotation on every play
	
	match effect_key:
		"Sword":        _play_sword(anim_or_element)
		"Lance_Pierce": _play_lance("Pierce")
		"Lance_Thrust": _play_lance("Thrust")
		"Bow":          _play_bow(anim_or_element)
		"Staff_Cast":   _play_staff_cast(anim_or_element)
		"Staff_Shoot":  _play_staff_shoot(anim_or_element, shoot_direction)

# ── Sword ─────────────────────────────────────────────────────
func _play_sword(element: String) -> void:
	var node = $Sword_Slash
	node.visible = true
	node.play(element)  # "Fire" | "Lightning" | "Water"
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

# ── Lance ─────────────────────────────────────────────────────
func _play_lance(mode: String) -> void:
	var node = $Lance_Poke
	node.visible = true
	node.play(mode)     # "Pierce" | "Thrust"
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

# ── Bow ───────────────────────────────────────────────────────
func _play_bow(element: String) -> void:
	var node = $Bow_Arrow
	node.visible = true
	if node.sprite_frames and node.sprite_frames.has_animation(element):
		node.play(element)
	elif node.sprite_frames and node.sprite_frames.has_animation("default"):
		node.play("default")
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

# ── Staff Phase 1: Casting ────────────────────────────────────
# Cast orb appears at the hands — stays upright (no rotation).
# No animation_finished here; the CHARACTER sprite's finished signal
# triggers the shoot phase in character.gd.
func _play_staff_cast(anim_name: String) -> void:
	var node = $Staff_Magic
	node.visible  = true
	node.rotation = 0.0
	node.play(anim_name)  # "Casting_FireBall" | "Casting_Lightning"

# ── Staff Phase 2: Shooting ───────────────────────────────────
# The Shoot_FireBall sprite travels left→right by default (0°).
# We rotate Staff_Magic so the fireball travels toward shoot_direction.
#
# How the rotation works:
#   Vector2.RIGHT.angle() == 0°   → sprite already points right → no rotation needed
#   shoot_direction.angle()       → angle of the aim vector in world space
#   Staff_Magic.rotation = that angle → sprite rotates to match
#
# Examples:
#   aim right  →  angle = 0°    → no rotation  → fireball goes right  ✓
#   aim left   →  angle = 180°  → flips sprite  → fireball goes left   ✓
#   aim up     →  angle = -90°  → rotates up    → fireball goes up     ✓
#   aim down   →  angle =  90°  → rotates down  → fireball goes down   ✓
func _play_staff_shoot(anim_name: String, shoot_dir: Vector2) -> void:
	var node = $Staff_Magic
	node.visible = true
	# Rotate the sprite to match the aim direction
	if shoot_dir != Vector2.ZERO:
		node.rotation = shoot_dir.angle()
	else:
		node.rotation = 0.0
	node.play(anim_name)  # "Shoot_FireBall" | "Shoot_Lightning"
	node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)
	
# ── Cleanup ───────────────────────────────────────────────────
func _on_effect_finished(node: AnimatedSprite2D) -> void:
	node.visible  = false
	node.rotation = 0.0
	node.stop()
