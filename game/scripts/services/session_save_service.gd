class_name SessionSaveService
extends RefCounted

const CONTRACT_PATH = "res://data/runtime_save_contract_v2.json"
const SCHEMA = 2

static func load_contract() -> Dictionary:
	var f := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if f == null:
		return {"error":"runtime save contract missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != SCHEMA:
		return {"error":"runtime save contract malformed"}
	return parsed

static func build_payload(world: Dictionary, mode: String, mode_state: Dictionary = {}) -> Dictionary:
	var contract := load_contract()
	if contract.has("error"):
		return contract
	if not contract.get("save_modes", []).has(mode):
		return {"error":"unsupported save mode"}
	var payload := {"schema":SCHEMA,"mode":mode,"world":world.duplicate(true),"mode_state":mode_state.duplicate(true)}
	var errors := validate_payload(payload)
	if not errors.is_empty():
		return {"error":"invalid save payload","details":errors}
	return payload

static func validate_payload(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(payload.get("schema", 0)) != SCHEMA:
		errors.append("wrong save schema")
		return errors
	var contract := load_contract()
	if contract.has("error"):
		errors.append(contract.error)
		return errors
	var mode := str(payload.get("mode", ""))
	if not contract.get("save_modes", []).has(mode):
		errors.append("unknown mode")
	var world = payload.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		errors.append("world is not dictionary")
		return errors
	for field in contract.get("required_world_fields", []):
		if not world.has(field):
			errors.append("missing world field " + str(field))
	var state = payload.get("mode_state", {})
	if typeof(state) != TYPE_DICTIONARY:
		errors.append("mode_state is not dictionary")
		return errors
	if mode == "DIALOGUE":
		for field in contract.get("dialogue_fields", []):
			if not state.has(field):
				errors.append("missing dialogue field " + str(field))
	if mode == "POKER":
		for field in contract.get("poker_fields", []):
			if not state.has(field):
				errors.append("missing poker field " + str(field))
	return errors

static func migrate_v1_world_only(old: Dictionary) -> Dictionary:
	if int(old.get("schema", 0)) != 1:
		return {"error":"not a v1 save"}
	var world := old.duplicate(true)
	world.erase("schema")
	if not world.has("world_layer"):
		world["world_layer"] = 0
	if not world.has("return_anchor"):
		world["return_anchor"] = world.get("current_anchor", "")
	return build_payload(world, "WORLD", {})

static func tournament_mode_state(event_instance_id: String, tournament: TournamentDirector) -> Dictionary:
	if event_instance_id.is_empty() or tournament == null:
		return {"error":"missing event instance or tournament"}
	return {"event_instance_id":event_instance_id,"event_id":tournament.event_id,"tournament_snapshot":tournament.to_snapshot()}

static func restore_tournament(mode_state: Dictionary):
	if mode_state.get("event_instance_id", "").is_empty():
		return null
	return TournamentDirector.from_snapshot(mode_state.get("tournament_snapshot", {}))

static func write_atomic(path: String, payload: Dictionary) -> bool:
	var errors := validate_payload(payload)
	if not errors.is_empty():
		return false
	var temp_path := path + ".tmp"
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		return false
	temp.store_string(JSON.stringify(payload))
	temp.flush()
	temp = null
	var abs_temp := ProjectSettings.globalize_path(temp_path)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(abs_path)
		if remove_error != OK:
			DirAccess.remove_absolute(abs_temp)
			return false
	return DirAccess.rename_absolute(abs_temp, abs_path) == OK

static func read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error":"save file missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error":"save file unreadable"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error":"save file malformed"}
	var errors := validate_payload(parsed)
	if not errors.is_empty():
		return {"error":"save validation failed","details":errors}
	return parsed
