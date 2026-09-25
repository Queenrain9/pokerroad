class_name SceneSourceStore
extends RefCounted
const STORE_ROOT = "res://data/original_scenes/"

static func get_original(scene_id: String, manifest_record: Dictionary) -> Dictionary:
	if manifest_record.get("id", "") != scene_id:
		return {"error": "scene manifest ID does not match source request"}
	if not scene_id.is_valid_filename() or scene_id.length() != 6:
		return {"error": "invalid scene source ID"}
	var path: String = STORE_ROOT + scene_id + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "full original source has not been imported", "source_import_status": "NOT_IMPORTED"}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "malformed original source record"}
	if parsed.get("scene_id", "") != scene_id or parsed.get("source_page_id", "") != manifest_record.get("source_page_id", ""):
		return {"error": "original scene provenance mismatch"}
	if parsed.get("source_import_status", "") != "ORIGINAL_TEXT_CAPTURED":
		return {"error": "source not captured"}
	var source: String = str(parsed.get("verbatim_source_markdown", ""))
	if source.length() < 80:
		return {"error": "scene source unexpectedly short"}
	var actual_hash: String = source.sha256_text()
	if actual_hash != parsed.get("source_section_sha256", ""):
		return {"error": "original source digest mismatch"}
	return {"scene_id": scene_id, "source_page_id": parsed.source_page_id,
		"verbatim_source_markdown": source, "source_section_sha256": actual_hash,
		"source_import_status": "ORIGINAL_TEXT_CAPTURED",
		"game_implementation_status": "NOT_IMPLEMENTED"}
