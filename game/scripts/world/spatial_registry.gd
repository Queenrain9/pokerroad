class_name SpatialRegistry
extends RefCounted

const PATH = "res://data/spatial_metrics_v1.json"

static func data() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {"error":"spatial metrics missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return {"error":"spatial metrics malformed"}
	return parsed

static func region_layout(region_id: String) -> Dictionary:
	var d := data()
	if d.has("error"):
		return d
	var region = d.get("regions", {}).get(region_id, {})
	if typeof(region) != TYPE_DICTIONARY or region.is_empty():
		return {"error":"region has no spatial metrics"}
	return region.duplicate(true)

static func world_bounds(region_id: String) -> Rect2:
	var r := region_layout(region_id)
	if r.has("error"):
		return Rect2()
	var b: Array = r.get("bounds", [])
	if b.size() != 4:
		return Rect2()
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))

static func anchor_position(region_id: String, anchor_id: String) -> Vector2:
	var r := region_layout(region_id)
	if r.has("error"):
		return Vector2.INF
	var raw = r.get("anchors", {}).get(anchor_id)
	if typeof(raw) != TYPE_ARRAY or raw.size() != 2:
		return Vector2.INF
	return Vector2(float(raw[0]), float(raw[1]))

static func player_metrics() -> Dictionary:
	var d := data()
	return {} if d.has("error") else d.get("player", {}).duplicate(true)

static func camera_metrics() -> Dictionary:
	var d := data()
	return {} if d.has("error") else d.get("camera", {}).duplicate(true)

static func validate_against_manifest(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var d := data()
	if d.has("error"):
		errors.append(str(d.error))
		return errors
	var layouts: Dictionary = d.get("regions", {})
	if layouts.size() != 8:
		errors.append("spatial metrics must cover exactly eight regions")
	for region in manifest.get("regions", []):
		var id := str(region.get("id", ""))
		if not layouts.has(id):
			errors.append(id + ": missing spatial layout")
			continue
		var bounds := world_bounds(id)
		if bounds.size.x <= 1280.0 or bounds.size.y <= 720.0:
			errors.append(id + ": world bounds too small for production viewport")
		var seen_positions := {}
		var layout_anchors: Dictionary = layouts[id].get("anchors", {})
		var manifest_ids := []
		for anchor in region.get("anchors", []):
			var anchor_id := str(anchor.get("id", ""))
			manifest_ids.append(anchor_id)
			if not layout_anchors.has(anchor_id):
				errors.append(id + ": missing anchor position " + anchor_id)
				continue
			var pos := anchor_position(id, anchor_id)
			if not bounds.has_point(pos):
				errors.append(id + ": anchor outside world bounds " + anchor_id)
			var key := "%0.2f,%0.2f" % [pos.x, pos.y]
			if seen_positions.has(key):
				errors.append(id + ": overlapping anchor positions " + anchor_id)
			seen_positions[key] = true
		if layout_anchors.size() != manifest_ids.size():
			errors.append(id + ": spatial anchor count differs from manifest")
	return errors
