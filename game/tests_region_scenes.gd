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
		var anchor_count: int = manifest.get("anchors", []).size()
		must(mounted.get("id", "") == region_id, region_id + " scene identity exact")
		must(mounted.get("anchor_ids", []).size() == anchor_count, region_id + " scene exposes every manifest anchor identity")
		must(not mounted.get("capabilities", []).is_empty(), region_id + " scene carries production capability contract")
		must(mounted.get("navigation_skeleton_status", "") == "ANCHORS_POSITIONED", region_id + " has positioned nonvisual anchors")
		must(mounted.get("physical_map_status", "") == "ROUTE_GEOMETRY_ACTIVE", region_id + " has active nonvisual route geometry")
		must(int(mounted.get("route_edge_count", 0)) > 0, region_id + " has traversable route edges")
		must(mounted.get("visual_asset_status", "") == "NOT_STARTED", region_id + " does not claim visual assets")
		must(host.current_region_world.get_child_count() == anchor_count + 1, region_id + " creates anchors plus physical routes")
		for child in host.current_region_world.get_children():
			if child is Marker2D:
				must(child.get_meta("runtime_role", "") == "NON_VISUAL_INTERACTION_ANCHOR", region_id + " marker cannot masquerade as art")
			else:
				must(child.name == "PhysicalRoutes" and child.get_meta("runtime_role", "") == "NON_VISUAL_ROUTE_GEOMETRY", region_id + " physical collision root is present")
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
