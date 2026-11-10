extends Control
## Screen composition. Campaign owns state; this layer only requests transactions.
const Dialogue = preload("res://Game/dialogue.gd")
const Field = preload("res://Game/field.gd")
const BG = "res://Game/Art/Backgrounds/"
const BG2 = "res://Game/Art/Backgrounds/"
var screen: Control
var overlay: CanvasLayer
var modal: Control
var field: Node2D
var toast: Label
var toast_timer = 0.0
var hud_hp: Label
var hud_details: Label
var context: Label
var screen_name = ""
var header: Label
var relationship_summary: Label
var quest_summary: Label
var capture_action = ""
var hotspot_controls: Array = []
var clock_accumulator = 0.0
var ending_titles={"promise_kept":"A Promise Kept","beside_you":"Beside You","another_spring":"Another Spring","lanterns":"Lanterns Beyond the Gate","her_tomorrow":"Her Own Tomorrow"}

func _ready() -> void:
	theme=PromiseSkin.theme()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay=CanvasLayer.new(); overlay.layer=40; add_child(overlay)
	var notifications=Control.new(); PromiseSkin.fill(notifications); notifications.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(notifications)
	toast=PromiseSkin.label("",19,PromiseSkin.INK); toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); toast.offset_top=133; toast.offset_left=40; toast.offset_right=-40; toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notifications.add_child(toast)
	Campaign.notice.connect(_notice)
	Campaign.changed.connect(_state_changed)
	menu()
	if "--redesign-smoke" in OS.get_cmdline_user_args(): call_deferred("_runtime_smoke")

func _clear(name: String) -> void:
	_close_modal()
	if is_instance_valid(field): field.queue_free(); field=null
	if is_instance_valid(screen): remove_child(screen); screen.queue_free()
	screen=Control.new(); PromiseSkin.fill(screen); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(screen)
	screen_name=name; hotspot_controls=[]; hud_hp=null; hud_details=null; context=null
	header=null; relationship_summary=null; quest_summary=null

func _background(path: String, shade := 0.0) -> void:
	var picture=PromiseSkin.image(path); PromiseSkin.fill(picture); screen.add_child(picture)
	if shade>0:
		var veil=ColorRect.new(); veil.color=Color(0.025,0.055,0.045,shade); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; PromiseSkin.fill(veil); screen.add_child(veil)

func _compact_header(at_home: bool) -> void:
	var bar=ColorRect.new(); bar.color=Color("141414"); bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); bar.offset_bottom=36; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; bar.set_meta("persistent_hud",true); screen.add_child(bar)
	var row=HBoxContainer.new(); row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); row.offset_left=16; row.offset_right=-16; row.offset_top=2; row.offset_bottom=34; row.set_meta("persistent_hud",true); screen.add_child(row)
	header=PromiseSkin.label("",16,Color.WHITE); header.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(header)
	var menu_button=PromiseSkin.button("Menu",func():
		if not Campaign.input_locked: _pause())
	menu_button.custom_minimum_size=Vector2(70,30); menu_button.add_theme_font_size_override("font_size",16); menu_button.add_theme_color_override("font_color",Color.WHITE); menu_button.add_theme_color_override("font_hover_color",Color.WHITE)
	menu_button.add_theme_color_override("font_focus_color",Color.WHITE); menu_button.add_theme_color_override("font_pressed_color",Color.WHITE)
	var empty=StyleBoxEmpty.new(); menu_button.add_theme_stylebox_override("normal",empty); menu_button.add_theme_stylebox_override("hover",empty); row.add_child(menu_button)
	if at_home:
		for index in range(2):
			var panel=PanelContainer.new(); panel.position=Vector2(16+index*254,46); panel.size=Vector2(244 if index==0 else 330,72); panel.set_meta("persistent_hud",true); screen.add_child(panel)
			var label=PromiseSkin.label("",15,PromiseSkin.INK); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; panel.add_child(label)
			if index==0: relationship_summary=label
			else: quest_summary=label
	_refresh_header()

