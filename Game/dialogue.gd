extends CanvasLayer
## Custom cinematic layout driven by Dialogic timelines and its auto-skip engine.
signal closed
var event: Dictionary = {}
var speaker: Label
var body: DialogicNode_DialogText
var choices: VBoxContainer
var skip_button: Button
var hint: Label
var hold_time = 0.0
var pointer_held = false
var protected_scene = false
var release_required = true
var done = false
var choices_ready = false
var portrait: TextureRect
var on_finish: Callable
var illustration: TextureRect

func _ready() -> void:
	layer=80
	Campaign.input_locked=true
	var root=Control.new(); PromiseSkin.fill(root); root.theme=PromiseSkin.theme(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	illustration=PromiseSkin.image(""); PromiseSkin.fill(illustration); illustration.hide(); root.add_child(illustration)
	portrait=PromiseSkin.image("res://Game/Art/Illustrations/rin_conversation.png")
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	portrait.position=Vector2(-560,-680); portrait.size=Vector2(560,700)
	root.add_child(portrait)
	var panel=PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); panel.offset_left=36; panel.offset_right=-36; panel.offset_top=-150; panel.offset_bottom=-20; root.add_child(panel)
	var dialogue_style=StyleBoxFlat.new(); dialogue_style.bg_color=Color(0.13,0.13,0.13,0.94); dialogue_style.border_color=Color("777777"); dialogue_style.set_border_width_all(1); dialogue_style.set_content_margin_all(10); panel.add_theme_stylebox_override("panel",dialogue_style)
	var content=VBoxContainer.new(); content.add_theme_constant_override("separation",4); panel.add_child(content)
	speaker=PromiseSkin.label("",18,Color.WHITE); content.add_child(speaker)
	body=DialogicNode_DialogText.new(); body.custom_minimum_size.y=46; body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.start_hidden=false; body.auto_visibility=false; body.mouse_filter=Control.MOUSE_FILTER_IGNORE; body.add_theme_font_size_override("normal_font_size",18); body.add_theme_color_override("default_color",Color.WHITE); content.add_child(body)
	var row=HBoxContainer.new(); content.add_child(row)
	hint=PromiseSkin.label("Enter / Space · continue",14,Color("c8c8c8")); hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(hint)
	skip_button=PromiseSkin.button("Hold to skip",func(): pass)
	skip_button.custom_minimum_size.y=28; skip_button.add_theme_font_size_override("font_size",14)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style=StyleBoxFlat.new(); style.bg_color=Color("dddddd"); style.border_color=Color("777777"); style.set_border_width_all(1); style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=3; style.content_margin_bottom=3; skip_button.add_theme_stylebox_override(state,style)
	skip_button.button_down.connect(func():pointer_held=true)
	skip_button.button_up.connect(func():pointer_held=false)
	row.add_child(skip_button)
	choices=VBoxContainer.new(); choices.position=Vector2(300,250); choices.size=Vector2(500,0); root.add_child(choices)
	Dialogic.signal_event.connect(_signal)
	Dialogic.timeline_ended.connect(_ended)
	# This layout owns its teardown. Dialogic's default [clear] ending would
	# instantiate the retired VN layout just to animate it out.
	Dialogic.dialog_ending_timeline=null
	Dialogic.Inputs.auto_skip.disable_on_user_input=false
	Dialogic.Inputs.auto_skip.time_per_event=0.10
	ProjectSettings.set_setting("dialogic/text/input_action","advance")

func play(data: Dictionary, callback := Callable()) -> void:
	event=data; on_finish=callback
	var timeline=DialogicTimeline.new()
	var start_index=0
	if Campaign.dialogue.get("id","")==str(event.get("id","")): start_index=int(Campaign.dialogue.get("index",0))
	var lines: Array=event.get("lines",[])
	var text=""
	for i in range(start_index,lines.size()):
		var parts=str(lines[i]).split("|",true,1)
		var who=parts[0] if parts.size()>1 else ""
		var words=parts[1] if parts.size()>1 else parts[0]
		var critical=bool(event.get("critical",false))
		if str(event.get("id",""))=="prologue": critical=i in [2,3,7,8]
		text+='[signal arg="line:%d:%s:%s"]\n' % [i,who,"protected" if critical else "routine"]
		text+=words.replace("\n"," ")+"\n"
	timeline.from_text(text)
	var source="res://Game/Timelines/"+str(event.get("id",""))+".dtl"
	if ResourceLoader.exists(source):
		timeline=load(source)
		Dialogic.start_timeline(timeline,"line_"+str(start_index))
	else: Dialogic.start_timeline(timeline)

