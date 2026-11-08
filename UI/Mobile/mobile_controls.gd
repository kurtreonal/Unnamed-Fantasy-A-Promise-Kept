extends CanvasLayer
## Multi-touch controls, present only in exploration scenes on touch devices.

const ACTIONS := ["Up", "Down", "Left", "Right", "Sword_Attack", "interact", "Switch_Element", "Switch_Weapon", "Switch_Skill", "Recall"]
var _buttons: Dictionary = {}

class ActionButton extends TouchScreenButton:
	func _draw() -> void:
		var fill := Color(0.12, 0.15, 0.21, 0.9) if is_pressed() else Color(0.05, 0.07, 0.11, 0.72)
		draw_circle(Vector2.ZERO, 40.0, fill)
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(0.85, 0.77, 0.56, 0.9), 2.0, true)

func _ready() -> void:
	layer = 20
	if not (OS.has_feature("android") or DisplayServer.is_touchscreen_available()):
		return
	_build_controls()
	get_viewport().size_changed.connect(_arrange)

func _build_controls() -> void:
	for action in ACTIONS:
		var button := ActionButton.new()
		button.action = action
		button.name = action
		button.shape = CircleShape2D.new()
		button.shape.radius = 42.0
		button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		button.pressed.connect(button.queue_redraw)
		button.released.connect(button.queue_redraw)
		var label := Label.new()
		label.text = {"Up": "UP", "Down": "DOWN", "Left": "LEFT", "Right": "RIGHT", "Sword_Attack": "ATTACK", "interact": "USE", "Switch_Element": "ELEMENT", "Switch_Weapon": "WEAPON", "Switch_Skill": "SKILL", "Recall": "HOME"}[action]
		label.position = Vector2(-42, -14)
		label.size = Vector2(84, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		add_child(button)
		_buttons[action] = button
	_arrange()

func _arrange() -> void:
	if _buttons.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	var positions := {
		"Up": Vector2(132, size.y - 222),
		"Left": Vector2(44, size.y - 134),
		"Down": Vector2(132, size.y - 134),
		"Right": Vector2(220, size.y - 134),
		"Sword_Attack": Vector2(size.x - 66, size.y - 112),
		"interact": Vector2(size.x - 154, size.y - 200),
		"Switch_Element": Vector2(size.x - 242, size.y - 112),
		"Switch_Weapon": Vector2(size.x - 242, size.y - 288),
		"Switch_Skill": Vector2(size.x - 154, size.y - 112),
		"Recall": Vector2(size.x - 66, size.y - 288),
	}
	for action in _buttons:
		_buttons[action].position = positions[action]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_actions()

func _exit_tree() -> void:
	_release_actions()

func _release_actions() -> void:
	for action in _buttons:
		Input.action_release(action)