func _refresh_header() -> void:
	if is_instance_valid(header):
		var health_text="Wellbeing %d/100" % Campaign.health if screen_name=="home" else "HP %d/%d" % [Campaign.player_hp,Campaign.max_hp()]
		header.text="Day %d   %s     %s     %s     %dg" % [Campaign.day,Campaign.clock(),Campaign.catalog.chapters[Campaign.chapter()],health_text,Campaign.coins]
	if is_instance_valid(relationship_summary):
		var mood="Tired" if Campaign.health<30 else ("Content" if Campaign.affection>=40 else "Calm")
		relationship_summary.text="Affection %d    Love %d\nMood: %s" % [Campaign.affection,Campaign.love,mood]
	if is_instance_valid(quest_summary):
		var active=Campaign.active_quests()
		quest_summary.text="Spring journal\n"+(str(active[0].title) if not active.is_empty() else "Make time for each other.")

func _music(path: String) -> void:
	MusicPlayer.play(load(path))

func menu() -> void:
	_clear("menu")
	_background(BG+"Livingroom_Day.png",0.0)
	_music("res://BGM/Sickly_Days_and_Summer_Traces_trailer.mp3")
	var paper=Panel.new(); paper.position=Vector2(70,120); paper.size=Vector2(520,575)
	var paper_style=StyleBoxFlat.new(); paper_style.bg_color=Color(1,1,1,0.96); paper_style.border_color=Color("333333"); paper_style.set_border_width_all(1); paper.add_theme_stylebox_override("panel",paper_style); screen.add_child(paper)
	var column=VBoxContainer.new(); column.position=Vector2(95,140); column.size=Vector2(440,0); column.add_theme_constant_override("separation",13); screen.add_child(column)
	column.add_child(PromiseSkin.label("A PROMISE KEPT",48))
	column.add_child(PromiseSkin.label("An ordinary life. A promise worth sharing.",21,PromiseSkin.MUTED))
	column.add_spacer(false)
	column.add_child(PromiseSkin.button("Begin a new story",_new_game))
	var resume=PromiseSkin.button("Continue",_continue)
	resume.disabled=not FileAccess.file_exists(Campaign.SAVE_DIR+"autosave.json"); column.add_child(resume)
	column.add_child(PromiseSkin.button("Save stories",func():_slots(false)))
	column.add_child(PromiseSkin.button("Settings",_settings))
	column.add_child(PromiseSkin.button("Credits",_credits))
	if not OS.has_feature("web"): column.add_child(PromiseSkin.button("Quit",func():get_tree().quit()))
	var footer=PromiseSkin.label("STORY & GAMEPLAY REDESIGN  ·  0.2.0",15,PromiseSkin.MUTED); footer.position=Vector2(95,667); screen.add_child(footer)
	column.get_child(3).grab_focus()

func _new_game() -> void:
	Campaign.reset(); home()
	var prologue={"id":"prologue","title":"The Same Promise","critical":false,"lines":[
		"Narrator|Eight years ago, on a night of rain and candlelight, Rin’s father asked you never to let his daughter believe she was alone.",
		"Father|Let her know she belongs somewhere. Make sure she can truly smile.",
		"You|I promise.",
		"Narrator|Your family made a place for her. You grew up together, through school days, shared homework, and ordinary breakfasts. The promise stayed.",
		"Narrator|Now you and Rin are both seventeen, high-school classmates at the village academy. Spring recess has begun, but her illness has kept her away from the things she loves.",
		"Narrator|Her illness has made those mornings harder. The village healers can ease the symptoms, but the old sanctuary records describe a possible cure.",
		"Rin|If you are going to search, let me help you understand what you find.",
		"You|Then we do this together.",
		"Rin|And promise me something else. Do not forget to live while you are trying to save me.",
		"Narrator|Twenty-eight days until classes resume and the spring physicians leave the valley. Time enough for hope, and for the ordinary things hope is made of."
	]}
	_show_dialogue(prologue)

func _continue() -> void:
	if not Campaign.load_game(): _notice("The save could not be read."); return
	_resume()

func _resume() -> void:
	if Campaign.ending!="": _ending(Campaign.ending); return
	if Campaign.phase=="expedition": explore()
	else: home()
	if not Campaign.dialogue.is_empty():
		var saved: Dictionary=Campaign.dialogue.get("event",{})
		if not saved.is_empty(): _show_dialogue(saved)

