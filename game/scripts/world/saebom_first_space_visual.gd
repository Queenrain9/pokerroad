class_name SaebomFirstSpaceVisual
extends Node2D

# Region 01 data-driven 3/4 engineering blockout.
# World-space positions come only from canonical spatial, micro-navigation and
# validated level-geometry data. Extrusion height / roof skew are explicitly
# non-final visual massing values and never affect navigation or story state.

var region_world
var state
var board_marker: Node2D
var bokrye_marker: Node2D
var story_markers: Dictionary = {}
var debug_root: Node2D

const MICRO_PATH = "res://data/micro_navigation_v1.json"

const C_GROUND = Color("#728078")
const C_WALK = Color("#c9bda4")
const C_WALK_EDGE = Color("#9e927e")
const C_PLAZA = Color("#d5cbb4")
const C_BUILDING_FRONT = Color("#c6b89c")
const C_BUILDING_SIDE = Color("#9f927b")
const C_BUILDING_ROOF = Color("#52666a")
const C_TOWER_FRONT = Color("#7e888d")
const C_TOWER_SIDE = Color("#59656c")
const C_TOWER_ROOF = Color("#354b55")
const C_PROP = Color("#806754")
const C_PROP_TOP = Color("#aa8d70")
const C_LABEL = Color("#f4ead1")
const C_INK = Color("#26393e")
const C_MARKER = Color("#e6bd63")
const C_DEBUG_STAND = Color(0.77, 0.34, 0.32, 0.32)
const C_DEBUG_APPROACH = Color(0.26, 0.62, 0.66, 0.22)
const C_OCCLUSION = Color(0.22, 0.32, 0.34, 0.28)

func setup(p_region_world, p_state) -> void:
	region_world = p_region_world
	state = p_state
	name = "SaebomFirstSpaceVisual"
	z_index = 0
	_build_ground_and_walkable()
	_build_buildings()
	_build_function_props()
	_build_interaction_slots()
	_build_occlusion_candidates()
	_refresh_story_markers()
	if state != null and not state.world_changed.is_connected(_refresh_story_markers):
		state.world_changed.connect(_refresh_story_markers)

func _level() -> Dictionary:
	return LevelGeometryRegistry.region_geometry("01")

func _micro() -> Dictionary:
	var file := FileAccess.open(MICRO_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var region = parsed.get("regions", {}).get("01", {})
	return region if typeof(region) == TYPE_DICTIONARY else {}

func _points(raw) -> PackedVector2Array:
	var result := PackedVector2Array()
	if typeof(raw) != TYPE_ARRAY:
		return result
	for p in raw:
		if typeof(p) == TYPE_ARRAY and p.size() == 2:
			result.append(Vector2(float(p[0]), float(p[1])))
	return result

func _poly(points: PackedVector2Array, color: Color, z: int, parent: Node2D) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	shape.z_index = z
	parent.add_child(shape)
	return shape

func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])

