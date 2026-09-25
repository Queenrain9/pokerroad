class_name RouteGeometry
extends RefCounted

# Engineering geometry for the production world. Every corridor is derived from
# the canonical traversal graph; a portal is used where a route requires an
# explicit action or choice. Art can be added without changing these rules.
const CORRIDOR_HALF_WIDTH = 96.0
const ANCHOR_PLAZA_RADIUS = 138.0
const PORTAL_OFFSET = 118.0
const MICRO_NAV_PATH = "res://data/micro_navigation_v1.json"

var region_id: String
var edges: Array = []
var portal_pairs: Dictionary = {}
var local_walkable_zones: Array = []

func _init(p_region_id: String) -> void:
	region_id = p_region_id
	var graph: Dictionary = TraversalService.load_graph()
	for region in graph.get("regions", []):
		if str(region.get("id", "")) == region_id:
			edges = region.get("edges", []).duplicate(true)
			break
	for edge in edges:
		if bool(edge.get("requires_player_route_choice", false)):
			portal_pairs[_pair_key(str(edge.get("from", "")), str(edge.get("to", "")))] = true
	_load_local_walkable_zones()

func _pair_key(a: String, b: String) -> String:
	return a + ":" + b if a < b else b + ":" + a

func is_portal(source: String, destination: String) -> bool:
	return portal_pairs.has(_pair_key(source, destination))

func outgoing(source: String) -> Array:
	var result: Array = []
	for edge in edges:
		if str(edge.get("from", "")) == source:
			result.append(edge)
	return result

func has_edge(source: String, destination: String) -> bool:
	for edge in outgoing(source):
		if str(edge.get("to", "")) == destination:
			return true
	return false

func portal_position(source: String, destination: String) -> Vector2:
	if not has_edge(source, destination) or not is_portal(source, destination):
		return Vector2.INF
	var a: Vector2 = SpatialRegistry.anchor_position(region_id, source)
	var b: Vector2 = SpatialRegistry.anchor_position(region_id, destination)
	if a == Vector2.INF or b == Vector2.INF:
		return Vector2.INF
	return a + (b - a).normalized() * PORTAL_OFFSET

func nearest_portal(source: String, position: Vector2, radius: float) -> String:
	var best := ""
	var best_distance := radius
	for edge in outgoing(source):
		var destination: String = str(edge.get("to", ""))
		var gate: Vector2 = portal_position(source, destination)
		if gate == Vector2.INF:
			continue
		var distance := position.distance_to(gate)
		if distance <= best_distance:
			best = destination
			best_distance = distance
	return best

func local_zone_count() -> int:
	return local_walkable_zones.size()

func local_zone_ids_for(source: String) -> Array[String]:
	var result: Array[String] = []
	for zone in local_walkable_zones:
		var owners: Array = zone.get("owners", [])
		if owners.has(source):
			result.append(str(zone.get("id", "")))
	return result

func _load_local_walkable_zones() -> void:
	local_walkable_zones.clear()
	if not FileAccess.file_exists(MICRO_NAV_PATH):
		return
	var file: FileAccess = FileAccess.open(MICRO_NAV_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var region: Dictionary = parsed.get("regions", {}).get(region_id, {})
	for raw_zone in region.get("zones", []):
		if typeof(raw_zone) != TYPE_DICTIONARY:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for raw_point in raw_zone.get("polygon", []):
			if typeof(raw_point) != TYPE_ARRAY or raw_point.size() != 2:
				continue
			points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
		if points.size() < 3:
			continue
		var zone: Dictionary = raw_zone.duplicate(true)
		zone["_polygon_points"] = points
		local_walkable_zones.append(zone)

func _inside_local_zone(source: String, position: Vector2) -> bool:
	for zone in local_walkable_zones:
		var owners: Array = zone.get("owners", [])
		if not owners.has(source):
			continue
		var points: PackedVector2Array = zone.get("_polygon_points", PackedVector2Array())
		if points.size() >= 3 and Geometry2D.is_point_in_polygon(position, points):
			return true
	return false

func is_walkable(source: String, position: Vector2) -> bool:
	var start: Vector2 = SpatialRegistry.anchor_position(region_id, source)
	if start == Vector2.INF:
		return false
	if start.distance_to(position) <= ANCHOR_PLAZA_RADIUS:
		return true
	if _inside_local_zone(source, position):
		return true
	for edge in outgoing(source):
		var destination: String = str(edge.get("to", ""))
		if is_portal(source, destination):
			continue
		var finish: Vector2 = SpatialRegistry.anchor_position(region_id, destination)
		if finish == Vector2.INF:
			continue
		var segment: Vector2 = finish - start
		var t: float = clampf((position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		if position.distance_to(start + segment * t) <= CORRIDOR_HALF_WIDTH:
			return true
	return false
