class_name LevelGeometryRegistry
extends RefCounted

const PATH = "res://data/level_geometry_v1.json"
const MICRO_PATH = "res://data/micro_navigation_v1.json"

static func data() -> Dictionary:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {"error":"level geometry missing"}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return {"error":"level geometry malformed"}
	return parsed

static func region_geometry(region_id: String) -> Dictionary:
	var d: Dictionary = data()
	if d.has("error"):
		return d
	var region = d.get("regions", {}).get(region_id, {})
	if typeof(region) != TYPE_DICTIONARY or region.is_empty():
		return {}
	return region.duplicate(true)

static func summary(region_id: String) -> Dictionary:
	var region: Dictionary = region_geometry(region_id)
	if region.is_empty() or region.has("error"):
		return {"status":"NONE","building_count":0,"interaction_slot_count":0,"occlusion_candidate_count":0}
	return {
		"status":str(data().get("status", "")),
		"building_count":region.get("building_footprints", []).size(),
		"interaction_slot_count":region.get("interaction_slots", []).size(),
		"occlusion_candidate_count":region.get("occlusion_candidates", []).size()
	}

static func _poly(raw) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(raw) != TYPE_ARRAY:
		return points
	for item in raw:
		if typeof(item) == TYPE_ARRAY and item.size() == 2:
			points.append(Vector2(float(item[0]), float(item[1])))
	return points

static func _rect_from_poly(raw) -> Rect2:
	var p: PackedVector2Array = _poly(raw)
	if p.size() < 3:
		return Rect2()
	var min_x := p[0].x
	var min_y := p[0].y
	var max_x := p[0].x
	var max_y := p[0].y
	for point in p:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(a + segment * t)

static func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b - a).cross(c - a)

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o1 := _orientation(a, b, c)
	var o2 := _orientation(a, b, d)
	var o3 := _orientation(c, d, a)
	var o4 := _orientation(c, d, b)
	return ((o1 > 0.0 and o2 < 0.0) or (o1 < 0.0 and o2 > 0.0)) and ((o3 > 0.0 and o4 < 0.0) or (o3 < 0.0 and o4 > 0.0))

static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if _segments_intersect(a, b, c, d):
		return 0.0
	return minf(minf(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d)),
		minf(_point_segment_distance(c, a, b), _point_segment_distance(d, a, b)))

static func _rect_segment_distance(rect: Rect2, a: Vector2, b: Vector2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var p0 := rect.position
	var p1 := Vector2(rect.end.x, rect.position.y)
	var p2 := rect.end
	var p3 := Vector2(rect.position.x, rect.end.y)
	return minf(minf(_segment_distance(p0, p1, a, b), _segment_distance(p1, p2, a, b)),
		minf(_segment_distance(p2, p3, a, b), _segment_distance(p3, p0, a, b)))

static func _rect_point_distance(rect: Rect2, point: Vector2) -> float:
	if rect.has_point(point):
		return 0.0
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)

static func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, 0.0), b.position.x - a.end.x)
	var dy := maxf(maxf(a.position.y - b.end.y, 0.0), b.position.y - a.end.y)
	return sqrt(dx * dx + dy * dy)

