extends SceneTree

var checks := 0
var failures: Array[String] = []
var game
var state

func must(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run_suite")

func walk_to(position: Vector2) -> void:
	var steps := 0
	while game.player.global_position.distance_to(position) > 55.0 and steps < 600:
		game.player.set_virtual_move_vector((position - game.player.global_position).normalized())
		await physics_frame
		steps += 1
	game.player.clear_virtual_move()
	must(steps < 600, "physical walking reaches target " + str(position))

func reach(anchor: String, selected_route: String = "") -> void:
	var region = game.region_host.current_region_world
	var from_anchor: String = state.current_anchor
	var destination: Vector2 = region.anchor_position(anchor)
	if region.is_portal(from_anchor, anchor):
		destination = region.route_geometry.portal_position(from_anchor, anchor)
	await walk_to(destination)
	var nearby: Dictionary = game.inspect_world_interaction()
	must(["TRAVEL_CONFIRMABLE","ROUTE_CHOICE_REQUIRED"].has(nearby.get("kind", "")),
		"physical route " + from_anchor + " -> " + anchor)
	var route := selected_route
	if nearby.get("kind", "") == "ROUTE_CHOICE_REQUIRED" and route.is_empty():
		route = str(nearby.get("choices", [""])[0])
	var result: Dictionary = game.confirm_world_interaction(route)
	must(not result.has("error") and state.current_anchor == anchor, "arrives at " + anchor)

func open_current(id: String) -> void:
	var nearby: Dictionary = game.inspect_world_interaction()
	must(nearby.get("kind", "") == "CURRENT_ANCHOR" and nearby.get("scene_ids", []).has(id), id + " reachable")
	var opened: Dictionary = game.open_nearby_scene(id)
	must(not opened.has("error") and game.runtime.mode == "DIALOGUE"
		and str(opened.get("verbatim_source_markdown", "")).length() > 80, id + " opens canonical dialogue")

func choose(interaction: String, option: String, target: String) -> void:
	var selected: Dictionary = game.runtime.select_scene_choice(interaction, option)
	must(not selected.has("error") and game.runtime.mode == target, option + " enters " + target)

func observe_and_return(label: String) -> void:
	must(not game.runtime.finish_observation().has("error"), label + " observation ends")
	must(not game.runtime.acknowledge_result().has("error") and game.runtime.mode == "WORLD", label + " returns to world")

func complete(id: String, next_id: String) -> void:
	must(game.runtime.mode == "WORLD" and game.runtime.scene_runner.ready_to_complete(), id + " ready")
	var result: Dictionary = game.runtime.commit_active_scene()
	must(not result.has("error") and state.finished_main.has(id) and state.main_cursor == next_id, id + " -> " + next_id)
	must(game.runtime.mode == "WORLD" and not game.runtime.scene_runner.has_active_scene(), id + " restores world")
	must(game.runtime.save_runtime(), id + " saves")

func run_suite() -> void:
	state = root.get_node("GameState")
	state._ready()
	state.main_cursor = "03-M04"
	state.current_region = "03"
	state.current_anchor = "F4"
	state.return_anchor = "F4"
	state.unlocked_regions = {"01":true,"02":true,"03":true}
	state.finished_main.clear()
	state.finished_optional.clear()
	state.rewards_paid.clear()
	state.story_flags.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.observed_events.clear()
	state.event_serial = 0
	state.chips = 0
	state.player_q = "NO"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.play_ui.set_process(false)
	await physics_frame

	print("M17-24 STEP: 03-M04")
	await reach("F3")
	open_current("03-M04")
	choose("DOYUN_SOLGAE_INTRO", "LATER", "WORLD")
	complete("03-M04", "03-M05")
	must(state.story_flags.get("DOYUN_DIRECT_03", "") == "NOT_ENTERED"
		and state.story_flags.get("SOLGAE_INTRO", false), "03-M04 preserves optional direct-match result")

	print("M17-24 STEP: 03-M05")
	await reach("F4")
	open_current("03-M05")
	choose("HARBOR_POSTER", "READ", "WORLD")
	await reach("F6")
	open_current("03-M05")
	choose("HARBOR_TRANSIT", "COAST", "WORLD")
	complete("03-M05", "04-M01")
	must(state.current_region == "04" and state.current_anchor == "H0"
		and game.region_host.current_region_id == "04", "forest transit mounts harbor")

	print("M17-24 STEP: 04-M01")
	await reach("H1")
	open_current("04-M01")
	choose("NARAE_SAFETY_BRIEF", "JOIN", "WORLD")
	complete("04-M01", "04-M02")

	print("M17-24 STEP: 04-M02")
	open_current("04-M02")
	choose("TIDE_BOARD", "LOW", "WORLD")
	await reach("H2", "LOW_TIDE_MARKER_PATH")
	open_current("04-M02")
	choose("SAFE_MARKERS", "PAIR", "WORLD")
	await reach("H3")
	open_current("04-M02")
	choose("LIGHTHOUSE", "FIND_FLAG", "WORLD")
	await reach("H4")
	open_current("04-M02")
	choose("SAFE_REPORT", "READ", "WORLD")
	complete("04-M02", "04-M03")
	must(state.story_flags.get("BOAT_FOUND", false) and state.story_flags.get("CREW_SAFE", false),
		"rescue stores boat and crew-safe state")
	must(state.chips == 10 and state.rewards_paid.has("R04_CREW_SAFE_FIRST"), "rescue reward is granted once")

	print("M17-24 STEP: 04-M03")
	await reach("H5")
	open_current("04-M03")
	choose("NARAE_CAFE", "SKIP", "WORLD")
	open_current("04-M03")
	choose("OFFICIAL_OPTION", "WATCH_RESULTS", "OBSERVE")
	observe_and_return("04-M03")
	complete("04-M03", "04-M04")
	must(state.story_flags.get("NARAE_PLAYER_MATCH_RESULT", "") == "NOT_ENTERED", "cafe non-entry creates no player win")
	must(state.story_flags.get("NARAE_NPC_QUALIFIED", false), "Narae independent qualifier evidence stored")
	var narae_events: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r04_narae_qualifier")
	must(narae_events.size() == 1 and int(narae_events[0].get("final_rank", 0)) == 1, "Narae engine replay satisfies canonical qualifying result")

	print("M17-24 STEP: 04-M04")
	await reach("H6")
	open_current("04-M04")
	choose("IAN_DOYUN_VIEW", "BOARD", "WORLD")
	complete("04-M04", "04-M05")
	must(state.story_flags.get("IAN_DOYUN_NPC_04_RESULT", "") == "DOYUN_WIN", "invite result is Doyun win")
	var invite_events: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r04_doyun_ian_invite")
	must(invite_events.size() == 1 and int(invite_events[0].get("final_rank", 0)) == 1
		and invite_events[0].get("participants", []).has("NPC_IAN"), "invite replay uses Doyun and Ian identities")

	print("M17-24 STEP: 04-M05")
	await reach("H5")
	open_current("04-M05")
	choose("NARAE_NOTICE", "CONGRATS", "WORLD")
	complete("04-M05", "04-M06")
	must(state.story_flags.get("NARAE_NOTICE_04", "") == "RECEIVED", "Narae account notice stored without revealing proxy identity")

	print("M17-24 STEP: 04-M06")
	await reach("H6")
	await reach("H8")
	open_current("04-M06")
	choose("LAST_STATION_TRAIN", "IAN", "WORLD")
	complete("04-M06", "05-M01")
	must(state.current_region == "05" and state.current_anchor == "E0"
		and game.region_host.current_region_id == "05", "regular train mounts last-station region")
	must(state.player_q == "NO" and state.player_events.is_empty(), "spectator mainline does not fabricate player qualification")

	for failure in failures:
		push_error("MAIN 17-24 E2E FAILED: " + failure)
	if failures.is_empty():
		print("POKERROAD_MAIN_17_24_E2E: %d checks passed" % checks)
		quit(0)
	else:
		quit(1)
