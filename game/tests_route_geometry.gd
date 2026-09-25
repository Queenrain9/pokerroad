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
	var host = Host.new()
	get_root().add_child(host)
	var graph: Dictionary = TraversalService.load_graph()
	var total_anchors := 0
	var total_edges := 0
	var total_portals := 0
	for region in graph.get("regions", []):
		var id: String = str(region.get("id", ""))
		var mounted: Dictionary = host.mount_region(id, state)
		must(not mounted.has("error"), id + " mounts with physical geometry")
		if mounted.has("error"):
			continue
		var world = host.current_region_world
		var physical: Node2D = world.get_node("PhysicalRoutes")
		var wall_count := 0
		var corridor_wall_count := 0
		for child in physical.get_children():
			if child is StaticBody2D:
				wall_count += 1
				if child.name.begins_with("CorridorWall_"):
					corridor_wall_count += 1
				must(child.get_child(0) is CollisionShape2D, id + " boundary or gate has an engine collision shape")
		must(wall_count == 4 + int(mounted.get("portal_count", 0)) + corridor_wall_count, id + " has bounds, corridor and gate collision")
		must(corridor_wall_count >= 6, id + " has physical corridor side walls")
		for anchor in region.get("anchors", []):
			var source: String = str(anchor)
			total_anchors += 1
			must(world.can_walk_from(source, world.anchor_position(source)), id + "/" + source + " is a valid spawn plaza")
		for edge in region.get("edges", []):
			total_edges += 1
			var source: String = str(edge.get("from", ""))
			var destination: String = str(edge.get("to", ""))
			var a: Vector2 = world.anchor_position(source)
			var b: Vector2 = world.anchor_position(destination)
			if world.is_portal(source, destination):
				total_portals += 1
				var gate: Vector2 = world.route_geometry.portal_position(source, destination)
				must(gate != Vector2.INF and world.can_walk_from(source, gate), id + "/" + source + "→" + destination + " entrance is reachable")
				must(not world.can_walk_from(source, b), id + "/" + source + "→" + destination + " cannot be crossed on foot")
			else:
				must(world.can_walk_from(source, (a + b) / 2.0), id + "/" + source + "→" + destination + " corridor midpoint is walkable")
				must(world.can_walk_from(source, b), id + "/" + source + "→" + destination + " has a reachable destination")
		must(not world.can_walk_from(str(region.get("entry_anchor", "")), Vector2(40.0, 40.0)), id + " off-route ground is blocked")
	must(total_anchors == 60, "all 60 canonical anchors have physical plazas")
	must(total_edges > 90 and total_portals >= 20, "all eight route graphs contain corridors and gated portals")
	for error in errors:
		push_error("ROUTE GEOMETRY FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_ROUTE_GEOMETRY: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
