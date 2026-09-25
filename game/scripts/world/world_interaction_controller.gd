class_name WorldInteractionController
extends RefCounted

var state
var runtime
var region_host
var player

func _init(p_state, p_runtime, p_region_host, p_player) -> void:
	state = p_state
	runtime = p_runtime
	region_host = p_region_host
	player = p_player

func inspect_nearby(context: Dictionary = {}) -> Dictionary:
	if state == null or runtime == null or region_host == null or player == null:
		return {"error":"world interaction controller is not fully bound"}
	if region_host.current_region_world == null or region_host.current_region_id != state.current_region:
		return {"error":"mounted region does not match world state"}
	if not region_host.current_region_world.can_walk_from(state.current_anchor, player.global_position):
		return {"kind":"BLOCKED","from":state.current_anchor,
			"reason":"player is outside the current physical route"}
	var portal_target: String = region_host.current_region_world.nearest_portal(
		state.current_anchor, player.global_position, player.interaction_radius)
	if not portal_target.is_empty():
		return _preview_target(portal_target, context)
	var anchor_id: String = player.nearest_interactable_anchor()
	if anchor_id.is_empty():
		return {"kind":"NONE","current_anchor":state.current_anchor}
	if anchor_id == state.current_anchor:
		return {
			"kind":"CURRENT_ANCHOR",
			"anchor_id":anchor_id,
			"scene_ids":runtime.world_runtime.bound_scene_ids_at(anchor_id)
		}
	if region_host.current_region_world.is_portal(state.current_anchor, anchor_id):
		return {"kind":"BLOCKED","from":state.current_anchor,"to":anchor_id,
			"reason":"transit destination requires its entrance portal"}
	return _preview_target(anchor_id, context)

func _preview_target(anchor_id: String, context: Dictionary) -> Dictionary:
	var graph: Dictionary = TraversalService.load_graph()
	if graph.has("error"):
		return graph
	var preview: Dictionary = TraversalService.plan_step(graph, state.current_region, state.current_anchor,
		anchor_id, "", context)
	if preview.has("error"):
		if preview.has("choices"):
			return {
				"kind":"ROUTE_CHOICE_REQUIRED",
				"from":state.current_anchor,
				"to":anchor_id,
				"choices":preview.get("choices", []).duplicate(),
				"safe_return_anchor":preview.get("safe_return_anchor", state.current_anchor),
				"reason":preview.error
			}
		return {
			"kind":"BLOCKED",
			"from":state.current_anchor,
			"to":anchor_id,
			"reason":preview.error,
			"alternative_anchor":preview.get("alternative_anchor", "")
		}
	return {
		"kind":"TRAVEL_CONFIRMABLE",
		"from":state.current_anchor,
		"to":anchor_id,
		"plan":preview
	}

func enter_nearby_anchor(selected_route: String = "", context: Dictionary = {}) -> Dictionary:
	var nearby: Dictionary = inspect_nearby(context)
	if nearby.has("error"):
		return nearby
	if nearby.get("kind", "") == "NONE":
		return {"error":"no physical anchor in interaction range"}
	if nearby.get("kind", "") == "CURRENT_ANCHOR":
		return nearby
	if not ["ROUTE_CHOICE_REQUIRED", "TRAVEL_CONFIRMABLE"].has(nearby.get("kind", "")):
		return {"error":str(nearby.get("reason", "route is physically blocked")),
			"safe_return_anchor":state.current_anchor}
	var target := str(nearby.get("to", ""))
	if target.is_empty():
		return {"error":"nearby anchor target missing"}
	var plan: Dictionary = runtime.world_runtime.travel_to_anchor(target, selected_route, context)
	if plan.has("error"):
		return plan
	if region_host.current_region_world.is_portal(str(plan.get("from", "")), target):
		player.global_position = region_host.current_region_world.anchor_position(target)
		player.velocity = Vector2.ZERO
	return {
		"kind":"ARRIVED",
		"anchor_id":state.current_anchor,
		"route_choice":plan.get("route_choice", ""),
		"scene_ids":runtime.world_runtime.bound_scene_ids_at(state.current_anchor),
		"plan":plan
	}

func open_nearby_scene(scene_id: String) -> Dictionary:
	var nearby: Dictionary = inspect_nearby()
	if nearby.get("kind", "") != "CURRENT_ANCHOR":
		return {"error":"scene interaction requires physical proximity to current anchor"}
	var available: Array = nearby.get("scene_ids", [])
	if not available.has(scene_id):
		return {"error":"scene is not bound to this physical anchor"}
	return runtime.open_scene(scene_id)
