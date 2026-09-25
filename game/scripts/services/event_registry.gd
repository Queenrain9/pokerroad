class_name EventRegistry
extends RefCounted
## Events with identical scenes can have different owners, sanction and prizes.
## Existing entries are canonical identities, NOT the full tournament engine.

const CATALOG_PATH = "res://data/event_catalog_dev.json"

static func catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {"error": "event catalog missing"}
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "event catalog malformed"}
	return data

static func event_by_id(event_id: String) -> Dictionary:
	for item in catalog().get("events", []):
		if item.get("event_id", "") == event_id:
			return item
	return {}

static func gives_player_national_qualification(event_id: String, owner_id: String, rank: int, reviewed_verified: bool) -> bool:
	var event := event_by_id(event_id)
	if event.is_empty() or event.get("sanction_status", "") != "OFFICIAL":
		return false
	if not event.get("national_qualifier", false) or event.get("record_owner", "") != "PLAYER" or owner_id != "PLAYER":
		return false
	return reviewed_verified and rank > 0 and rank <= int(event.get("qualifying_places_dev", 0))
