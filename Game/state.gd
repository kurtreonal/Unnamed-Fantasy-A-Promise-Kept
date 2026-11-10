extends Node
## The single transactional state owner for the redesigned campaign.
signal changed
signal notice(message: String)
const SAVE_VERSION = 3
const SAVE_DIR = "user://campaign/"
var catalog: Dictionary
var day = 1
var hour = 8
var minute = 0
var phase = "morning"
var coins = 180
var affection = 10
var love = 0
var health = 65
var player_hp = 100
var inventory: Dictionary = {}
var equipment: Dictionary = {}
var quest_progress: Dictionary = {}
var completed: Array = []
var memories: Array = []
var seen_events: Array = []
var daily: Dictionary = {}
var dialogue: Dictionary = {}
var expedition: Dictionary = {}
var ending = ""
var settings: Dictionary = {"zoom":2.0,"hotspots":false,"music":0.75,"remaps":{}}
var modal_open = false
var input_locked = false
var region = 0
var checkpoint: Dictionary = {}

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://Game/Data/campaign.json"))
	reset(false)
	_load_settings()
	configure_inputs()

func reset(notify := true) -> void:
	day=1; hour=8; minute=0; phase="morning"; coins=180; affection=10; love=0; health=65; player_hp=100
	inventory={"sword_1":1,"potion":3,"grain":4,"vegetable":4,"herb":3,"honey":2,"cloth_coat":1}
	equipment={"weapon":"sword_1","armor":"cloth_coat","accessory":""}
	quest_progress={}; completed=[]; memories=[]; seen_events=[]; daily={}; dialogue={}; expedition={}; ending=""; region=0; checkpoint={}
	modal_open=false; input_locked=false
	if notify: changed.emit()

func chapter() -> int:
	return clampi((day-1)/7,0,3)

func clock() -> String:
	return "%02d:%02d" % [hour,minute]

func add_time(hours: int) -> void:
	hour=mini(22,hour+hours)
	if phase=="morning" and hour>=18:
		phase="evening"
		notice.emit("Evening has settled over the house.")
	changed.emit()

func stay_home() -> void:
	if phase!="morning": return
	phase="evening"; hour=18; minute=0; health=mini(100,health+3)
	notice.emit("A quiet afternoon at home · Wellbeing +3")
	changed.emit(); save_game()

func item_name(id: String) -> String:
	return catalog.items.get(id,{}).get("name",id)

func quantity(id: String) -> int:
	return int(inventory.get(id,0))

func grant(id: String, amount := 1) -> void:
	inventory[id]=quantity(id)+amount
	changed.emit()

func spend(amount: int) -> bool:
	if amount<0 or coins<amount: return false
	coins-=amount
	changed.emit()
	return true

func active_quests() -> Array:
	return catalog.quests.filter(func(q): return day>=int(q.day) and not q.id in completed and (q.requires=="" or q.requires in completed))

func record(event: String, amount := 1) -> void:
	for quest in active_quests():
		if quest.event != event: continue
		quest_progress[quest.id]=mini(int(quest.count),int(quest_progress.get(quest.id,0))+amount)
		if int(quest_progress[quest.id])>=int(quest.count):
			completed.append(quest.id)
			coins+=int(quest.reward)
			notice.emit("Quest complete · %s · +%dg" % [quest.title,quest.reward])
	changed.emit()

func take_loot(id: String, amount := 1) -> void:
	grant(id,amount)
	record("gather:"+id,amount)
	notice.emit("%s ×%d" % [item_name(id),amount])

