extends Node

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
const RegionHostScript = preload("res://scripts/world/region_host.gd")
const PlayerScript = preload("res://scripts/world/player_controller.gd")
const CameraScript = preload("res://scripts/world/camera_rig.gd")
const InteractionScript = preload("res://scripts/world/world_interaction_controller.gd")

var runtime
var region_host
var player
var camera
var interaction_controller
var state

func _ready() -> void:
	state = get_node_or_null("/root/GameState")
	if state == null:
		push_error("PokerRoad GameState autoload missing")
		return
	var problems: Array[String] = state.validate_world_manifest()
	problems.append_array(SpatialRegistry.validate_against_manifest(state.manifest))
	if not problems.is_empty():
		for problem in problems:
			push_error("PokerRoad world manifest/spatial: " + problem)
		return
	runtime = Runtime.new(state)
	add_child(runtime)
	var runtime_problems: Array[String] = runtime.validate_runtime()
	if not runtime_problems.is_empty():
		for problem in runtime_problems:
			push_error("PokerRoad runtime: " + problem)
		return
	region_host = RegionHostScript.new()
	add_child(region_host)
	var region_problems: Array[String] = region_host.validate_all_region_scenes(state)
	if not region_problems.is_empty():
		for problem in region_problems:
			push_error("PokerRoad region scene: " + problem)
		return
	var mounted: Dictionary = region_host.mount_region(state.current_region, state)
	if mounted.has("error"):
		push_error("PokerRoad region mount: " + str(mounted.error))
		return
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	var player_bound: Dictionary = player.bind_region(region_host.current_region_world, state)
	if player_bound.has("error"):
		push_error("PokerRoad player bind: " + str(player_bound.error))
		return
	camera = CameraScript.new()
	camera.name = "WorldCamera"
	player.add_child(camera)
	camera.make_current()
	var camera_bound: Dictionary = camera.apply_region(region_host.current_region_world)
	if camera_bound.has("error"):
		push_error("PokerRoad camera bind: " + str(camera_bound.error))
		return
	interaction_controller = InteractionScript.new(state, runtime, region_host, player)
	if not state.world_changed.is_connected(_on_world_changed):
		state.world_changed.connect(_on_world_changed)
	var world: Dictionary = runtime.world_runtime.current_world()
	if world.has("error"):
		push_error("PokerRoad current world: " + str(world.error))
		return
	print("POKERROAD_P5_ROUTE_BOOT_OK: 8 region route geometries, gates, anchors and player/camera active; final environment art remains unimplemented")

func _on_world_changed() -> void:
	if region_host == null or state == null:
		return
	if region_host.current_region_id != state.current_region:
		var mounted: Dictionary = region_host.mount_region(state.current_region, state)
		if mounted.has("error"):
			push_error("PokerRoad region remount: " + str(mounted.error))
			return
		if player != null:
			var player_bound: Dictionary = player.bind_region(region_host.current_region_world, state)
			if player_bound.has("error"):
				push_error("PokerRoad player remount: " + str(player_bound.error))
		if camera != null:
			var camera_bound: Dictionary = camera.apply_region(region_host.current_region_world)
			if camera_bound.has("error"):
				push_error("PokerRoad camera remount: " + str(camera_bound.error))
	elif player != null and player.active_region != null:
		var anchor_position: Vector2 = region_host.current_region_world.anchor_position(state.current_anchor)
		if anchor_position != Vector2.INF and not region_host.current_region_world.can_walk_from(state.current_anchor, player.global_position):
			player.global_position = anchor_position
			player.velocity = Vector2.ZERO


func inspect_world_interaction(context: Dictionary = {}) -> Dictionary:
	if interaction_controller == null:
		return {"error":"world interaction controller unavailable"}
	return interaction_controller.inspect_nearby(context)

func confirm_world_interaction(selected_route: String = "", context: Dictionary = {}) -> Dictionary:
	if interaction_controller == null:
		return {"error":"world interaction controller unavailable"}
	return interaction_controller.enter_nearby_anchor(selected_route, context)

func open_nearby_scene(scene_id: String) -> Dictionary:
	if interaction_controller == null:
		return {"error":"world interaction controller unavailable"}
	return interaction_controller.open_nearby_scene(scene_id)
