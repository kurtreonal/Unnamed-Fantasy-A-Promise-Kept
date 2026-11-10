extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if "Redesign Smoke" not in str(ProjectSettings.get_setting("application/config/name")) or "Redesign Smoke" not in OS.get_user_data_dir(): quit(2); return
	var campaign=root.get_node("Campaign")
	campaign.reset(); campaign.eat("porridge"); campaign.depart(0)
	var app=load("res://Game/main.tscn").instantiate(); root.add_child(app); app.explore()
	await process_frame
	var field=app.field
	var controller=field.get_children().filter(func(node):return node.get_script()==load("res://Game/touch.gd"))[0]
	if controller.controls.is_empty(): controller._ready()
	var stick=controller.controls[0]
	var press=InputEventScreenTouch.new(); press.index=0; press.pressed=true; press.position=stick.position+Vector2(125,75)
	root.push_input(press,true)
	await physics_frame
	var start=field.player.position
	await create_timer(0.12).timeout
	assert(field.player.position.x>start.x,"Touch joystick must move right")
	assert(not Input.is_action_pressed("attack"),"Movement touch cannot attack")
	app._inventory()
	await create_timer(0.05).timeout
	assert(not Input.is_action_pressed("move_right"),"Opening menu releases joystick")
	app._close_modal()
	await create_timer(0.05).timeout
	assert(stick.finger==-1,"Hidden joystick cannot keep a stale touch owner")
	press.pressed=false; root.push_input(press,true)
	press=InputEventScreenTouch.new(); press.index=1; press.pressed=true; press.position=controller.controls[1].position
	root.push_input(press,true)
	await physics_frame
	assert(Input.is_action_pressed("attack"),"Attack touch must hold primary attack")
	press.pressed=false; root.push_input(press,true)
	await physics_frame
	assert(not Input.is_action_pressed("attack"),"Releasing attack touch clears action")
	print("PASS: touch movement, attack, menu release, and joystick ownership")
	app.queue_free(); await process_frame; quit()
