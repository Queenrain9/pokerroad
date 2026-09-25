extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")

var checked := 0
var errors: Array[String] = []
var gs

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func manifest_region(region_id: String) -> Dictionary:
	for region in gs.manifest.get("regions", []):
		if region.get("id", "") == region_id:
			return region
	return {}

func _initialize() -> void:
	gs = get_root().get_node("GameState")
	gs._ready()
	var host = Host.new()
	get_root().add_child(host)
	var validation: Array[String] = host.validate_all_region_scenes(gs)
	must(validation.is_empty(), "all eight production region scenes satisfy RegionWorld contract")
	for i in range(1, 9):
		var region_id := "%02d" % i
		var mounted: Dictionary = host.mount_region(region_id, gs)
		must(not mounted.has("error"), region_id + " region scene mounts")
		if mounted.has("error"):
			continue
		var manifest: Dictionary = manifest_region(region_id)
		must(mounted.get("id", "") == region_id, region_id + " scene identity exact")
		must(mounted.get("anchor_ids", []).size() == manifest.get("anchors", []).size(), region_id + " scene exposes every manifest anchor identity")
		must(not mounted.get("capabilities", []).is_empty(), region_id + " scene carries production capability contract")
		must(mounted.get("physical_map_status", "") == "NOT_IMPLEMENTED", region_id + " does not claim a physical map")
		must(mounted.get("visual_asset_status", "") == "NOT_STARTED", region_id + " does not claim visual assets")
		must(host.current_region_world.get_child_count() == 0, region_id + " scene contains no disposable placeholder art/geometry")
	gs.current_region = "01"
	gs.current_anchor = "P0"
	var first: Dictionary = host.mount_region("01", gs)
	must(not first.has("error") and host.current_region_world.current_anchor_is_valid(), "production entry region validates P0 anchor")
	for error in errors:
		push_error("REGION SCENE FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_REGION_SCENES: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
