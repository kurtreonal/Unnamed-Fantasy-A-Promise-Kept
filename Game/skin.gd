extends RefCounted
class_name PromiseSkin
const INK = Color("222222")
const MUTED = Color("626262")
const GOLD = Color("303030")
const PAPER = Color("fafafa")

static func theme() -> Theme:
	var result=Theme.new()
	result.default_font=ThemeDB.fallback_font
	result.default_font_size=18
	for type in ["Label","Button","RichTextLabel","CheckButton"]:
		result.set_color("font_color",type,INK)
	result.set_color("font_hover_color","Button",Color.BLACK)
	result.set_color("font_focus_color","Button",Color.BLACK)
	result.set_color("font_pressed_color","Button",Color.BLACK)
	result.set_color("default_color","RichTextLabel",INK)
	result.set_color("font_disabled_color","Button",Color("747b70"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color(1,1,1,0.97) if state=="normal" else Color(0.87,0.87,0.87,0.98)
		style.border_color=Color.BLACK if state in ["hover","focus"] else Color("555555")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left=18; style.content_margin_right=18; style.content_margin_top=10; style.content_margin_bottom=10
		result.set_stylebox(state,"Button",style)
	var panel=StyleBoxFlat.new()
	panel.bg_color=Color(1,1,1,0.97); panel.border_color=Color("333333"); panel.set_border_width_all(1); panel.set_content_margin_all(16)
	result.set_stylebox("panel","PanelContainer",panel)
	return result

static func label(text: String, size := 22, color := INK) -> Label:
	var node=Label.new(); node.text=text; node.add_theme_font_size_override("font_size",size); node.add_theme_color_override("font_color",color)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable) -> Button:
	var node=Button.new(); node.text=text; node.custom_minimum_size.y=48; node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; node.pressed.connect(callback)
	return node

static func fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func image(path: String) -> TextureRect:
	var node=TextureRect.new(); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path): node.texture=load(path)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return node
