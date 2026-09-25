extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")
const Player = preload("res://scripts/world/player_controller.gd")
const Camera = preload("res://scripts/world/camera_rig.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var gs = get_root().get_node("GameState")
	gs._ready()
	gs.current_region = "01"
	gs.current_anchor = "P0"
	gs.main_cursor = "01-M01"
	gs.finished_main.clear()

	var host = Host.new()
	get_root().add_child(host)
	var mounted: Dictionary = host.mount_region("01", gs)
	must(not mounted.has("error"), "Saebom region mounts")
	must(mounted.get("visual_asset_status", "") == "SAEBOM_DATA_DRIVEN_3_4_BLOCKOUT",
		"Saebom reports data-driven blockout honestly")
	must(int(mounted.get("level_collision_count", 0)) == 8,
		"all validated building footprints have physical collision")

	var world = host.current_region_world
	var visual = world.get_node_or_null("SaebomFirstSpaceVisual")
	must(visual != null, "Saebom data-driven blockout layer exists")
	if visual != null:
		var ground = visual.get_node_or_null("BlockoutGround")
		var buildings = visual.get_node_or_null("BlockoutBuildings")
		var props = visual.get_node_or_null("BlockoutProps")
		var slots = visual.get_node_or_null("InteractionSlots")
		var fg = visual.get_node_or_null("ForegroundOcclusion")
		must(ground != null, "canonical route and micro-navigation ground exists")
		must(buildings != null and buildings.get_child_count() == 8,
			"exact eight validated building masses are instantiated")
		must(props != null and props.get_child_count() == 4,
			"four authored prop/function zones are instantiated")
		must(fg != null and fg.get_child_count() == 5,
			"five non-colliding occlusion candidates are instantiated")
		must(slots != null, "interaction slot root exists")
		var debug = slots.get_node_or_null("BlockoutDebug") if slots != null else null
		must(debug != null and not debug.visible,
			"engineering interaction overlays exist but stay hidden in normal play")
		must(visual.story_markers.size() == 12,
			"all 12 interaction slots expose story marker metadata")
		must(visual.board_marker != null and visual.board_marker.visible,
			"M01 board marker is active from exact interaction data")
		must(visual.bokrye_marker != null and not visual.bokrye_marker.visible,
			"M02 Bokrye marker waits for story progression")
		gs.main_cursor = "01-M02"
		visual._refresh_story_markers()
		must(not visual.board_marker.visible and visual.bokrye_marker.visible,
			"story progression switches to exact Bokrye slot")

	var physical_level = world.get_node_or_null("PhysicalLevelGeometry")
	must(physical_level != null and physical_level.get_child_count() == 8,
		"validated building footprints instantiate eight StaticBody2D collisions")

	var player = Player.new()
	get_root().add_child(player)
	must(not player.bind_region(world, gs).has("error"), "player binds to canonical P0")
	var p0: Vector2 = world.anchor_position("P0")
	must(player.z_index == int(p0.y), "player depth key starts from exact world Y")
	player.global_position = Vector2(p0.x, p0.y + 80.0)
	player._update_depth_sort()
	must(player.z_index == int(p0.y + 80.0), "player depth key follows world Y for 3/4 occlusion")

	var camera = Camera.new()
	player.add_child(camera)
	var camera_result: Dictionary = camera.apply_region(world)
	must(not camera_result.has("error"), "Saebom camera applies")
	must(camera.position == Vector2(90, -110), "initial camera still frames P0/P1 without moving canonical geometry")

	for error in errors:
		push_error("SAEBOM DATA BLOCKOUT FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SAEBOM_DATA_BLOCKOUT: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
