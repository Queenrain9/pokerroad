extends SceneTree

const Host = preload("res://scripts/world/region_host.gd")
const Player = preload("res://scripts/world/player_controller.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = get_root().get_node("GameState")
	state._ready()
	state.current_region = "01"
	state.current_anchor = "P0"
	var host = Host.new()
	get_root().add_child(host)
	must(not host.mount_region("01", state).has("error"), "entry world mounts")
	var player = Player.new()
	get_root().add_child(player)
	must(not player.bind_region(host.current_region_world, state).has("error"), "physical player binds")
	var start: Vector2 = player.global_position
	player.set_virtual_move_vector(Vector2.UP)
	for i in range(65):
		await physics_frame
	player.clear_virtual_move()
	must(player.global_position.y < start.y, "virtual input moves the CharacterBody2D")
	must(host.current_region_world.can_walk_from("P0", player.global_position), "actual physics cannot leave the source plaza")
	must(player.global_position.distance_to(start) <= RouteGeometry.ANCHOR_PLAZA_RADIUS + 2.0, "off-route movement stops at the corridor boundary")
	player.global_position = start
	player.set_virtual_move_vector((host.current_region_world.anchor_position("P1") - start).normalized())
	for i in range(112):
		await physics_frame
	player.clear_virtual_move()
	must(host.current_region_world.can_walk_from("P0", player.global_position), "actual movement remains in the P0 to P1 corridor")
	must(player.nearest_interactable_anchor() == "P1", "walking the corridor reaches the next interaction anchor")

	# Regression: K3 has an optional tower gate next to the legal K3→K5 exit.
	# The gate collision must never trap the player on the public exit corridor.
	state.current_region = "02"
	state.current_anchor = "K3"
	must(not host.mount_region("02", state).has("error"), "river world mounts for adjacent-gate regression")
	must(not player.bind_region(host.current_region_world, state).has("error"), "player binds at K3")
	var river_exit: Vector2 = host.current_region_world.anchor_position("K5")
	var first_river_collider := ""
	player.set_virtual_move_vector((river_exit - player.global_position).normalized())
	for i in range(420):
		await physics_frame
		if first_river_collider.is_empty() and player.get_slide_collision_count() > 0:
			var collision = player.get_slide_collision(0)
			if collision != null and collision.get_collider() != null:
				first_river_collider = str(collision.get_collider().name)
	player.clear_virtual_move()
	print("PHYSICS K3-K5 final=", player.global_position, " target=", river_exit, " nearest=", player.nearest_interactable_anchor(), " collider=", first_river_collider)
	must(player.nearest_interactable_anchor() == "K5", "K3 optional tower gate does not block K3 to K5 public exit")

	for error in errors:
		push_error("PHYSICS ROUTES FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_PHYSICS_ROUTES: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