static func _micro_zones(region_id: String) -> Array:
	var file: FileAccess = FileAccess.open(MICRO_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var region = parsed.get("regions", {}).get(region_id, {})
	return region.get("zones", []) if typeof(region) == TYPE_DICTIONARY else []

static func _unique_non_portal_segments(region_id: String) -> Array:
	var result: Array = []
	var graph: Dictionary = TraversalService.load_graph()
	var seen: Dictionary = {}
	for region in graph.get("regions", []):
		if str(region.get("id", "")) != region_id:
			continue
		for edge in region.get("edges", []):
			if bool(edge.get("requires_player_route_choice", false)):
				continue
			var source := str(edge.get("from", ""))
			var destination := str(edge.get("to", ""))
			var key := source + ":" + destination if source < destination else destination + ":" + source
			if seen.has(key):
				continue
			seen[key] = true
			var a := SpatialRegistry.anchor_position(region_id, source)
			var b := SpatialRegistry.anchor_position(region_id, destination)
			if a != Vector2.INF and b != Vector2.INF:
				result.append({"a":a,"b":b})
	return result

static func validate_region(region_id: String) -> Array[String]:
	var errors: Array[String] = []
	var region: Dictionary = region_geometry(region_id)
	if region.is_empty():
		return errors
	var d: Dictionary = data()
	if d.has("error"):
		return [str(d.error)]
	var rules: Dictionary = d.get("rules", {})
	var clearance := float(rules.get("minimum_walkable_clearance", 28))
	var interaction_radius := float(rules.get("interaction_radius", 82))
	var portal_clearance := float(rules.get("portal_clearance_radius", 100))
	var bounds := SpatialRegistry.world_bounds(region_id)
	var micro: Array = _micro_zones(region_id)
	var anchor_ids: Array[String] = []
	var layout: Dictionary = SpatialRegistry.region_layout(region_id)
	for key in layout.get("anchors", {}).keys():
		anchor_ids.append(str(key))
	var segments: Array = _unique_non_portal_segments(region_id)

	for building in region.get("building_footprints", []):
		var id := str(building.get("id", "BUILDING"))
		var rect := _rect_from_poly(building.get("polygon", []))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			errors.append(id + ": invalid footprint polygon")
			continue
		if not bounds.encloses(rect):
			errors.append(id + ": footprint outside world bounds")
		for zone in micro:
			var zone_rect := _rect_from_poly(zone.get("polygon", []))
			if rect.grow(clearance).intersects(zone_rect, true):
				errors.append(id + ": violates micro-navigation clearance " + str(zone.get("id", "")))
		for anchor_id in anchor_ids:
			var anchor := SpatialRegistry.anchor_position(region_id, anchor_id)
			if _rect_point_distance(rect, anchor) < RouteGeometry.ANCHOR_PLAZA_RADIUS + clearance:
				errors.append(id + ": violates anchor plaza clearance " + anchor_id)
		for segment in segments:
			if _rect_segment_distance(rect, segment.a, segment.b) < RouteGeometry.CORRIDOR_HALF_WIDTH + clearance:
				errors.append(id + ": violates canonical corridor clearance")

	var geometry := RouteGeometry.new(region_id)
	for rule in region.get("no_build_rules", []):
		if str(rule.get("kind", "")) != "PORTAL_RADIUS":
			continue
		var source := str(rule.get("source_anchor", ""))
		var destination := str(rule.get("destination_anchor", ""))
		var gate := geometry.portal_position(source, destination)
		if gate == Vector2.INF:
			errors.append(str(rule.get("id", "PORTAL")) + ": portal position unavailable")
			continue
		var radius := float(rule.get("radius", portal_clearance))
		for building in region.get("building_footprints", []):
			var rect := _rect_from_poly(building.get("polygon", []))
			if _rect_point_distance(rect, gate) < radius:
				errors.append(str(building.get("id", "")) + ": blocks portal clearance")
		for slot in region.get("interaction_slots", []):
			if str(slot.get("target_kind", "")) != "NPC":
				continue
			var stand := _rect_from_poly(slot.get("stand_zone", []))
			if _rect_point_distance(stand, gate) < radius:
				errors.append(str(slot.get("id", "")) + ": NPC stand zone blocks portal clearance")

	for slot in region.get("interaction_slots", []):
		var id := str(slot.get("id", "INTERACTION"))
		var anchor_id := str(slot.get("anchor_id", ""))
		if not anchor_ids.has(anchor_id):
			errors.append(id + ": unknown anchor owner")
			continue
		var stand := _rect_from_poly(slot.get("stand_zone", []))
		var approach := _rect_from_poly(slot.get("approach_zone", []))
		if stand.size.x <= 0.0 or approach.size.x <= 0.0:
			errors.append(id + ": malformed stand/approach zone")
			continue
		if not bounds.encloses(stand) or not bounds.encloses(approach):
			errors.append(id + ": interaction zone outside bounds")
		if _rect_distance(stand, approach) > interaction_radius:
			errors.append(id + ": no valid interaction point within radius")
		var samples := [
			approach.position,
			Vector2(approach.end.x, approach.position.y),
			approach.end,
			Vector2(approach.position.x, approach.end.y),
			approach.get_center()
		]
		for sample in samples:
			if not geometry.is_walkable(anchor_id, sample):
				errors.append(id + ": player approach leaves owner walkable space")
				break
		if str(slot.get("target_kind", "")) == "NPC" and not geometry.is_walkable(anchor_id, stand.get_center()):
			errors.append(id + ": NPC stand center is outside owner walkable space")

	for candidate in region.get("occlusion_candidates", []):
		var rect := _rect_from_poly(candidate.get("polygon", []))
		if rect.size.x <= 0.0 or not bounds.encloses(rect):
			errors.append(str(candidate.get("id", "OCCLUSION")) + ": invalid occlusion candidate")
		if bool(candidate.get("collision", true)):
			errors.append(str(candidate.get("id", "OCCLUSION")) + ": occlusion candidate must remain non-colliding")
	return errors
