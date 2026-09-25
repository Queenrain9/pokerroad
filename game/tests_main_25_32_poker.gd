extends SceneTree

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	call_deferred("run_suite")

func drive_to_result(runtime, seed_base: int) -> void:
	var steps := 0
	while runtime.mode == "POKER" and steps < 24000:
		if runtime.active_tournament.active_hand == null:
			var next: Dictionary = runtime.begin_next_hand(seed_base + steps)
			if next.has("error"):
				errors.append("next hand failed: " + str(next.error))
				break
		else:
			var acted: Dictionary = runtime.submit_ai_action("BALANCED", 0.5, seed_base + 50000 + steps)
			if acted.has("error"):
				errors.append("table action failed: " + str(acted.error))
				break
		steps += 1
	must(steps < 24000 and runtime.mode == "RESULT", "event reaches final result")

func run_suite() -> void:
	var graph: Dictionary = TraversalService.load_graph()
	var b_walk: Dictionary = TraversalService.plan_step(graph, "05", "E3", "E4", "B_LINE_WALK", {"last_train_available":false})
	must(not b_walk.has("error") and b_walk.get("route_choice", "") == "B_LINE_WALK", "B-line walk works after A-line last train ends")
	var missed: Dictionary = TraversalService.plan_step(graph, "05", "E3", "E4", "TAKE_LAST_TRAIN", {"last_train_available":false})
	must(missed.has("error") and missed.get("alternative_anchor", "") == "E3B", "missed A-line points to free-night-bus fallback")

	var state = root.get_node("GameState")
	state._ready()
	state.current_region = "05"
	state.current_anchor = "E4"
	state.return_anchor = "E4"
	state.main_cursor = "05-M04"
	state.unlocked_regions = {"01":true,"02":true,"03":true,"04":true,"05":true,"06":true}
	state.finished_main.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.story_flags.clear()
	state.observed_events.clear()
	state.rewards_paid.clear()
	state.event_serial = 0
	state.chips = 0
	state.player_q = "NO"
	var runtime = Runtime.new(state)
	root.add_child(runtime)

	must(not runtime.open_scene("05-M04").has("error"), "05-M04 opens")
	var direct: Dictionary = runtime.select_scene_choice("DOYUN_DIRECT_05", "PLAY")
	must(not direct.has("error") and runtime.mode == "POKER"
		and runtime.active_event_instance_id.begins_with("r05_doyun_individual#"), "region05 Doyun practice starts")
	var doyun_id: String = runtime.active_event_instance_id
	drive_to_result(runtime, 101000)
	must(state.player_events.has(doyun_id), "region05 Doyun result stored once")
	must(state.story_flags.get("PLAYER_VS_DOYUN_05_RESULT", "") in ["WIN","LOSS"], "Doyun whole-match result consumed")
	must(not runtime.acknowledge_result().has("error"), "Doyun practice returns to world")
	must(not runtime.commit_active_scene().has("error") and state.main_cursor == "05-M05", "05-M04 completes after direct match")
	must(state.player_q == "NO", "Doyun exhibition cannot alter Q")

	state.current_region = "06"
	state.current_anchor = "G3"
	state.return_anchor = "G3"
	state.main_cursor = "06-M02"
	must(not runtime.open_scene("06-M02").has("error"), "06-M02 opens")
	var court: Dictionary = runtime.select_scene_choice("PUBLIC_COURT", "PLAY")
	must(not court.has("error") and runtime.mode == "POKER"
		and runtime.active_event_instance_id.begins_with("r06_palace_public#"), "player palace public match starts separately")
	var court_id: String = runtime.active_event_instance_id
	must(runtime.save_runtime(), "palace public match saves mid-hand")
	var resumed = Runtime.new(state)
	root.add_child(resumed)
	var restored: Dictionary = resumed.restore_runtime()
	must(not restored.has("error") and resumed.mode == "POKER" and resumed.active_event_instance_id == court_id,
		"palace public match restores mid-hand")
	drive_to_result(resumed, 111000)
	must(state.player_events.has(court_id), "player palace result stored")
	must(state.story_flags.get("PLAYER_COURT_MATCH_RESULT", "") in ["WIN","LOSS"], "player court outcome consumed")
	must(not resumed.acknowledge_result().has("error"), "palace player result returns to world")
	must(not resumed.commit_active_scene().has("error") and state.main_cursor == "06-M03", "06-M02 completes")
	var eunsol: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r06_eunsol_independent")
	must(eunsol.size() == 1 and eunsol[0].get("owner_id", "") == "NPC_EUNSOL"
		and eunsol[0].get("participants", []).has("NPC_RECOMMENDED_MASTER"), "Eunsol NPC match is a separate engine replay")
	must(state.story_flags.get("EUNSOL_NPC_EVENT_RECORDED", false), "Eunsol event completion flag stored")
	must(state.player_q == "NO", "palace exhibition remains non-qualifying")
	must(resumed.run_independent_npc_event("r06_eunsol_independent").get("already_recorded", false), "Eunsol replay cannot duplicate")

	for error in errors:
		push_error("MAIN 25-32 POKER FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_MAIN_25_32_POKER: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
