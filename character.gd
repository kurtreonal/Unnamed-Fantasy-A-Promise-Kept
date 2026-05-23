extends CharacterBody2D

@export var speed = 200
@export var bullet_scene: PackedScene

@onready var collision = $Collision
@onready var sprite = $AnimatedSprite2D

@onready var attack_pivot = $AttackPivot
@onready var slash_hitbox = $AttackPivot/Slash
@onready var poke_hitbox = $AttackPivot/Poke
@onready var shield_hitbox = $AttackPivot/Shield
@onready var shoot_point = $AttackPivot/ShootPoint

var screen_size
var facing = Vector2.DOWN
var state = "idle"

func _ready():
	screen_size = get_viewport_rect().size
	disable_hitboxes()


func _process(delta):
	handle_combat()

	if state != "attack" and state != "shield":
		handle_movement(delta)


func handle_movement(delta):
	var input_dir = Vector2.ZERO

	input_dir.x = Input.get_action_strength("Walk_Right") - Input.get_action_strength("Left")
	input_dir.y = Input.get_action_strength("Walk_Down") - Input.get_action_strength("Up")

	if input_dir != Vector2.ZERO:

		facing = input_dir.normalized()

		velocity = facing * speed

		# Rotate AttackPivot toward direction
		attack_pivot.rotation = facing.angle()

		# Animation
		if abs(input_dir.x) > abs(input_dir.y):
			sprite.play("Walk_Sword_Right" if input_dir.x > 0 else "Walk_Sword_Left")
		else:
			sprite.play("Walk_Sword_Down" if input_dir.y > 0 else "Walk_Sword_Up")

	else:
		velocity = Vector2.ZERO
		sprite.stop()

	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)


func handle_combat():

	if Input.is_action_just_pressed("slash"):
		slash()

	if Input.is_action_just_pressed("poke"):
		poke()

	if Input.is_action_just_pressed("shoot"):
		shoot()

	if Input.is_action_pressed("Magic"):
		shield(true)
	else:
		shield(false)


func slash():
	state = "attack"

	disable_hitboxes()
	slash_hitbox.monitoring = true

	sprite.play("slash")

	await get_tree().create_timer(0.2).timeout

	slash_hitbox.monitoring = false
	state = "idle"


func poke():
	state = "attack"

	disable_hitboxes()
	poke_hitbox.monitoring = true

	sprite.play("poke")

	await get_tree().create_timer(0.1).timeout

	poke_hitbox.monitoring = false
	state = "idle"


func shoot():
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()

	get_parent().add_child(bullet)

	bullet.global_position = shoot_point.global_position
	bullet.direction = facing


func shield(active):

	if active:
		state = "Casting"
		shield_hitbox.monitoring = true
		sprite.play("Magic")
	else:
		shield_hitbox.monitoring = false

		if state == "Casting":
			state = "idle"


func disable_hitboxes():
	slash_hitbox.monitoring = false
	poke_hitbox.monitoring = false
	shield_hitbox.monitoring = false
