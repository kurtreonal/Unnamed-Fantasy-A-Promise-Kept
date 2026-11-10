extends Node2D
signal returned
signal story_requested(data: Dictionary)
const Player=preload("res://Game/player.gd")
const Enemy=preload("res://Game/enemy.gd")
const Touch=preload("res://Game/touch.gd")
const ART="res://Game/Art/Packs/dungeon/0x72_DungeonTilesetII_v1.7/"
const FOREST="res://Game/Art/Packs/forest/tiny-RPG-forest-files/PNG/"
var player: CharacterBody2D
var cells: Dictionary={}
var props: Array=[]
var harvests: Array=[]
var chests: Array=[]
var projectiles: Array=[]
var enemies: Array=[]
var combat_time=0.0
var recall_left=0.0
var recall_position=Vector2.ZERO
var clock_time=0.0
var save_time=0.0
var finished=false
var floor_texture: Texture2D
var forest_texture: Texture2D
var tree: Texture2D
var chest_texture: Texture2D
var glint: Texture2D
var hits: Array=[]
var route: Dictionary
var rng=RandomNumberGenerator.new()
var room_centers: Array=[]

func _ready() -> void:
	y_sort_enabled=true
	var palette=ShaderMaterial.new(); palette.shader=load("res://Game/world_palette.gdshader"); material=palette
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	rng.seed=Campaign.day*901+Campaign.region*77
	route=Campaign.catalog.regions[Campaign.region]
	floor_texture=load(ART+"atlas_floor-16x16.png")
	forest_texture=load(FOREST+"environment/tileset.png")
	tree=load(FOREST+"environment/sliced-objects/tree-orange.png")
	chest_texture=load(ART+"frames/chest_full_open_anim_f0.png")
	glint=load(ART+"frames/flask_big_green.png") if ResourceLoader.exists(ART+"frames/flask_big_green.png") else chest_texture
	_build_map()
	player=Player.new(); player.field=self; player.position=Vector2(9*32,29*32); add_child(player)
	if Campaign.checkpoint.has("x"): player.position=Vector2(float(Campaign.checkpoint.x),float(Campaign.checkpoint.y)); player.camera.reset_smoothing()
	_spawn_encounters()
	var controls=Touch.new(); add_child(controls)
	if not Campaign.checkpoint.is_empty():
		for enemy in enemies:
			if Campaign.checkpoint.get("enemy_hp",{}).has(enemy.spawn_id): enemy.hp=int(Campaign.checkpoint.enemy_hp[enemy.spawn_id])
	queue_redraw()

func _build_map() -> void:
	var rooms=[Rect2i(3,25,12,8),Rect2i(6,14,11,8),Rect2i(22,22,12,9),Rect2i(22,9,12,9),Rect2i(35,3,10,10)]
	if Campaign.region==1: rooms=[Rect2i(3,25,12,8),Rect2i(18,25,10,8),Rect2i(18,14,13,8),Rect2i(5,5,13,9),Rect2i(34,3,11,12)]
	elif Campaign.region==2: rooms=[Rect2i(3,25,12,8),Rect2i(7,15,10,8),Rect2i(22,18,10,10),Rect2i(24,5,10,9),Rect2i(36,3,10,12)]
	for room in rooms:
		room_centers.append(Vector2(room.get_center()))
		for x in range(room.position.x,room.end.x):
			for y in range(room.position.y,room.end.y): cells[Vector2i(x,y)]=true
	var path=[]
	for center in room_centers: path.append(Vector2i(center))
	for i in range(path.size()-1):
		var point: Vector2i=path[i]; var end: Vector2i=path[i+1]
		while point!=end:
			for ox in range(-2,3):
				for oy in range(-2,3): cells[point+Vector2i(ox,oy)]=true
			if point.x!=end.x: point.x+=signi(end.x-point.x)
			else: point.y+=signi(end.y-point.y)
	for x in range(48):
		for y in range(36):
			var key=Vector2i(x,y)
			if cells.has(key): continue
			var adjacent=false
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if cells.has(key+offset): adjacent=true
			if not adjacent: continue
			var wall=StaticBody2D.new(); wall.position=Vector2(key)*32+Vector2(16,16); wall.collision_layer=1
			var collider=CollisionShape2D.new(); var rect=RectangleShape2D.new(); rect.size=Vector2(32,32); collider.shape=rect; wall.add_child(collider); add_child(wall)
	var rare_points=[room_centers[0]+Vector2(-2,-1),room_centers[1]+Vector2(-2,-1),room_centers[2]+Vector2(-2,-1),room_centers[3]+Vector2(-2,-1),room_centers[4]+Vector2(-2,-1),room_centers[4]+Vector2(2,2)]
	for point in rare_points:
		harvests.append({"pos":point*32,"id":str(harvests.size()),"item":str(route.material)})
	for index in range(4): harvests.append({"pos":(room_centers[index]+Vector2(-2,2))*32,"id":str(harvests.size()),"item":"herb"})
	for index in [0,2,4]: chests.append({"pos":(room_centers[index]+Vector2(2,2))*32,"id":str(chests.size())})

