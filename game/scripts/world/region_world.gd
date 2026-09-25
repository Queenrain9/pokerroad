class_name RegionWorld
extends Node2D

@export var region_id: String = ""

var state
var region_record: Dictionary = {}
var capabilities: Array = []

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
