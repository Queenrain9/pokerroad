extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	var state = get_root().get_node("GameState")
	state._ready()
	state.current_region = "01"
	state.current_anchor = "P0"
	var validation: Array[String] = LevelGeometryRegistry.validate_region("01")
	must(validation.is_empty(), "Saebom level geometry passes native validator")
	if not validation.is_empty():
		for item in validation:
			push_error("LEVEL GEOMETRY DETAIL: " + item)

	var host = Host.new()
	get_root().add_child(host)
	var mounted: Dictionary = host.mount_region("01", state)
	must(not mounted.has("error"), "Saebom mounts with validated level geometry")
	if not mounted.has("error"):
		must(mounted.get("level_geometry_status", "") == "PROVISIONAL_BLOCKOUT_GEOMETRY_VALIDATED_NOT_FINAL_ART",
			"descriptor reports honest blockout status")
		must(int(mounted.get("level_building_count", 0)) == 8, "descriptor exposes 8 proposed building footprints")
		must(int(mounted.get("level_interaction_slot_count", 0)) == 12, "descriptor exposes 12 interaction slots")
		must(int(mounted.get("level_occlusion_candidate_count", 0)) == 5, "descriptor exposes 5 visual occlusion candidates")

	var region: Dictionary = LevelGeometryRegistry.region_geometry("01")
	must(region.get("building_footprints", []).size() == 8, "registry loads every building footprint")
	must(region.get("interaction_slots", []).size() == 12, "registry loads every interaction slot")
	var slot_ids: Array[String] = []
	for slot in region.get("interaction_slots", []):
		slot_ids.append(str(slot.get("id", "")))
	for required in ["I_M01_BOARD","I_M02_BOKRYE","I_S02_ENDHOUSE","I_S02_BOMI","I_M03_HAECHAN",
		"I_M04_MATCH_TENT","I_M05_IAN","I_M06_TOWER_STAFF","I_M07_POSTER","I_M07_DAON_BUS"]:
		must(slot_ids.has(required), "required authored slot exists: " + required)

	must(LevelGeometryRegistry.validate_region("02").is_empty(), "unauthored regions remain valid and unaffected")

	for error in errors:
		push_error("SAEBOM LEVEL GEOMETRY FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SAEBOM_LEVEL_GEOMETRY: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