func _spawn_encounters() -> void:
	var candidates: Array=Campaign.catalog.enemies.filter(func(e):return int(e.region)==Campaign.region)
	var positions=[]
	for index in range(1,5):
		positions.append(room_centers[index]+Vector2(-2,-1)); positions.append(room_centers[index]+Vector2(2,1))
	positions.append(room_centers[2]+Vector2(0,2)); positions.append(room_centers[3]+Vector2(2,-2))
	for i in range(positions.size()): _spawn(candidates[i%candidates.size()],positions[i]*32,str(i),false)
	var boss={"id":"boss"+str(Campaign.region),"name":route.boss,"hp":220+Campaign.region*100,"attack":15+Campaign.region*4,"speed":45,"style":["charge","melee","ranged"][Campaign.region]}
	_spawn(boss,Vector2(40,7)*32,"boss",true)

func _spawn(spec: Dictionary, position_: Vector2, id: String, boss: bool) -> void:
	if id in Campaign.expedition.get("defeated",[]): return
	var enemy=Enemy.new(); enemy.field=self; enemy.spec=spec; enemy.spawn_id=id; enemy.boss=boss; enemy.position=position_; add_child(enemy); enemies.append(enemy)

func _process(delta: float) -> void:
	if finished or Campaign.modal_open or Campaign.input_locked: return
	if not Campaign.expedition.get("boss_intro",false):
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.boss and player.position.distance_to(enemy.position)<230:
				_boss_introduction(enemy)
				return
	combat_time=maxf(0,combat_time-delta)
	clock_time+=delta; save_time+=delta
	if clock_time>=1.0:
		clock_time-=1; Campaign.minute+=1
		if Campaign.minute>=60: Campaign.minute=0; Campaign.hour+=1
		if Campaign.hour==17 and Campaign.minute in [0,30]: Campaign.notice.emit("%s · Time to think about heading home." % Campaign.clock())
		if Campaign.hour>=18: finish(); return
	if save_time>=20: save_time=0; capture_checkpoint(); Campaign.save_game()
	if recall_left>0:
		if player.position.distance_to(recall_position)>5: recall_left=0; Campaign.notice.emit("Recall interrupted by movement.")
		else:
			recall_left-=delta
			if recall_left<=0: finish(); return
	for projectile in projectiles.duplicate():
		projectile.pos+=projectile.dir*projectile.speed*delta; projectile.life-=delta
		if not cells.has(Vector2i(projectile.pos/32)): projectile.life=0
		if projectile.enemy:
			if projectile.pos.distance_to(player.position)<15: player.take_damage(projectile.damage); projectile.life=0
		else:
			for enemy in enemies:
				if is_instance_valid(enemy) and not enemy.dead and projectile.pos.distance_to(enemy.position)<(26 if enemy.boss else 17):
					enemy.take_damage(projectile.damage,projectile.dir); projectile.life=0; break
		if projectile.life<=0: projectiles.erase(projectile)
	for hit in hits.duplicate():
		hit.life-=delta
		if hit.life<=0: hits.erase(hit)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if Campaign.modal_open or Campaign.input_locked or finished: return
	if event.is_action_pressed("recall"): begin_recall()
	elif event.is_action_pressed("use"): interact()

func begin_recall() -> void:
	if recall_left>0: recall_left=0; return
	recall_left=4; recall_position=player.position
	Campaign.notice.emit("Stay still for four seconds to return home.")

func finish(defeated := false) -> void:
	if finished: return
	finished=true; Campaign.return_home(defeated); returned.emit()

func interaction_text() -> String:
	if finished: return ""
	if player.position.distance_to(Vector2(9,30)*32)<48: return "F · Return to the village"
	for node in harvests:
		if not node.id in Campaign.expedition.get("harvested",[]) and player.position.distance_to(node.pos)<45: return "F · Gather "+Campaign.item_name(node.item)
	for node in chests:
		if not node.id in Campaign.expedition.get("chests",[]) and player.position.distance_to(node.pos)<45: return "F · Open chest"
	return ""

func interact() -> void:
	if player.position.distance_to(Vector2(9,30)*32)<48: finish(); return
	for node in harvests:
		if not node.id in Campaign.expedition.harvested and player.position.distance_to(node.pos)<45:
			Campaign.expedition.harvested.append(node.id); Campaign.take_loot(node.item)
			if rng.randf()<0.6: Campaign.grant(["grain","vegetable","honey"][rng.randi_range(0,2)])
			capture_checkpoint(); Campaign.save_game(); return
	for node in chests:
		if not node.id in Campaign.expedition.chests and player.position.distance_to(node.pos)<45:
			Campaign.expedition.chests.append(node.id)
			var families=["sword","spear","bow","staff"]
			Campaign.take_loot(families[(Campaign.day+int(node.id))%4]+"_"+str(Campaign.region+1))
			Campaign.grant("potion"); _earn(25); Campaign.record("chest")
			capture_checkpoint(); Campaign.save_game(); return

func _earn(amount: int) -> void:
	Campaign.coins+=amount; Campaign.expedition.earnings=int(Campaign.expedition.get("earnings",0))+amount; Campaign.changed.emit()

