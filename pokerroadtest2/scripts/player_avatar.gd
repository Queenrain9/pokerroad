extends Node2D

# Fixed back-facing player matching the supplied reference.
# This test scene intentionally has no movement or interaction.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, -63), 34, Color(1.0, 0.56, 0.25, 0.075))

	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 25), Vector2(-4, 25), Vector2(-5, 73), Vector2(-18, 73)
	]), Color("#e8b08f"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 25), Vector2(18, 25), Vector2(20, 73), Vector2(7, 73)
	]), Color("#e8b08f"))
	draw_rect(Rect2(-19, 66, 15, 15), Color("#d8d3c7"), true)
	draw_rect(Rect2(7, 66, 15, 15), Color("#d8d3c7"), true)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-23, 77), Vector2(-3, 76), Vector2(2, 88), Vector2(-25, 89)
	]), Color("#b84538"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 76), Vector2(25, 77), Vector2(29, 88), Vector2(3, 89)
	]), Color("#b84538"))
	draw_line(Vector2(-22, 84), Vector2(0, 84), Color("#eee6d5"), 4)
	draw_line(Vector2(6, 84), Vector2(28, 84), Color("#eee6d5"), 4)
	draw_line(Vector2(-17, 76), Vector2(-4, 80), Color("#202124"), 3)
	draw_line(Vector2(8, 80), Vector2(22, 76), Color("#202124"), 3)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-31, 9), Vector2(31, 9), Vector2(26, 33), Vector2(-27, 33)
	]), Color("#17181b"))
	for x in [-19, -7, 7, 19]:
		draw_line(Vector2(x, 12), Vector2(x * 0.9, 30), Color("#373438"), 2)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -47), Vector2(-18, -61), Vector2(18, -61), Vector2(32, -46),
		Vector2(27, 14), Vector2(-28, 14)
	]), Color("#202126"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, -44), Vector2(-45, -27), Vector2(-38, 7), Vector2(-26, 4)
	]), Color("#222329"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(29, -44), Vector2(44, -26), Vector2(37, 7), Vector2(26, 4)
	]), Color("#222329"))
	draw_line(Vector2(-27, -43), Vector2(-38, -15), Color("#523d35"), 2)
	draw_line(Vector2(27, -43), Vector2(38, -15), Color("#523d35"), 2)

	draw_circle(Vector2(-38, 8), 6, Color("#e7ad8d"))
	draw_circle(Vector2(37, 8), 6, Color("#e7ad8d"))
	draw_rect(Rect2(-8, -70, 16, 17), Color("#e6aa88"), true)

	draw_circle(Vector2(0, -88), 28, Color("#2f211f"))
	draw_circle(Vector2(-14, -91), 16, Color("#382522"))
	draw_circle(Vector2(15, -92), 15, Color("#382522"))
	draw_circle(Vector2(3, -119), 15, Color("#2e201e"))
	draw_circle(Vector2(-6, -118), 10, Color("#382522"))
	draw_line(Vector2(-18, -104), Vector2(-27, -92), Color("#4a2d24"), 4)
	draw_line(Vector2(22, -103), Vector2(31, -92), Color("#4a2d24"), 4)
	draw_line(Vector2(15, -119), Vector2(26, -128), Color("#4a2d24"), 3)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-27, -55), Vector2(27, -55), Vector2(31, 4), Vector2(22, 17),
		Vector2(-22, 17), Vector2(-31, 4)
	]), Color("#17191c"))
	draw_polyline(PackedVector2Array([
		Vector2(-27, -55), Vector2(27, -55), Vector2(31, 4), Vector2(22, 17),
		Vector2(-22, 17), Vector2(-31, 4), Vector2(-27, -55)
	]), Color("#7c542f"), 3)
	draw_line(Vector2(-16, -52), Vector2(-24, -15), Color("#8c623c"), 3)
	draw_line(Vector2(16, -52), Vector2(24, -15), Color("#8c623c"), 3)
	draw_rect(Rect2(-20, -28, 40, 29), Color("#202328"), true)
	draw_rect(Rect2(-18, -25, 36, 24), Color("#8c623c"), false, 2)

	draw_circle(Vector2(0, -39), 6, Color("#b68445"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -51), Vector2(-8, -41), Vector2(0, -35), Vector2(8, -41)
	]), Color("#b68445"))
	draw_rect(Rect2(-2, -36, 4, 8), Color("#b68445"), true)

	draw_circle(Vector2(22, -14), 7, Color("#eee3cf"))
	draw_circle(Vector2(18, -23), 4, Color("#eee3cf"))
	draw_circle(Vector2(25, -23), 4, Color("#eee3cf"))
	draw_line(Vector2(22, -7), Vector2(22, 3), Color("#c99663"), 2)
	draw_circle(Vector2(19.5, -15), 1.2, Color("#3b3434"))
	draw_circle(Vector2(24.5, -15), 1.2, Color("#3b3434"))

	draw_circle(Vector2(-25, -4), 4, Color("#bc403d"))
	draw_line(Vector2(-24, -8), Vector2(-20, -17), Color("#c99956"), 2)