func home() -> void:
	_clear("home")
	var pose=_rin_pose()
	_background(BG+"Livingroom_Day.png",0.0)
	_music("res://BGM/Sea, You Next - night.mp3" if Campaign.phase=="evening" else "res://BGM/坂の上の陽炎 - morning 2.mp3")
	_compact_header(true)
	var rin=PromiseSkin.image("res://Game/Art/Illustrations/rin_"+pose+".png")
	rin.name="RinIllustration"
	rin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; rin.position=Vector2(620,366); rin.size=Vector2(240,350); screen.add_child(rin)
	# The source pelvis (255,408) lands on the sofa cushion at approximately (740,552).
	var contact=Polygon2D.new(); var outline=PackedVector2Array()
	for point in range(32):
		var angle=TAU*point/32.0; outline.append(Vector2(120,186)+Vector2(cos(angle)*46,sin(angle)*7))
	contact.polygon=outline; contact.color=Color(0.08,0.06,0.04,0.16); contact.show_behind_parent=true; rin.add_child(contact)
	var rin_button=_hotspot("Rin",Rect2(rin.position,rin.size),_rin_interact)
	rin_button.tooltip_text="Spend time with Rin · "+pose.capitalize()
	_hotspot("Kitchen · meals",Rect2(38,450,240,75),_meals)
	_hotspot("Table · shared activities",Rect2(38,540,310,75),_activities)
	_hotspot("Notes · treatment",Rect2(920,465,300,65),_treatment)
	if Campaign.phase=="morning": _hotspot("Door · prepare to leave",Rect2(920,550,300,65),_routes)
	else: _hotspot("Bedroom · rest",Rect2(920,550,300,65),_sleep)
	var hint=PromiseSkin.label("Click Rin to talk  ·  H: show interactions  ·  Menu: activities and meals",15,PromiseSkin.MUTED); hint.position=Vector2(22,690); screen.add_child(hint)

func _rin_pose() -> String:
	return "seated"

func _hotspot(text: String, rect: Rect2, callback: Callable) -> Button:
	var node=PromiseSkin.button(text,callback); node.position=rect.position; node.size=rect.size
	var transparent=StyleBoxEmpty.new(); node.add_theme_stylebox_override("normal",transparent)
	node.add_theme_color_override("font_color",PromiseSkin.GOLD if Campaign.settings.hotspots else Color(1,1,1,0))
	node.add_theme_color_override("font_hover_color",PromiseSkin.INK); node.add_theme_color_override("font_focus_color",PromiseSkin.INK)
	node.mouse_entered.connect(func():node.add_theme_color_override("font_color",PromiseSkin.INK))
	node.mouse_exited.connect(func():node.add_theme_color_override("font_color",PromiseSkin.GOLD if Campaign.settings.hotspots else Color(1,1,1,0)))
	screen.add_child(node); hotspot_controls.append(node)
	return node

func _rin_interact() -> void:
	if not Campaign.dialogue.is_empty():
		_show_dialogue(Campaign.dialogue.get("event",{})); return
	if Campaign.daily.has("activity:talk"):
		_show_dialogue({"id":"home_greeting","critical":false,"lines":["Rin|Welcome back. What would you like to do together?"]},_activities)
		return
	_perform_activity("talk")

func _perform_activity(id: String) -> void:
	var result=Campaign.activity(id)
	if not result.ok: _notice(result.reason); return
	_close_modal()
	var event: Dictionary=result.event
	if event.is_empty():
		event={"id":"routine_"+id,"critical":false,"lines":["Narrator|"+str(result.activity.hint),"Rin|I am glad we made time for this.","You|So am I."]}
	_show_dialogue(event,func():home())

func _show_dialogue(event: Dictionary, callback := Callable()) -> void:
	if event.is_empty(): return
	var hidden_controls: Array=screen.get_children().filter(func(node):return node is Control and not node.get_meta("persistent_hud",false) and (node.name=="RinIllustration" or (not node is TextureRect and not node is ColorRect)))
	for control in hidden_controls: control.hide()
	var dialogue=Dialogue.new(); add_child(dialogue)
	dialogue.closed.connect(func():
		for control in hidden_controls:
			if is_instance_valid(control): control.show())
	dialogue.play(event,callback)

