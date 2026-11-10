extends CharacterBody2D
const ART="res://Game/Art/Packs/dungeon/0x72_DungeonTilesetII_v1.7/frames/"
var field: Node2D
var spec: Dictionary
var spawn_id = ""
var boss = false
var hp = 30
var maximum = 30
var cooldown = 0.8
var windup = 0.0
var locked_direction=Vector2.RIGHT
var knockback=Vector2.ZERO
var hit_flash=0.0
var sprite: AnimatedSprite2D
var dead=false
var charge_time=0.0

func _ready() -> void:
	collision_layer=4; collision_mask=1
	hp=int(spec.hp); maximum=hp
	var shape=CollisionShape2D.new(); var circle=CircleShape2D.new(); circle.radius=13 if boss else 9; shape.shape=circle; add_child(shape)
	sprite=AnimatedSprite2D.new(); sprite.sprite_frames=SpriteFrames.new(); sprite.scale=Vector2.ONE*(3 if boss else 2); sprite.position.y=-20 if boss else -12; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var names={"slug":"swampy","thorn":"goblin","moth":"imp","crawler":"tiny_zombie","shade":"necromancer","sentinel":"masked_orc","wisp":"chort","keeper":"skelet","boss0":"big_zombie","boss1":"ogre","boss2":"big_demon"}
	var prefix: String=names.get(spec.id,"goblin")
	for anim in ["idle","run"]:
		sprite.sprite_frames.add_animation(anim); sprite.sprite_frames.set_animation_speed(anim,6)
		for index in range(4):
			var path=ART+prefix+"_"+anim+"_anim_f%d.png" % index
			if not ResourceLoader.exists(path): path=ART+prefix+"_anim_f%d.png" % index
			if not ResourceLoader.exists(path): path=ART+"goblin_idle_anim_f%d.png" % index
			sprite.sprite_frames.add_frame(anim,load(path))
	add_child(sprite)
	add_to_group("redesign_enemies")

func _physics_process(delta: float) -> void:
	if dead or Campaign.modal_open or Campaign.input_locked or not is_instance_valid(field.player): return
	hit_flash=maxf(0,hit_flash-delta); sprite.modulate=Color(1.5,0.7,0.6) if hit_flash>0 else Color(0.92,0.93,0.86)
	var distance=global_position.distance_to(field.player.global_position)
	if distance>350: return
	field.combat_time=maxf(field.combat_time,1)
	cooldown-=delta
	var direction=global_position.direction_to(field.player.global_position)
	if charge_time>0:
		charge_time-=delta; velocity=locked_direction*350
		if distance<28 and field.line_clear(global_position,field.player.global_position): field.player.take_damage(int(spec.attack))
	elif windup>0:
		windup-=delta; velocity=knockback
		if windup<=0:
			if spec.style=="ranged":
				field.shoot(global_position,locked_direction,170 if not boss else 210,int(spec.attack),true,Color("c8a48a"))
				if boss:
					for angle in [-0.30,0.30]: field.shoot(global_position,locked_direction.rotated(angle),170,int(spec.attack),true,Color("c8a48a"))
			elif spec.style=="charge":
				charge_time=0.25; velocity=locked_direction*350
			else:
				if distance<(95 if boss else 49) and field.line_clear(global_position,field.player.global_position): field.player.take_damage(int(spec.attack))
			cooldown=1.5 if boss else 1.1
	else:
		var attack_range=190 if spec.style=="ranged" else (110 if spec.style=="charge" else 43)
		if distance<attack_range and cooldown<=0 and field.line_clear(global_position,field.player.global_position):
			windup=0.8 if boss else 0.55; locked_direction=direction; velocity=Vector2.ZERO
		else:
			velocity=direction*float(spec.speed) if distance>attack_range*0.8 else Vector2.ZERO
			if not field.line_clear(global_position,field.player.global_position): velocity=Vector2.ZERO
	velocity+=knockback; knockback=knockback.move_toward(Vector2.ZERO,delta*650)
	move_and_slide()
	sprite.play("run" if velocity.length()>5 else "idle"); sprite.flip_h=direction.x<0
	queue_redraw()

func take_damage(amount: int, direction := Vector2.ZERO) -> void:
	if dead: return
	hp-=amount; hit_flash=0.12; knockback=direction*100
	if windup>0 and not boss: windup=0; cooldown=0.4
	if hp<=0:
		dead=true; field.enemy_defeated(self); queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO,13 if boss else 9,Color(0,0,0,0.2))
	if windup>0:
		var radius=88.0 if boss else 42.0
		draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(0.85,0.55,0.38,0.6),2)
		draw_line(Vector2.ZERO,locked_direction*radius,Color(0.95,0.73,0.43,0.8),3)
	if hp<maximum or boss:
		draw_rect(Rect2(-18,-51,36,3),Color("383a35"))
		draw_rect(Rect2(-18,-51,36*float(hp)/maximum,3),Color("bcb287"))
