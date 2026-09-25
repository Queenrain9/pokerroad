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
	state.main_cursor = "05-M01"
	state.current_region = "05"
	state.current_anchor = "E0"
	state.return_anchor = "E0"
	state.unlocked_regions = {"01":true,"02":true,"03":true,"04":true,"05":true}
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

	print("M25-32 STEP: 05-M01")
	await reach("E1")
	await reach("E2")
	open_current("05-M01")
	choose("NARAE_RECORD_REVIEW", "WHO_RESERVED", "WORLD")
	open_current("05-M01")
	choose("NARAE_OBJECTION", "LET_NARAE_FILE", "WORLD")
	complete("05-M01", "05-M02")
	must(state.story_flags.get("NARAE_RECORD_REVIEWED", false)
		and state.story_flags.get("NARAE_OBJECTION_SUBMITTED", false), "Narae reviews and files her own objection")
	must(state.player_q == "NO", "Narae records do not alter player qualification")

	print("M25-32 STEP: 05-M02")
	await reach("E3")
	open_current("05-M02")
	choose("NIGHT_ROUTE_PLAN", "B_WALK", "WORLD")
	await reach("E4", "B_LINE_WALK")
	open_current("05-M02")
	choose("EVENT_ENTRANCE", "ARRIVED", "WORLD")
	complete("05-M02", "05-M03")
	must(state.story_flags.get("R05_ROUTE_PLAN", "") == "B_LINE_WALK", "B-line walking route stored without last-train dependency")

	print("M25-32 STEP: 05-M03")
	open_current("05-M03")
	choose("DOYUN_IDENTITY_NOTICE", "READ_BOARD", "OBSERVE")
	observe_and_return("05-M03")
	complete("05-M03", "05-M04")
	must(state.story_flags.get("DOYUN_RESERVED_ID_KNOWN", false), "Doyun provisional reservation identity learned")
	must(not state.story_flags.has("NARAE_SEAT_RESTORED") and not state.story_flags.has("DOYUN_PROXY_CANCELLED"),
		"identity reveal does not smuggle later reform state")

	print("M25-32 STEP: 05-M04")
	open_current("05-M04")
	choose("DOYUN_DIRECT_05", "IAN_REVIEW", "WORLD")
	complete("05-M04", "05-M05")
	must(state.story_flags.get("PLAYER_VS_DOYUN_05_RESULT", "") == "NO_MATCH"
		and state.player_events.is_empty(), "Ian review path creates no fake player match")

	print("M25-32 STEP: 05-M05")
	open_current("05-M05")
	choose("CHAYUKYUNG_NEWS", "PALACE_NEWS", "WORLD")
	await reach("E6")
	open_current("05-M05")
	choose("PALACE_TRANSIT", "WATCH", "WORLD")
	complete("05-M05", "06-M01")
	must(state.current_region == "06" and state.current_anchor == "G0"
		and game.region_host.current_region_id == "06", "regular transit mounts palace region")

	print("M25-32 STEP: 06-M01")
	open_current("06-M01")
	choose("PALACE_ENTRY", "SPECTATE", "WORLD")
	complete("06-M01", "06-M02")
	must(state.story_flags.get("R06_COURT_INTENT", "") == "VIEW", "free spectator route remains available")

	await reach("G1")
	await reach("G2")
	await reach("G3")
	print("M25-32 STEP: 06-M02")
	open_current("06-M02")
	choose("PUBLIC_COURT", "WATCH_EUNSOL", "OBSERVE")
	observe_and_return("06-M02")
	complete("06-M02", "06-M03")
	must(state.story_flags.get("PLAYER_COURT_MATCH_RESULT", "") == "WATCH"
		and state.player_events.is_empty(), "Eunsol observation has no player result")
	var eunsol_events: Array = state.npc_events.values().filter(func(v): return v.get("event_id", "") == "r06_eunsol_independent")
	must(eunsol_events.size() == 1 and eunsol_events[0].get("owner_id", "") == "NPC_EUNSOL"
		and eunsol_events[0].get("participants", []).has("NPC_RECOMMENDED_MASTER"),
		"Eunsol independent court replay uses authored NPC identities")

	print("M25-32 STEP: 06-M03")
	open_current("06-M03")
	choose("WOLIN_INTRO", "VIEW_ONLY", "WORLD")
	await reach("G4")
	await reach("G5", "OPTIONAL_TOWER_ENTRY")
	open_current("06-M03")
	choose("WOLIN_LOBBY", "VIEW", "WORLD")
	complete("06-M03", "06-M04")
	must(state.story_flags.get("WOLIN_INTRO", false) and state.story_flags.get("WOLIN_LOBBY_VISITED", false),
		"Wolin intro and free lobby visit stored")
	must(state.player_q == "NO" and state.main_cursor == "06-M04", "batch ends at 06-M04 without fabricated qualification")

	for failure in failures:
		push_error("MAIN 25-32 E2E FAILED: " + failure)
	if failures.is_empty():
		print("POKERROAD_MAIN_25_32_E2E: %d checks passed" % checks)
		quit(0)
	else:
		quit(1)
