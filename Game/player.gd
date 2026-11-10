extends CharacterBody2D
const ART="res://Game/Art/Packs/dungeon/0x72_DungeonTilesetII_v1.7/frames/"
var field: Node2D
var aim=Vector2.RIGHT
var facing=Vector2.RIGHT
var skill_left=0.0
var dodge_left=0.0
var dodge_time=0.0
var dodge_dir=Vector2.ZERO
var invulnerable=0.0
var attack_left=0.0
var attack_age=1.0
var attack_fired=true
var attack_direction=Vector2.RIGHT
var buffer_left=0.0
var sprite: AnimatedSprite2D
var weapon_sprite: Sprite2D
var equipped=""
var camera: Camera2D

func _ready() -> void:
	collision_layer=2; collision_mask=1
	add_to_group("redesign_player")
	var shape=CollisionShape2D.new(); var circle=CircleShape2D.new(); circle.radius=9; shape.shape=circle; add_child(shape)
	sprite=AnimatedSprite2D.new(); sprite.sprite_frames=SpriteFrames.new(); sprite.scale=Vector2(2,2); sprite.position.y=-18; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for animation in ["idle","run"]:
		sprite.sprite_frames.add_animation(animation); sprite.sprite_frames.set_animation_speed(animation,7)
		for frame in range(4): sprite.sprite_frames.add_frame(animation,load(ART+"elf_m_"+animation+"_anim_f%d.png" % frame))
	add_child(sprite)
	weapon_sprite=Sprite2D.new(); weapon_sprite.scale=Vector2(2,2); weapon_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(weapon_sprite)
	camera=Camera2D.new(); camera.position_smoothing_enabled=true; camera.position_smoothing_speed=7; camera.zoom=Vector2.ONE*float(Campaign.settings.zoom)
	camera.limit_left=0; camera.limit_top=0; camera.limit_right=1536; camera.limit_bottom=1152; add_child(camera)
	camera.reset_smoothing()
	_update_weapon()
	Campaign.changed.connect(_update_weapon)

func _update_weapon() -> void:
	var id: String=Campaign.equipment.weapon
	if equipped==id: return
	equipped=id
	var visuals={"sword":"weapon_rusty_sword.png","spear":"weapon_spear.png","bow":"weapon_bow_2.png","staff":"weapon_green_magic_staff.png"}
	var path=ART+visuals.get(Campaign.weapon().family,"weapon_rusty_sword.png")
	if not ResourceLoader.exists(path): path=ART+"weapon_rusty_sword.png"
	weapon_sprite.texture=load(path)
	weapon_sprite.modulate=[Color("c8c4ae"),Color("c5d5c2"),Color("dfd3a5")][int(Campaign.weapon().tier)-1]

func _physics_process(delta: float) -> void:
	_update_weapon()
	camera.zoom=Vector2.ONE*float(Campaign.settings.zoom)
	if Campaign.modal_open or Campaign.input_locked:
		velocity=Vector2.ZERO; buffer_left=0; return
	skill_left=maxf(0,skill_left-delta); dodge_left=maxf(0,dodge_left-delta); invulnerable=maxf(0,invulnerable-delta); attack_left=maxf(0,attack_left-delta); buffer_left=maxf(0,buffer_left-delta)
	var movement=Input.get_vector("move_left","move_right","move_up","move_down")
	if DisplayServer.is_touchscreen_available() or OS.has_feature("android"):
		if movement.length()>0.1: aim=movement.normalized()
		var target=field.nearest_enemy(global_position,140)
		if is_instance_valid(target): aim=global_position.direction_to(target.global_position)
	else:
		var pointer=get_global_mouse_position()-global_position
		if pointer.length()>8: aim=pointer.normalized()
	if Input.is_action_just_pressed("heal"): Campaign.heal()
	if Input.is_action_just_pressed("dodge") and dodge_left<=0:
		dodge_left=0.85; dodge_time=0.18; invulnerable=0.22
		dodge_dir=movement.normalized() if movement.length()>0.1 else aim
		attack_left=0; attack_fired=true
	if Input.is_action_just_pressed("attack"): buffer_left=0.14
	if (buffer_left>0 or Input.is_action_pressed("attack")) and attack_left<=0 and dodge_time<=0:
		attack_left=0.38; attack_age=0; attack_fired=false; attack_direction=aim; buffer_left=0
	if not attack_fired:
		attack_age+=delta
		if attack_age>=0.075:
			attack_fired=true; _primary()
	if Input.is_action_just_pressed("skill") and skill_left<=0 and dodge_time<=0:
		skill_left=4.0; _skill()
	if dodge_time>0:
		dodge_time-=delta; velocity=dodge_dir*420
	else:
		var speed=145.0
		if attack_left>0: speed*=0.55 if Campaign.weapon().family in ["bow","staff"] else 0.7
		velocity=movement*speed
	move_and_slide()
	if movement.length()>0.1: facing=movement.normalized()
	sprite.play("run" if velocity.length()>5 else "idle")
	sprite.flip_h=aim.x<0
	sprite.modulate.a=0.5 if invulnerable>0 and int(invulnerable*20)%2==0 else 1.0
	weapon_sprite.position=aim*16+Vector2(0,-10)
	weapon_sprite.rotation=aim.angle()+PI/2+(sin(attack_left*16)*0.45 if attack_left>0 else 0.0)
	var look=movement*24
	camera.position=camera.position.lerp(look,1-exp(-delta*4))
	queue_redraw()

func _primary() -> void:
	field.combat_time=4
	var item=Campaign.weapon()
	var damage=int(item.attack)
	match item.family:
		"sword": field.melee(global_position,attack_direction,58,0.2,damage)
		"spear": field.melee(global_position,attack_direction,88,0.78,damage)
		"bow": field.shoot(global_position+Vector2(0,-10),attack_direction,420,damage,false,Color("d1c69a"))
		"staff": field.shoot(global_position+Vector2(0,-10),attack_direction,290,damage+2,false,Color("a6bca9"))

func _skill() -> void:
	field.combat_time=4
	var damage=int(Campaign.weapon().attack)
	match Campaign.weapon().family:
		"sword": field.melee(global_position,aim,83,-1.0,int(damage*1.6))
		"spear":
			field.melee(global_position,aim,115,0.65,damage*2)
			dodge_time=0.10; dodge_dir=aim; invulnerable=maxf(invulnerable,0.12)
		"bow":
			for angle in [-0.18,0.0,0.18]: field.shoot(global_position+Vector2(0,-10),aim.rotated(angle),460,damage,false,Color("ded1a1"))
		"staff": field.melee(global_position+aim*55,aim,86,-1.0,int(damage*1.8))

func take_damage(amount: int) -> void:
	if invulnerable>0 or Campaign.input_locked or Campaign.modal_open: return
	Campaign.player_hp=maxi(0,Campaign.player_hp-maxi(1,amount-Campaign.defense()))
	invulnerable=0.75; field.combat_time=5; field.recall_left=0
	Campaign.changed.emit()
	if Campaign.player_hp<=0: field.finish(true)

func _draw() -> void:
	draw_ellipse_shadow()
	if attack_left>0.12 and Campaign.weapon().family in ["sword","spear"]:
		draw_arc(Vector2.ZERO,38,attack_direction.angle()-0.65,attack_direction.angle()+0.65,14,Color(0.9,0.85,0.65,attack_left*1.4),2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.4)); draw_circle(Vector2.ZERO,12,Color(0,0,0,0.24)); draw_set_transform(Vector2.ZERO)
