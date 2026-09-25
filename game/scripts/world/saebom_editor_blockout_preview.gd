@tool
class_name SaebomEditorBlockoutPreview
extends Node2D

# Editor-only preview for Region 01.
# It reads the same authoritative JSON used by runtime blockout generation.
# Nothing drawn here changes runtime collision, navigation, scene state or saves.

const SPATIAL_PATH = "res://data/spatial_metrics_v1.json"
const GRAPH_PATH = "res://data/traversal_graph_dev.json"
const MICRO_PATH = "res://data/micro_navigation_v1.json"
const LEVEL_PATH = "res://data/level_geometry_v1.json"

@export var show_walkable: bool = true:
	set(value):
		show_walkable = value
		queue_redraw()
@export var show_buildings: bool = true:
	set(value):
		show_buildings = value
		queue_redraw()
@export var show_interactions: bool = true:
	set(value):
		show_interactions = value
		queue_redraw()
@export var show_occlusion_candidates: bool = true:
	set(value):
		show_occlusion_candidates = value
		queue_redraw()
@export var show_labels: bool = true:
	set(value):
		show_labels = value
		queue_redraw()

const C_WORLD = Color("#56675f")
const C_ROUTE = Color("#c8bca3")
const C_MICRO = Color("#d5cab2")
const C_ANCHOR = Color("#e5bd63")
const C_BUILDING_FOOT = Color("#7b6d5b")
const C_BUILDING_FRONT = Color("#bdaf94")
const C_BUILDING_SIDE = Color("#938670")
const C_BUILDING_ROOF = Color("#506368")
const C_TOWER_FRONT = Color("#7c878d")
const C_TOWER_SIDE = Color("#59656b")
const C_TOWER_ROOF = Color("#344b54")
const C_PROP = Color("#8b705b")
const C_STAND = Color(0.84, 0.29, 0.25, 0.55)
const C_APPROACH = Color(0.20, 0.69, 0.76, 0.30)
const C_OCCLUSION = Color(0.27, 0.36, 0.38, 0.38)
const C_LABEL = Color("#f8eed6")

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _notification(what: int) -> void:
	if Engine.is_editor_hint() and (what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSFORM_CHANGED):
		queue_redraw()

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _points(raw) -> PackedVector2Array:
	var result := PackedVector2Array()
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item in raw:
		if typeof(item) == TYPE_ARRAY and item.size() == 2:
			result.append(Vector2(float(item[0]), float(item[1])))
	return result

func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.size() < 3:
		return Rect2()
	var min_x: float = points[0].x
	var min_y: float = points[0].y
	var max_x: float = points[0].x
	var max_y: float = points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _corridor(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var vector: Vector2 = b - a
	if vector.length_squared() <= 0.000001:
		return PackedVector2Array()
	var normal: Vector2 = vector.orthogonal().normalized() * half_width
	return PackedVector2Array([a + normal, b + normal, b - normal, a - normal])

func _label(pos: Vector2, value: String, size: int = 18) -> void:
	if not show_labels:
		return
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, C_LABEL)

