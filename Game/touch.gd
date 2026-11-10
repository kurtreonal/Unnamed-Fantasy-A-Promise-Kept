extends CanvasLayer
## Compact mobile controls. Gameplay actions share the desktop input map.
const ACTIONS=["move_up","move_down","move_left","move_right","attack","skill","dodge","use"]
var controls: Array=[]

class Stick extends Control:
	var finger=-1
	var vector=Vector2.ZERO
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_STOP
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and finger==-1: finger=event.index; _move(event.position)
			elif not event.pressed and event.index==finger: finger=-1; _release()
			accept_event()
		elif event is InputEventScreenDrag and event.index==finger: _move(event.position); accept_event()
	func _move(point: Vector2) -> void:
		vector=(point-size/2)/55.0
		if vector.length()>1: vector=vector.normalized()
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		if absf(vector.x)>0.15: Input.action_press("move_right" if vector.x>0 else "move_left",absf(vector.x))
		if absf(vector.y)>0.15: Input.action_press("move_down" if vector.y>0 else "move_up",absf(vector.y))
		queue_redraw()
	func _release() -> void:
		vector=Vector2.ZERO
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		queue_redraw()
	func _draw() -> void:
		draw_circle(size/2,66,Color(0.04,0.07,0.06,0.45)); draw_arc(size/2,66,0,TAU,48,Color(0.75,0.75,0.62,0.7),2)
		draw_circle(size/2+vector*46,25,Color(0.65,0.68,0.56,0.65))
	func _exit_tree() -> void: _release()

class Action extends TouchScreenButton:
	var text=""
	func _draw() -> void:
		draw_circle(Vector2.ZERO,34,Color(0.22,0.29,0.24,0.9) if is_pressed() else Color(0.04,0.07,0.06,0.55))
		draw_arc(Vector2.ZERO,34,0,TAU,32,Color(0.75,0.75,0.62,0.7),1.5)
		draw_string(ThemeDB.fallback_font,Vector2(-26,5),text,HORIZONTAL_ALIGNMENT_CENTER,52,13,Color("e5dfcf"))

func _ready() -> void:
	layer=25
	if not (DisplayServer.is_touchscreen_available() or OS.has_feature("android") or "--touch-test" in OS.get_cmdline_user_args()): return
	var stick=Stick.new(); stick.size=Vector2(150,150); add_child(stick); controls.append(stick)
	for action in ["attack","skill","dodge","use"]:
		var button=Action.new(); button.action=action; button.text={"attack":"ATTACK","skill":"SKILL","dodge":"DODGE","use":"USE"}[action]
		var shape=CircleShape2D.new(); shape.radius=38; button.shape=shape; button.pressed.connect(button.queue_redraw); button.released.connect(button.queue_redraw)
		add_child(button); controls.append(button)
	_arrange(); get_viewport().size_changed.connect(_arrange)

func _arrange() -> void:
	if controls.is_empty(): return
	var size=get_viewport().get_visible_rect().size
	controls[0].position=Vector2(30,size.y-190)
	var positions=[Vector2(size.x-75,size.y-100),Vector2(size.x-155,size.y-165),Vector2(size.x-235,size.y-100),Vector2(size.x-75,size.y-245)]
	for i in range(1,5): controls[i].position=positions[i-1]

func _process(_delta: float) -> void:
	var active=not Campaign.modal_open and not Campaign.input_locked
	for control in controls: control.visible=active
	if not active: _release()

func _release() -> void:
	for action in ACTIONS: Input.action_release(action)
	for control in controls:
		if is_instance_valid(control) and control is Stick:
			control.finger=-1; control._release()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: _release()

func _exit_tree() -> void: _release()
