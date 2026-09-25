extends Node

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
const RegionHostScript = preload("res://scripts/world/region_host.gd")

var runtime
var region_host
var state

func _ready() -> void:
	state = get_node_or_null("/root/GameState")
	if state == null:
		push_error("PokerRoad GameState autoload missing")
		return
	var problems: Array[String] = state.validate_world_manifest()
	if not problems.is_empty():
		for problem in problems:
			push_error("PokerRoad world manifest: " + problem)
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
	if not state.world_changed.is_connected(_on_world_changed):
		state.world_changed.connect(_on_world_changed)
	var world: Dictionary = runtime.world_runtime.current_world()
	if world.has("error"):
		push_error("PokerRoad current world: " + str(world.error))
		return
	print("POKERROAD_P5_RUNTIME_BOOT_OK: 8 region scenes registered / current region mounted / source-backed SceneRunner / poker-result-world runtime ready; physical maps remain unimplemented")

func _on_world_changed() -> void:
	if region_host == null or state == null:
		return
	if region_host.current_region_id == state.current_region:
		return
	var mounted: Dictionary = region_host.mount_region(state.current_region, state)
	if mounted.has("error"):
		push_error("PokerRoad region remount: " + str(mounted.error))
