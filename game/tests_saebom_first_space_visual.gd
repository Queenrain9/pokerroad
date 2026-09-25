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

func count_polygons(node: Node) -> int:
	var total := 1 if node is Polygon2D else 0
	for child in node.get_children():
		total += count_polygons(child)
	return total

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
	must(mounted.get("visual_asset_status", "") == "FIRST_SPACE_3_4_PROTOTYPE", "Saebom reports scoped visual prototype")
	var world = host.current_region_world
	var visual = world.get_node_or_null("SaebomFirstSpaceVisual")
	must(visual != null, "first-space visual layer exists")
	if visual != null:
		must(count_polygons(visual) >= 35, "first-space visual is layered from many drawable planes")
		var fg = visual.get_node_or_null("ForegroundOcclusion")
		must(fg != null and fg.z_index > 20, "foreground occlusion renders above player plane")
		must(visual.board_marker != null and visual.board_marker.visible, "M01 board marker is active")
		must(visual.bokrye_marker != null and not visual.bokrye_marker.visible, "M02 Bokrye marker waits for story progression")
		gs.main_cursor = "01-M02"
		visual._refresh_story_markers()
		must(not visual.board_marker.visible and visual.bokrye_marker.visible, "story progression moves marker to Bokrye")
	var player = Player.new()
	get_root().add_child(player)
	must(not player.bind_region(world, gs).has("error"), "3/4 player binds to canonical P0")
	must(player.z_index == 20, "player renders between world props and foreground occlusion")
	var camera = Camera.new()
	player.add_child(camera)
	var camera_result: Dictionary = camera.apply_region(world)
	must(not camera_result.has("error"), "Saebom camera applies")
	must(camera.position == Vector2(90, -110), "first-space camera frames raised terrace and background")
	var p0: Vector2 = world.anchor_position("P0")
	var p1: Vector2 = world.anchor_position("P1")
	must(p0.distance_to(p1) > 400.0, "P0 to P1 remains a real walkable spatial route")
	for error in errors:
		push_error("SAEBOM FIRST SPACE FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SAEBOM_FIRST_SPACE: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
