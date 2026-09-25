class_name PokerRoadPlayer
extends CharacterBody2D

var state
var active_region
var virtual_move := Vector2.ZERO
var move_speed := 260.0
var world_bounds := Rect2()
var interaction_radius := 82.0

var facing := Vector2.DOWN

func _draw() -> void:
	# Prototype 3/4 player sprite drawn from simple shapes. It is intentionally
	# asset-free so scale/readability can be validated before final character art.
	var shadow := PackedVector2Array([Vector2(-24,17),Vector2(-16,10),Vector2(0,8),Vector2(16,10),Vector2(24,17),Vector2(16,24),Vector2(0,26),Vector2(-16,24)])
	draw_colored_polygon(shadow, Color(0.05,0.09,0.10,0.22))
	var flip := 1.0 if facing.x >= 0.0 else -1.0
	# legs / shoes
	draw_rect(Rect2(Vector2(-13, 5), Vector2(9, 24)), Color("#293b42"))
	draw_rect(Rect2(Vector2(5, 5), Vector2(9, 24)), Color("#293b42"))
	draw_rect(Rect2(Vector2(-16, 24), Vector2(14, 7)), Color("#d7d5c9"))
	draw_rect(Rect2(Vector2(3, 24), Vector2(14, 7)), Color("#d7d5c9"))
	# torso and backpack
	var torso := PackedVector2Array([Vector2(-20,-25),Vector2(16,-25),Vector2(24,-3),Vector2(16,12),Vector2(-17,12),Vector2(-25,-4)])
	draw_colored_polygon(torso, Color("#40545d"))
	draw_circle(Vector2(-13*flip,-5), 13, Color("#26383f"))
	# neck / head
	draw_circle(Vector2(0,-42), 16, Color("#d8b08d"))
	var hair := PackedVector2Array([Vector2(-17,-46),Vector2(-12,-59),Vector2(5,-62),Vector2(17,-51),Vector2(14,-39),Vector2(-14,-39)])
	draw_colored_polygon(hair, Color("#332d2b"))
	draw_circle(Vector2(-8*flip,-62), 8, Color("#332d2b"))
	# tiny backpack charm / suit accent
	draw_circle(Vector2(-16*flip,2), 3.5, Color("#e0b95f"))

func _ready() -> void:
	z_index = 20
	var metrics: Dictionary = SpatialRegistry.player_metrics()
	move_speed = float(metrics.get("move_speed_units_per_sec", 260))
	interaction_radius = float(metrics.get("interaction_radius", 82))
	if get_node_or_null("CollisionShape2D") == null:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = float(metrics.get("collision_radius", 18))
		shape_node.shape = circle
		add_child(shape_node)

func bind_region(region_world, p_state) -> Dictionary:
	active_region = region_world
	state = p_state
	if active_region == null or state == null:
		return {"error":"player requires mounted region and state"}
	world_bounds = active_region.world_bounds()
	var spawn: Vector2 = active_region.anchor_position(state.current_anchor)
	if spawn == Vector2.INF:
		return {"error":"current anchor has no physical position"}
	global_position = spawn
	velocity = Vector2.ZERO
	return {"position":global_position,"anchor":state.current_anchor}

func set_virtual_move_vector(value: Vector2) -> void:
	virtual_move = value.limit_length(1.0)

func clear_virtual_move() -> void:
	virtual_move = Vector2.ZERO

func nearest_interactable_anchor() -> String:
	if active_region == null:
		return ""
	return active_region.nearest_anchor(global_position, interaction_radius)

func _physics_process(_delta: float) -> void:
	var keyboard: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y += 1.0
	var direction: Vector2 = virtual_move if virtual_move.length_squared() > 0.0001 else keyboard.normalized()
	if direction.length_squared() > 0.0001:
		facing = direction
		queue_redraw()
	velocity = direction * move_speed
	var previous_position: Vector2 = global_position
	move_and_slide()
	if active_region != null and state != null and not active_region.can_walk_from(state.current_anchor, global_position):
		global_position = previous_position
		velocity = Vector2.ZERO
	if world_bounds.size != Vector2.ZERO:
		var r: float = float(SpatialRegistry.player_metrics().get("collision_radius", 18))
		global_position.x = clampf(global_position.x, world_bounds.position.x + r, world_bounds.end.x - r)
		global_position.y = clampf(global_position.y, world_bounds.position.y + r, world_bounds.end.y - r)
