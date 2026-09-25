extends Node
## Permanent world-state API for the eight-region mainline. Story content must
## come from the original v4.2 scene records, not fake placeholder dialogue.
signal world_changed

const MANIFEST_PATH = "res://data/world_manifest.json"
const SAVE_PATH = "user://poker_road_save_v1.json"
const SAVE_SCHEMA = 1
const SESSION_SAVE_PATH = "user://poker_road_save_v2.json"

var manifest: Dictionary = {}
var main_cursor := "01-M01"
var current_region := "01"
var current_anchor := "P0"
var world_layer := 0
var return_anchor := "P0"
var unlocked_regions: Dictionary = {"01": true}
var finished_main: Dictionary = {}
var finished_optional: Dictionary = {}
var rewards_paid: Dictionary = {}
var world_phase := 0
var chips := 0
var player_q := "NO"
var registration_intent := "VIEW"
var player_events: Dictionary = {}
var npc_events: Dictionary = {}
var npc_seat_status: Dictionary = {}
var observed_events: Dictionary = {}
var story_flags: Dictionary = {}
var event_serial := 0

func _ready() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing original scene world manifest")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Malformed original scene world manifest")
		return
	manifest = parsed

func validate_world_manifest() -> Array[String]:
	var errors: Array[String] = []
	if manifest.get("regions", []).size() != 8:
		errors.append("expected 8 regions")
	if manifest.get("scenes", []).size() != 88:
		errors.append("expected 88 original scene IDs")
	var seen: Dictionary = {}
	var main_total := 0
	for item in manifest.get("scenes", []):
		var id := str(item.get("id", ""))
		if seen.has(id):
			errors.append("duplicate scene ID " + id)
		seen[id] = true
		if item.get("kind", "") == "MAIN":
			main_total += 1
	if main_total != 48:
		errors.append("expected 48 main scene IDs")
	return errors

func scene_record(scene_id: String) -> Dictionary:
	for record in manifest.get("scenes", []):
		if record.get("id", "") == scene_id:
			return record
	return {}

func scene_source_record(scene_id: String) -> Dictionary:
	var record := scene_record(scene_id)
	if record.is_empty():
		return {"error": "unknown source scene"}
	return SceneSourceStore.get_original(scene_id, record)

func scene_is_implemented(scene_id: String) -> bool:
	var record := scene_record(scene_id)
	if record.is_empty() or record.get("source_import_status") != "IMPORTED" or record.get("game_implementation_status") != "IMPLEMENTED":
		return false
	return not scene_source_record(scene_id).has("error") and not record.get("player_action_bindings", []).is_empty()

func complete_main_scene(scene_id: String) -> bool:
	if scene_id != main_cursor or not scene_is_implemented(scene_id):
		return false
	finished_main[scene_id] = true
	var record := scene_record(scene_id)
	var next_id = record.get("next_main_scene_id")
	if next_id == null:
		main_cursor = "STORY_END"
	else:
		main_cursor = str(next_id)
		if main_cursor.substr(0, 2) != scene_id.substr(0, 2):
			unlocked_regions[main_cursor.substr(0, 2)] = true
	emit_signal("world_changed")
	return true

func step_to_anchor(destination: String, selected_route: String = "", context: Dictionary = {}) -> Dictionary:
	var graph: Dictionary = TraversalService.load_graph()
	if graph.has("error"):
		return graph
	var plan: Dictionary = TraversalService.plan_step(graph, current_region, current_anchor,
		destination, selected_route, context)
	if plan.has("error"):
		return plan
	current_anchor = destination
	emit_signal("world_changed")
	return plan

func change_region(region_id: String, anchor_id: String) -> bool:
	if not unlocked_regions.has(region_id) or region_id == current_region:
		return false
	if absi(int(region_id) - int(current_region)) != 1:
		return false
	var graph: Dictionary = TraversalService.load_graph()
	if graph.has("error"):
		return false
	for region in graph.get("regions", []):
		if region.get("id", "") != region_id:
			continue
		if anchor_id != region.get("entry_anchor", ""):
			return false
		if not TraversalService.can_leave_region_at_public_exit(graph, current_region,
				current_anchor, true):
			return false
		current_region = region_id
		current_anchor = anchor_id
		emit_signal("world_changed")
		return true
	return false

