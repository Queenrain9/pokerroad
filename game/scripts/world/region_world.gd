class_name RegionWorld
extends Node2D

@export var region_id: String = ""

var state
var region_record: Dictionary = {}
var capabilities: Array = []
var spatial_layout: Dictionary = {}
var anchor_markers: Dictionary = {}
var route_geometry: RouteGeometry
var portal_markers: Dictionary = {}

func initialize_from_state(p_state) -> Dictionary:
	state = p_state
	if state == null:
		return {"error":"region world requires GameState"}
	if region_id.is_empty():
		return {"error":"region scene has no region_id"}
	for region in state.manifest.get("regions", []):
		if region.get("id", "") == region_id:
			region_record = region.duplicate(true)
			break
	if region_record.is_empty():
		return {"error":"region scene id is absent from world manifest"}
	capabilities = PresentationContract.region_capabilities(region_id).duplicate()
	if capabilities.is_empty():
		return {"error":"region has no production capability contract"}
	spatial_layout = SpatialRegistry.region_layout(region_id)
	if spatial_layout.has("error"):
		return spatial_layout
	route_geometry = RouteGeometry.new(region_id)
	if route_geometry.edges.is_empty():
		return {"error":"region has no physical route geometry"}
	_build_anchor_markers()
	_build_route_geometry()
	return descriptor()

func descriptor() -> Dictionary:
	if region_record.is_empty():
		return {"error":"region scene is not initialized"}
	return {
		"id":region_id,
		"name":region_record.get("name", ""),
		"boss":region_record.get("boss", ""),
		"anchor_ids":anchor_ids(),
		"capabilities":capabilities.duplicate(),
		"world_bounds":world_bounds(),
		"navigation_skeleton_status":"ANCHORS_POSITIONED",
		"physical_map_status":"ROUTE_GEOMETRY_ACTIVE",
		"route_edge_count":route_geometry.edges.size(),
		"portal_count":portal_markers.size(),
		"visual_asset_status":"NOT_STARTED"
	}

func anchor_ids() -> Array[String]:
	var result: Array[String] = []
	for anchor in region_record.get("anchors", []):
		result.append(str(anchor.get("id", "")))
	return result

func contains_anchor(anchor_id: String) -> bool:
	return anchor_ids().has(anchor_id)

func current_anchor_is_valid() -> bool:
	return state != null and state.current_region == region_id and contains_anchor(state.current_anchor)

func world_bounds() -> Rect2:
	return SpatialRegistry.world_bounds(region_id)

func anchor_position(anchor_id: String) -> Vector2:
	if not contains_anchor(anchor_id):
		return Vector2.INF
	return SpatialRegistry.anchor_position(region_id, anchor_id)

func nearest_anchor(world_position: Vector2, radius: float) -> String:
	var best: String = ""
	var best_distance: float = radius
	for anchor_id in anchor_ids():
		var pos: Vector2 = anchor_position(anchor_id)
		if pos == Vector2.INF:
			continue
		var distance: float = world_position.distance_to(pos)
		if distance <= best_distance:
			best = anchor_id
			best_distance = distance
	return best

func nearest_portal(source: String, world_position: Vector2, radius: float) -> String:
	return route_geometry.nearest_portal(source, world_position, radius)

func can_walk_from(source: String, world_position: Vector2) -> bool:
	return route_geometry.is_walkable(source, world_position) and world_bounds().has_point(world_position)

func is_portal(source: String, destination: String) -> bool:
	return route_geometry.is_portal(source, destination)

func _build_anchor_markers() -> void:
	for marker in anchor_markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	anchor_markers.clear()
	for anchor_id in anchor_ids():
		var pos: Vector2 = anchor_position(anchor_id)
		if pos == Vector2.INF:
			continue
		var marker: Marker2D = Marker2D.new()
		marker.name = "Anchor_" + anchor_id
		marker.position = pos
		marker.set_meta("anchor_id", anchor_id)
		marker.set_meta("runtime_role", "NON_VISUAL_INTERACTION_ANCHOR")
		add_child(marker)
		anchor_markers[anchor_id] = marker

func _build_route_geometry() -> void:
	var physical: Node2D = Node2D.new()
	physical.name = "PhysicalRoutes"
	physical.set_meta("runtime_role", "NON_VISUAL_ROUTE_GEOMETRY")
	add_child(physical)
	var bounds: Rect2 = world_bounds()
	_add_wall(physical, "NorthBoundary", Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y - 16.0), Vector2(bounds.size.x + 64.0, 32.0))
	_add_wall(physical, "SouthBoundary", Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.end.y + 16.0), Vector2(bounds.size.x + 64.0, 32.0))
	_add_wall(physical, "WestBoundary", Vector2(bounds.position.x - 16.0, bounds.position.y + bounds.size.y / 2.0), Vector2(32.0, bounds.size.y + 64.0))
	_add_wall(physical, "EastBoundary", Vector2(bounds.end.x + 16.0, bounds.position.y + bounds.size.y / 2.0), Vector2(32.0, bounds.size.y + 64.0))
	var built_corridors: Dictionary = {}
	for source in anchor_ids():
		for edge in route_geometry.outgoing(source):
			var destination: String = str(edge.get("to", ""))
			if not route_geometry.is_portal(source, destination):
				var pair_key: String = source + ":" + destination if source < destination else destination + ":" + source
				if not built_corridors.has(pair_key):
					_build_corridor_walls(physical, source, destination)
					built_corridors[pair_key] = true
				continue
			var position: Vector2 = route_geometry.portal_position(source, destination)
			if position == Vector2.INF:
				continue
			var marker: Marker2D = Marker2D.new()
			marker.name = "Portal_" + source + "_" + destination
			marker.position = position
			marker.set_meta("from_anchor", source)
			marker.set_meta("to_anchor", destination)
			marker.set_meta("edge_kind", str(edge.get("kind", "")))
			physical.add_child(marker)
			portal_markers[source + ":" + destination] = marker
			# A solid threshold prevents a player from walking through the transit
			# connection. The action marker remains on the accessible side.
			var a: Vector2 = anchor_position(source)
			var b: Vector2 = anchor_position(destination)
			var normal: Vector2 = (b - a).normalized()
			_add_wall(physical, "GateWall_" + source + "_" + destination,
				a + normal * 188.0, Vector2(16.0, 210.0), normal.angle())

func _build_corridor_walls(physical: Node2D, source: String, destination: String) -> void:
	var a: Vector2 = anchor_position(source)
	var b: Vector2 = anchor_position(destination)
	var vector: Vector2 = b - a
	var length: float = vector.length()
	if length <= RouteGeometry.ANCHOR_PLAZA_RADIUS * 2.0:
		return
	var normal: Vector2 = vector.orthogonal().normalized()
	var center: Vector2 = (a + b) / 2.0
	var wall_length: float = length - RouteGeometry.ANCHOR_PLAZA_RADIUS * 2.0
	for side in [-1.0, 1.0]:
		var label: String = "Left" if side < 0.0 else "Right"
		_add_wall(physical, "CorridorWall_" + source + "_" + destination + "_" + label,
			center + normal * (RouteGeometry.CORRIDOR_HALF_WIDTH + 8.0) * side,
			Vector2(wall_length, 16.0), vector.angle())

func _add_wall(parent: Node2D, wall_name: String, center: Vector2, size: Vector2, facing: float = 0.0) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = wall_name
	body.position = center
	body.rotation = facing
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
