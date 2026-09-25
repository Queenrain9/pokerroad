extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")
const Player = preload("res://scripts/world/player_controller.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")

var checked := 0
var errors: Array[String] = []
var gs

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	gs = get_root().get_node("GameState")
	gs._ready()
	var spatial_errors: Array[String] = SpatialRegistry.validate_against_manifest(gs.manifest)
	must(spatial_errors.is_empty(), "spatial metrics match all eight manifest regions and anchors")
	var host = Host.new()
	get_root().add_child(host)
	var seen_total := 0
	for i in range(1, 9):
		var region_id := "%02d" % i
		var mounted: Dictionary = host.mount_region(region_id, gs)
		must(not mounted.has("error"), region_id + " spatial region mounts")
		if mounted.has("error"):
			continue
		var world = host.current_region_world
		var bounds: Rect2 = world.world_bounds()
		must(bounds.size.x > 1280.0 and bounds.size.y > 720.0, region_id + " bounds exceed reference viewport")
		var local_seen := {}
		for anchor_id in world.anchor_ids():
			var pos: Vector2 = world.anchor_position(anchor_id)
			must(pos != Vector2.INF and bounds.has_point(pos), region_id + "/" + anchor_id + " positioned inside bounds")
			var key := "%d,%d" % [int(pos.x), int(pos.y)]
			must(not local_seen.has(key), region_id + "/" + anchor_id + " does not overlap another anchor")
			local_seen[key] = true
			seen_total += 1
		must(world.nearest_anchor(world.anchor_position(world.anchor_ids()[0]), 2.0) == world.anchor_ids()[0], region_id + " nearest-anchor lookup exact")
	must(seen_total == 60, "all 60 canonical world anchors receive production navigation coordinates")

	gs.current_region = "01"
	gs.current_anchor = "P0"
	var first: Dictionary = host.mount_region("01", gs)
	must(not first.has("error"), "entry region mounts for player/camera")
	var player = Player.new()
	get_root().add_child(player)
	var bound: Dictionary = player.bind_region(host.current_region_world, gs)
	must(not bound.has("error"), "player binds to mounted region")
	must(player.global_position == host.current_region_world.anchor_position("P0"), "player spawns at canonical current anchor")
	must(player.nearest_interactable_anchor() == "P0", "spawn anchor is interactable")
	player.set_virtual_move_vector(Vector2(1.0, 0.0))
	must(player.virtual_move == Vector2(1.0, 0.0), "mobile virtual movement vector accepted")
	var camera = CameraRig.new()
	player.add_child(camera)
	var camera_result: Dictionary = camera.apply_region(host.current_region_world)
	must(not camera_result.has("error"), "camera consumes shared cross-region metrics")
	must(camera.limit_right > camera.limit_left and camera.limit_bottom > camera.limit_top, "camera limits follow region world bounds")

	for error in errors:
		push_error("SPATIAL RUNTIME FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SPATIAL_RUNTIME: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
