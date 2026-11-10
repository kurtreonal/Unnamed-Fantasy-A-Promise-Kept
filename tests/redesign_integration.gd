extends SceneTree
var failures=0
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)

func _run() -> void:
	if "Redesign Smoke" not in str(ProjectSettings.get_setting("application/config/name")) or "Redesign Smoke" not in OS.get_user_data_dir():
		push_error("Isolated profile required"); quit(2); return
	var app=load("res://Game/main.tscn").instantiate(); root.add_child(app)
	var campaign=root.get_node("Campaign")
	campaign.reset(); app.home()
	var data={"id":"prologue","critical":false,"lines":["Narrator|One.","Narrator|Two.","Rin|Important.","You|A promise.","Narrator|Five."]}
	var seated=app.screen.get_node("RinIllustration")
	expect(seated.material==null and is_equal_approx(seated.position.y,366.0),"Colored seated Rin is anchored to the sofa cushion")
	app._show_dialogue(data)
	await create_timer(0.10).timeout
	expect(campaign.input_locked,"Dialogue locks gameplay")
	expect(not seated.visible,"Seated Rin disappears when conversation starts")
	Input.action_press("advance")
	await create_timer(0.9).timeout
	var dialogic=root.get_node("Dialogic")
	expect(int(campaign.dialogue.get("index",-1))==2,"Held skip must stop at the first protected line")
	expect(not dialogic.Inputs.auto_skip.enabled,"Auto-skip disabled at critical line")
	var echo=InputEventKey.new(); echo.physical_keycode=KEY_ENTER; echo.pressed=true; echo.echo=true
	root.push_input(echo,true)
	await create_timer(0.35).timeout
	expect(int(campaign.dialogue.get("index",-1))==2,"Continued hold cannot clear a critical line")
	Input.action_release("advance")
	await process_frame
	var dialogue=root.get_node("PromiseKept").get_children().filter(func(n):return n is CanvasLayer and n.get_script()==load("res://Game/dialogue.gd"))[0]
	expect(dialogue.portrait.texture.resource_path.ends_with("rin_conversation.png"),"Conversation uses the dedicated half-body portrait")
	expect(dialogue.portrait.material==null and dialogue.portrait.size.x>=560,"Conversation preserves color and uses close player-facing framing")
	dialogic.Text.skip_text_reveal()
	await create_timer(0.15).timeout
	dialogic.Inputs.handle_input()
	await create_timer(0.15).timeout
	expect(int(campaign.dialogue.get("index",-1))==3,"Fresh manual advance reaches the next protected line")
	dialogue._finish()
	await process_frame
	expect(seated.visible,"Seated Rin returns when conversation ends")
	expect(campaign.load_game() and campaign.dialogue.is_empty(),"Completed routine dialogue stays closed after reloading the autosave")
	campaign.dialogue={}; campaign.input_locked=false
	expect(ResourceLoader.exists("res://Game/Timelines/e01.dtl"),"Story scenes must be editable Dialogic resources")
	var actual=campaign.activity("talk")
	campaign.dialogue={"id":"e01","index":2}
	app._show_dialogue(actual.event)
	await create_timer(0.15).timeout
	expect(campaign.dialogue.get("id","")=="e01" and int(campaign.dialogue.get("index",-1))==2,"Real Dialogic source resumes through stable line labels")
	var talking=app.get_children().filter(func(node):return node is CanvasLayer and node.get_script()==load("res://Game/dialogue.gd"))[0]
	expect(talking.portrait.visible,"Rin is visible in the foreground during conversation")
	dialogic.Text.skip_text_reveal(); await create_timer(0.15).timeout; dialogic.Inputs.handle_input(); await create_timer(0.15).timeout
	expect(talking.portrait.visible,"Talking Rin stays present while the protagonist speaks")
	for node in app.get_children():
		if node is CanvasLayer and node.get_script()==load("res://Game/dialogue.gd"): node.queue_free()
	await process_frame
	campaign.dialogue={}; campaign.input_locked=false
	campaign.eat("porridge"); campaign.depart(0); app.explore()
	await physics_frame
	var field=app.field
	var player=field.player
	var target=field.enemies[0]
	player.position=Vector2(350,550); target.position=Vector2(390,550); target.cooldown=100
	await physics_frame
	var before=target.hp
	field.melee(player.position,Vector2.RIGHT,58,0.2,int(campaign.weapon().attack))
	expect(target.hp==before-int(campaign.weapon().attack),"Enemy takes equipped weapon damage exactly once per swing")
	var health=campaign.player_hp
	player.take_damage(10); player.take_damage(10)
	expect(campaign.player_hp==health-maxi(1,10-campaign.defense()),"Hit invulnerability prevents repeated damage")
	campaign.modal_open=true
	var original=player.position
	Input.action_press("move_right")
	await create_timer(0.10).timeout
	expect(player.position==original,"Menus stop gameplay movement")
	Input.action_release("move_right"); campaign.modal_open=false
	campaign.grant("bow_2"); campaign.equip("bow_2")
	await process_frame
	expect(player.equipped=="bow_2","Equipment change updates the active weapon")
	player.attack_direction=Vector2.LEFT; player._primary()
	expect(field.projectiles[-1].dir==Vector2.LEFT,"Ranged aim is independent of movement-facing")
	field.begin_recall(); player.position.x+=10
	await process_frame
	expect(field.recall_left==0,"Moving interrupts recall")
	var boss=field.enemies.filter(func(enemy):return is_instance_valid(enemy) and enemy.boss)[0]
	campaign.settings.zoom=1.5
	field._boss_introduction(boss)
	await create_timer(0.7).timeout
	expect(campaign.input_locked and player.camera.position.length()>10,"Boss introduction controls framing and blocks gameplay")
	var introduction=app.get_children().filter(func(node):return node is CanvasLayer and node.get_script()==load("res://Game/dialogue.gd"))[0]
	introduction._finish()
	await process_frame
	expect(player.camera.position==Vector2.ZERO and is_equal_approx(player.camera.zoom.x,1.5),"Cutscene restores player framing and selected zoom")
	field.finish(true)
	expect(campaign.phase=="evening" and campaign.equipment.weapon=="bow_2","Defeat preserves equipment and returns home")
	if failures==0: print("PASS: protected held-skip, combat damage, hit immunity, equipment visuals, ranged aim, menus, recall, defeat")
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