func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.size() < 3:
		return Rect2()
	var min_x := points[0].x
	var min_y := points[0].y
	var max_x := points[0].x
	var max_y := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _label(text_value: String, pos: Vector2, font_size: int, parent: Node2D, z: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.z_index = z
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", C_LABEL)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _circle(center: Vector2, radius: float, color: Color, z: int, parent: Node2D, sides: int = 28) -> Polygon2D:
	var points := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return _poly(points, color, z, parent)

func _corridor_polygon(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var vector := b - a
	if vector.length_squared() <= 0.000001:
		return PackedVector2Array()
	var normal := vector.orthogonal().normalized() * half_width
	return PackedVector2Array([a + normal, b + normal, b - normal, a - normal])

func _build_ground_and_walkable() -> void:
	var ground := Node2D.new()
	ground.name = "BlockoutGround"
	ground.z_index = -2000
	add_child(ground)
	var bounds: Rect2 = region_world.world_bounds()
	_poly(_rect_points(bounds), C_GROUND, 0, ground)

	# Canonical non-portal routes remain the navigation skeleton.
	var seen: Dictionary = {}
	for source in region_world.anchor_ids():
		for edge in region_world.route_geometry.outgoing(source):
			var destination := str(edge.get("to", ""))
			if region_world.is_portal(source, destination):
				continue
			var key := source + ":" + destination if source < destination else destination + ":" + source
			if seen.has(key):
				continue
			seen[key] = true
			var a: Vector2 = region_world.anchor_position(source)
			var b: Vector2 = region_world.anchor_position(destination)
			_poly(_corridor_polygon(a, b, RouteGeometry.CORRIDOR_HALF_WIDTH), C_WALK, 4, ground)

	# Local micro-navigation polygons widen the actual living spaces without
	# inventing new story anchors.
	for zone in _micro().get("zones", []):
		var points := _points(zone.get("polygon", []))
		if points.size() >= 3:
			_poly(points, C_WALK, 5, ground)

	# Canonical anchor plazas are shown as soft paved discs.
	for anchor_id in region_world.anchor_ids():
		_circle(region_world.anchor_position(anchor_id), RouteGeometry.ANCHOR_PLAZA_RADIUS, C_PLAZA, 6, ground)

func _build_buildings() -> void:
	var root := Node2D.new()
	root.name = "BlockoutBuildings"
	add_child(root)
	for record in _level().get("building_footprints", []):
		var points := _points(record.get("polygon", []))
		if points.size() != 4:
			continue
		var rect := _rect_from_points(points)
		var height := float(record.get("blockout_visual_height", 120.0))
		var shift_x := float(record.get("blockout_roof_shift_x", 30.0))
		var rise := Vector2(shift_x, -height)
		var top := PackedVector2Array()
		for p in points:
			top.append(p + rise)
		var is_tower := str(record.get("kind", "")) == "CASINO_TOWER"
		var front_color := C_TOWER_FRONT if is_tower else C_BUILDING_FRONT
		var side_color := C_TOWER_SIDE if is_tower else C_BUILDING_SIDE
		var roof_color := C_TOWER_ROOF if is_tower else C_BUILDING_ROOF

		var node := Node2D.new()
		node.name = str(record.get("id", "Building"))
		node.z_index = clampi(int(rect.end.y), -4096, 4096)
		node.set_meta("runtime_role", "DATA_DRIVEN_3_4_BLOCKOUT_BUILDING")
		node.set_meta("footprint_id", str(record.get("id", "")))
		node.set_meta("blockout_visual_height", height)
		root.add_child(node)

		# Ground footprint is exact. Front/right faces and roof are visual-only
		# upward extrusion, preserving the physical footprint below.
		_poly(points, front_color.darkened(0.24), -4, node)
		_poly(PackedVector2Array([points[3], points[2], top[2], top[3]]), front_color, 0, node)
		_poly(PackedVector2Array([points[1], points[2], top[2], top[1]]), side_color, 1, node)
		_poly(top, roof_color, 2, node)

		var label_pos := top[3].lerp(top[2], 0.12) + Vector2(8, 10)
		var label := _label(str(record.get("label", "")), label_pos, 17 if not is_tower else 20, node, 3)
		label.modulate = Color(1, 1, 1, 0.92)

func _build_function_props() -> void:
	var root := Node2D.new()
	root.name = "BlockoutProps"
	add_child(root)
	for record in _level().get("prop_function_zones", []):
		var points := _points(record.get("polygon", []))
		if points.size() < 3:
			continue
		var rect := _rect_from_points(points)
		var node := Node2D.new()
		node.name = str(record.get("id", "Prop"))
		node.z_index = clampi(int(rect.end.y), -4096, 4096)
		node.set_meta("runtime_role", "DATA_DRIVEN_FUNCTION_PROP")
		root.add_child(node)
		_poly(points, C_PROP, 0, node)
		var raised := PackedVector2Array()
		for p in points:
			raised.append(p + Vector2(10, -24))
		_poly(raised, C_PROP_TOP, 1, node)
		_label(str(record.get("label", "")), rect.position + Vector2(8, -34), 14, node, 2)

func _build_interaction_slots() -> void:
	var root := Node2D.new()
	root.name = "InteractionSlots"
	root.z_index = 0
	add_child(root)
	debug_root = Node2D.new()
	debug_root.name = "BlockoutDebug"
	debug_root.visible = false
	root.add_child(debug_root)

	for slot in _level().get("interaction_slots", []):
		var stand_points := _points(slot.get("stand_zone", []))
		var approach_points := _points(slot.get("approach_zone", []))
		if stand_points.size() < 3 or approach_points.size() < 3:
			continue
		var stand_rect := _rect_from_points(stand_points)
		var approach_rect := _rect_from_points(approach_points)
		var marker := Marker2D.new()
		marker.name = "Interaction_" + str(slot.get("id", ""))
		marker.position = stand_rect.get_center()
		marker.z_index = 3400
		marker.set_meta("interaction_slot_id", str(slot.get("id", "")))
		marker.set_meta("anchor_id", str(slot.get("anchor_id", "")))
		marker.set_meta("target", str(slot.get("target", "")))
		marker.set_meta("stand_zone", stand_rect)
		marker.set_meta("approach_zone", approach_rect)
		root.add_child(marker)

		var debug_slot := Node2D.new()
		debug_slot.name = "Debug_" + str(slot.get("id", ""))
		debug_root.add_child(debug_slot)
		_poly(stand_points, C_DEBUG_STAND, 1, debug_slot)
		_poly(approach_points, C_DEBUG_APPROACH, 0, debug_slot)

		var story_marker := _story_marker(approach_rect.get_center())
		story_marker.name = "StoryMarker_" + str(slot.get("id", ""))
		story_marker.set_meta("scene_ids", slot.get("scene_ids", []).duplicate())
		root.add_child(story_marker)
		story_markers[str(slot.get("id", ""))] = story_marker

	board_marker = story_markers.get("I_M01_BOARD")
	bokrye_marker = story_markers.get("I_M02_BOKRYE")

func _story_marker(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos + Vector2(0, -54)
	n.z_index = 3500
	var diamond := PackedVector2Array([Vector2(0,-15),Vector2(11,0),Vector2(0,15),Vector2(-11,0)])
	_poly(diamond, C_MARKER, 0, n)
	_circle(Vector2.ZERO, 4.0, C_INK, 1, n, 12)
	return n

func _build_occlusion_candidates() -> void:
	var root := Node2D.new()
	root.name = "ForegroundOcclusion"
	add_child(root)
	for record in _level().get("occlusion_candidates", []):
		var points := _points(record.get("polygon", []))
		if points.size() < 3:
			continue
		var rect := _rect_from_points(points)
		var node := Node2D.new()
		node.name = str(record.get("id", "Occlusion"))
		node.z_index = clampi(int(rect.end.y), -4096, 4096)
		node.set_meta("runtime_role", "NON_COLLIDING_OCCLUSION_CANDIDATE")
		node.set_meta("fade_when_player_behind", bool(record.get("fade_when_player_behind", false)))
		root.add_child(node)
		_poly(points, C_OCCLUSION, 0, node)

func set_debug_overlays(value: bool) -> void:
	if debug_root != null:
		debug_root.visible = value

func _refresh_story_markers() -> void:
	if state == null:
		return
	for marker in story_markers.values():
		if not is_instance_valid(marker):
			continue
		var scene_ids = marker.get_meta("scene_ids", [])
		marker.visible = scene_ids.has(state.main_cursor)
