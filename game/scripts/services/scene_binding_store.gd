class_name SceneBindingStore
extends RefCounted

const PATH = "res://data/scene_bindings_v1.json"
const ALLOWED_EFFECTS = ["SET_FLAG","SET_OBSERVATION","SET_REGISTRATION_INTENT","RESERVE_EVENT","GRANT_REWARD","REQUEST_EVENT"]

static func catalog() -> Dictionary:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {"error":"scene binding catalog missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return {"error":"scene binding catalog malformed"}
	return parsed

static func binding_by_id(scene_id: String) -> Dictionary:
	var data: Dictionary = catalog()
	if data.has("error"):
		return {}
	for binding in data.get("scenes", []):
		if binding.get("scene_id", "") == scene_id:
			return binding
	return {}

static func bindings_for(region_id: String, anchor_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Dictionary = catalog()
	if data.has("error"):
		return result
	for binding in data.get("scenes", []):
		if binding.get("region_id", "") == region_id and binding.get("entry_anchors", []).has(anchor_id):
			result.append(binding)
	return result

static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var data: Dictionary = catalog()
	if data.has("error"):
		errors.append(data.error)
		return errors
	var manifest_file: FileAccess = FileAccess.open("res://data/world_manifest.json", FileAccess.READ)
	if manifest_file == null:
		errors.append("world manifest missing")
		return errors
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	if typeof(manifest) != TYPE_DICTIONARY:
		errors.append("world manifest malformed")
		return errors
	var known_scenes: Dictionary = {}
	var anchors_by_region: Dictionary = {}
	for region in manifest.get("regions", []):
		var anchors: Array = []
		for point in region.get("anchors", []):
			anchors.append(point.get("id", ""))
		anchors_by_region[region.get("id", "")] = anchors
	for item in manifest.get("scenes", []):
		known_scenes[item.get("id", "")] = item
	var seen: Dictionary = {}
	for binding in data.get("scenes", []):
		var scene_id: String = str(binding.get("scene_id", ""))
		if scene_id.is_empty() or seen.has(scene_id):
			errors.append("duplicate/empty runtime binding: " + scene_id)
			continue
		seen[scene_id] = true
		if not known_scenes.has(scene_id):
			errors.append(scene_id + ": unknown source scene")
			continue
		var manifest_record: Dictionary = known_scenes[scene_id]
		if manifest_record.get("region_id", "") != binding.get("region_id", ""):
			errors.append(scene_id + ": region mismatch")
		var source_path: String = "res://data/original_scenes/" + scene_id + ".json"
		var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
		if source_file == null:
			errors.append(scene_id + ": imported source missing")
			continue
		var source = JSON.parse_string(source_file.get_as_text())
		if typeof(source) != TYPE_DICTIONARY:
			errors.append(scene_id + ": imported source malformed")
			continue
		if source.get("source_section_sha256", "") != binding.get("source_section_sha256", ""):
			errors.append(scene_id + ": binding/source hash mismatch")
		var region_id: String = str(binding.get("region_id", ""))
		for anchor in binding.get("entry_anchors", []):
			if not anchors_by_region.get(region_id, []).has(anchor):
				errors.append(scene_id + ": unknown entry anchor " + str(anchor))
		if binding.get("physical_world_binding_status", "") == "PLAYABLE":
			if binding.get("entry_anchors", []).is_empty() or str(binding.get("target", "")).is_empty():
				errors.append(scene_id + ": playable binding needs anchor and target")
		var open_mode: String = str(binding.get("open_mode", ""))
		for interaction in binding.get("interactions", []):
			for choice in interaction.get("choices", []):
				var requested_mode: String = str(choice.get("requested_mode", open_mode))
				for required_anchor in choice.get("requires_anchor", []):
					if not anchors_by_region.get(region_id, []).has(required_anchor):
						errors.append(scene_id + ": choice requires unknown anchor " + str(required_anchor))
				if requested_mode != open_mode and not PresentationContract.can_transition(open_mode, requested_mode):
					errors.append(scene_id + ": illegal mode request " + open_mode + " -> " + requested_mode)
				for effect in choice.get("effects", []):
					var effect_type: String = str(effect.get("type", ""))
					if not ALLOWED_EFFECTS.has(effect_type):
						errors.append(scene_id + ": unsupported effect " + effect_type)
					if effect_type == "REQUEST_EVENT" and EventRegistry.event_by_id(str(effect.get("event_id", ""))).is_empty():
						errors.append(scene_id + ": unknown requested event " + str(effect.get("event_id", "")))
					if effect_type == "RESERVE_EVENT" and EventRegistry.event_by_id(str(effect.get("event_id", ""))).is_empty():
						errors.append(scene_id + ": unknown reserved event " + str(effect.get("event_id", "")))
		var npc_event: String = str(binding.get("npc_event", ""))
		if not npc_event.is_empty() and EventRegistry.event_by_id(npc_event).is_empty():
			errors.append(scene_id + ": unknown independent NPC event " + npc_event)
		for effect in binding.get("npc_event_effects", []):
			var effect_type: String = str(effect.get("type", ""))
			if not ALLOWED_EFFECTS.has(effect_type) or effect_type == "REQUEST_EVENT":
				errors.append(scene_id + ": unsupported NPC completion effect " + effect_type)
	return errors
