class_name PokerRoadPlayer
extends CharacterBody2D

var state
var active_region
var virtual_move := Vector2.ZERO
var move_speed := 260.0
var world_bounds := Rect2()
var interaction_radius := 82.0

func _ready() -> void:
	var metrics := SpatialRegistry.player_metrics()
	move_speed = float(metrics.get("move_speed_units_per_sec", 260))
	interaction_radius = float(metrics.get("interaction_radius", 82))
	if get_node_or_null("CollisionShape2D") == null:
		var shape_node := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(metrics.get("collision_radius", 18))
		shape_node.shape = circle
		add_child(shape_node)

func bind_region(region_world, p_state) -> Dictionary:
	active_region = region_world
	state = p_state
	if active_region == null or state == null:
		return {"error":"player requires mounted region and state"}
	world_bounds = active_region.world_bounds()
	var spawn := active_region.anchor_position(state.current_anchor)
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
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y += 1.0
	var direction := virtual_move if virtual_move.length_squared() > 0.0001 else keyboard.normalized()
	velocity = direction * move_speed
	move_and_slide()
	if world_bounds.size != Vector2.ZERO:
		var r := float(SpatialRegistry.player_metrics().get("collision_radius", 18))
		global_position.x = clampf(global_position.x, world_bounds.position.x + r, world_bounds.end.x - r)
		global_position.y = clampf(global_position.y, world_bounds.position.y + r, world_bounds.end.y - r)
