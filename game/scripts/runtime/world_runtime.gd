class_name WorldRuntime
extends RefCounted

var state
var scene_runner

func _init(p_state, runner = null) -> void:
	state = p_state
	scene_runner = runner if runner != null else SceneRunner.new(state)

func region_descriptor(region_id: String) -> Dictionary:
	for region in state.manifest.get("regions", []):
		if region.get("id", "") == region_id:
			return {
				"id":region_id,
				"name":region.get("name", ""),
				"boss":region.get("boss", ""),
				"anchors":region.get("anchors", []).duplicate(true),
				"capabilities":PresentationContract.region_capabilities(region_id),
				"physical_map_status":"ROUTE_GEOMETRY_ACTIVE"
			}
	return {"error":"unknown region"}

func current_world() -> Dictionary:
	var descriptor: Dictionary = region_descriptor(state.current_region)
	if descriptor.has("error"):
		return descriptor
	var anchor_known: bool = false
	for anchor in descriptor.anchors:
		if anchor.get("id", "") == state.current_anchor:
			anchor_known = true
			break
	if not anchor_known:
		return {"error":"current anchor is not in current region"}
	descriptor["current_anchor"] = state.current_anchor
	descriptor["bound_scene_ids"] = bound_scene_ids_at(state.current_anchor)
	return descriptor

func all_region_descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(1, 9):
		result.append(region_descriptor("%02d" % i))
	return result

func bound_scene_ids_at(anchor_id: String) -> Array[String]:
	var ids: Array[String] = []
	for binding in SceneBindingStore.bindings_for(state.current_region, anchor_id):
		ids.append(str(binding.get("scene_id", "")))
	return ids

func open_scene(scene_id: String) -> Dictionary:
	return scene_runner.open_scene(scene_id, state.current_anchor)

func travel_to_anchor(destination: String, selected_route: String = "", context: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = state.step_to_anchor(destination, selected_route, context)
	if not plan.has("error"):
		state.return_anchor = destination
	return plan

func move_to_next_region(region_id: String, entry_anchor: String) -> bool:
	var changed: bool = state.change_region(region_id, entry_anchor)
	if changed:
		state.return_anchor = entry_anchor
	return changed
