class_name PresentationContract
extends RefCounted

const PATH = "res://data/presentation_contract_v1.json"

static func load_contract() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {"error":"presentation contract missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return {"error":"presentation contract malformed"}
	return parsed

static func can_transition(from_mode: String, to_mode: String) -> bool:
	var c := load_contract()
	if c.has("error"):
		return false
	return c.get("transition_graph", {}).get(from_mode, []).has(to_mode)

static func region_capabilities(region_id: String) -> Array:
	var c := load_contract()
	if c.has("error"):
		return []
	return c.get("region_capabilities", {}).get(region_id, [])

static func validate_all_regions() -> Array[String]:
	var errors: Array[String] = []
	var c := load_contract()
	if c.has("error"):
		errors.append(c.error)
		return errors
	var caps: Dictionary = c.get("region_capabilities", {})
	for i in range(1, 9):
		var id := "%02d" % i
		if not caps.has(id) or caps[id].is_empty():
			errors.append("missing production capability contract for region " + id)
	var transitions: Dictionary = c.get("transition_graph", {})
	if not transitions.get("POKER", []).has("RESULT") or not transitions.get("RESULT", []).has("WORLD"):
		errors.append("poker must resolve through RESULT and return to WORLD")
	return errors

static func poker_required_information() -> Array:
	var c := load_contract()
	return [] if c.has("error") else c.get("poker_information_priority", [])