func _open_panel(title: String) -> VBoxContainer:
	_close_modal(); Campaign.modal_open=true
	if is_instance_valid(field):
		for controls in field.get_children():
			if controls.has_method("_release"): controls._release()
	modal=Control.new(); PromiseSkin.fill(modal); modal.theme=theme; overlay.add_child(modal)
	var veil=ColorRect.new(); veil.color=Color(0.025,0.04,0.035,0.64); PromiseSkin.fill(veil); modal.add_child(veil)
	var panel=PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.offset_left=190; panel.offset_right=-190; panel.offset_top=60; panel.offset_bottom=-60; modal.add_child(panel)
	var stack=VBoxContainer.new(); stack.add_theme_constant_override("separation",10); panel.add_child(stack)
	var header=HBoxContainer.new(); stack.add_child(header)
	var label=PromiseSkin.label(title,32,PromiseSkin.GOLD); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(label)
	header.add_child(PromiseSkin.button("Close",_close_modal))
	var scroll=ScrollContainer.new(); scroll.name="ContentScroll"; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; stack.add_child(scroll)
	var body=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",10); scroll.add_child(body)
	header.get_child(1).grab_focus()
	return body

func _text(parent: Node, text: String, size := 21, color := PromiseSkin.INK) -> Label:
	var label=PromiseSkin.label(text,size,color); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(label); return label

func _npc(parent: Node, id: String, words: String) -> void:
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",18); parent.add_child(row)
	var portrait=PromiseSkin.image("res://Game/Art/Illustrations/npc_"+id+".png"); portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.custom_minimum_size=Vector2(100,130); row.add_child(portrait)
	_text(row,words,21,PromiseSkin.MUTED)

func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free(); modal=null
	Campaign.modal_open=false; capture_action=""

func _activities() -> void:
	var box=_open_panel("Time together")
	_text(box,"Choose something you both have time and energy for. Each activity takes one hour.")
	for a in Campaign.catalog.activities:
		var button=PromiseSkin.button(a.name+" · 1 hour",_perform_activity.bind(a.id)); button.disabled=Campaign.daily.has("activity:"+a.id); box.add_child(button)
	_text(box,"Some conversations grow from shared routines. Reading, gardening, research, and stargazing may reveal more than first appears.",18,PromiseSkin.MUTED)

func _meals() -> void:
	var box=_open_panel("A meal for two")
	_text(box,"Pantry porridge is always available. Gather ingredients or visit the village shop for other recipes.")
	for recipe in Campaign.catalog.recipes:
		var ingredients=[]
		for id in recipe.ingredients: ingredients.append("%s %d/%d" % [Campaign.item_name(id),Campaign.quantity(id),recipe.ingredients[id]])
		_text(box,recipe.name+" · Health +%d" % recipe.health,23,PromiseSkin.GOLD)
		_text(box,recipe.description+"  "+", ".join(ingredients),18,PromiseSkin.MUTED)
		var button=PromiseSkin.button("Prepare and share",_eat.bind(recipe.id)); button.disabled=Campaign.daily.has("meal:"+Campaign.phase); box.add_child(button)

func _eat(id: String) -> void:
	var result=Campaign.eat(id)
	if not result.ok: _notice(result.reason); return
	_close_modal()
	_show_dialogue({"id":"meal_"+id,"critical":false,"lines":["Narrator|You set two places and share "+str(result.recipe.name).to_lower()+".","Rin|Stay a moment. There is no need to hurry through this part of the day.","Narrator|Outside, the world keeps moving. For now, the table is enough."]},func():home())

func _routes() -> void:
	var box=_open_panel("Beyond the village")
	_text(box,"Return before 18:00. Exploration pauses while a menu or story is open. Recall takes four uninterrupted seconds.")
	for route in Campaign.catalog.regions:
		var button=PromiseSkin.button(route.name+" · available day %d" % route.day,_depart.bind(int(route.id))); button.disabled=Campaign.day<int(route.day); box.add_child(button)
	box.add_child(PromiseSkin.button("Spend a quiet afternoon at home",func():Campaign.stay_home(); home()))
	_text(box,"Equip one weapon from your inventory before leaving. Supplies and equipment stay with you after a defeat.",19,PromiseSkin.MUTED)
	box.add_child(PromiseSkin.button("Check equipment",_inventory))

func _depart(id: int) -> void:
	var result=Campaign.depart(id)
	if not result.ok: _notice(result.reason); return
	explore()

