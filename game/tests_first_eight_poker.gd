extends SceneTree

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	var state = root.get_node("GameState")
	state._ready()
	state.current_region = "01"
	state.current_anchor = "P3"
	state.return_anchor = "P3"
	state.main_cursor = "01-M03"
	state.unlocked_regions = {"01":true}
	state.finished_main.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.story_flags.clear()
	state.observed_events.clear()
	state.event_serial = 0
	var runtime = Runtime.new(state)
	root.add_child(runtime)
	must(not runtime.open_scene("01-M03").has("error"), "registration scene opens at P3")
	must(not runtime.select_scene_choice("STORY_ACTION", "ENTER").has("error"), "free first ticket registers player")
	var reserved: String = str(state.story_flags.get("R01_PLAYER_EVENT_ID", ""))
	must(reserved.begins_with("r01_arcade_local_record#"), "registration reserves distinct match identity")
	must(not runtime.commit_active_scene().has("error"), "registration completes and unlocks actual match")
	must(not runtime.open_scene("01-M04").has("error"), "match opens at same physical anchor")
	var started: Dictionary = runtime.select_scene_choice("STORY_ACTION", "PLAY_MATCH")
	must(not started.has("error") and runtime.mode == "POKER" and runtime.active_tournament != null,
		"M04 enters canonical TournamentDirector")
	must(runtime.active_event_instance_id == reserved, "match uses reserved identity")
	must(runtime.active_tournament.active_hand != null, "real cards are dealt")
	must(runtime.save_runtime(), "official match saves mid-hand")
	var resumed = Runtime.new(state)
	root.add_child(resumed)
	var recovered: Dictionary = resumed.restore_runtime()
	must(not recovered.has("error") and resumed.mode == "POKER" and resumed.active_event_instance_id == reserved,
		"mid-hand restore preserves match and source scene")
	var steps := 0
	while resumed.mode == "POKER" and steps < 20000:
		if resumed.active_tournament.active_hand == null:
			var next: Dictionary = resumed.begin_next_hand(30000 + steps)
			if next.has("error"):
				errors.append("next hand failed: " + str(next.error))
				break
		else:
			var acted: Dictionary = resumed.submit_ai_action("BALANCED", 0.5, 40000 + steps)
			if acted.has("error"):
				errors.append("table action failed: " + str(acted.error))
				break
		steps += 1
	must(steps < 20000 and resumed.mode == "RESULT", "official match reaches engine final rank")
	must(state.player_events.size() == 1 and state.player_events.has(reserved),
		"one real player match result is stored")
	must(state.story_flags.get("R01_MATCH_RESULT", "") in ["WIN","LOSS"],
		"scene consumes final match outcome, not hand result")
	must(not resumed.acknowledge_result().has("error") and resumed.mode == "WORLD",
		"result restores world control")
	must(not resumed.commit_active_scene().has("error"), "M04 completes after result")
	must(state.npc_events.size() == 1 and state.npc_events.values()[0].get("event_id", "") == "r01_ian_separate_local",
		"independent Ian tournament is played by engine and recorded once")
	must(resumed.run_independent_npc_event("r01_ian_separate_local").get("already_recorded", false),
		"Ian event cannot replay for duplicate reward or record")
	for error in errors:
		push_error("FIRST EIGHT POKER FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_FIRST_EIGHT_POKER: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