func enemy_defeated(enemy: Node) -> void:
	Campaign.expedition.defeated.append(enemy.spawn_id)
	Campaign.record("kill"); _earn(70 if enemy.boss else 8)
	if enemy.boss:
		if Campaign.quantity(route.seal)==0: Campaign.take_loot(route.seal)
		Campaign.record("boss:"+str(Campaign.region))
		Campaign.take_loot("sword_"+str(mini(3,Campaign.region+2)))
		Campaign.notice.emit("%s defeated · treatment record recovered" % route.boss)
	elif rng.randf()<0.15:
		Campaign.take_loot(["sword","spear","bow","staff"][rng.randi_range(0,3)]+"_"+str(Campaign.region+1))
	hits.append({"pos":enemy.position,"life":0.25})
	capture_checkpoint(); Campaign.save_game()

func nearest_enemy(point: Vector2, maximum: float) -> Node2D:
	var closest: Node2D=null
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var distance=point.distance_to(enemy.position)
			if distance<maximum and line_clear(point,enemy.position): closest=enemy; maximum=distance
	return closest

func melee(point: Vector2, direction: Vector2, reach: float, cone: float, damage: int) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var to=enemy.position-point
		if to.length()<=reach and (to.length()<5 or to.normalized().dot(direction)>=cone) and line_clear(point,enemy.position): enemy.take_damage(damage,direction)
	hits.append({"pos":point+direction*reach*0.5,"life":0.15})

func shoot(point: Vector2, direction: Vector2, speed: float, damage: int, hostile: bool, color: Color) -> void:
	projectiles.append({"pos":point,"dir":direction,"speed":speed,"damage":damage,"enemy":hostile,"color":color,"life":3.0})

func line_clear(from: Vector2, to: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1)).is_empty()

func capture_checkpoint() -> void:
	if finished: return
	var hp={}
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead: hp[enemy.spawn_id]=enemy.hp
	Campaign.checkpoint={"x":player.position.x,"y":player.position.y,"enemy_hp":hp}

func _boss_introduction(boss: Node2D) -> void:
	Campaign.expedition.boss_intro=true; Campaign.input_locked=true
	player.camera.position_smoothing_enabled=false
	var pan=create_tween(); pan.tween_property(player.camera,"position",boss.position-player.position,0.55).set_trans(Tween.TRANS_SINE)
	await pan.finished
	if not is_inside_tree(): return
	var lore=["Roots have grown through the old forester’s coat. The record you need is caught beneath the warden’s seal.","A broken mining bell sounds once. The keeper turns toward you, guarding the physician’s final field journal.","The sanctuary’s last custodian opens its eyes. Behind it, the treatment formula waits in the first light."]
	story_requested.emit({"id":"boss_intro_"+str(Campaign.region),"critical":true,"lines":["Narrator|"+str(lore[Campaign.region]),"You|I will bring these notes home. We will understand them together."]})

func restore_camera() -> void:
	if not is_instance_valid(player): return
	player.camera.position=Vector2.ZERO
	player.camera.zoom=Vector2.ONE*float(Campaign.settings.zoom)
	player.camera.position_smoothing_enabled=true; player.camera.reset_smoothing()

func _draw() -> void:
	var colors: Array=route.get("palette",["#465140","#6f715b","#30372f"])
	draw_rect(Rect2(0,0,1536,1152),Color(colors[2]))
	for key in cells:
		var rectangle=Rect2(Vector2(key)*32,Vector2(32,32))
		if Campaign.region==0:
			draw_texture_rect_region(forest_texture,rectangle,Rect2(256,288,16,16),Color(0.72,0.84,0.74))
		else: draw_texture_rect_region(floor_texture,rectangle,Rect2((posmod(key.x*7+key.y,3))*16,0,16,16),Color(0.92,0.94,0.88))
	for x in range(2,47,3):
		for y in range(2,35,3):
			if cells.has(Vector2i(x,y)): continue
			if Campaign.region==0: draw_texture_rect(tree,Rect2(x*32-16,y*32-48,64,96),false,Color(0.63,0.76,0.64))
			else: draw_texture_rect_region(floor_texture,Rect2(x*32,y*32,32,32),Rect2(0,0,16,16),Color(0.5,0.55,0.51))
	for node in harvests:
		if node.id in Campaign.expedition.get("harvested",[]): continue
		draw_texture_rect(glint,Rect2(node.pos-Vector2(12,24),Vector2(24,32)),false,Color(0.8,0.94,0.8))
	for node in chests:
		if node.id in Campaign.expedition.get("chests",[]): continue
		draw_texture_rect(chest_texture,Rect2(node.pos-Vector2(16,16),Vector2(32,32)),false)
	draw_arc(Vector2(9,30)*32,25,0,TAU,24,Color("bbbf9b"),2)
	for projectile in projectiles: draw_line(projectile.pos-projectile.dir*10,projectile.pos,projectile.color,4)
	for hit in hits: draw_arc(hit.pos,12+(0.25-hit.life)*35,0,TAU,12,Color(0.85,0.8,0.6,hit.life*3),2)
