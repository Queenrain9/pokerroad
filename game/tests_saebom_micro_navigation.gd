extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	var state = get_root().get_node("GameState")
	state._ready()
	state.current_region = "01"
	state.current_anchor = "P0"
	var host = Host.new()
	get_root().add_child(host)
	var mounted: Dictionary = host.mount_region("01", state)
	must(not mounted.has("error"), "Saebom mounts with micro-navigation")
	if mounted.has("error"):
		_finish()
		return
	var world = host.current_region_world
	var geometry = world.route_geometry

	must(geometry.local_zone_count() == 12, "Saebom exposes all 12 authored local walkable zones")
	must(mounted.get("micro_navigation_status", "") == "LOCAL_WALKABLE_ZONES_ACTIVE", "descriptor reports active local walkable zones")
	must(int(mounted.get("micro_navigation_zone_count", 0)) == 12, "descriptor reports exact local zone count")

	must(world.can_walk_from("P0", Vector2(400, 1400)), "P0 can enter playground free-roam pocket")
	must(world.can_walk_from("P0", Vector2(120, 1420)), "P0 can reach S02 apartment end-house lane")
	must(not world.can_walk_from("P1", Vector2(120, 1420)), "P1 cannot bypass anchor progression directly into P0 end-house pocket")
	must(world.can_walk_from("P1", Vector2(850, 1240)), "P1 can circulate around the super resident pocket")
	must(world.can_walk_from("P2", Vector2(1500, 850)), "P2 can approach the shop court away from the canonical centerline")
	must(world.can_walk_from("P3", Vector2(2100, 700)), "P3 can enter Ian back-alley micro-space")
	must(world.can_walk_from("P4", Vector2(2700, 450)), "P4 can circulate across the tower entrance plaza")
	must(world.can_walk_from("P3", Vector2(3000, 1040)), "P3 public-exit approach has breathing room beyond the thin corridor")
	must(world.can_walk_from("P5", Vector2(3450, 1080)), "P5 can circulate around the bus plaza")
	must(not world.can_walk_from("P0", Vector2(1500, 850)), "P0 local free-roam cannot skip directly into P2 shop pocket")
	must(not world.can_walk_from("P0", Vector2(3500, 1600)), "un-authored ground remains blocked")

	var physical: Node2D = world.get_node("PhysicalRoutes")
	var corridor_walls := 0
	for child in physical.get_children():
		if child is StaticBody2D and child.name.begins_with("CorridorWall_"):
			corridor_walls += 1
	must(corridor_walls == 0, "Saebom local polygons are not physically sealed by old corridor walls")

	var portal: Vector2 = geometry.portal_position("P3", "P4")
	must(portal != Vector2.INF and world.can_walk_from("P3", portal), "P3 tower portal remains reachable through the back-alley space")
	must(not world.can_walk_from("P3", world.anchor_position("P4")), "P3 still cannot walk through the optional tower portal")

	_finish()

func _finish() -> void:
	for error in errors:
		push_error("SAEBOM MICRO NAV FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SAEBOM_MICRO_NAV: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
