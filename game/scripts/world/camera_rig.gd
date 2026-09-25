class_name PokerRoadCamera
extends Camera2D

func apply_region(region_world) -> Dictionary:
	if region_world == null:
		return {"error":"camera requires mounted region"}
	var metrics: Dictionary = SpatialRegistry.camera_metrics()
	var raw_zoom: Array = metrics.get("zoom", [1.0,1.0])
	if raw_zoom.size() != 2:
		return {"error":"camera zoom metric malformed"}
	zoom = Vector2(float(raw_zoom[0]), float(raw_zoom[1]))
	position_smoothing_enabled = bool(metrics.get("position_smoothing", true))
	position_smoothing_speed = float(metrics.get("position_smoothing_speed", 7.0))
	# Region 01 prototype composes slightly ahead/up so the raised terrace and
	# distant tower layer stay visible while the player remains in the lower third.
	position = Vector2(90, -110) if str(region_world.region_id) == "01" else Vector2.ZERO
	var bounds: Rect2 = region_world.world_bounds()
	var margin: int = int(metrics.get("bounds_margin", 120))
	limit_left = int(bounds.position.x) + margin
	limit_top = int(bounds.position.y) + margin
	limit_right = int(bounds.end.x) - margin
	limit_bottom = int(bounds.end.y) - margin
	return {"bounds":bounds,"zoom":zoom}
