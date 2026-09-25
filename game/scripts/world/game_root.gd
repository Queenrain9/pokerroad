extends Node
## Production entrypoint, intentionally no disposable UI. Region scenes and art are
## added only after the common spatial / visual contract has been approved.

func _ready() -> void:
	var problems: Array[String] = GameState.validate_world_manifest()
	if not problems.is_empty():
		for problem in problems:
			push_error("PokerRoad world manifest: " + problem)
		return
	print("POKERROAD_P0_BOOT_OK: 8 regions, 88 original scene IDs registered; scene content NOT imported")
