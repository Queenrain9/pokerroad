class_name CompetitionContract
extends RefCounted

const CONTRACT_PATH = "res://data/competition_contract_v1.json"

static func load_contract() -> Dictionary:
	var f := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if f == null:
		return {"error":"competition contract missing"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return {"error":"competition contract malformed"}
	return parsed

static func can_transition(from_state: String, to_state: String) -> bool:
	var c := load_contract()
	if c.has("error"):
		return false
	var transitions: Dictionary = c.get("event_lifecycle", {}).get("allowed_transitions", {})
	return transitions.get(from_state, []).has(to_state)

static func validate_event_catalog(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var c := load_contract()
	if c.has("error"):
		errors.append(c.error)
		return errors
	var seen := {}
	for event in catalog.get("events", []):
		var event_id := str(event.get("event_id", ""))
		if event_id.is_empty() or seen.has(event_id):
			errors.append("duplicate or empty event_id: " + event_id)
		seen[event_id] = true
		if event.get("wallet_and_tournament_chips_are_separate", false) != true:
			errors.append(event_id + ": wallet/tournament chips must be separate")
		if event.get("record_owner", "") != "PLAYER" and event.get("national_qualifier", false) and int(event.get("qualifying_places_dev", 0)) > 0:
			# NPC may qualify itself, but never the player. This flag only describes the event.
			pass
		if event.get("kind", "") == "OPTIONAL_TOWER_FINAL" and event.get("national_qualifier", false):
			errors.append(event_id + ": tower must never grant national Q")
		if event.get("kind", "") == "OFFICIAL_FINAL" and event.get("national_qualifier", false):
			errors.append(event_id + ": national final is not a qualifier")
	return errors

static func resolve_player_q(evidence: Dictionary, event_rules: Dictionary) -> String:
	return Qualification.qualify_from_result(evidence, event_rules)

static func official_champion(evidence: Dictionary, event_rules: Dictionary) -> bool:
	return event_rules.get("kind", "") == "OFFICIAL_FINAL" 		and event_rules.get("record_owner", "") == "PLAYER" 		and evidence.get("owner_id", "") == "PLAYER" 		and evidence.get("registered_official", false) 		and evidence.get("match_status", "") == "FINISHED" 		and int(evidence.get("final_rank", 0)) == 1

static func mainline_must_remain_open(context: Dictionary) -> bool:
	if context.get("tower_required", false):
		return false
	if context.get("requires_match_win", false):
		return false
	if context.get("requires_positive_wallet", false):
		return false
	return true