func eat(id: String) -> Dictionary:
	var key="meal:"+phase
	if daily.has(key): return fail("We have already shared this meal.")
	var recipe: Dictionary = {}
	for entry in catalog.recipes:
		if entry.id==id: recipe=entry
	if recipe.is_empty(): return fail("Unknown recipe.")
	for ingredient in recipe.ingredients:
		if quantity(ingredient)<int(recipe.ingredients[ingredient]): return fail("We need more "+item_name(ingredient)+".")
	if coins<int(recipe.cost): return fail("Not enough coins.")
	coins-=int(recipe.cost)
	for ingredient in recipe.ingredients: inventory[ingredient]-=int(recipe.ingredients[ingredient])
	daily[key]=id
	health=clampi(health+int(recipe.health),0,100)
	affection=clampi(affection+int(recipe.affection),0,100)
	add_time(1)
	record("meal"); record("meal:"+id)
	notice.emit("Shared %s · Affection +%d" % [recipe.name,recipe.affection])
	save_game()
	return {"ok":true,"recipe":recipe}

func activity(id: String) -> Dictionary:
	if hour>=22: return fail("It is late. Let us rest and try tomorrow.")
	var entry: Dictionary = {}
	for a in catalog.activities:
		if a.id==id: entry=a
	if entry.is_empty(): return fail("Unknown activity.")
	if daily.has("activity:"+id): return fail("We have already made time for this today.")
	if id=="walk" and health<25: return fail("Rin would prefer to rest today. Tea or reading would be welcome.")
	if id=="stargaze" and phase!="evening": return fail("The stars will be out this evening.")
	daily["activity:"+id]=true
	affection=clampi(affection+int(entry.affection),0,100)
	health=clampi(health+int(entry.health),0,100)
	add_time(int(entry.hours))
	record("activity:"+id)
	if id=="talk": record("talk")
	var story: Dictionary = {}
	for event in catalog.events:
		if event.activity==id and day>=int(event.day) and not event.id in seen_events:
			story=event
			break
	notice.emit("Affection +%d · Time together" % entry.affection)
	save_game()
	return {"ok":true,"event":story,"activity":entry}

func commit_event(id: String, choice: int) -> bool:
	if id in seen_events: return false
	for event in catalog.events:
		if event.id!=id: continue
		if day<int(event.day) or not daily.has("activity:"+str(event.activity)): return false
		if choice<0 or choice>=event.choices.size(): return false
		var option: Dictionary=event.choices[choice]
		seen_events.append(id)
		if not option.flag in memories: memories.append(option.flag)
		affection=clampi(affection+int(option.affection),0,100)
		love=clampi(love+int(option.love),0,100)
		dialogue={}
		notice.emit("Affection +%d · Love +%d" % [option.affection,option.love])
		changed.emit(); save_game()
		return true
	return false

func available_regions() -> Array:
	return catalog.regions.filter(func(r): return day>=int(r.day))

func depart(id: int) -> Dictionary:
	if hour>=18: return fail("It is too late to begin an expedition.")
	if not daily.has("meal:"+phase): return fail("Share breakfast before setting out. Warm porridge is always available.")
	if id<0 or id>=catalog.regions.size() or day<int(catalog.regions[id].day): return fail("This route is not open yet.")
	region=id; phase="expedition"; hour=maxi(hour,10); player_hp=max_hp()
	expedition={"earnings":0,"harvested":[],"chests":[],"defeated":[],"room":0}
	checkpoint={}
	input_locked=false; modal_open=false
	save_game()
	return {"ok":true}

func return_home(defeated := false) -> void:
	if phase!="expedition": return
	if defeated:
		var lost=int(expedition.get("earnings",0))/2
		coins=maxi(0,coins-lost)
		notice.emit("You returned safely. Lost %dg of expedition earnings." % lost)
	phase="evening"; hour=18; minute=0; checkpoint={}; player_hp=max_hp()
	record("return")
	save_game()

func sleep() -> Dictionary:
	if phase!="evening": return fail("There is still a day ahead of us.")
	if not daily.has("meal:evening"): return fail("Have dinner together first. Porridge is always available.")
	if day>=28: return {"ok":true,"finale":true}
	day+=1; hour=8; minute=0; phase="morning"; daily={}; health=maxi(15,health-8)
	if health<30: notice.emit("Rin needs a quieter day. Rest and warm food can help.")
	changed.emit(); save_game()
	return {"ok":true,"finale":false}