func explore() -> void:
	_clear("field")
	field=Field.new(); add_child(field); move_child(field,0)
	field.returned.connect(home)
	field.story_requested.connect(_field_story)
	_music("res://BGM/LVS04_04_Sealed_Sanctuary.mp3")
	_compact_header(false)
	hud_details=PromiseSkin.label("",18,PromiseSkin.GOLD); hud_details.position=Vector2(28,80); screen.add_child(hud_details)
	context=PromiseSkin.label("",20); context.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); context.offset_top=-78; context.offset_bottom=-40; context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; screen.add_child(context)
	_state_changed()
	_notice(Campaign.catalog.regions[Campaign.region].name)

func _field_story(data: Dictionary) -> void:
	_show_dialogue(data,func():
		if is_instance_valid(field): field.restore_camera())

func _inventory() -> void:
	var box=_open_panel("Your pack")
	_text(box,"%dg · %s equipped" % [Campaign.coins,Campaign.weapon().name],23,PromiseSkin.GOLD)
	for id in Campaign.inventory:
		if Campaign.quantity(id)<=0: continue
		var item: Dictionary=Campaign.catalog.items.get(id,{})
		var kind: String=item.get("kind","")
		if kind in ["weapon","armor","accessory"]:
			var detail=" · ATK %d" % int(item.get("attack",0)) if kind=="weapon" else (" · DEF %d" % int(item.get("defense",0)) if kind=="armor" else " · HP +%d" % int(item.get("max_hp",0)))
			var button=PromiseSkin.button(item.name+detail+(" · equipped" if Campaign.equipment.get(kind,"")==id else " · equip"),_equip.bind(id)); button.disabled=Campaign.equipment.get(kind,"")==id; box.add_child(button)
		else: _text(box,"%s ×%d" % [Campaign.item_name(id),Campaign.quantity(id)],20,PromiseSkin.MUTED)
	box.add_child(PromiseSkin.button("Drink restorative tea · +45 HP",func():
		if not Campaign.heal(): _notice("You do not need healing, or have no restorative tea.")
		_inventory()))

func _equip(id: String) -> void:
	var result=Campaign.equip(id)
	if result.ok: _inventory()
	else: _notice(result.reason)

func _journal() -> void:
	var box=_open_panel("The spring journal")
	_npc(box,"archivist","Look at the dates in the margins. People leave the important things out of headings.")
	_text(box,"Day %d of 28 · %s · %s" % [Campaign.day,Campaign.clock(),Campaign.catalog.chapters[Campaign.chapter()]],23,PromiseSkin.GOLD)
	_text(box,"Find the three treatment records, study them together, prepare medicine, and complete the Elixir of Spring before the physicians leave.")
	for quest in Campaign.active_quests():
		_text(box,("STORY · " if quest.kind=="main" else "VILLAGE · ")+quest.title,23,PromiseSkin.GOLD)
		_text(box,"%s  (%d/%d)" % [quest.description,Campaign.quest_progress.get(quest.id,0),quest.count],20)
	_text(box,"Completed requests: %d / 24" % Campaign.completed.size(),20,PromiseSkin.MUTED)
	_text(box,"A road beyond the gate begins with an atlas. A future of her own begins with seeds and a voice in the research.",19,PromiseSkin.MUTED)

func _relationship() -> void:
	var box=_open_panel("Rin · the life you share")
	for entry in [["Affection",Campaign.affection],["Love",Campaign.love],["Wellbeing",Campaign.health]]:
		_text(box,"%s · %d / 100" % [entry[0],entry[1]],24,PromiseSkin.GOLD)
		var bar=ProgressBar.new(); bar.value=entry[1]; bar.show_percentage=false; bar.custom_minimum_size.y=12; box.add_child(bar)
	_text(box,"Affection grows through daily care and attention. Love grows through unique conversations and choices. Neither is a debt to repay.",21)
	_text(box,"Shared memories · %d / 24" % Campaign.seen_events.size(),23,PromiseSkin.GOLD)
	for event in Campaign.catalog.events:
		if event.id in Campaign.seen_events: _text(box,event.title,19,PromiseSkin.MUTED)

