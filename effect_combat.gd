# effect_combat.gd
# ─────────────────────────────────────────────────────────────────
# Node2D — spawned by character.gd for every weapon attack / skill cast.
# Handles animation playback, projectile movement, hitbox toggling,
# and audio so character.gd stays clean.
#
# BALANCE NOTES (tuned alongside character.gd WEAPON_EFFECT_OFFSET):
#   • Audio volume unified at AUDIO_VOLUME_DB (-3 dB) — loud but not
#     ear-splitting on a typical 2D mix.
#   • Arrow speed slightly reduced to match the visible sprite travel.
#   • Staff speed unchanged — fireball "feels" snappy at 350 px/s.
#   • Auto-free timer (in character.gd) set to 2.5 s — enough for even a
#     slow arrow to leave the viewport before cleanup.
# ─────────────────────────────────────────────────────────────────
extends Node2D

# ── Projectile velocities ─────────────────────────────────────
var _arrow_velocity : Vector2 = Vector2.ZERO
var _staff_velocity : Vector2 = Vector2.ZERO

# Tuned so arrow feels snappy but readable; staff ball is slightly slower
# so the player can track it visually.
const ARROW_SPEED : float = 480.0   # was 500 — marginally more readable
const STAFF_SPEED : float = 350.0   # unchanged — feels right

# ── Audio ─────────────────────────────────────────────────────
# Slightly below 0 dB so all weapons sit at the same perceived volume
# without competing with each other on simultaneous hits.
const AUDIO_VOLUME_DB : float = 1.0

# ── Per-frame: move projectiles ───────────────────────────────
func _process(delta: float) -> void:
	if _arrow_velocity != Vector2.ZERO:
		$Arrow_Projectile.position += _arrow_velocity * delta

	if _staff_velocity != Vector2.ZERO:
		$Staff_Magic.position += _staff_velocity * delta

# ── Public entry point ────────────────────────────────────────
func play(effect_key: String, anim_or_element: String,
		shoot_direction: Vector2 = Vector2.ZERO) -> void:
	# Reset all children before starting a new effect
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

# ── Damage callback ───────────────────────────────────────────
## weapon_type and sub_type are forwarded to the enemy's damage table.
func _on_hit_body(hit_body: Node2D, weapon_type: String = "", sub_type: String = "") -> void:
	if not hit_body.is_in_group("enemy"):
		return
	if hit_body.has_method("take_damage"):
		hit_body.take_damage(0, weapon_type, sub_type)

# ── Hitbox helpers ────────────────────────────────────────────
## Sets layers so projectile hitboxes only detect enemies (layer 2),
## never the player body (layer 1).
##   collision_layer 3 = player weapons
##   collision_mask  2 = enemy bodies
func _setup_projectile_hitbox(hb: Area2D) -> void:
	hb.collision_layer = 3
	hb.collision_mask  = 2

func _enable_hitbox(hb: Area2D, enabled: bool) -> void:
	hb.monitoring  = enabled
	hb.monitorable = enabled
	hb.get_child(0).set_deferred("disabled", not enabled)

# ── Sword ─────────────────────────────────────────────────────
func _play_sword(element: String) -> void:
	var node := $Sword_Slash
	node.visible = true
	node.play(element)
	_play_audio($Sword_Slash/AudioStreamPlayer2D)

	var hb := _get_character_hitbox("SwordHitBox")
	if hb:
		# Place hitbox in front of the player using the effect's rotation
		# (character.gd sets effect.rotation = direction.angle() for sword).
		_orient_character_hitbox(hb, rotation, 36.0)
		_enable_hitbox(hb, true)
		if not hb.body_entered.is_connected(_on_sword_hit):
			hb.body_entered.connect(_on_sword_hit)
		node.animation_finished.connect(func():
			_enable_hitbox(hb, false)
			_on_effect_finished(node)
		, CONNECT_ONE_SHOT)
	else:
		node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

func _on_sword_hit(body: Node2D) -> void:
	_on_hit_body(body, "sword")

# ── Lance ─────────────────────────────────────────────────────
func _play_lance(mode: String) -> void:
	var node := $Lance_Poke
	node.visible = true
	node.play(mode)
	_play_audio($Lance_Poke/AudioStreamPlayer2D)

	var hb := _get_character_hitbox("LanceHitBox")
	if hb:
		# Lance hitbox sits further out than sword (longer weapon reach)
		_orient_character_hitbox(hb, rotation, 56.0)
		_enable_hitbox(hb, true)
		var sub := mode.to_lower()   # "pierce" or "thrust"
		if not hb.body_entered.is_connected(_on_lance_hit):
			hb.body_entered.connect(_on_lance_hit.bind(sub))
		node.animation_finished.connect(func():
			_enable_hitbox(hb, false)
			_on_effect_finished(node)
		, CONNECT_ONE_SHOT)
	else:
		node.animation_finished.connect(_on_effect_finished.bind(node), CONNECT_ONE_SHOT)