func craft(id: String) -> Dictionary:
	var needs: Dictionary
	if id=="medicine": needs={"herb":2,"moss":1}
	elif id=="cure":
		if not "m11" in completed: return fail("Finish reviewing the treatment with Rin first.")
		needs={"forest_seal":1,"mine_seal":1,"ruin_seal":1,"moss":3,"moonstone":3,"sunpetal":3}
	else: return fail("Unknown formula.")
	if quantity(id)>0: return fail("This formula is already prepared.")
	for ingredient in needs:
		if quantity(ingredient)<int(needs[ingredient]): return fail("Need %s ×%d." % [item_name(ingredient),needs[ingredient]])
	for ingredient in needs: inventory[ingredient]-=int(needs[ingredient])
	grant(id); record("craft:"+id)
	if id=="medicine": health=mini(100,health+15)
	if id=="cure": health=100
	save_game()
	return {"ok":true}

func buy(id: String) -> Dictionary:
	var item: Dictionary=catalog.items.get(id,{})
	if item.is_empty() or int(item.price)<=0: return fail("This item is not for sale.")
	if int(item.get("tier",1))>chapter()+1: return fail("The merchant has not received this stock yet.")
	if not spend(int(item.price)): return fail("Not enough coins.")
	grant(id); save_game()
	return {"ok":true}

func equip(id: String) -> Dictionary:
	if quantity(id)<1: return fail("This item is not in your pack.")
	var kind: String=catalog.items[id].kind
	if not kind in ["weapon","armor","accessory"]: return fail("This item cannot be equipped.")
	equipment[kind]=id
	changed.emit(); save_game()
	return {"ok":true}

func weapon() -> Dictionary:
	return catalog.items.get(equipment.get("weapon","sword_1"),catalog.items.sword_1)

func defense() -> int:
	return int(catalog.items.get(equipment.get("armor",""),{}).get("defense",0))

func max_hp() -> int:
	return 100+int(catalog.items.get(equipment.get("accessory",""),{}).get("max_hp",0))

func heal() -> bool:
	if quantity("potion")==0 or player_hp>=max_hp(): return false
	inventory.potion-=1; player_hp=mini(max_hp(),player_hp+45)
	changed.emit()
	return true

func ending_options() -> Array:
	if quantity("cure")==0 and not "m12" in completed: return ["another_spring"]
	var romantic=love>=70 and "commitment" in memories and "romance2" in memories
	var options: Array=["promise_kept" if romantic else "beside_you"]
	if romantic and ["travel1","travel2","travel3"].all(func(f):return f in memories): options.append("lanterns")
	if ["research1","research2","research3","personal1","personal2","personal3"].all(func(f):return f in memories): options.append("her_tomorrow")
	return options

