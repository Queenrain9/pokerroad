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

func reach(anchor: String) -> void:
	var region = game.region_host.current_region_world
	var from_anchor: String = state.current_anchor
	var destination: Vector2 = region.anchor_position(anchor)
	if region.is_portal(from_anchor, anchor):
		destination = region.route_geometry.portal_position(from_anchor, anchor)
	await walk_to(destination)
	var nearby: Dictionary = game.inspect_world_interaction()
	must(["TRAVEL_CONFIRMABLE","ROUTE_CHOICE_REQUIRED"].has(nearby.get("kind", "")),
		"physical interaction previews " + from_anchor + " -> " + anchor)
	var route := ""
	if nearby.get("kind", "") == "ROUTE_CHOICE_REQUIRED":
		route = str(nearby.get("choices", [""])[0])
	var result: Dictionary = game.confirm_world_interaction(route)
	must(not result.has("error") and state.current_anchor == anchor,
		"route service confirms arrival at " + anchor)

func open_current(id: String) -> void:
	var nearby: Dictionary = game.inspect_world_interaction()
	must(nearby.get("kind", "") == "CURRENT_ANCHOR" and nearby.get("scene_ids", []).has(id),
		id + " is reachable and bound to the nearby target")
	var opened: Dictionary = game.open_nearby_scene(id)
	must(not opened.has("error") and game.runtime.mode == "DIALOGUE" and
		str(opened.get("verbatim_source_markdown", "")).length() > 80,
		id + " enters source-backed dialogue")

func choice(interaction: String, option: String, target: String) -> void:
	var selected: Dictionary = game.runtime.select_scene_choice(interaction, option)
	must(not selected.has("error") and game.runtime.mode == target,
		"choice " + option + " enters " + target)

func complete(id: String, next_id: String) -> void:
	must(game.runtime.mode == "WORLD" and game.runtime.scene_runner.ready_to_complete(),
		id + " returns control with completion ready")
	var result: Dictionary = game.runtime.commit_active_scene()
	must(not result.has("error") and state.finished_main.has(id) and state.main_cursor == next_id,
		id + " mutates state, exits and unlocks " + next_id)
	must(game.runtime.mode == "WORLD" and not game.runtime.scene_runner.has_active_scene(),
		id + " restores world control")
	must(game.runtime.save_runtime(), id + " saves completed world")
	var cursor: String = state.main_cursor
	state.main_cursor = id
	var restored: Dictionary = game.runtime.restore_runtime()
	must(not restored.has("error") and state.main_cursor == cursor and state.finished_main.has(id),
		id + " reloads without replaying completion")
	must(not game.runtime.commit_active_scene().has("completed"), id + " cannot complete twice")
	if state.current_region == id.substr(0, 2):
		var replay: Dictionary = game.open_nearby_scene(id)
		must(not replay.has("error") and replay.get("completed", false), id + " offers completed dialogue")
		var binding: Dictionary = game.runtime.scene_runner.active_binding
		var first: Dictionary = binding.get("interactions", [])[0]
		var first_choice: Dictionary = first.get("choices", [])[0]
		must(game.runtime.select_scene_choice(str(first.get("interaction_id", "")), str(first_choice.get("choice_id", ""))).has("error"),
			id + " cannot repeat action or reward")
		must(not game.runtime.close_completed_scene().has("error"), id + " completed dialogue exits to world")

func run_suite() -> void:
	state = root.get_node("GameState")
	state._ready()
	state.main_cursor = "01-M01"
	state.current_region = "01"
	state.current_anchor = "P0"
	state.return_anchor = "P0"
	state.unlocked_regions = {"01":true}
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
	open_current("01-M01")
	choice("START_ACK", "BOARD_CONFIRM", "WORLD")
	complete("01-M01", "01-M02")
	await reach("P1")
	open_current("01-M02")
	choice("BOKRYE_FREE_TABLE", "SKIP", "WORLD")
	complete("01-M02", "01-M03")
	await reach("P2")
	await reach("P3")
	open_current("01-M03")
	choice("STORY_ACTION", "VIEW", "WORLD")
	complete("01-M03", "01-M04")
	open_current("01-M04")
	choice("STORY_ACTION", "WATCH_BOARD", "OBSERVE")
	must(not game.runtime.finish_observation().has("error"), "M04 observation performs actual OBSERVE action")
	must(not game.runtime.acknowledge_result().has("error"), "M04 observation result returns to world")
	complete("01-M04", "01-M05")
	must(state.npc_events.size() == 1 and state.player_events.is_empty(),
		"M04 uses independent NPC engine replay without player result for spectator")
	open_current("01-M05")
	choice("STORY_ACTION", "OBSERVE", "WORLD")
	complete("01-M05", "01-M06")
	await reach("P4")
	open_current("01-M06")
	choice("STORY_ACTION", "LATER", "WORLD")
	complete("01-M06", "01-M07")
	await reach("P3")
	await reach("P5")
	open_current("01-M07")
	choice("STORY_ACTION", "OBSERVE", "WORLD")
	complete("01-M07", "02-M01")
	must(state.current_region == "02" and state.current_anchor == "K0" and game.region_host.current_region_id == "02",
		"free physical bus transition mounts river world")
	open_current("02-M01")
	choice("STORY_ACTION", "WALK", "WORLD")
	complete("02-M01", "02-M02")
	must(state.story_flags.get("R02_RIVER_SEEN", false) and state.player_q == "NO",
		"river arrival sets first-route knowledge without qualification")
	for failure in failures:
		push_error("FIRST EIGHT E2E FAILED: " + failure)
	if failures.is_empty():
		print("POKERROAD_FIRST_EIGHT_E2E: %d checks passed" % checks)
		quit(0)
	else:
		quit(1)