func grant_one_time_reward(reward_id: String, amount: int) -> bool:
	if reward_id.is_empty() or rewards_paid.has(reward_id) or amount < 0:
		return false
	rewards_paid[reward_id] = true
	chips += amount
	emit_signal("world_changed")
	return true

func pay_entry_fee(amount: int) -> bool:
	if amount < 0 or chips < amount:
		return false
	chips -= amount
	emit_signal("world_changed")
	return true

func record_player_event(event_id: String, event: Dictionary) -> bool:
	if event_id.is_empty() or player_events.has(event_id) or npc_events.has(event_id):
		return false
	player_events[event_id] = event.duplicate(true)
	emit_signal("world_changed")
	return true

func record_npc_event(event_id: String, event: Dictionary) -> bool:
	if event_id.is_empty() or player_events.has(event_id) or npc_events.has(event_id):
		return false
	npc_events[event_id] = event.duplicate(true)
	emit_signal("world_changed")
	return true

func set_story_flag(key: String, value) -> bool:
	if key.is_empty():
		return false
	story_flags[key] = value
	emit_signal("world_changed")
	return true

func record_observation(event_id: String, status: String) -> bool:
	if event_id.is_empty() or status.is_empty():
		return false
	observed_events[event_id] = status
	emit_signal("world_changed")
	return true

func allocate_event_instance_id(event_id: String) -> String:
	if event_id.is_empty():
		return ""
	event_serial += 1
	emit_signal("world_changed")
	return "%s#%06d" % [event_id, event_serial]

func _save_payload() -> Dictionary:
	return {"schema": SAVE_SCHEMA, "main_cursor": main_cursor, "current_region": current_region,
		"current_anchor": current_anchor, "unlocked_regions": unlocked_regions, "finished_main": finished_main,
		"finished_optional": finished_optional, "rewards_paid": rewards_paid,
		"world_phase": world_phase, "chips": chips, "player_q": player_q,
		"registration_intent": registration_intent, "player_events": player_events,
		"npc_events": npc_events, "npc_seat_status": npc_seat_status,
		"observed_events": observed_events, "story_flags": story_flags, "event_serial": event_serial}

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_save_payload()))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var loaded = JSON.parse_string(file.get_as_text())
	if typeof(loaded) != TYPE_DICTIONARY or loaded.get("schema") != SAVE_SCHEMA:
		return false
	if loaded.get("chips", -1) < 0 or not ["YES", "NO", "PENDING"].has(loaded.get("player_q", "")):
		return false
	if loaded.get("main_cursor", "") != "STORY_END" and scene_record(str(loaded.get("main_cursor", ""))).is_empty():
		return false
	for key in ["main_cursor", "unlocked_regions", "finished_main", "finished_optional", "rewards_paid", "world_phase", "chips", "player_q", "registration_intent", "player_events", "npc_events", "npc_seat_status", "observed_events"]:
		if not loaded.has(key):
			return false
	var known_anchor := false
	for region in manifest.get("regions", []):
		if region.get("id", "") != str(loaded.get("current_region", "")):
			continue
		for point in region.get("anchors", []):
			if point.get("id", "") == str(loaded.get("current_anchor", "")):
				known_anchor = true
	if not known_anchor or not loaded.unlocked_regions.has(str(loaded.current_region)) or not loaded.unlocked_regions.has("01"):
		return false
	current_region = str(loaded.current_region)
	current_anchor = str(loaded.current_anchor)
	main_cursor = loaded.main_cursor
	unlocked_regions = loaded.unlocked_regions
	finished_main = loaded.finished_main
	finished_optional = loaded.finished_optional
	rewards_paid = loaded.rewards_paid
	world_phase = loaded.world_phase
	chips = loaded.chips
	player_q = loaded.player_q
	registration_intent = loaded.registration_intent
	player_events = loaded.player_events
	npc_events = loaded.npc_events
	npc_seat_status = loaded.npc_seat_status
	observed_events = loaded.observed_events
	story_flags = loaded.get("story_flags", {}).duplicate(true)
	event_serial = int(loaded.get("event_serial", 0))
	emit_signal("world_changed")
	return true


