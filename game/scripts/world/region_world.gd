class_name RegionWorld
extends Node2D

@export var region_id: String = ""

var state
var region_record: Dictionary = {}
var capabilities: Array = []
var spatial_layout: Dictionary = {}
var anchor_markers: Dictionary = {}

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
	_build_anchor_markers()
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
		"physical_map_status":"NOT_IMPLEMENTED",
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
