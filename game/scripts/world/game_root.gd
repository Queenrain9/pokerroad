extends Node

const Runtime = preload("res://scripts/runtime/game_runtime.gd")
var runtime
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
	var world: Dictionary = runtime.world_runtime.current_world()
	if world.has("error"):
		push_error("PokerRoad current world: " + str(world.error))
		return
	print("POKERROAD_P5_RUNTIME_BOOT_OK: 8 region descriptors / source-backed SceneRunner / poker-result-world runtime ready; physical maps remain unimplemented")
