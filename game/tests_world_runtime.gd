extends SceneTree

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
const BindingStore = preload("res://scripts/services/scene_binding_store.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func reset_world(region: String, anchor: String, cursor: String) -> void:
	GameState.main_cursor = cursor
	GameState.current_region = region
	GameState.current_anchor = anchor
	GameState.return_anchor = anchor
	GameState.world_layer = 0
	GameState.unlocked_regions = {"01":true,"02":true,"03":true,"04":true,"05":true,"06":true,"07":true,"08":true}
	GameState.finished_main.clear()
	GameState.finished_optional.clear()
	GameState.rewards_paid.clear()
	GameState.world_phase = 0
	GameState.chips = 100
	GameState.player_q = "NO"
	GameState.registration_intent = "VIEW"
	GameState.player_events.clear()
	GameState.npc_events.clear()
	GameState.npc_seat_status.clear()
	GameState.observed_events.clear()
	GameState.story_flags.clear()
	GameState.event_serial = 0

func fresh_runtime():
	var runtime = Runtime.new()
	get_root().add_child(runtime)
	return runtime

func _initialize() -> void:
	must(BindingStore.validate_catalog().is_empty(), "source-backed binding catalog validates")

	reset_world("01","P0","01-M01")
	var runtime = fresh_runtime()
	must(runtime.validate_runtime().is_empty(), "common runtime validates all eight region descriptors")
	var regions := runtime.world_runtime.all_region_descriptors()
	must(regions.size() == 8, "all eight region runtime descriptors exist")
	for region in regions:
		must(region.get("physical_map_status","") == "NOT_IMPLEMENTED", "runtime does not fake a finished physical map")
		must(not region.get("capabilities", []).is_empty(), "each region carries production capabilities")
	var opened := runtime.open_scene("01-M01")
	must(not opened.has("error") and runtime.mode == "DIALOGUE", "01-M01 opens from real source at P0")
	must(str(opened.get("verbatim_source_markdown","")).contains("골목 게시판"), "runner exposes canonical source rather than rewritten placeholder")
	var ack := runtime.select_scene_choice("START_ACK","BOARD_CONFIRM")
	must(not ack.has("error") and runtime.mode == "WORLD", "01-M01 source-authored choice returns to world")
	must(GameState.story_flags.get("START_ACK",false) == true, "01-M01 sets START_ACK only")
	must(runtime.scene_runner.ready_to_complete(), "01-M01 runtime completion condition is satisfied")
	var blocked := runtime.commit_active_scene()
	must(blocked.has("error") and GameState.main_cursor == "01-M01", "runtime binding cannot masquerade as physical scene implementation")

	runtime.queue_free()
	reset_world("01","P1","01-M02")
	runtime = fresh_runtime()
	must(not runtime.open_scene("01-M02").has("error"), "01-M02 opens at P1")
	var watch := runtime.select_scene_choice("BOKRYE_FREE_TABLE","WATCH")
	must(not watch.has("error") and runtime.mode == "OBSERVE", "tutorial watch route uses OBSERVE mode")
	must(GameState.story_flags.get("TUTORIAL_RESULT","") == "WATCH", "watch route has no fake win/loss")
	must(GameState.observed_events.get("r01_grandma_practice","") == "VIEWED_FULL", "watch evidence stays separate")
	must(runtime.save_runtime(), "observation runtime saves")
	var resumed = fresh_runtime()
	var resumed_state := resumed.restore_runtime()
	must(not resumed_state.has("error") and resumed.mode == "OBSERVE", "observation resumes into OBSERVE")
	must(resumed.scene_runner.active_scene_id() == "01-M02", "observation resume preserves source scene")
	must(not resumed.finish_observation().has("error") and resumed.mode == "RESULT", "observation resolves through RESULT")
	var observe_ack := resumed.acknowledge_result()
	must(not observe_ack.has("error") and resumed.mode == "WORLD", "observation result returns to WORLD")
	if FileAccess.file_exists(GameState.SESSION_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SESSION_SAVE_PATH))
	runtime.queue_free()
	resumed.queue_free()

	reset_world("01","P1","01-M02")
	runtime = fresh_runtime()
	must(not runtime.open_scene("01-M02").has("error"), "tutorial play scene opens")
	var play := runtime.select_scene_choice("BOKRYE_FREE_TABLE","PLAY_FREE")
	must(not play.has("error") and runtime.mode == "POKER", "source choice enters actual tournament runtime")
	must(runtime.active_event_rule.get("event_id","") == "r01_grandma_practice", "tutorial uses canonical event identity")
	var saved_instance := runtime.active_event_instance_id
	var saved_deck = runtime.active_tournament.active_hand.deck.duplicate()
	must(runtime.save_runtime(), "mid-poker runtime saves with scene context")
	resumed = fresh_runtime()
	resumed_state = resumed.restore_runtime()
	must(not resumed_state.has("error") and resumed.mode == "POKER", "mid-poker runtime resumes to POKER")
	must(resumed.active_event_instance_id == saved_instance, "event instance identity survives interruption")
	must(resumed.scene_runner.active_scene_id() == "01-M02", "poker resume retains source scene consumer")
	must(resumed.active_tournament.active_hand.deck == saved_deck, "poker resume preserves exact remaining deck order")
	var guard := 0
	while resumed.mode == "POKER" and guard < 200:
		if resumed.active_tournament.active_hand == null:
			resumed.begin_next_hand(9000 + guard)
		else:
			var seat: int = resumed.active_tournament.active_hand.current_actor
			resumed.submit_action(seat, "fold")
		guard += 1
	must(resumed.mode == "RESULT" and guard < 200, "real tutorial tournament reaches a match result")
	must(["WIN","LOSS"].has(GameState.story_flags.get("TUTORIAL_RESULT","")), "full match result maps back to source scene without single-hand shortcut")
	must(GameState.player_events.size() == 1, "event instance creates exactly one player match record")
	var poker_ack := resumed.acknowledge_result()
	must(not poker_ack.has("error") and poker_ack.get("scene_ready_to_complete",false), "poker result returns to world with scene completion ready")
	if FileAccess.file_exists(GameState.SESSION_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SESSION_SAVE_PATH))
	runtime.queue_free()
	resumed.queue_free()

	reset_world("05","E4","05-M03")
	runtime = fresh_runtime()
	must(not runtime.open_scene("05-M03").has("error"), "05-M03 opens at actual E4 anchor")
	var board := runtime.select_scene_choice("DOYUN_IDENTITY_NOTICE","READ_BOARD")
	must(not board.has("error") and runtime.mode == "OBSERVE", "Doyun identity can be learned by bulletin")
	must(GameState.story_flags.get("DOYUN_RESERVED_ID_KNOWN",false), "only Doyun identity/provisional reservation fact is learned")
	must(GameState.observed_events.get("r05_doyun_identity","") == "LEARNED_BULLETIN", "bulletin knowledge is distinct from full viewing")
	must(GameState.npc_seat_status.is_empty() and GameState.player_q == "NO", "05-M03 does not prematurely restore/cancel seats or alter player Q")
	runtime.queue_free()

	reset_world("08","C4","08-M03")
	runtime = fresh_runtime()
	must(not runtime.open_scene("08-M03").has("error"), "08-M03 opens at affected broadcast anchor")
	var pause := runtime.select_scene_choice("AFFECTED_BROADCAST_PAUSE","ON_SITE")
	must(not pause.has("error") and runtime.mode == "OBSERVE", "affected broadcast is observed rather than magically repaired")
	must(GameState.story_flags.get("AFFECTED_BROADCAST_PAUSED",false), "only affected broadcast pause is committed")
	must(not GameState.story_flags.has("NARAE_SEAT_RESTORED") and not GameState.story_flags.has("DOYUN_PROXY_CANCELLED"), "08-M03 cannot apply later reform outcomes")
	runtime.queue_free()

	for error in errors:
		push_error("WORLD RUNTIME FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_WORLD_RUNTIME: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
