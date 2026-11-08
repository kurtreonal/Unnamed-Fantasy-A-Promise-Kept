extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.get_user_data_dir().ends_with("Unnamed Fantasy Release Smoke Test"))
	assert(change_scene_to_file("res://Scenes/World1.tscn") == OK)
	await process_frame
	await process_frame
	var player := get_first_node_in_group("player")
	assert(player != null)
	var controls: Node
	for child in current_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://UI/Mobile/mobile_controls.gd":
			controls = child
	assert(controls != null)
	controls._build_controls()
	assert(controls.get_child_count() == 10)
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.position = controls.get_node("Right").position
	press.pressed = true
	root.push_input(press, true)
	await physics_frame
	await physics_frame
	assert(Input.is_action_pressed("Right"), "Movement touch must hold the action")
	assert(not Input.is_action_pressed("Sword_Attack"), "Movement touch must not attack")
	assert(player.velocity.x > 0)
	press.pressed = false
	root.push_input(press, true)
	await physics_frame
	assert(not Input.is_action_pressed("Right"))
	var element: int = player.sword_element
	Input.action_press("Switch_Element")
	await physics_frame
	await physics_frame
	Input.action_release("Switch_Element")
	assert(player.sword_element == (element + 1) % 3, "Element must cycle once")
	var weapon: int = player.current_weapon
	Input.action_press("Switch_Weapon")
	await physics_frame
	await physics_frame
	Input.action_release("Switch_Weapon")
	assert(player.current_weapon == (weapon + 1) % 4)
	press.position = controls.get_node("Recall").position
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	assert(current_scene._recall_active, "Home touch must start recall")
	press.pressed = false
	root.push_input(press, true)
	print("PASS: touch movement, release, single element cycle, weapon switch, recall")
	quit()
