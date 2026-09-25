class_name TraversalService
extends RefCounted
const GRAPH_FILE = "res://data/traversal_graph_dev.json"

static func load_graph() -> Dictionary:
	var f := FileAccess.open(GRAPH_FILE, FileAccess.READ)
	if f == null:
		return {"error": "traversal graph missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("regions", []).size() != 8:
		return {"error": "invalid traversal graph"}
	return parsed

static func _region(graph: Dictionary, region_id: String) -> Dictionary:
	for region in graph.get("regions", []):
		if region.get("id", "") == region_id:
			return region
	return {}

static func plan_step(graph: Dictionary, region_id: String, source: String, destination: String,
		chosen_route: String = "", world: Dictionary = {}) -> Dictionary:
	var region := _region(graph, region_id)
	if region.is_empty() or not region.get("anchors", []).has(source) or not region.get("anchors", []).has(destination):
		return {"error": "invalid source, destination or region"}
	for edge in region.get("edges", []):
		if edge.get("from", "") != source or edge.get("to", "") != destination:
			continue
		if int(edge.get("fee", -1)) != 0:
			return {"error": "basic spatial route unexpectedly charges chips"}
		var route_choices: Array = edge.get("choices", [])
		if edge.get("requires_player_route_choice", false) and chosen_route.is_empty():
			return {"error": "player must explicitly choose route", "choices": route_choices,
				"safe_return_anchor": source}
		if not route_choices.is_empty() and not route_choices.has(chosen_route):
			return {"error": "unknown route choice", "choices": route_choices,
				"safe_return_anchor": source}
		var kind: String = str(edge.get("kind", ""))
		if kind == "TIDE_ROUTE":
			if not ["LOW", "HIGH"].has(world.get("tide", "")):
				return {"error": "tide must be established by actual tide board", "safe_return_anchor": source}
			var required: String = "LOW_TIDE_MARKER_PATH" if world.tide == "LOW" else "HIGH_TIDE_SAFE_PATH"
			if chosen_route != required:
				return {"error": "current tide makes selected route unsafe", "safe_return_anchor": source,
					"allowed_route": required}
		if kind == "LAST_TRAIN_ONLY" and not world.get("last_train_available", false):
			return {"error": "last train missed; use the free night bus", "safe_return_anchor": source,
				"alternative_anchor": "E3B"}
		if chosen_route == "REGISTERED_PLAYER_ONLY":
			if not (world.get("player_q", "NO") == "YES" and world.get("registered_official", false)):
				return {"error": "official player entrance requires own verified entry", "safe_return_anchor": source,
					"alternative_route": "PUBLIC_SPECTATOR"}
		return {"region_id": region_id, "from": source, "to": destination,
			"edge_kind": kind, "route_choice": chosen_route, "fee": 0,
			"requires_actual_map_movement": true}
	return {"error": "no direct edge; actual map travel cannot be teleported", "safe_return_anchor": source}

static func can_leave_region_at_public_exit(graph: Dictionary, region_id: String, anchor: String,
		next_region_unlocked: bool) -> bool:
	var region := _region(graph, region_id)
	return next_region_unlocked and not region.is_empty() and anchor == region.get("public_exit_anchor", "")
