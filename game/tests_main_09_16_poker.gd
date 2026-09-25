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
	while runtime.mode == "POKER" and steps < 20000:
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
	must(steps < 20000 and runtime.mode == "RESULT", "event reaches final result")

func run_suite() -> void:
	var state = root.get_node("GameState")
	state._ready()
	state.current_region = "02"
	state.current_anchor = "K3"
	state.return_anchor = "K3"
	state.main_cursor = "02-M03"
	state.unlocked_regions = {"01":true,"02":true}
	state.finished_main.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.story_flags.clear()
	state.observed_events.clear()
	state.event_serial = 0
	var runtime = Runtime.new(state)
	root.add_child(runtime)

	must(not runtime.open_scene("02-M03").has("error"), "02-M03 opens")
	must(not runtime.select_scene_choice("BOAT_ACCESS", "ENTER").has("error"), "boat match reserved")
	var reserved: String = str(state.story_flags.get("R02_PUBLIC_MATCH_ID", ""))
	must(reserved.begins_with("r02_boat_open#"), "reserved boat identity")
	must(not runtime.commit_active_scene().has("error") and state.main_cursor == "02-M04", "registration completes")

	must(not runtime.open_scene("02-M04").has("error"), "02-M04 opens")
	var started: Dictionary = runtime.select_scene_choice("BOAT_EVENT", "PLAY_MATCH")
	must(not started.has("error") and runtime.mode == "POKER" and runtime.active_event_instance_id == reserved, "reserved TournamentDirector event starts")
	must(runtime.save_runtime(), "boat match saves mid-hand")
	var resumed = Runtime.new(state)
	root.add_child(resumed)
	var recovered: Dictionary = resumed.restore_runtime()
	must(not recovered.has("error") and resumed.mode == "POKER" and resumed.active_event_instance_id == reserved, "boat match restores mid-hand")
	drive_to_result(resumed, 61000)
	must(state.player_events.has(reserved), "boat result stored once")
	must(state.story_flags.get("R02_MATCH_RESULT", "") in ["WIN","LOSS"], "whole-match boat result consumed")
	must(not resumed.acknowledge_result().has("error"), "boat result returns to world")
	must(not resumed.commit_active_scene().has("error") and state.main_cursor == "02-M05", "02-M04 completes")
	must(state.npc_events.values().any(func(v): return v.get("event_id", "") == "r02_yunharu_boat_demo"), "Yunharu demo replayed")

	must(not resumed.open_scene("02-M05").has("error"), "02-M05 opens")
	var direct: Dictionary = resumed.select_scene_choice("REUNION", "IAN_PRACTICE")
	must(not direct.has("error") and resumed.mode == "POKER" and resumed.active_event_instance_id.begins_with("r02_ian_direct_practice#"), "Ian direct practice starts separately")
	var direct_id: String = resumed.active_event_instance_id
	drive_to_result(resumed, 72000)
	must(state.player_events.has(direct_id) and direct_id != reserved, "Ian match has distinct identity")
	must(state.story_flags.get("R02_IAN_DIRECT_RESULT", "") in ["WIN","LOSS"], "Ian direct outcome separate")
	must(not resumed.acknowledge_result().has("error"), "Ian result returns to world")
	must(not resumed.commit_active_scene().has("error") and state.main_cursor == "02-M06", "02-M05 completes")
	must(state.player_q == "NO", "river matches do not fabricate national qualification")
	must(resumed.run_independent_npc_event("r02_yunharu_boat_demo").get("already_recorded", false), "Yunharu replay cannot duplicate")

	for error in errors:
		push_error("MAIN 09-16 POKER FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_MAIN_09_16_POKER: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
