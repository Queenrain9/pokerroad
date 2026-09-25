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
	var state = root.get_node("GameState")
	state._ready()
	state.current_region = "03"
	state.current_anchor = "F3"
	state.return_anchor = "F3"
	state.main_cursor = "03-M04"
	state.unlocked_regions = {"01":true,"02":true,"03":true,"04":true}
	state.finished_main.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.story_flags.clear()
	state.observed_events.clear()
	state.rewards_paid.clear()
	state.event_serial = 0
	state.chips = 100
	state.player_q = "NO"
	var runtime = Runtime.new(state)
	root.add_child(runtime)

	must(not runtime.open_scene("03-M04").has("error"), "03-M04 opens")
	var direct: Dictionary = runtime.select_scene_choice("DOYUN_SOLGAE_INTRO", "DIRECT")
	must(not direct.has("error") and runtime.mode == "POKER"
		and runtime.active_event_instance_id.begins_with("r03_doyun_practice#"), "Doyun direct practice starts")
	var doyun_id: String = runtime.active_event_instance_id
	drive_to_result(runtime, 81000)
	must(state.player_events.has(doyun_id), "Doyun direct result stored as player event")
	must(state.story_flags.get("DOYUN_DIRECT_03", "") in ["WIN","LOSS"], "Doyun direct whole-match result consumed")
	must(not runtime.acknowledge_result().has("error"), "Doyun result returns to world")
	must(not runtime.commit_active_scene().has("error") and state.main_cursor == "03-M05", "03-M04 completes after direct match")
	must(state.player_q == "NO", "forest exhibition cannot create player Q")

	state.current_region = "04"
	state.current_anchor = "H5"
	state.return_anchor = "H5"
	state.main_cursor = "04-M03"
	must(not runtime.open_scene("04-M03").has("error"), "04-M03 opens")
	var skipped: Dictionary = runtime.select_scene_choice("NARAE_CAFE", "SKIP")
	must(not skipped.has("error") and runtime.mode == "WORLD", "cafe match can be skipped")
	must(not runtime.open_scene("04-M03").has("error"), "04-M03 reopens for official choice")
	var pending: Dictionary = runtime.select_scene_choice("OFFICIAL_OPTION", "ENTER")
	must(pending.get("requires_confirmation", false) and runtime.mode == "DIALOGUE"
		and int(runtime.pending_paid_event.get("fee", 0)) == 40, "official entry requires explicit wallet confirmation")
	must(state.chips == 100, "entry fee is not charged before confirmation")
	var started: Dictionary = runtime.confirm_pending_event()
	must(not started.has("error") and runtime.mode == "POKER" and state.chips == 60, "confirmed official entry charges once and starts poker")
	var qualifier_id: String = runtime.active_event_instance_id
	must(runtime.save_runtime(), "official qualifier saves mid-hand")
	var resumed = Runtime.new(state)
	root.add_child(resumed)
	var restored: Dictionary = resumed.restore_runtime()
	must(not restored.has("error") and resumed.mode == "POKER"
		and resumed.active_event_instance_id == qualifier_id and state.chips == 60, "official qualifier restores without double charging")
	drive_to_result(resumed, 91000)
	must(state.player_events.has(qualifier_id), "player official result stored separately")
	must(state.player_q == "PENDING", "engine-only official result remains PENDING external review")
	must(state.story_flags.get("R04_PLAYER_OFFICIAL_RESULT", "") in ["WIN","LOSS"], "official whole-match result consumed")
	must(not resumed.acknowledge_result().has("error"), "official result returns to world")
	must(not resumed.commit_active_scene().has("error") and state.main_cursor == "04-M04", "04-M03 completes")
	var narae: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r04_narae_qualifier")
	must(narae.size() == 1 and int(narae[0].get("final_rank", 0)) == 1
		and narae[0].get("owner_id", "") == "NPC_NARAE", "Narae qualifier is independent canonical NPC evidence")
	must(state.story_flags.get("NARAE_NPC_QUALIFIED", false), "Narae qualification story flag follows her NPC event")

	state.current_anchor = "H6"
	must(not resumed.open_scene("04-M04").has("error"), "04-M04 opens")
	var board: Dictionary = resumed.select_scene_choice("IAN_DOYUN_VIEW", "BOARD")
	must(not board.has("error") and resumed.mode == "WORLD", "invite result board can be read without player seat")
	must(not resumed.commit_active_scene().has("error") and state.main_cursor == "04-M05", "04-M04 completes")
	var invite: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r04_doyun_ian_invite")
	must(invite.size() == 1 and invite[0].get("owner_id", "") == "NPC_DOYUN"
		and int(invite[0].get("final_rank", 0)) == 1
		and invite[0].get("participants", []).has("NPC_IAN"), "Doyun-Ian replay preserves canonical participants and winner")
	must(state.player_q == "PENDING", "NPC events cannot overwrite player qualification review state")
	must(resumed.run_independent_npc_event("r04_doyun_ian_invite").get("already_recorded", false), "invite replay cannot duplicate")

	for error in errors:
		push_error("MAIN 17-24 POKER FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_MAIN_17_24_POKER: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
