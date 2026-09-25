class_name SceneRunner
extends RefCounted

var active_binding: Dictionary = {}
var active_source: Dictionary = {}
var selected_interaction := ""
var last_choice := ""

func has_active_scene() -> bool:
	return not active_binding.is_empty()

func active_scene_id() -> String:
	return str(active_binding.get("scene_id", ""))

func open_scene(scene_id: String, anchor_id: String) -> Dictionary:
	var binding: Dictionary = SceneBindingStore.binding_by_id(scene_id)
	if binding.is_empty():
		return {"error":"scene has no authored runtime binding"}
	if binding.get("region_id", "") != GameState.current_region:
		return {"error":"scene belongs to another region"}
	if not binding.get("entry_anchors", []).has(anchor_id):
		return {"error":"scene cannot start at this anchor"}
	if binding.get("kind", "") == "MAIN" and GameState.main_cursor != scene_id and not GameState.finished_main.has(scene_id):
		return {"error":"main scene is not the current cursor"}
	var source: Dictionary = GameState.scene_source_record(scene_id)
	if source.has("error"):
		return source
	if source.get("source_section_sha256", "") != binding.get("source_section_sha256", ""):
		return {"error":"runtime binding no longer matches canonical source"}
	active_binding = binding.duplicate(true)
	active_source = source.duplicate(true)
	selected_interaction = ""
	last_choice = ""
	return view_model()

func view_model() -> Dictionary:
	if active_binding.is_empty():
		return {"error":"no active scene"}
	return {
		"scene_id":active_scene_id(),
		"region_id":active_binding.get("region_id", ""),
		"open_mode":active_binding.get("open_mode", "DIALOGUE"),
		"entry_anchors":active_binding.get("entry_anchors", []).duplicate(),
		"verbatim_source_markdown":active_source.get("verbatim_source_markdown", ""),
		"source_section_sha256":active_source.get("source_section_sha256", ""),
		"interactions":active_binding.get("interactions", []).duplicate(true),
		"physical_world_binding_status":active_binding.get("physical_world_binding_status", "NOT_IMPLEMENTED")
	}

func choose(interaction_id: String, choice_id: String) -> Dictionary:
	if active_binding.is_empty():
		return {"error":"no active scene"}
	var interaction: Dictionary = {}
	for item in active_binding.get("interactions", []):
		if item.get("interaction_id", "") == interaction_id:
			interaction = item
			break
	if interaction.is_empty():
		return {"error":"unknown interaction"}
	var choice: Dictionary = {}
	for item in interaction.get("choices", []):
		if item.get("choice_id", "") == choice_id:
			choice = item
			break
	if choice.is_empty():
		return {"error":"unknown choice"}
	var requests: Array[Dictionary] = []
	for effect in choice.get("effects", []):
		var result: Dictionary = _apply_effect(effect)
		if result.has("error"):
			return result
		if result.has("request"):
			requests.append(result.request)
	selected_interaction = interaction_id
	last_choice = choice_id
	return {
		"scene_id":active_scene_id(),
		"interaction_id":interaction_id,
		"choice_id":choice_id,
		"requested_mode":choice.get("requested_mode", active_binding.get("open_mode", "DIALOGUE")),
		"external_requests":requests,
		"ready_to_complete":ready_to_complete()
	}

func _apply_effect(effect: Dictionary) -> Dictionary:
	match str(effect.get("type", "")):
		"SET_FLAG":
			if not GameState.set_story_flag(str(effect.get("key", "")), effect.get("value")):
				return {"error":"failed to set story flag"}
		"SET_OBSERVATION":
			if not GameState.record_observation(str(effect.get("event_id", "")), str(effect.get("status", ""))):
				return {"error":"failed to record observation"}
		"SET_REGISTRATION_INTENT":
			var value: String = str(effect.get("value", ""))
			if not ["VIEW","OFFICIAL"].has(value):
				return {"error":"invalid registration intent"}
			GameState.registration_intent = value
			GameState.world_changed.emit()
		"REQUEST_EVENT":
			return {"request":{
				"type":"START_EVENT",
				"event_id":str(effect.get("event_id", "")),
				"participants":effect.get("participants", []).duplicate(),
				"registered_official":bool(effect.get("registered_official", false)),
				"source_scene_id":active_scene_id()
			}}
		_:
			return {"error":"unsupported scene effect"}
	return {"ok":true}

func apply_external_result(event_id: String, outcome: String) -> Dictionary:
	if active_binding.is_empty():
		return {"error":"no active scene"}
	var mappings: Dictionary = active_binding.get("external_results", {})
	if not mappings.has(event_id):
		return {"error":"active scene does not consume this event result"}
	var by_outcome: Dictionary = mappings[event_id]
	if not by_outcome.has(outcome):
		return {"error":"unmapped external event outcome"}
	for effect in by_outcome[outcome]:
		var result: Dictionary = _apply_effect(effect)
		if result.has("error"):
			return result
	return {"ready_to_complete":ready_to_complete()}

func ready_to_complete() -> bool:
	if active_binding.is_empty():
		return false
	var completion: Dictionary = active_binding.get("completion", {})
	match str(completion.get("policy", "")):
		"FLAG_IN":
			var value = GameState.story_flags.get(str(completion.get("key", "")))
			return completion.get("values", []).has(value)
	return false

func commit_completion() -> Dictionary:
	if active_binding.is_empty() or not ready_to_complete():
		return {"error":"scene completion conditions not met"}
	if active_binding.get("kind", "") != "MAIN":
		return {"error":"optional completion path not implemented in common runner yet"}
	if active_binding.get("completion", {}).get("advance_main", false):
		if not GameState.complete_main_scene(active_scene_id()):
			return {"error":"physical scene implementation gate not satisfied","ready":true}
		var completed: String = active_scene_id()
		clear()
		return {"completed":completed,"main_cursor":GameState.main_cursor}
	return {"error":"binding has no completion transition"}

func snapshot() -> Dictionary:
	if active_binding.is_empty():
		return {}
	return {
		"active_scene_id":active_scene_id(),
		"dialogue_cursor":0,
		"choice_cursor":last_choice,
		"return_anchor":GameState.return_anchor,
		"selected_interaction":selected_interaction
	}

func restore(snapshot: Dictionary) -> Dictionary:
	var scene_id: String = str(snapshot.get("active_scene_id", ""))
	if scene_id.is_empty():
		return {"error":"dialogue save has no active scene"}
	var opened: Dictionary = open_scene(scene_id, GameState.current_anchor)
	if opened.has("error"):
		return opened
	selected_interaction = str(snapshot.get("selected_interaction", ""))
	last_choice = str(snapshot.get("choice_cursor", ""))
	return view_model()

func clear() -> void:
	active_binding.clear()
	active_source.clear()
	selected_interaction = ""
	last_choice = ""