func _shop(scroll_position := 0) -> void:
	var box=_open_panel("Village provisions · %dg" % Campaign.coins)
	_npc(box,"merchant","The valley roads are muddy. Take enough provisions, and come home before the light goes.")
	_text(box,"The merchant carries practical supplies and equipment. Stock improves as spring unfolds.")
	var item_ids: Array=Campaign.catalog.items.keys()
	var order={"ingredient":0,"consumable":1,"armor":2,"weapon":3,"accessory":4,"quest":5}
	item_ids.sort_custom(func(a,b):return int(order.get(Campaign.catalog.items[a].kind,5))<int(order.get(Campaign.catalog.items[b].kind,5)))
	for id in item_ids:
		var item: Dictionary=Campaign.catalog.items[id]
		if int(item.price)<=0 or int(item.get("tier",1))>Campaign.chapter()+1: continue
		var button=PromiseSkin.button("%s · %dg" % [item.name,item.price],_buy.bind(id)); button.disabled=Campaign.coins<int(item.price); box.add_child(button)
	box.get_parent().set_deferred("scroll_vertical",scroll_position)

func _buy(id: String) -> void:
	var scroll=modal.find_child("ContentScroll",true,false)
	var previous_position=scroll.scroll_vertical if scroll else 0
	var result=Campaign.buy(id)
	if result.ok: _shop(previous_position)
	else: _notice(result.reason)

func _treatment() -> void:
	var box=_open_panel("The treatment notebook")
	_npc(box,"healer","The records describe methods, not miracles. Keep notes, and ask Rin how she wants to proceed.")
	_text(box,"Rin studies each record with you. Follow the story requests in the journal to uncover the complete formula.")
	for id in ["moss","moonstone","sunpetal","forest_seal","mine_seal","ruin_seal"]: _text(box,"%s ×%d" % [Campaign.item_name(id),Campaign.quantity(id)],20)
	box.add_child(PromiseSkin.button("Prepare herbal medicine · 2 herbs + 1 silver moss",_craft.bind("medicine")))
	box.add_child(PromiseSkin.button("Prepare Elixir of Spring · three records + three of each rare ingredient",_craft.bind("cure")))
	box.add_child(PromiseSkin.button("Study together · 1 hour",_perform_activity.bind("research")))

func _craft(id: String) -> void:
	var result=Campaign.craft(id)
	if result.ok: _notice(Campaign.item_name(id)+" prepared."); _treatment()
	else: _notice(result.reason)

func _sleep() -> void:
	var result=Campaign.sleep()
	if not result.ok: _notice(result.reason); return
	if result.finale: _finale()
	else: home()

func _finale() -> void:
	var box=_open_panel("Tomorrow is yours to choose")
	_text(box,"The physicians leave at dawn. You and Rin sit beside the window and speak of the days ahead.")
	for id in Campaign.ending_options(): box.add_child(PromiseSkin.button(ending_titles[id],_ending.bind(id)))

func _ending(id: String) -> void:
	if not id in Campaign.ending_options(): return
	Campaign.ending=id; Campaign.save_game()
	_clear("ending"); _background(BG+"Sitting_Room.png",0.45)
	_music("res://BGM/Sea, You & Me.mp3")
	var passages={
		"promise_kept":["Narrator|The treatment works slowly. There is no miracle morning, only a little more strength each day.","Rin|You kept your promise. Now let us make one that belongs only to us.","You|An ordinary life, together. With room for both of us to grow.","Narrator|She reaches for your hand. Beyond the window, the rosemary is flowering."],
		"beside_you":["Narrator|The physicians leave a treatment plan and a promise of follow-up letters.","Rin|We do not have to call this anything it is not.","You|Then let us call it home.","Narrator|There are many ways to keep a promise. This one has two chairs beside the window."],
		"another_spring":["Narrator|The final formula remains unfinished, but the records you recovered give the physicians a place to begin.","Rin|I do not want you to remember this spring as a failure.","You|Then I will remember the mornings we made room for each other.","Narrator|There will be more appointments, more questions, and more difficult days. Tomorrow still belongs to both of you."],
		"lanterns":["Narrator|On a free Saturday after classes resume, the river town is real beneath your feet. Paper lanterns move across the water like patient stars.","You|Will you tell me your wish now?","Rin|I wanted to stand somewhere neither of us had been afraid.","Narrator|She kisses your cheek, takes your hand, and chooses the next road."],
		"her_tomorrow":["Narrator|The village greenhouse smells of wet earth and rosemary. Rin has a workbench of her own; her schoolbag hangs beside it.","Rin|I have a life to build. Some days I will need help. Some days you will.","You|I would like to be here for both.","Narrator|She opens her research book beside her class notes. The next page is hers to write."]}
	_show_dialogue({"id":"ending_"+id,"critical":true,"lines":passages[id]},func():
		var box=_open_panel(ending_titles[id])
		_text(box,"A Promise Kept\nThank you for sharing this spring.",27,PromiseSkin.GOLD)
		_text(box,"Memories shared: %d / 24 · Quests completed: %d / 24" % [Campaign.seen_events.size(),Campaign.completed.size()])
		box.add_child(PromiseSkin.button("Return to title",menu)))

