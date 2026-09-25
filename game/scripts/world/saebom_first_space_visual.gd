class_name SaebomFirstSpaceVisual
extends Node2D

# First-space visual prototype for Region 01.
# This deliberately uses procedural 2D shapes so the 3/4 spatial language can
# be tested before final art is produced. Runtime anchors/collision stay owned
# by RegionWorld / RouteGeometry.

var region_world
var state
var board_marker: Node2D
var bokrye_marker: Node2D

const C_SKY = Color("#58717a")
const C_HAZE = Color("#8ea0a0")
const C_FAR = Color("#405a63")
const C_ROAD = Color("#c8b89b")
const C_ROAD_EDGE = Color("#8a8071")
const C_STONE = Color("#9a8e79")
const C_STONE_DARK = Color("#6f685d")
const C_WALL = Color("#cdbd9c")
const C_WALL_SIDE = Color("#a8997e")
const C_ROOF = Color("#495f61")
const C_ROOF_LIGHT = Color("#607475")
const C_ACCENT = Color("#d66d58")
const C_GREEN = Color("#587a67")
const C_GREEN_LIGHT = Color("#73917c")
const C_INK = Color("#203238")
const C_CREAM = Color("#f1dfb9")
const C_GOLD = Color("#e2bb68")

func setup(p_region_world, p_state) -> void:
	region_world = p_region_world
	state = p_state
	name = "SaebomFirstSpaceVisual"
	z_index = -10
	_build_backdrop()
	_build_first_space()
	_build_foreground_occlusion()
	_refresh_story_markers()
	if state != null and not state.world_changed.is_connected(_refresh_story_markers):
		state.world_changed.connect(_refresh_story_markers)

func _poly(points: Array, color: Color, z: int = 0, parent: Node2D = self) -> Polygon2D:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(p)
	var shape := Polygon2D.new()
	shape.polygon = packed
	shape.color = color
	shape.z_index = z
	parent.add_child(shape)
	return shape

func _rect(center: Vector2, size: Vector2, color: Color, z: int = 0, parent: Node2D = self) -> Polygon2D:
	var h := size / 2.0
	return _poly([
		center + Vector2(-h.x, -h.y),
		center + Vector2(h.x, -h.y),
		center + Vector2(h.x, h.y),
		center + Vector2(-h.x, h.y)
	], color, z, parent)

func _circle(center: Vector2, radius: float, color: Color, z: int = 0, parent: Node2D = self, sides: int = 20) -> Polygon2D:
	var points: Array = []
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return _poly(points, color, z, parent)

func _label(text_value: String, position: Vector2, size: int = 22, color: Color = C_CREAM, z: int = 10, parent: Node2D = self) -> Label:
	var l := Label.new()
	l.text = text_value
	l.position = position
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.z_index = z
	parent.add_child(l)
	return l

func _building(base: Vector2, size: Vector2, wall: Color, roof: Color, title: String = "") -> Node2D:
	var n := Node2D.new()
	n.position = base
	add_child(n)
	# front face
	_poly([
		Vector2(-size.x * 0.5, -size.y * 0.55),
		Vector2(size.x * 0.5, -size.y * 0.55),
		Vector2(size.x * 0.5, size.y * 0.45),
		Vector2(-size.x * 0.5, size.y * 0.45)
	], wall, 2, n)
	# visible right-side face for the 3/4 read
	_poly([
		Vector2(size.x * 0.5, -size.y * 0.55),
		Vector2(size.x * 0.5 + 58, -size.y * 0.82),
		Vector2(size.x * 0.5 + 58, size.y * 0.16),
		Vector2(size.x * 0.5, size.y * 0.45)
	], wall.darkened(0.16), 1, n)
	# roof plane
	_poly([
		Vector2(-size.x * 0.58, -size.y * 0.55),
		Vector2(size.x * 0.5, -size.y * 0.55),
		Vector2(size.x * 0.5 + 58, -size.y * 0.82),
		Vector2(-size.x * 0.28, -size.y * 0.86)
	], roof, 4, n)
	# roof highlight
	_poly([
		Vector2(-size.x * 0.52, -size.y * 0.59),
		Vector2(size.x * 0.42, -size.y * 0.59),
		Vector2(size.x * 0.49, -size.y * 0.66),
		Vector2(-size.x * 0.43, -size.y * 0.66)
	], roof.lightened(0.12), 5, n)
	if not title.is_empty():
		_rect(Vector2(0, -size.y * 0.16), Vector2(size.x * 0.72, 44), C_GREEN, 7, n)
		var label := _label(title, Vector2(-size.x * 0.29, -size.y * 0.26), 24, C_CREAM, 8, n)
		label.custom_minimum_size.x = size.x * 0.6
	return n

