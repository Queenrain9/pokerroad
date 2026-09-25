class_name RegionHost
extends Node2D

const REGION_SCENES = {
	"01":"res://scenes/regions/01_saebomdong.tscn",
	"02":"res://scenes/regions/02_hangang.tscn",
	"03":"res://scenes/regions/03_acorn_forest.tscn",
	"04":"res://scenes/regions/04_seagull_port.tscn",
	"05":"res://scenes/regions/05_last_station.tscn",
	"06":"res://scenes/regions/06_moon_palace.tscn",
	"07":"res://scenes/regions/07_sleepless_market.tscn",
	"08":"res://scenes/regions/08_central_city.tscn"
}

var current_region_id := ""
var current_region_world

func mount_region(region_id: String, state) -> Dictionary:
	if not REGION_SCENES.has(region_id):
		return {"error":"no region scene registered"}
	var resource = load(str(REGION_SCENES[region_id]))
	if resource == null or not resource is PackedScene:
		return {"error":"region PackedScene missing"}
	var world = resource.instantiate()
	if world == null or not world.has_method("initialize_from_state"):
		if world != null:
			world.free()
		return {"error":"region scene has no RegionWorld contract"}
	var initialized: Dictionary = world.initialize_from_state(state)
	if initialized.has("error"):
		world.free()
		return initialized
	if current_region_world != null:
		remove_child(current_region_world)
		current_region_world.free()
	current_region_world = world
	current_region_id = region_id
	add_child(current_region_world)
	return initialized

func validate_all_region_scenes(state) -> Array[String]:
	var errors: Array[String] = []
	if REGION_SCENES.size() != 8:
		errors.append("expected eight registered region scenes")
	for i in range(1, 9):
		var region_id := "%02d" % i
		if not REGION_SCENES.has(region_id):
			errors.append("missing region scene " + region_id)
			continue
		var resource = load(str(REGION_SCENES[region_id]))
		if resource == null or not resource is PackedScene:
			errors.append(region_id + ": PackedScene missing")
			continue
		var world = resource.instantiate()
		if world == null or not world.has_method("initialize_from_state"):
			errors.append(region_id + ": RegionWorld contract missing")
			if world != null:
				world.free()
			continue
		var initialized: Dictionary = world.initialize_from_state(state)
		if initialized.has("error"):
			errors.append(region_id + ": " + str(initialized.error))
		else:
			if initialized.get("id", "") != region_id:
				errors.append(region_id + ": identity mismatch")
			if initialized.get("physical_map_status", "") != "NOT_IMPLEMENTED":
				errors.append(region_id + ": physical map status is dishonest")
			if initialized.get("anchor_ids", []).is_empty():
				errors.append(region_id + ": no manifest anchors")
			if initialized.get("capabilities", []).is_empty():
				errors.append(region_id + ": no region capabilities")
		world.free()
	return errors
