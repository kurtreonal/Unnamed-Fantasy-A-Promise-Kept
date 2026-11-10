extends SceneTree
var failures=0
func _initialize() -> void: call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _run() -> void:
	if "Redesign Smoke" not in str(ProjectSettings.get_setting("application/config/name")) or "Redesign Smoke" not in OS.get_user_data_dir():
		push_error("Refusing to test against player saves"); quit(2); return
	var state=root.get_node("Campaign")
	expect(state.catalog.quests.size()==24,"24 quests required")
	expect(state.catalog.events.size()==24,"24 relationship events required")
	expect(int(state.catalog.characters.rin.age)==17 and int(state.catalog.characters.player.age)==17,"Story characters must remain high-school peers")
	state.reset()
	var initial=state.coins
	expect(state.eat("porridge").ok,"Free meal must always work")
	expect(not state.eat("porridge").ok,"A meal must not reward twice")
	expect(state.coins==initial,"Pantry meal must not charge money")
	state.grant("spear_2"); expect(state.equip("spear_2").ok,"Owned weapon equips")
	expect(state.weapon().family=="spear" and state.weapon().attack==18,"Equipped weapon determines combat stats")
	state.phase="evening"; state.eat("porridge")
	state.activity("talk"); state.commit_event("e01",0)
	var affection=state.affection
	expect(not state.commit_event("e01",0),"Story rewards must be idempotent")
	expect(state.affection==affection,"Duplicate choice cannot change affection")
	state.dialogue={"id":"e02","index":2,"event":state.catalog.events[1]}
	var expected=state.snapshot()
	expect(state.save_game("1"),"Snapshot write succeeds")
	state.reset(); expect(state.load_game("1"),"Snapshot load succeeds")
	expect(JSON.stringify(state.snapshot())==JSON.stringify(expected),"Every campaign field round-trips")
	var before_corruption=state.snapshot()
	expect(not state.restore({"version":3,"phase":"morning","inventory":[]}),"Malformed snapshots must be rejected")
	expect(state.snapshot()==before_corruption,"Rejected snapshot cannot partially mutate state")
	state.reset()
	# Exercise a full calendar route; fixture rewards stand in for physical gathering.
	for day in range(1,29):
		expect(state.day==day,"Calendar must advance once per sleep")
		state.eat("porridge")
		if day==22: expect(state.craft("medicine").ok,"Medicine is craftable from guaranteed ingredients")
		for event in state.catalog.events:
			if int(event.day)==day and event.activity!="stargaze":
				var result=state.activity(event.activity)
				expect(result.ok,"Scheduled event activity is available: "+event.id)
				if result.ok:
					expect(result.event.get("id","")==event.id,"Scheduled story event must be selected")
					state.commit_event(event.id,0)
		if day==1:
			state.take_loot("moss",6); state.grant("forest_seal"); state.record("boss:0")
		if day==9:
			state.activity("research"); state.take_loot("moonstone",6); state.grant("mine_seal"); state.record("boss:1")
		if day==15:
			state.activity("read"); state.take_loot("sunpetal",6); state.grant("ruin_seal"); state.record("boss:2")
		if day==22:
			expect(state.craft("cure").ok,"Cure progression must be reachable")
		state.phase="evening"; state.hour=18
		# Evening-only events are scheduled after expedition return.
		for event in state.catalog.events:
			if int(event.day)==day and event.activity=="stargaze" and not event.id in state.seen_events:
				var result=state.activity("stargaze")
				if result.ok: state.commit_event(event.id,0)
		state.eat("porridge")
		var sleep=state.sleep()
		expect(sleep.ok,"Dinner permits sleep")
		if day==28: expect(sleep.finale,"Last day opens ending selection")
	expect("m12" in state.completed,"All main quests complete")
	expect(state.seen_events.size()==24,"All 24 relationship events reachable")
	var endings=state.ending_options()
	expect("promise_kept" in endings,"Romantic cure ending reachable")
	expect("lanterns" in endings,"Travel secret reachable through memory chain")
	expect("her_tomorrow" in endings,"Independent future secret reachable")
	state.memories.erase("commitment")
	expect("beside_you" in state.ending_options(),"Companionship cure ending reachable")
	state.inventory.erase("cure"); state.completed.erase("m12")
	expect(state.ending_options()==["another_spring"],"Continuing-care ending reachable")
	# Legacy import writes a new slot and preserves its source byte for byte.
	var old="user://legacy-fixture.json"
	var fixture=FileAccess.open(old,FileAccess.WRITE)
	fixture.store_string('{"version":2,"meal":{"coins":321},"affection":{"current_affection":27},"health":{"rin_health":48}}'); fixture.close()
	var original=FileAccess.get_file_as_string(old)
	expect(state.import_legacy(old,"9"),"Legacy import succeeds in empty slot")
	expect(state.day==1 and state.coins==321 and state.affection==27 and state.health==48,"Legacy progress imports safely")
	expect(FileAccess.get_file_as_string(old)==original,"Legacy source remains unchanged")
	expect(not state.import_legacy(old,"9"),"Legacy import cannot overwrite occupied slot")
	state.reset(); state.add_time(10)
	expect(state.phase=="evening","Home activities crossing 18:00 cannot trap the morning phase")
	state.reset(); state.stay_home(); state.eat("porridge")
	expect(state.sleep().ok,"A rest day without an expedition must remain completable")
	if failures==0: print("PASS: campaign routes, five endings, wallet, equipment, save round-trip, and legacy preservation")
	quit(0 if failures==0 else 1)