func _signal(arg: Variant) -> void:
	if done: return
	var value=str(arg)
	if not value.begins_with("line:"): return
	var parts=value.split(":",true,3)
	speaker.text=parts[2]
	var new_protected=parts[3]=="protected"
	if new_protected!=protected_scene or new_protected:
		release_required=true; hold_time=0; Dialogic.Inputs.auto_skip.enabled=false
	protected_scene=new_protected
	skip_button.disabled=protected_scene
	hint.text="Important moment · press to continue" if protected_scene else "Enter / Space · continue   ·   Hold to skip"
	Campaign.dialogue={"id":event.get("id",""),"index":int(parts[1]),"event":event}
	Campaign.save_game()
	var id=str(event.get("id",""))
	portrait.visible=not id.begins_with("boss_intro_") and (id!="prologue" or int(parts[1])>=6)
	portrait.modulate.a=1.0 if speaker.text=="Rin" else 0.85
	var artwork={"e03":"event_atlas","e15":"event_greenhouse","ending_lanterns":"event_lanterns"}.get(str(event.get("id","")),"")
	if str(event.get("id",""))=="prologue" and int(parts[1])<4: artwork="event_promise"
	var art_path="res://Game/Art/Illustrations/"+str(artwork)+".png"
	illustration.visible=artwork!="" and ResourceLoader.exists(art_path)
	if illustration.visible: illustration.texture=load(art_path)

func _process(delta: float) -> void:
	var held=Input.is_action_pressed("advance") or pointer_held
	if not held:
		hold_time=0; release_required=false; Dialogic.Inputs.auto_skip.enabled=false
		if done and not choices_ready and choices.get_child_count()>0:
			choices_ready=true
			for button in choices.get_children(): button.disabled=false
			choices.get_child(0).grab_focus()
		return
	if done or protected_scene or release_required: return
	hold_time+=delta
	if hold_time>=0.35: Dialogic.Inputs.auto_skip.enabled=true

func _input(input: InputEvent) -> void:
	if done: return
	if input.is_action("advance"):
		if input.is_action_pressed("advance") and not input.is_echo() and not release_required: Dialogic.Inputs.handle_input()
		get_viewport().set_input_as_handled()
		return
	if input is InputEventMouseButton and input.pressed and input.button_index==MOUSE_BUTTON_LEFT and get_viewport().get_mouse_position().y>get_viewport().get_visible_rect().size.y-150:
		if not release_required: Dialogic.Inputs.handle_input()
		get_viewport().set_input_as_handled()

func _ended() -> void:
	if done: return
	done=true; Dialogic.Inputs.auto_skip.enabled=false; release_required=true
	var options: Array=event.get("choices",[])
	if options.is_empty():
		_finish()
		return
	hint.text="Choose your response"
	for index in range(options.size()):
		var button=PromiseSkin.button(str(options[index].text),_choose.bind(index))
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.disabled=true
		choices.add_child(button)

func _choose(index: int) -> void:
	if not Campaign.commit_event(str(event.get("id","")),index): return
	_finish()

func _finish() -> void:
	done=true; Dialogic.Inputs.auto_skip.enabled=false
	if Dialogic.current_timeline!=null: Dialogic.end_timeline(true)
	Campaign.dialogue={}; Campaign.input_locked=false
	if on_finish.is_valid(): on_finish.call()
	Campaign.save_game()
	closed.emit()
	queue_free()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer_held=false; hold_time=0; release_required=true
		if is_instance_valid(Dialogic): Dialogic.Inputs.auto_skip.enabled=false

func _exit_tree() -> void:
	if Dialogic.signal_event.is_connected(_signal): Dialogic.signal_event.disconnect(_signal)
	if Dialogic.timeline_ended.is_connected(_ended): Dialogic.timeline_ended.disconnect(_ended)
	Dialogic.Inputs.auto_skip.enabled=false
	if Dialogic.current_timeline: Dialogic.end_timeline(true)
	Campaign.input_locked=false