func world_snapshot_v2() -> Dictionary:
	return {
		"main_cursor":main_cursor,
		"current_region":current_region,
		"current_anchor":current_anchor,
		"world_layer":world_layer,
		"return_anchor":return_anchor,
		"unlocked_regions":unlocked_regions.duplicate(true),
		"finished_main":finished_main.duplicate(true),
		"finished_optional":finished_optional.duplicate(true),
		"rewards_paid":rewards_paid.duplicate(true),
		"world_phase":world_phase,
		"chips":chips,
		"player_q":player_q,
		"registration_intent":registration_intent,
		"player_events":player_events.duplicate(true),
		"npc_events":npc_events.duplicate(true),
		"npc_seat_status":npc_seat_status.duplicate(true),
		"observed_events":observed_events.duplicate(true),
		"story_flags":story_flags.duplicate(true),
		"event_serial":event_serial
	}

func apply_world_snapshot_v2(world: Dictionary) -> bool:
	var contract := SessionSaveService.load_contract()
	if contract.has("error"):
		return false
	for field in contract.get("required_world_fields", []):
		if not world.has(field):
			return false
	if int(world.get("chips", -1)) < 0 or not ["YES","NO","PENDING"].has(str(world.get("player_q", ""))):
		return false
	var region := str(world.get("current_region", ""))
	var anchor := str(world.get("current_anchor", ""))
	var known_anchor := false
	for item in manifest.get("regions", []):
		if item.get("id", "") != region:
			continue
		for point in item.get("anchors", []):
			if point.get("id", "") == anchor:
				known_anchor = true
	if not known_anchor:
		return false
	if world.get("main_cursor", "") != "STORY_END" and scene_record(str(world.get("main_cursor", ""))).is_empty():
		return false
	var unlocked = world.get("unlocked_regions", {})
	if typeof(unlocked) != TYPE_DICTIONARY or not unlocked.has("01") or not unlocked.has(region):
		return false
	main_cursor = str(world.main_cursor)
	current_region = region
	current_anchor = anchor
	world_layer = int(world.world_layer)
	return_anchor = str(world.return_anchor)
	unlocked_regions = unlocked.duplicate(true)
	finished_main = world.finished_main.duplicate(true)
	finished_optional = world.finished_optional.duplicate(true)
	rewards_paid = world.rewards_paid.duplicate(true)
	world_phase = int(world.world_phase)
	chips = int(world.chips)
	player_q = str(world.player_q)
	registration_intent = str(world.registration_intent)
	player_events = world.player_events.duplicate(true)
	npc_events = world.npc_events.duplicate(true)
	npc_seat_status = world.npc_seat_status.duplicate(true)
	observed_events = world.observed_events.duplicate(true)
	story_flags = world.story_flags.duplicate(true)
	event_serial = int(world.event_serial)
	emit_signal("world_changed")
	return true

func save_session_v2(mode: String, mode_state: Dictionary = {}) -> bool:
	var payload := SessionSaveService.build_payload(world_snapshot_v2(), mode, mode_state)
	if payload.has("error"):
		return false
	return SessionSaveService.write_atomic(SESSION_SAVE_PATH, payload)

func load_session_v2() -> Dictionary:
	var payload := SessionSaveService.read_payload(SESSION_SAVE_PATH)
	if payload.has("error"):
		return payload
	if not apply_world_snapshot_v2(payload.world):
		return {"error":"world snapshot rejected"}
	return {"mode":payload.mode, "mode_state":payload.mode_state.duplicate(true)}
