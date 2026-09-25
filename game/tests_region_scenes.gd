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
		if region_id == "01":
			must(mounted.get("visual_asset_status", "") == "FIRST_SPACE_3_4_PROTOTYPE", "01 reports first-space visual prototype honestly")
			must(mounted.get("micro_navigation_status", "") == "LOCAL_WALKABLE_ZONES_ACTIVE", "01 reports active local micro-navigation")
			must(int(mounted.get("micro_navigation_zone_count", 0)) == 12, "01 exposes the authored 12 local walkable zones")
			must(mounted.get("level_geometry_status", "") == "PROVISIONAL_BLOCKOUT_GEOMETRY_VALIDATED_NOT_FINAL_ART", "01 reports validated blockout geometry honestly")
			must(int(mounted.get("level_building_count", 0)) == 8, "01 exposes 8 blockout building footprints")
			must(int(mounted.get("level_interaction_slot_count", 0)) == 12, "01 exposes 12 interaction slots")
			must(int(mounted.get("level_occlusion_candidate_count", 0)) == 5, "01 exposes 5 non-colliding occlusion candidates")
		else:
			must(mounted.get("visual_asset_status", "") == "NOT_STARTED", region_id + " does not claim visual assets")
			must(mounted.get("micro_navigation_status", "") == "NONE", region_id + " does not claim unauthored local micro-navigation")
			must(int(mounted.get("micro_navigation_zone_count", 0)) == 0, region_id + " has no unauthored local zones")
			must(mounted.get("level_geometry_status", "") == "NONE", region_id + " does not claim unauthored blockout geometry")
		var marker_count := 0
		var route_count := 0
		var visual_count := 0
		for child in host.current_region_world.get_children():
			if child is Marker2D:
				marker_count += 1
				must(child.get_meta("runtime_role", "") == "NON_VISUAL_INTERACTION_ANCHOR", region_id + " marker cannot masquerade as art")
			elif child is Label:
				must(not child.text.is_empty(), region_id + " wayfinding label is readable")
			elif child.name == "PhysicalRoutes":
				route_count += 1
				must(child.get_meta("runtime_role", "") == "NON_VISUAL_ROUTE_GEOMETRY", region_id + " physical collision root is present")
			elif region_id == "01" and child.name == "SaebomFirstSpaceVisual":
				visual_count += 1
		must(marker_count == anchor_count and route_count == 1, region_id + " creates every anchor and physical route root")
		must(visual_count == (1 if region_id == "01" else 0), region_id + " visual layer count matches scope")
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
