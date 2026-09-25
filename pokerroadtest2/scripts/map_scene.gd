extends Node2D

# POKERROAD Map Studio
# One fixed 1280x720 composition only.
# No dialogue, buttons, interactions, adjacent areas or off-screen world are implemented.

const W := 1280.0
const H := 720.0

var ui_font: Font

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_distant_city()
	_draw_river_and_bridge()
	_draw_far_hillside()
	_draw_left_block()
	_draw_center_block()
	_draw_right_block()
	_draw_stairs()
	_draw_street_details()
	_draw_foreground()

func poly(points, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func txt(pos: Vector2, text: String, size: int, color := Color(0.13, 0.10, 0.08), width := 220.0) -> void:
	draw_string(ui_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)

func _draw_sky() -> void:
	var top := Color("#5b466f")
	var mid := Color("#d17273")
	var bottom := Color("#ffbf72")
	for y in range(0, 320, 4):
		var t := float(y) / 320.0
		var c := top.lerp(mid, min(t * 1.45, 1.0)) if t < 0.68 else mid.lerp(bottom, (t - 0.68) / 0.32)
		draw_rect(Rect2(0, y, W, 5), c, true)
	for i in range(15):
		var x := 35.0 + i * 92.0
		var y := 58.0 + sin(float(i) * 0.9) * 25.0
		draw_line(Vector2(x, y), Vector2(x + 155, y + 18), Color(1.0, 0.71, 0.58, 0.18), 8.0)
	draw_circle(Vector2(916, 153), 33, Color("#ffd58d"))
	draw_circle(Vector2(916, 153), 53, Color(1.0, 0.72, 0.38, 0.10))
	poly([Vector2(0, 253), Vector2(180, 190), Vector2(305, 235), Vector2(444, 181), Vector2(592, 244), Vector2(770, 190), Vector2(965, 250), Vector2(1112, 198), Vector2(1280, 252), Vector2(1280, 355), Vector2(0, 355)], Color("#5d526d"))
	poly([Vector2(0, 287), Vector2(206, 227), Vector2(395, 287), Vector2(565, 224), Vector2(741, 298), Vector2(919, 235), Vector2(1082, 294), Vector2(1280, 246), Vector2(1280, 365), Vector2(0, 365)], Color("#4c465e"))

func _draw_distant_city() -> void:
	draw_rect(Rect2(0, 255, 1280, 150), Color("#303343"), true)
	for i in range(64):
		var x := float(i) * 21.0
		var h := 25.0 + float((i * 37) % 68)
		draw_rect(Rect2(x, 355.0 - h, 16, h), Color("#242a36"), true)
		if i % 3 != 0:
			draw_rect(Rect2(x + 4, 347.0 - h, 3, 3), Color(1.0, 0.73, 0.38, 0.78), true)
			draw_rect(Rect2(x + 10, 335.0 - h, 3, 3), Color(1.0, 0.57, 0.31, 0.62), true)

	var tower_x := [838, 873, 910, 952, 990, 1025, 1060, 1094]
	var tower_h := [92, 122, 112, 202, 168, 128, 103, 86]
	for i in range(tower_x.size()):
		var x := float(tower_x[i])
		var h := float(tower_h[i])
		draw_rect(Rect2(x, 315.0 - h, 20, h), Color("#262a3a"), true)
		poly([Vector2(x - 4, 315 - h), Vector2(x + 10, 296 - h), Vector2(x + 24, 315 - h)], Color("#262a3a"))
		draw_circle(Vector2(x + 10, 307 - h), 3.3, Color("#ffd77a"))
		for k in range(3):
			draw_rect(Rect2(x + 5, 326 - h + k * 24, 4, 7), Color("#e3b05e"), true)
			draw_rect(Rect2(x + 13, 326 - h + k * 24, 4, 7), Color("#e3b05e"), true)
	for i in range(tower_x.size() - 1):
		draw_line(Vector2(tower_x[i] + 10, 300 - tower_h[i] * 0.55), Vector2(tower_x[i + 1] + 10, 300 - tower_h[i + 1] * 0.52), Color(1.0, 0.75, 0.34, 0.72), 2.0)

func _draw_river_and_bridge() -> void:
	for y in range(355, 450, 5):
		var t := float(y - 355) / 95.0
		draw_rect(Rect2(570, y, 710, 6), Color("#43445d").lerp(Color("#2b344b"), t), true)
	for i in range(18):
		var yy := 360.0 + i * 5.2
		var span := 145.0 - i * 3.5
		draw_line(Vector2(900 - span * 0.5, yy), Vector2(900 + span * 0.5, yy), Color(1.0, 0.64, 0.30, 0.18 + i * 0.015), 2.0)
	draw_line(Vector2(610, 382), Vector2(1260, 342), Color("#171e2a"), 10.0)
	draw_line(Vector2(610, 390), Vector2(1260, 350), Color("#c39859"), 2.0)
	for x in range(640, 1250, 45):
		var y := 388.0 - (float(x) - 610.0) * 0.0615
		draw_line(Vector2(x, y), Vector2(x, y + 25), Color("#202634"), 4.0)
		draw_circle(Vector2(x, y + 7), 2.5, Color("#ffc765"))

func _draw_far_hillside() -> void:
	for row in range(4):
		for col in range(6):
			var x := 760.0 + col * 92.0 + row * 15.0
			var y := 397.0 + row * 54.0 - col * 6.0
			var w := 74.0
			var h := 52.0
			draw_rect(Rect2(x, y, w, h), Color("#685247").darkened(float(row) * 0.04), true)
			poly([Vector2(x - 4, y), Vector2(x + w * 0.5, y - 25), Vector2(x + w + 7, y)], Color("#342e31"))
			draw_rect(Rect2(x + 12, y + 15, 16, 22), Color("#ffd783"), true)
			draw_rect(Rect2(x + 44, y + 12, 12, 17), Color("#f1b76e"), true)

func _draw_left_block() -> void:
	draw_rect(Rect2(0, 62, 345, 315), Color("#4b433f"), true)
	poly([Vector2(0, 63), Vector2(105, 37), Vector2(350, 70), Vector2(350, 100), Vector2(0, 93)], Color("#29262a"))
	draw_rect(Rect2(0, 118, 340, 14), Color("#2e292a"), true)
	for x in [35, 105, 185, 268]:
		draw_rect(Rect2(x, 86, 32, 48), Color("#f2b56e"), true)
		draw_rect(Rect2(x + 5, 91, 22, 38), Color("#453a3b"), false, 2)
	draw_rect(Rect2(22, 194, 356, 236), Color("#ded0b0"), true)
	draw_rect(Rect2(28, 223, 344, 198), Color("#f2e3bf"), true)
	draw_rect(Rect2(34, 273, 335, 144), Color("#312d2c"), true)
	for i in range(4):
		var x := 39.0 + i * 82.0
		draw_rect(Rect2(x, 281, 72, 125), Color("#f8d88d"), true)
		draw_rect(Rect2(x + 4, 286, 64, 117), Color("#58473b"), false, 3)
		for k in range(4):
			draw_rect(Rect2(x + 8, 301 + k * 24, 54, 7), Color("#f0c56d").darkened(k * 0.04), true)
	draw_rect(Rect2(28, 197, 344, 65), Color("#f2ead6"), true)
	draw_rect(Rect2(28, 197, 344, 10), Color("#f27c34"), true)
	draw_rect(Rect2(28, 249, 344, 10), Color("#35a66f"), true)
	txt(Vector2(72, 239), "새봄편의점", 27, Color("#37526a"), 260)
	for i in range(10):
		draw_rect(Rect2(28 + i * 34.4, 262, 35, 17), Color("#efcf9b") if i % 2 == 0 else Color("#4e7f6b"), true)
	draw_rect(Rect2(378, 150, 110, 305), Color("#786653"), true)
	for i in range(10):
		_flower_cluster(Vector2(396 + (i % 3) * 26, 175 + i * 27), 0.75)
	draw_rect(Rect2(422, 148, 86, 110), Color("#8c7a5e"), true)
	txt(Vector2(427, 184), "달빛골목", 15, Color("#3b3027"), 75)

func _draw_center_block() -> void:
	draw_rect(Rect2(505, 72, 205, 322), Color("#554b43"), true)
	poly([Vector2(500, 74), Vector2(590, 42), Vector2(715, 72), Vector2(715, 92), Vector2(500, 99)], Color("#2e2b2d"))
	for i in range(5):
		var x := 523.0 + (i % 2) * 82.0
		var y := 105.0 + int(i / 2) * 76.0
		draw_rect(Rect2(x, y, 45, 52), Color("#ebb471"), true)
		draw_rect(Rect2(x + 6, y + 6, 33, 40), Color("#5b4a40"), false, 3)
	draw_rect(Rect2(654, 282, 272, 205), Color("#876448"), true)
	draw_rect(Rect2(666, 326, 250, 148), Color("#5b4437"), true)
	draw_rect(Rect2(682, 338, 78, 126), Color("#f4c672"), true)
	draw_rect(Rect2(774, 338, 128, 126), Color("#edb969"), true)
	draw_rect(Rect2(660, 274, 266, 51), Color("#c8a56f"), true)
	draw_rect(Rect2(668, 282, 250, 34), Color("#b99763"), false, 3)
	txt(Vector2(695, 307), "복례분식", 25, Color("#57392c"), 200)
	poly([Vector2(660, 325), Vector2(927, 325), Vector2(910, 349), Vector2(677, 349)], Color("#9f412f"))
	for i in range(9):
		draw_line(Vector2(678 + i * 28, 329), Vector2(690 + i * 25, 346), Color("#d27756"), 3)
	for i in range(5):
		draw_rect(Rect2(688 + i * 40, 365, 25, 12), Color("#7b4730"), true)
		draw_circle(Vector2(702 + i * 40, 391), 6, Color("#ffd17e"))
	draw_rect(Rect2(692, 418, 203, 8), Color("#4f3329"), true)
	draw_rect(Rect2(642, 474, 234, 12), Color("#553b2e"), true)
	for x in [665, 734, 810]:
		draw_line(Vector2(x, 486), Vector2(x - 7, 523), Color("#3e3029"), 5)
		draw_line(Vector2(x + 36, 486), Vector2(x + 43, 523), Color("#3e3029"), 5)

func _draw_right_block() -> void:
	poly([Vector2(1000, 93), Vector2(1280, 110), Vector2(1280, 604), Vector2(1010, 570)], Color("#55473e"))
	poly([Vector2(1002, 93), Vector2(1135, 48), Vector2(1280, 87), Vector2(1280, 119), Vector2(1000, 119)], Color("#2e2828"))
	draw_rect(Rect2(1048, 315, 215, 175), Color("#9a7453"), true)
	draw_rect(Rect2(1060, 350, 194, 128), Color("#5a4438"), true)
	draw_rect(Rect2(1080, 359, 67, 111), Color("#f2c275"), true)
	draw_rect(Rect2(1160, 359, 77, 111), Color("#e8b668"), true)
	draw_rect(Rect2(1056, 311, 202, 42), Color("#c79b69"), true)
	txt(Vector2(1075, 340), "청춘슈퍼", 21, Color("#6d3d31"), 160)
	poly([Vector2(1054, 352), Vector2(1260, 352), Vector2(1247, 371), Vector2(1068, 371)], Color("#a34533"))
	for i in range(12):
		var p := Vector2(1020 + (i % 4) * 54, 115 + int(i / 4) * 46)
		_flower_cluster(p, 0.65)

func _draw_stairs() -> void:
	var center := 551.0
	for i in range(11):
		var y := 336.0 + i * 34.0
		var half := 76.0 + i * 12.0
		var c := Color("#9b8064").lightened(float(i) * 0.01)
		poly([Vector2(center - half, y), Vector2(center + half, y), Vector2(center + half + 8, y + 25), Vector2(center - half - 8, y + 25)], c)
		draw_line(Vector2(center - half - 8, y + 25), Vector2(center + half + 8, y + 25), Color("#5f4a3b"), 3)
	poly([Vector2(397, 319), Vector2(466, 342), Vector2(410, 695), Vector2(292, 720), Vector2(292, 407)], Color("#6d5c4c"))
	poly([Vector2(639, 337), Vector2(700, 352), Vector2(843, 720), Vector2(744, 720)], Color("#6a594a"))
	draw_line(Vector2(416, 344), Vector2(333, 694), Color("#242526"), 7)
	draw_line(Vector2(433, 352), Vector2(354, 694), Color("#c18b53"), 2)
	for i in range(7):
		var t := float(i) / 6.0
		var p := Vector2(416, 344).lerp(Vector2(333, 694), t)
		draw_line(p, p + Vector2(0, 48), Color("#242526"), 5)
	draw_line(Vector2(671, 362), Vector2(803, 700), Color("#262728"), 7)
	for i in range(7):
		var t := float(i) / 6.0
		var p := Vector2(671, 362).lerp(Vector2(803, 700), t)
		draw_line(p, p + Vector2(0, 46), Color("#262728"), 5)

func _draw_street_details() -> void:
	for x in [486.0, 975.0, 1217.0]:
		draw_line(Vector2(x, 50), Vector2(x, 470), Color("#393033"), 8)
		draw_line(Vector2(x - 7, 92), Vector2(x + 35, 92), Color("#393033"), 5)
	draw_bezier(Vector2(120, 62), Vector2(390, 120), Vector2(676, 30), Vector2(1008, 94), Color("#332a2d"), 3)
	draw_bezier(Vector2(274, 40), Vector2(506, 116), Vector2(870, 45), Vector2(1260, 92), Color("#332a2d"), 2)
	draw_bezier(Vector2(475, 108), Vector2(725, 126), Vector2(968, 88), Vector2(1264, 153), Color("#4a3432"), 2)
	_lamp(Vector2(498, 170), 1.0)
	_lamp(Vector2(943, 236), 0.82)
	_lamp(Vector2(1002, 442), 0.74)
	_lamp(Vector2(1251, 265), 0.9)
	draw_rect(Rect2(475, 212, 93, 33), Color("#46392f"), true)
	txt(Vector2(481, 236), "달빛골목 →", 13, Color("#e3d0aa"), 80)
	draw_rect(Rect2(472, 250, 99, 34), Color("#473a31"), true)
	txt(Vector2(478, 274), "전망대 →", 13, Color("#e3d0aa"), 86)
	draw_rect(Rect2(84, 420, 58, 44), Color("#3d6770"), true)
	draw_rect(Rect2(147, 431, 41, 34), Color("#326178"), true)
	draw_rect(Rect2(188, 426, 32, 49), Color("#617881"), true)
	for p in [Vector2(70, 463), Vector2(116, 478), Vector2(210, 474), Vector2(375, 483), Vector2(895, 520)]:
		_flower_pot(p)

func _draw_foreground() -> void:
	poly([Vector2(0, 554), Vector2(295, 514), Vector2(399, 720), Vector2(0, 720)], Color("#594539"))
	poly([Vector2(844, 546), Vector2(1280, 486), Vector2(1280, 720), Vector2(833, 720)], Color("#4b3b34"))
	draw_line(Vector2(0, 615), Vector2(326, 570), Color("#1f2425"), 9)
	for x in range(24, 328, 48):
		var y := 612.0 - float(x) * 0.14
		draw_line(Vector2(x, y), Vector2(x, y + 86), Color("#1f2425"), 7)
	for i in range(16):
		_flower_cluster(Vector2(18 + (i % 5) * 55, 626 + int(i / 5) * 40), 1.05)
	for i in range(14):
		_flower_cluster(Vector2(930 + (i % 5) * 70, 595 + int(i / 5) * 46), 0.9)
	for p in [Vector2(57, 565), Vector2(262, 605), Vector2(903, 554), Vector2(1130, 586)]:
		draw_circle(p, 38, Color(1.0, 0.61, 0.27, 0.055))

func _flower_pot(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 14, p.y, 28, 18), Color("#8c563b"), true)
	_flower_cluster(p + Vector2(0, -7), 0.65)