func _region_graph(graph: Dictionary) -> Dictionary:
	for region in graph.get("regions", []):
		if str(region.get("id", "")) == "01":
			return region
	return {}

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var spatial: Dictionary = _load_json(SPATIAL_PATH)
	var graph: Dictionary = _load_json(GRAPH_PATH)
	var micro: Dictionary = _load_json(MICRO_PATH)
	var level: Dictionary = _load_json(LEVEL_PATH)
	if spatial.is_empty() or graph.is_empty() or micro.is_empty() or level.is_empty():
		return

	var spatial_region: Dictionary = spatial.get("regions", {}).get("01", {})
	var anchors: Dictionary = spatial_region.get("anchors", {})
	var bounds_raw: Array = spatial_region.get("bounds", [])
	if bounds_raw.size() != 4:
		return
	var bounds := Rect2(float(bounds_raw[0]), float(bounds_raw[1]), float(bounds_raw[2]), float(bounds_raw[3]))
	draw_rect(bounds, C_WORLD, true)
	draw_rect(bounds, Color("#ead9ad"), false, 8.0)

	var graph_region: Dictionary = _region_graph(graph)
	if show_walkable:
		var seen: Dictionary = {}
		for edge in graph_region.get("edges", []):
			if bool(edge.get("requires_player_route_choice", false)):
				continue
			var source: String = str(edge.get("from", ""))
			var destination: String = str(edge.get("to", ""))
			if not anchors.has(source) or not anchors.has(destination):
				continue
			var key: String = source + ":" + destination if source < destination else destination + ":" + source
			if seen.has(key):
				continue
			seen[key] = true
			var a_raw: Array = anchors[source]
			var b_raw: Array = anchors[destination]
			var a := Vector2(float(a_raw[0]), float(a_raw[1]))
			var b := Vector2(float(b_raw[0]), float(b_raw[1]))
			draw_colored_polygon(_corridor(a, b, 96.0), C_ROUTE)

		var micro_region: Dictionary = micro.get("regions", {}).get("01", {})
		for zone in micro_region.get("zones", []):
			var polygon := _points(zone.get("polygon", []))
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, C_MICRO)
				draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color("#9d927c"), 2.0)

	var level_region: Dictionary = level.get("regions", {}).get("01", {})
	if show_buildings:
		for record in level_region.get("building_footprints", []):
			var base := _points(record.get("polygon", []))
			if base.size() != 4:
				continue
			var rect := _rect_from_points(base)
			var visual_height: float = float(record.get("blockout_visual_height", 120.0))
			var shift_x: float = float(record.get("blockout_roof_shift_x", 30.0))
			var rise := Vector2(shift_x, -visual_height)
			var top := PackedVector2Array()
			for point in base:
				top.append(point + rise)
			var is_tower: bool = str(record.get("kind", "")) == "CASINO_TOWER"
			draw_colored_polygon(base, C_BUILDING_FOOT)
			draw_colored_polygon(PackedVector2Array([base[3], base[2], top[2], top[3]]), C_TOWER_FRONT if is_tower else C_BUILDING_FRONT)
			draw_colored_polygon(PackedVector2Array([base[1], base[2], top[2], top[1]]), C_TOWER_SIDE if is_tower else C_BUILDING_SIDE)
			draw_colored_polygon(top, C_TOWER_ROOF if is_tower else C_BUILDING_ROOF)
			_label(top[3] + Vector2(8, -8), str(record.get("label", "")), 16 if not is_tower else 20)
			draw_rect(rect, Color(0.95, 0.80, 0.45, 0.55), false, 2.0)

		for prop in level_region.get("prop_function_zones", []):
			var prop_poly := _points(prop.get("polygon", []))
			if prop_poly.size() >= 3:
				draw_colored_polygon(prop_poly, C_PROP)
				var prop_rect := _rect_from_points(prop_poly)
				_label(prop_rect.position + Vector2(4, -8), str(prop.get("label", "")), 14)

	if show_occlusion_candidates:
		for item in level_region.get("occlusion_candidates", []):
			var occ := _points(item.get("polygon", []))
			if occ.size() >= 3:
				draw_colored_polygon(occ, C_OCCLUSION)

	if show_interactions:
		for slot in level_region.get("interaction_slots", []):
			var stand := _points(slot.get("stand_zone", []))
			var approach := _points(slot.get("approach_zone", []))
			if approach.size() >= 3:
				draw_colored_polygon(approach, C_APPROACH)
			if stand.size() >= 3:
				draw_colored_polygon(stand, C_STAND)
				var stand_rect := _rect_from_points(stand)
				draw_circle(stand_rect.get_center(), 8.0, Color("#ffdf69"))
				_label(stand_rect.get_center() + Vector2(12, -10), str(slot.get("target", "")), 13)

	for anchor_id_value in anchors.keys():
		var anchor_id: String = str(anchor_id_value)
		var raw: Array = anchors[anchor_id]
		var point := Vector2(float(raw[0]), float(raw[1]))
		draw_circle(point, 18.0, C_ANCHOR)
		draw_arc(point, 138.0, 0.0, TAU, 48, Color(0.95, 0.84, 0.46, 0.40), 2.0)
		_label(point + Vector2(22, -18), anchor_id, 19)

	# Optional tower portal is intentionally shown as a link, not a normal walk corridor.
	if anchors.has("P3") and anchors.has("P4"):
		var p3_raw: Array = anchors["P3"]
		var p4_raw: Array = anchors["P4"]
		var p3 := Vector2(float(p3_raw[0]), float(p3_raw[1]))
		var p4 := Vector2(float(p4_raw[0]), float(p4_raw[1]))
		draw_dashed_line(p3, p4, Color("#e58b62"), 5.0, 18.0)
		_label(p3.lerp(p4, 0.52) + Vector2(0, -18), "P3→P4 선택형 진입", 15)
