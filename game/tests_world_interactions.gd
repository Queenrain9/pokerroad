extends SceneTree

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
const Host = preload("res://scripts/world/region_host.gd")
const Player = preload("res://scripts/world/player_controller.gd")
const Interactions = preload("res://scripts/world/world_interaction_controller.gd")

var checked: int = 0
var errors: Array[String] = []
var gs

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func reset_world(region_id: String, anchor_id: String, cursor: String) -> void:
	gs.current_region = region_id
	gs.current_anchor = anchor_id
	gs.return_anchor = anchor_id
	gs.main_cursor = cursor
	gs.unlocked_regions = {"01":true,"02":true,"03":true,"04":true,"05":true,"06":true,"07":true,"08":true}
	gs.story_flags.clear()
	gs.observed_events.clear()
	gs.player_events.clear()
	gs.npc_events.clear()
	gs.player_q = "NO"
	gs.registration_intent = "VIEW"

func make_stack(region_id: String):
	var runtime = Runtime.new(gs)
	get_root().add_child(runtime)
	var host = Host.new()
	get_root().add_child(host)
	var mounted: Dictionary = host.mount_region(region_id, gs)
	must(not mounted.has("error"), region_id + " mounts for interaction test")
	var player = Player.new()
	get_root().add_child(player)
	var bound: Dictionary = player.bind_region(host.current_region_world, gs)
	must(not bound.has("error"), region_id + " player binds")
	var controller = Interactions.new(gs, runtime, host, player)
	return {"runtime":runtime,"host":host,"player":player,"controller":controller}

func move_player(stack: Dictionary, anchor_id: String) -> void:
	stack.player.global_position = stack.host.current_region_world.anchor_position(anchor_id)

func dispose(stack: Dictionary) -> void:
	stack.player.queue_free()
	stack.host.queue_free()
	stack.runtime.queue_free()

func _initialize() -> void:
	gs = get_root().get_node("GameState")
	gs._ready()

	reset_world("01","P0","01-M01")
	var stack: Dictionary = make_stack("01")
	move_player(stack,"P1")
	var inspect: Dictionary = stack.controller.inspect_nearby()
	must(inspect.get("kind","") == "TRAVEL_CONFIRMABLE" and inspect.get("from","") == "P0" and inspect.get("to","") == "P1", "physical proximity previews only direct legal travel")
	var arrived: Dictionary = stack.controller.enter_nearby_anchor()
	must(not arrived.has("error") and gs.current_anchor == "P1", "normal nearby anchor travel updates persistent anchor")
	var current: Dictionary = stack.controller.inspect_nearby()
	must(current.get("kind","") == "CURRENT_ANCHOR", "arrived anchor becomes current physical interaction anchor")
	must(current.get("scene_ids", []).has("01-M01") and current.get("scene_ids", []).has("01-M02"), "P1 exposes only authored source bindings at that anchor")
	var opened: Dictionary = stack.controller.open_nearby_scene("01-M01")
	must(not opened.has("error") and stack.runtime.mode == "DIALOGUE", "physical current anchor opens source-backed scene")
	dispose(stack)

	reset_world("01","P0","01-M01")
	stack = make_stack("01")
	move_player(stack,"P3")
	inspect = stack.controller.inspect_nearby()
	must(inspect.get("kind","") == "BLOCKED", "standing near a non-adjacent marker cannot teleport persistent world state")
	must(gs.current_anchor == "P0", "blocked physical shortcut leaves current anchor unchanged")
	dispose(stack)

	reset_world("03","F2","03-M03")
	stack = make_stack("03")
	move_player(stack,"F3")
	inspect = stack.controller.inspect_nearby()
	must(inspect.get("kind","") == "ROUTE_CHOICE_REQUIRED", "forest vertical transfer requires explicit player route choice")
	must(set_from_array(inspect.get("choices", [])) == {"WORK_LIFT":true,"EXTERNAL_STAIRS":true}, "forest exposes both canonical vertical choices")
	var stairs: Dictionary = stack.controller.enter_nearby_anchor("EXTERNAL_STAIRS")
	must(not stairs.has("error") and gs.current_anchor == "F3", "chosen forest stairs route commits physical anchor")
	dispose(stack)

	reset_world("04","H1","04-M02")
	stack = make_stack("04")
	move_player(stack,"H2")
	var wrong_tide: Dictionary = stack.controller.enter_nearby_anchor("LOW_TIDE_MARKER_PATH", {"tide":"HIGH"})
	must(wrong_tide.has("error") and gs.current_anchor == "H1", "wrong tide route cannot commit anchor")
	var high_tide: Dictionary = stack.controller.enter_nearby_anchor("HIGH_TIDE_SAFE_PATH", {"tide":"HIGH"})
	must(not high_tide.has("error") and gs.current_anchor == "H2", "safe high-tide route commits anchor")
	dispose(stack)

	reset_world("05","E3","05-M02")
	stack = make_stack("05")
	move_player(stack,"E3B")
	inspect = stack.controller.inspect_nearby({"last_train_available":false})
	must(inspect.get("kind","") == "ROUTE_CHOICE_REQUIRED" and inspect.get("choices", []).has("BOARD_FREE_NIGHT_BUS"), "missed-train branch exposes explicit free night bus boarding")
	var bus: Dictionary = stack.controller.enter_nearby_anchor("BOARD_FREE_NIGHT_BUS", {"last_train_available":false})
	must(not bus.has("error") and gs.current_anchor == "E3B" and int(bus.get("plan",{}).get("fee",-1)) == 0, "free night bus anchor is physically commit-able at zero fee")
	dispose(stack)

	reset_world("08","C2","08-M02")
	stack = make_stack("08")
	move_player(stack,"C3")
	var blocked_gate: Dictionary = stack.controller.enter_nearby_anchor("REGISTERED_PLAYER_ONLY", {"player_q":"NO","registered_official":false})
	must(blocked_gate.has("error") and gs.current_anchor == "C2", "unqualified player cannot commit registered-player gate")
	var public_gate: Dictionary = stack.controller.enter_nearby_anchor("PUBLIC_SPECTATOR", {"player_q":"NO","registered_official":false})
	must(not public_gate.has("error") and gs.current_anchor == "C3", "public spectator route remains available without Q")
	dispose(stack)

	for error in errors:
		push_error("WORLD INTERACTION FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_WORLD_INTERACTIONS: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)

func set_from_array(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result