func _flower_cluster(p: Vector2, scale: float) -> void:
	draw_circle(p, 11 * scale, Color("#314d31"))
	draw_circle(p + Vector2(-8, 2) * scale, 8 * scale, Color("#355837"))
	draw_circle(p + Vector2(8, 3) * scale, 8 * scale, Color("#3c5e39"))
	var colors := [Color("#e85a73"), Color("#f39a64"), Color("#e8c16a"), Color("#cf7294")]
	for i in range(4):
		var a := float(i) * 1.57
		draw_circle(p + Vector2(cos(a), sin(a)) * 9.0 * scale, 3.7 * scale, colors[i])

func _lamp(p: Vector2, scale: float) -> void:
	draw_line(p, p + Vector2(0, 80) * scale, Color("#252527"), 5 * scale)
	draw_line(p, p + Vector2(27, 0) * scale, Color("#252527"), 4 * scale)
	draw_circle(p + Vector2(28, 8) * scale, 22 * scale, Color(1.0, 0.63, 0.25, 0.10))
	draw_circle(p + Vector2(28, 8) * scale, 8 * scale, Color("#ffd17d"))
	draw_line(p + Vector2(20, -4) * scale, p + Vector2(35, -4) * scale, Color("#332b28"), 5 * scale)

func draw_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var omt := 1.0 - t
		var p := a * omt * omt * omt + b * 3.0 * omt * omt * t + c * 3.0 * omt * t * t + d * t * t * t
		pts.append(p)
	draw_polyline(pts, color, width, true)