func snapshot() -> Dictionary:
	return {"version":SAVE_VERSION,"day":day,"hour":hour,"minute":minute,"phase":phase,"coins":coins,"affection":affection,"love":love,"health":health,"player_hp":player_hp,"inventory":inventory.duplicate(true),"equipment":equipment.duplicate(true),"quest_progress":quest_progress.duplicate(true),"completed":completed.duplicate(),"memories":memories.duplicate(),"seen_events":seen_events.duplicate(),"daily":daily.duplicate(true),"dialogue":dialogue.duplicate(true),"expedition":expedition.duplicate(true),"ending":ending,"region":region,"checkpoint":checkpoint.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0))!=SAVE_VERSION: return false
	for key in ["inventory","equipment","quest_progress","daily","dialogue","expedition","checkpoint"]:
		if not data.get(key,{}) is Dictionary: return false
	for key in ["completed","memories","seen_events"]:
		if not data.get(key,[]) is Array: return false
	for key in ["day","hour","minute","coins","affection","love","health","player_hp","region"]:
		var number=data.get(key,0)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	if not str(data.get("phase","")) in ["morning","evening","expedition"]: return false
	for key in data.get("inventory",{}):
		if not catalog.items.has(str(key)) or not (data.inventory[key] is int or data.inventory[key] is float): return false
	if str(data.get("phase",""))=="expedition":
		for key in ["harvested","chests","defeated"]:
			if not data.get("expedition",{}).get(key,[]) is Array: return false
	for key in snapshot():
		if key!="version" and data.has(key): set(key,data[key])
	for key in ["day","hour","minute","coins","affection","love","health","player_hp","region"]: set(key,int(get(key)))
	for key in inventory: inventory[key]=maxi(0,int(inventory[key]))
	for key in quest_progress: quest_progress[key]=int(quest_progress[key])
	if dialogue.has("index"): dialogue.index=int(dialogue.index)
	for key in ["earnings","room"]:
		if expedition.has(key): expedition[key]=int(expedition[key])
	day=clampi(day,1,28); hour=clampi(hour,0,23); minute=clampi(minute,0,59)
	affection=clampi(affection,0,100); love=clampi(love,0,100); health=clampi(health,0,100); coins=maxi(0,coins)
	if not phase in ["morning","evening","expedition"]: phase="morning"
	if phase=="morning" and hour>=18: phase="evening"
	if not catalog.items.has(equipment.get("weapon","")): equipment.weapon="sword_1"
	region=clampi(region,0,2); modal_open=false; input_locked=false
	changed.emit()
	return true

func save_game(slot := "autosave") -> bool:
	if slot!="autosave" and not slot in ["1","2","3","4","5","6","7","8","9"]: return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path=SAVE_DIR+slot+".json"
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(snapshot(),"\t")); file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path,path+".bak")
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func load_game(slot := "autosave") -> bool:
	var path=SAVE_DIR+slot+".json"
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var data=JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if data is Dictionary and restore(data): return true
	return false

func import_legacy(path: String, slot: String) -> bool:
	if not path.begins_with("user://"): return false
	if FileAccess.file_exists(SAVE_DIR+slot+".json"): return false
	var legacy=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not legacy is Dictionary: return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR+"legacy-backups")
	if DirAccess.copy_absolute(path,SAVE_DIR+"legacy-backups/"+FileAccess.get_sha256(path).substr(0,12)+"-"+path.get_file())!=OK: return false
	reset(false)
	coins=maxi(0,int(legacy.get("meal",{}).get("coins",180)))
	affection=clampi(int(legacy.get("affection",{}).get("current_affection",10)),0,100)
	health=clampi(int(legacy.get("health",{}).get("rin_health",65)),15,100)
	memories.append("legacy_import")
	return save_game(slot)

func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file=FileAccess.open(SAVE_DIR+"settings.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings,"\t"))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,float(settings.music))))

func _load_settings() -> void:
	if FileAccess.file_exists(SAVE_DIR+"settings.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR+"settings.json"))
		if saved is Dictionary: settings.merge(saved,true)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,float(settings.music))))

func configure_inputs() -> void:
	var bindings={"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"dodge":[KEY_SPACE],"use":[KEY_F],"heal":[KEY_R],"recall":[KEY_B],"inventory":[KEY_I],"journal":[KEY_J],"pause":[KEY_ESCAPE],"advance":[KEY_ENTER,KEY_SPACE],"hotspots":[KEY_H]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var keys: Array=settings.remaps.get(action,bindings[action])
		for key in keys:
			var event=InputEventKey.new(); event.physical_keycode=int(key)
			InputMap.action_add_event(action,event)
	for action in ["attack","skill"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT if action=="attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,event)

func fail(message: String) -> Dictionary:
	return {"ok":false,"reason":message}