func _on_lance_hit(body: Node2D, sub_type: String) -> void:
	_on_hit_body(body, "lance", sub_type)

# ── Orient character hitbox ───────────────────────────────────
# Moves the CollisionShape2D of a character-parented hitbox to face the
# attack direction at the specified reach (pixels from character origin).
func _orient_character_hitbox(hb: Area2D, attack_angle: float, reach: float) -> void:
	var shape_node := hb.get_child(0) as CollisionShape2D
	if shape_node == null:
		return
	shape_node.position = Vector2.RIGHT.rotated(attack_angle) * reach

# ── Character hitbox finder ───────────────────────────────────
func _get_character_hitbox(hitbox_name: String) -> Area2D:
	var root := get_parent()
	if root == null:
		return null
	for child in root.get_children():
		var found := _find_area_by_name(child, hitbox_name)
		if found:
			return found
	return null

func _find_area_by_name(node: Node, target: String) -> Area2D:
	if node.name == target and node is Area2D:
		return node
	for child in node.get_children():
		var result := _find_area_by_name(child, target)
		if result:
			return result
	return null

# ── Bow: arrow fly ────────────────────────────────────────────
func _play_bow_arrow_fly(direction: Vector2) -> void:
	var node := $Arrow_Projectile
	node.visible  = true
	node.rotation = direction.angle()
	node.play("Arrow")
	_play_audio($Arrow_Projectile/AudioStreamPlayer2D)

	var hb : Area2D = $Arrow_Projectile/ArrowHitbox
	# Layer 3 = player weapons, mask 2 = enemy bodies — never hits the player.
	_setup_projectile_hitbox(hb)
	if not hb.body_entered.is_connected(_on_arrow_hit):
		hb.body_entered.connect(_on_arrow_hit)
	_enable_hitbox(hb, true)

	_arrow_velocity = direction.normalized() * ARROW_SPEED

	# After 2 s arrow expires cleanly
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

func _on_arrow_hit(body: Node2D) -> void:
	_on_hit_body(body, "bow")

# ── Staff phase 1: cast orb ───────────────────────────────────
func _play_staff_cast(anim_name: String) -> void:
	var node       := $Staff_Magic
	node.visible    = true
	node.rotation   = 0.0
	node.position   = Vector2.ZERO   # reset any leftover travel position
	node.play(anim_name)
	var audio := $Staff_Magic/AudioStreamPlayer2D
	audio.stop()
	_play_audio(audio)

# ── Staff phase 2: projectile shoot ──────────────────────────
func _play_staff_shoot(anim_name: String, shoot_dir: Vector2) -> void:
	var node      := $Staff_Magic
	node.visible   = true
	node.rotation  = shoot_dir.angle() if shoot_dir != Vector2.ZERO else 0.0
	node.position  = Vector2.ZERO
	node.play(anim_name)

	var audio := $Staff_Magic/AudioStreamPlayer2D
	audio.stop()
	_play_audio(audio)

	var fb_box : Area2D = $Staff_Magic/FireBallHitBox
	var lt_box : Area2D = $Staff_Magic/LightningHitBox

	# Layer 3 = player weapons, mask 2 = enemy bodies — never hits the player.
	_setup_projectile_hitbox(fb_box)
	_setup_projectile_hitbox(lt_box)

	match anim_name:
		"Shoot_FireBall":
			if not fb_box.body_entered.is_connected(_on_fireball_hit):
				fb_box.body_entered.connect(_on_fireball_hit)
			_enable_hitbox(fb_box, true)
			_enable_hitbox(lt_box, false)
		"Shoot_Lightning":
			if not lt_box.body_entered.is_connected(_on_lightning_hit):
				lt_box.body_entered.connect(_on_lightning_hit)
			_enable_hitbox(lt_box, true)
			_enable_hitbox(fb_box, false)

	_staff_velocity = shoot_dir.normalized() * STAFF_SPEED if shoot_dir != Vector2.ZERO else Vector2.ZERO

	node.animation_finished.connect(_on_staff_shoot_finished.bind(node), CONNECT_ONE_SHOT)

func _on_fireball_hit(body: Node2D) -> void:
	_on_hit_body(body, "magic")

func _on_lightning_hit(body: Node2D) -> void:
	_on_hit_body(body, "magic")

# ── Audio helper ──────────────────────────────────────────────
func _play_audio(player: AudioStreamPlayer2D) -> void:
	player.volume_db = AUDIO_VOLUME_DB
	player.stop()
	player.play()

# ── Cleanup ───────────────────────────────────────────────────
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