func _pause() -> void:
	var box=_open_panel("A moment to breathe")
	if screen_name=="home":
		box.add_child(PromiseSkin.button("Meals",_meals))
		box.add_child(PromiseSkin.button("Spend time together",_activities))
		box.add_child(PromiseSkin.button("Treatment notes",_treatment))
		box.add_child(PromiseSkin.button("Village shop",_shop))
		box.add_child(PromiseSkin.button("Plan the afternoon",_routes) if Campaign.phase=="morning" else PromiseSkin.button("Rest for the night",_sleep))
	box.add_child(PromiseSkin.button("Inventory",_inventory))
	box.add_child(PromiseSkin.button("Journal",_journal))
	box.add_child(PromiseSkin.button("Relationship",_relationship))
	box.add_child(PromiseSkin.button("Save story",func():_slots(true)))
	box.add_child(PromiseSkin.button("Load story",func():_slots(false)))
	box.add_child(PromiseSkin.button("Settings",_settings))
	box.add_child(PromiseSkin.button("Return to title",func():Campaign.save_game(); menu()))
	if screen_name=="field": box.add_child(PromiseSkin.button("Recall home · four seconds",func():_close_modal(); field.begin_recall()))

func _slots(saving: bool) -> void:
	var box=_open_panel("Save story" if saving else "Load story")
	for index in range(1,10):
		var slot=str(index); var path=Campaign.SAVE_DIR+slot+".json"; var description="Empty"
		if FileAccess.file_exists(path):
			var info=JSON.parse_string(FileAccess.get_file_as_string(path))
			if info is Dictionary: description="Day %d · Affection %d · Love %d" % [info.get("day",1),info.get("affection",0),info.get("love",0)]
		var button=PromiseSkin.button("%d · %s" % [index,description],_slot_action.bind(slot,saving)); button.disabled=not saving and description=="Empty"; box.add_child(button)
	if not saving:
		for index in range(0,10):
			var old="user://savegame.json" if index==0 else "user://saves/slot_%02d.json" % index
			if FileAccess.file_exists(old): box.add_child(PromiseSkin.button("Import legacy "+("autosave" if index==0 else "slot "+str(index))+" into an empty new slot",_import.bind(old)))

func _slot_action(slot: String, saving: bool) -> void:
	if saving:
		_notice("Story saved." if Campaign.save_game(slot) else "Could not save this story."); _slots(true)
	elif Campaign.load_game(slot): _resume()
	else: _notice("This story could not be loaded.")

func _import(path: String) -> void:
	for index in range(1,10):
		if not FileAccess.file_exists(Campaign.SAVE_DIR+str(index)+".json"):
			if Campaign.import_legacy(path,str(index)):
				_notice("Legacy progress imported. Original backed up and preserved. Expanded story begins on day one."); home()
			else: _notice("Import failed; the original file was preserved.")
			return
	_notice("All new slots are occupied. Free a slot before importing.")