func _actor(position: Vector2, body_color: Color, hair_color: Color, facing_right: bool = true, scale_value: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = position
	n.scale = Vector2.ONE * scale_value
	n.z_index = 14
	add_child(n)
	# soft grounding shadow
	_poly([Vector2(-22,18),Vector2(22,18),Vector2(30,28),Vector2(-30,28)], Color(0.08,0.12,0.12,0.22), -1, n)
	# legs
	_rect(Vector2(-8,13), Vector2(11,32), Color("#2f4146"), 1, n)
	_rect(Vector2(8,13), Vector2(11,32), Color("#2f4146"), 1, n)
	# torso 3/4 wedge
	var flip := 1.0 if facing_right else -1.0
	_poly([
		Vector2(-24,-25), Vector2(20,-25), Vector2(28*flip,-2), Vector2(18,16), Vector2(-19,16), Vector2(-28*flip,-3)
	], body_color, 2, n)
	# backpack / rear silhouette
	_circle(Vector2(-14*flip,-3), 14, body_color.darkened(0.25), 1, n, 16)
	# head + hair cap
	_circle(Vector2(0,-47), 18, Color("#d8b28e"), 3, n, 18)
	_poly([
		Vector2(-19,-51),Vector2(-12,-66),Vector2(7,-68),Vector2(19,-55),Vector2(15,-43),Vector2(-15,-43)
	], hair_color, 4, n)
	# bun
	_circle(Vector2(-8*flip,-68), 9, hair_color, 4, n, 14)
	return n

func _marker(position: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = position
	n.z_index = 25
	add_child(n)
	_poly([Vector2(0,-18),Vector2(13,0),Vector2(0,18),Vector2(-13,0)], C_GOLD, 1, n)
	_circle(Vector2.ZERO, 5, C_INK, 2, n, 12)
	return n

func _build_backdrop() -> void:
	_rect(Vector2(1800,950), Vector2(3600,1900), C_SKY, -40)
	# distant river / haze band
	_rect(Vector2(1800,470), Vector2(3600,190), Color("#70898e"), -38)
	# distant city silhouette around the canonical P4 tower direction
	for x in range(60, 1660, 92):
		var h := 65.0 + float((x * 37) % 130)
		_rect(Vector2(float(x), 420.0 - h * 0.5), Vector2(58,h), C_FAR, -35)
	# distant tower landmark, intentionally schematic
	_rect(Vector2(1480,270), Vector2(88,280), Color("#344b55"), -34)
	_poly([Vector2(1436,132),Vector2(1480,66),Vector2(1524,132)], Color("#344b55"), -34)
	_circle(Vector2(1480,196), 15, C_GOLD, -33, self, 4)
	# hills
	_poly([Vector2(0,360),Vector2(260,260),Vector2(520,348),Vector2(790,220),Vector2(1040,335),Vector2(1280,245),Vector2(1620,345),Vector2(1620,520),Vector2(0,520)], Color("#48646a"), -36)

func _build_first_space() -> void:
	var p0: Vector2 = region_world.anchor_position("P0")
	var p1: Vector2 = region_world.anchor_position("P1")
	# lower P0 plaza
	_poly([
		p0 + Vector2(-260,-110), p0 + Vector2(210,-145),
		p0 + Vector2(290,85), p0 + Vector2(-220,145)
	], C_ROAD, -5)
	# raised P1 terrace with retaining face
	_poly([
		p1 + Vector2(-250,-155), p1 + Vector2(285,-175),
		p1 + Vector2(325,100), p1 + Vector2(-215,125)
	], C_ROAD.lightened(0.05), -4)
	_poly([
		p1 + Vector2(-215,125), p1 + Vector2(325,100),
		p1 + Vector2(325,170), p1 + Vector2(-215,195)
	], C_STONE_DARK, -3)
	# canonical P0->P1 path rendered as a stair/ramp corridor
	var v: Vector2 = p1 - p0
	var normal: Vector2 = v.orthogonal().normalized()
	var w := 88.0
	_poly([p0-normal*w,p0+normal*w,p1+normal*w,p1-normal*w], C_ROAD.lightened(0.08), -2)
	for i in range(1,9):
		var t := float(i)/9.0
		var c: Vector2 = p0.lerp(p1,t)
		_poly([c-normal*w,c+normal*w,c+normal*w+Vector2(0,8),c-normal*w+Vector2(0,8)], C_ROAD_EDGE, -1)
	# low walls / railings that frame but do not block corridor
	for x in [470.0, 560.0, 650.0]:
		_rect(Vector2(x, 940), Vector2(66,18), C_STONE, 0)
		_rect(Vector2(x, 922), Vector2(10,42), C_STONE_DARK, 1)
	# apartment mass behind P0
	var apt := _building(Vector2(250,865), Vector2(310,300), C_WALL, C_ROOF, "")
	_rect(Vector2(-82,-30),Vector2(56,88),Color("#344c53"),3,apt)
	_rect(Vector2(12,-30),Vector2(56,88),Color("#344c53"),3,apt)
	_rect(Vector2(89,45),Vector2(62,118),Color("#40575d"),3,apt)
	# board at P0, canonical first interaction target
	var board := Node2D.new()
	board.position = p0 + Vector2(5,-74)
	board.z_index = 12
	add_child(board)
	_rect(Vector2(0,-22),Vector2(118,76),Color("#efe0be"),1,board)
	_rect(Vector2(-45,45),Vector2(10,60),C_STONE_DARK,0,board)
	_rect(Vector2(45,45),Vector2(10,60),C_STONE_DARK,0,board)
	for y in [-38.0,-22.0,-6.0]:
		_rect(Vector2(0,y),Vector2(82,4),Color("#996f60"),2,board)
	_label("동네 게시판", Vector2(-58,62), 16, C_INK, 3, board)
	# supermarket on the raised P1 terrace
	var market := _building(Vector2(880,780), Vector2(360,285), C_WALL, C_ROOF_LIGHT, "슈퍼")
	_rect(Vector2(-96,50),Vector2(84,105),Color("#3d5960"),3,market)
	_rect(Vector2(18,50),Vector2(90,105),Color("#48676c"),3,market)
	_rect(Vector2(110,50),Vector2(48,105),Color("#3e555a"),3,market)
	# awning over the front
	_poly([Vector2(-175,-12),Vector2(175,-12),Vector2(150,30),Vector2(-160,30)],C_ACCENT,8,market)
	for x in [-125.0,-55.0,15.0,85.0]:
		_poly([Vector2(x,-12),Vector2(x+30,-12),Vector2(x+20,30),Vector2(x-10,30)],C_CREAM,9,market)
	# P1 평상
	var deck_pos: Vector2 = p1 + Vector2(80,-36)
	_rect(deck_pos, Vector2(210,72), Color("#6b5148"), 8)
	for dx in [-88.0,88.0]:
		_rect(deck_pos+Vector2(dx,52),Vector2(14,82),Color("#55413b"),7)
	# Bokrye and a super customer; both are visual, interaction remains anchor-driven
	_actor(p1 + Vector2(72,-52), Color("#8a5b69"), Color("#6c5650"), false, 1.0)
	_actor(p1 + Vector2(-95,-18), Color("#507b7b"), Color("#3d3532"), true, 0.9)
	# planters soften the terrace edges
	for pos in [p1+Vector2(-205,66),p1+Vector2(235,45),p0+Vector2(-190,70)]:
		_rect(pos+Vector2(0,16),Vector2(74,38),Color("#745c48"),4)
		_circle(pos+Vector2(-18,-12),24,C_GREEN,5)
		_circle(pos+Vector2(16,-16),26,C_GREEN_LIGHT,5)
	# utility pole between levels
	_rect(Vector2(592,812),Vector2(20,420),C_INK,6)
	_circle(Vector2(592,610),16,C_GOLD,7)
	_rect(Vector2(592,620),Vector2(130,9),C_INK,6)
	# hint of next street layer without creating new content
	_poly([Vector2(1060,905),Vector2(1360,855),Vector2(1490,1020),Vector2(1160,1060)], C_ROAD.darkened(0.03), -5)

func _build_foreground_occlusion() -> void:
	# Foreground masonry/roof pieces intentionally render above the player.
	# Alpha keeps the character readable while proving real layer occlusion.
	var fg := Node2D.new()
	fg.name = "ForegroundOcclusion"
	fg.z_index = 35
	add_child(fg)
	_poly([Vector2(40,1190),Vector2(360,1165),Vector2(430,1325),Vector2(0,1380)], Color(0.23,0.29,0.30,0.90), 0, fg)
	_poly([Vector2(30,1155),Vector2(330,1128),Vector2(382,1172),Vector2(58,1202)], Color(0.31,0.39,0.39,0.90), 1, fg)
	# flowering foreground hedge
	for pos in [Vector2(90,1155),Vector2(150,1144),Vector2(216,1140),Vector2(282,1135)]:
		_circle(pos,34,Color(0.32,0.48,0.39,0.78),2,fg)
		_circle(pos+Vector2(7,-10),8,Color(0.88,0.72,0.70,0.88),3,fg)

func _refresh_story_markers() -> void:
	if state == null:
		return
	if board_marker == null:
		board_marker = _marker(region_world.anchor_position("P0") + Vector2(0,-165))
	if bokrye_marker == null:
		bokrye_marker = _marker(region_world.anchor_position("P1") + Vector2(72,-142))
	board_marker.visible = state.main_cursor == "01-M01"
	bokrye_marker.visible = state.main_cursor == "01-M02"
