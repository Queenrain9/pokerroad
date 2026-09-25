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
	while game.player.global_position.distance_to(position) > 55.0 and steps < 1200:
		game.player.set_virtual_move_vector((position - game.player.global_position).normalized())
		await physics_frame
		steps += 1
	game.player.clear_virtual_move()
	must(steps < 1200, "physical walking reaches target " + str(position))

func reach(anchor: String, selected_route: String = "") -> void:
	var region = game.region_host.current_region_world
	var from_anchor: String = state.current_anchor
	var destination: Vector2 = region.anchor_position(anchor)
	if region.is_portal(from_anchor, anchor):
		destination = region.route_geometry.portal_position(from_anchor, anchor)
	await walk_to(destination)
	var nearby: Dictionary = game.inspect_world_interaction()
	must(["TRAVEL_CONFIRMABLE","ROUTE_CHOICE_REQUIRED"].has(nearby.get("kind", "")), "physical route " + from_anchor + " -> " + anchor)
	var route := selected_route
	if nearby.get("kind", "") == "ROUTE_CHOICE_REQUIRED" and route.is_empty():
		route = str(nearby.get("choices", [""])[0])
	var result: Dictionary = game.confirm_world_interaction(route)
	must(not result.has("error") and state.current_anchor == anchor, "arrives at " + anchor)

func open_current(id: String) -> void:
	var nearby: Dictionary = game.inspect_world_interaction()
	must(nearby.get("kind", "") == "CURRENT_ANCHOR" and nearby.get("scene_ids", []).has(id), id + " reachable")
	var opened: Dictionary = game.open_nearby_scene(id)
	must(not opened.has("error") and game.runtime.mode == "DIALOGUE" and str(opened.get("verbatim_source_markdown", "")).length() > 80, id + " opens canonical dialogue")

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
	var cursor: String = state.main_cursor
	state.main_cursor = id
	var restored: Dictionary = game.runtime.restore_runtime()
	must(not restored.has("error") and state.main_cursor == cursor and state.finished_main.has(id), id + " reloads")
	must(not game.runtime.commit_active_scene().has("completed"), id + " cannot complete twice")
	if state.current_region == id.substr(0, 2):
		var replay: Dictionary = game.open_nearby_scene(id)
		must(not replay.has("error") and replay.get("completed", false), id + " replay is dialogue-only")
		must(not game.runtime.close_completed_scene().has("error"), id + " replay closes")

func run_suite() -> void:
	state = root.get_node("GameState")
	state._ready()
	state.main_cursor = "02-M02"
	state.current_region = "02"
	state.current_anchor = "K0"
	state.return_anchor = "K0"
	state.unlocked_regions = {"01":true,"02":true}
	state.finished_main.clear()
	state.finished_optional.clear()
	state.rewards_paid.clear()
	state.story_flags.clear()
	state.player_events.clear()
	state.npc_events.clear()
	state.observed_events.clear()
	state.event_serial = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.play_ui.set_process(false)
	await physics_frame

	await reach("K1")
	await reach("K2")
	open_current("02-M02")
	choose("RIVER_BROADCAST", "SUMMARY", "OBSERVE")
	observe_and_return("02-M02")
	complete("02-M02", "02-M03")
	must(state.npc_events.values().any(func(v): return v.get("event_id", "") == "r02_ian_river_broadcast"), "Ian broadcast replay stored")

	await reach("K3")
	open_current("02-M03")
	choose("BOAT_ACCESS", "VIEW", "WORLD")
	complete("02-M03", "02-M04")
	must(state.story_flags.get("R02_ON_BOAT", false) and state.registration_intent == "VIEW", "spectator boarding stored")

	open_current("02-M04")
	choose("BOAT_EVENT", "WATCH_YUNHARU", "OBSERVE")
	observe_and_return("02-M04")
	complete("02-M04", "02-M05")
	must(state.story_flags.get("R02_MATCH_RESULT", "") == "VIEW" and state.player_events.is_empty(), "spectator has no player result")
	must(state.npc_events.values().any(func(v): return v.get("event_id", "") == "r02_yunharu_boat_demo"), "Yunharu replay stored")

	open_current("02-M05")
	choose("REUNION", "FOREST_NEWS", "WORLD")
	complete("02-M05", "02-M06")
	must(state.story_flags.get("R02_IAN_DIRECT_RESULT", "") == "NOT_ENTERED", "Ian practice remains optional")

	await reach("K5")
	open_current("02-M06")
	choose("FOREST_BUS", "LANDSCAPE", "WORLD")
	complete("02-M06", "03-M01")
	must(state.current_region == "03" and state.current_anchor == "F0" and game.region_host.current_region_id == "03", "free bus mounts forest")

	open_current("03-M01")
	choose("MIRO_GUIDE", "STAIRS", "WORLD")
	must(not game.runtime.scene_runner.ready_to_complete(), "03-M01 waits for F2 sign")
	await reach("F1")
	await reach("F2")
	open_current("03-M01")
	choose("PATH_SIGN", "CONFIRM", "WORLD")
	complete("03-M01", "03-M02")

	open_current("03-M02")
	choose("ASCENT", "EXTERNAL_STAIRS", "WORLD")
	must(not game.runtime.scene_runner.ready_to_complete(), "03-M02 waits for F3")
	await reach("F3", "EXTERNAL_STAIRS")
	open_current("03-M02")
	choose("ARRIVAL", "CONFIRM_F3", "WORLD")
	complete("03-M02", "03-M03")
	must(state.story_flags.get("R03_ASCENT_ROUTE", "") == "EXTERNAL_STAIRS", "forest route choice stored")

	await reach("F4")
	open_current("03-M03")
	choose("SHOWCASE_VIEW", "SUMMARY", "OBSERVE")
	observe_and_return("03-M03")
	must(not game.runtime.scene_runner.ready_to_complete(), "03-M03 keeps read response")
	open_current("03-M03")
	choose("SHOWCASE_READ", "WATCH", "WORLD")
	complete("03-M03", "03-M04")
	must(state.npc_events.values().any(func(v): return v.get("event_id", "") == "r03_doyun_showcase"), "Doyun replay stored")
	must(state.player_events.is_empty() and state.main_cursor == "03-M04", "batch ends at 03-M04 without fake player result")

	for failure in failures:
		push_error("MAIN 09-16 E2E FAILED: " + failure)
	if failures.is_empty():
		print("POKERROAD_MAIN_09_16_E2E: %d checks passed" % checks)
		quit(0)
	else:
		quit(1)