func _settings() -> void:
	var box=_open_panel("Settings")
	_text(box,"Camera distance",23,PromiseSkin.GOLD)
	var zoom=OptionButton.new(); zoom.custom_minimum_size.y=48
	for name in ["Wide","Balanced","Close"]: zoom.add_item(name)
	zoom.select([1.5,2.0,2.5].find(float(Campaign.settings.zoom)))
	zoom.item_selected.connect(func(i):Campaign.settings.zoom=[1.5,2.0,2.5][i]; Campaign.save_settings())
	box.add_child(zoom)
	var hints=CheckButton.new(); hints.text="Show room interaction labels"; hints.button_pressed=Campaign.settings.hotspots; hints.toggled.connect(func(v):Campaign.settings.hotspots=v; Campaign.save_settings()); box.add_child(hints)
	_text(box,"Music volume",23,PromiseSkin.GOLD)
	var volume=HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=0.05; volume.value=Campaign.settings.music; volume.value_changed.connect(func(v):Campaign.settings.music=v; Campaign.save_settings()); box.add_child(volume)
	_text(box,"Keyboard controls · select an action, then press its new key",20,PromiseSkin.MUTED)
	for action in ["move_up","move_down","move_left","move_right","dodge","use","heal","recall","inventory","journal"]:
		var events=InputMap.action_get_events(action)
		var key=events[0].as_text() if not events.is_empty() else "Unbound"
		box.add_child(PromiseSkin.button(action.replace("_"," ").capitalize()+" · "+key,func():capture_action=action; _notice("Press a key for "+action.replace("_"," "))))
	box.add_child(PromiseSkin.button("Restore default controls",func():Campaign.settings.remaps={}; Campaign.configure_inputs(); Campaign.save_settings(); _settings()))

func _credits() -> void:
	var box=_open_panel("Credits")
	_text(box,"A Promise Kept\nOriginal project: kurtreonal\nStory and gameplay redesign: 2026",25,PromiseSkin.GOLD)
	_text(box,"Background illustrations: Noraneko Games.\nCC0 game assets: Luis Zuno / Ansimuz, 0x72, and Kenney.\nDialogue: Dialogic.\nFonts: EB Garamond and Noto Serif JP, under their included font licenses.\nThe original soundtrack is preserved.")
	_text(box,"See the bundled asset manifest for provenance, modifications, and generated-art model information.",18,PromiseSkin.MUTED)

func _notice(message: String) -> void:
	if not is_instance_valid(toast): return
	toast.text=message; toast_timer=4.5; toast.show()

func _state_changed() -> void:
	if is_instance_valid(hud_hp): hud_hp.text="HP %d / %d" % [Campaign.player_hp,Campaign.max_hp()]
	_refresh_header()

func _process(delta: float) -> void:
	if screen_name in ["home","field"]: _refresh_header()
	toast_timer-=delta
	if toast_timer<=0 and is_instance_valid(toast): toast.hide()
	if screen_name=="field" and is_instance_valid(field):
		hud_details.visible=field.combat_time>0 or field.recall_left>0
		hud_details.text="%s · skill %.1fs · tea %d" % [Campaign.weapon().name,field.player.skill_left,Campaign.quantity("potion")]
		if field.recall_left>0: hud_details.text="Recalling home · %.1fs" % field.recall_left
		context.text=field.interaction_text()

func _unhandled_input(event: InputEvent) -> void:
	if capture_action!="" and event is InputEventKey and event.pressed and not event.echo:
		Campaign.settings.remaps[capture_action]=[event.physical_keycode]; Campaign.configure_inputs(); Campaign.save_settings(); capture_action=""; _settings(); get_viewport().set_input_as_handled(); return
	if Campaign.input_locked: return
	if event.is_action_pressed("pause"):
		if is_instance_valid(modal): _close_modal()
		else: _pause()
		get_viewport().set_input_as_handled()
	elif not Campaign.modal_open:
		if event.is_action_pressed("inventory"): _inventory()
		elif event.is_action_pressed("journal"): _journal()
		elif event.is_action_pressed("hotspots") and screen_name=="home": Campaign.settings.hotspots=not Campaign.settings.hotspots; Campaign.save_settings(); home()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: Campaign.save_game()

func _runtime_smoke() -> void:
	if "Redesign Smoke" not in str(ProjectSettings.get_setting("application/config/name")) or "Redesign Smoke" not in OS.get_user_data_dir():
		push_error("Smoke test requires isolated application identity"); get_tree().quit(2); return
	Campaign.reset(); home()
	await get_tree().process_frame
	assert(hotspot_controls.size()==5)
	assert(Campaign.eat("porridge").ok)
	assert(Campaign.depart(0).ok)
	explore()
	await get_tree().process_frame
	assert(is_instance_valid(field.player))
	_inventory(); assert(Campaign.modal_open)
	_close_modal(); assert(not Campaign.modal_open)
	Campaign.return_home(); home()
	print("PASS: redesigned home, meals, expedition, inventory, and return")
	get_tree().quit()
