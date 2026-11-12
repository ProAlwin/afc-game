extends Control

var tutorial_step: int = 0
var shop_level: int = 0
var chickens: int = 2
var portions: int = 0
var workers: int = 0
var player_position := Vector2(0.46, 0.665)
var player_walking: bool = false
var player_inside: bool = false
var player_scale: float = 1.0
var ceremony_elapsed: float = 0.0
var animation_time: float = 0.0
var celebration: float = 0.0
var mission_kind: String = ""
var mission_fraction: float = 0.0
var toast: String = ""

const GRASS := Color("90b96c")
const GRASS_LIGHT := Color("a8c777")
const GRASS_DARK := Color("739d58")
const INK := Color("2d463a")
const RED := Color("d6533e")
const CREAM := Color("fff2d7")
const WOOD := Color("8f6040")

func _process(delta: float) -> void:
	animation_time += delta
	if celebration > 0.0:
		celebration = maxf(0.0, celebration - delta)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	_draw_world_ground(w, h)
	_draw_path(w, h)
	_draw_bushes_and_flowers(w, h)
	_draw_coop(w, h)
	_draw_kitchen(w, h)
	_draw_shop(w, h)
	_draw_chickens(w, h)
	_draw_customers(w, h)
	_draw_player(w, h)
	_draw_target_marker(w, h)
	_draw_status_sparkles(w, h)

func _draw_world_ground(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GRASS)
	# Soft, irregular patches break up the lawn without turning it into a flat map.
	for i in range(38):
		var px := float((i * 73 + 41) % 997) / 997.0 * w
		var py := h * 0.12 + float((i * 131 + 19) % 809) / 997.0 * h * 0.66
		var radius := h * (0.012 + float(i % 4) * 0.003)
		var color := GRASS_LIGHT if i % 3 == 0 else GRASS_DARK
		draw_circle(Vector2(px, py), radius, Color(color.r, color.g, color.b, 0.12))
	# Little grass marks add a hand-painted texture across the playable clearing.
	for i in range(64):
		var gx := float((i * 151 + 23) % 991) / 991.0 * w
		var gy := h * 0.14 + float((i * 227 + 57) % 733) / 991.0 * h * 0.65
		if gy > h * 0.48 and gx > w * 0.14 and gx < w * 0.86:
			continue
		var blade := h * 0.008
		draw_line(Vector2(gx - blade, gy + blade), Vector2(gx, gy - blade), Color("587f49"), maxf(1.0, h * 0.003))
		draw_line(Vector2(gx, gy - blade), Vector2(gx + blade, gy + blade), Color("587f49"), maxf(1.0, h * 0.003))

func _draw_path(w: float, h: float) -> void:
	var lane := PackedVector2Array([
		Vector2(w * 0.37, h * 0.43), Vector2(w * 0.63, h * 0.43),
		Vector2(w * 0.61, h * 0.58), Vector2(w * 0.77, h * 0.70),
		Vector2(w * 0.70, h * 0.77), Vector2(w * 0.52, h * 0.64),
		Vector2(w * 0.28, h * 0.77), Vector2(w * 0.21, h * 0.70),
		Vector2(w * 0.41, h * 0.57)
	])
	draw_colored_polygon(lane, Color("d9c394"))
	draw_polyline(PackedVector2Array([lane[0], lane[8], lane[7], lane[6]]), Color("c3ad7c"), maxf(1.0, h * 0.004), true)
	draw_polyline(PackedVector2Array([lane[1], lane[2], lane[3], lane[4]]), Color("c3ad7c"), maxf(1.0, h * 0.004), true)
	for i in range(9):
		var t := float(i) / 8.0
		var stone_x := lerpf(w * 0.5, w * 0.5 + sin(t * PI * 1.3) * w * 0.14, t)
		var stone_y := lerpf(h * 0.48, h * 0.72, t)
		draw_ellipse(Vector2(stone_x, stone_y), Vector2(w * 0.023, h * 0.009), Color("e8d4aa"))

func _draw_bushes_and_flowers(w: float, h: float) -> void:
	for i in range(9):
		var x := w * (0.07 + float(i) * 0.108)
		var y := h * (0.19 + float((i * 7) % 3) * 0.018)
		if x > w * 0.19 and x < w * 0.81:
			continue
		draw_ellipse(Vector2(x, y + h * 0.018), Vector2(w * 0.038, h * 0.025), Color("557c48"))
		draw_circle(Vector2(x - w * 0.016, y), h * 0.021, Color("719a55"))
		draw_circle(Vector2(x + w * 0.011, y - h * 0.006), h * 0.025, Color("82a95e"))
	for i in range(14):
		var x := w * (0.04 + float((i * 139) % 907) / 907.0 * 0.92)
		var y := h * (0.23 + float((i * 73) % 531) / 997.0 * 0.53)
		if absf(x - w * 0.5) < w * 0.30 and y < h * 0.54:
			continue
		var petal := Color("fff0c3") if i % 2 == 0 else Color("edaf76")
		draw_circle(Vector2(x, y), h * 0.006, petal)
		draw_circle(Vector2(x + h * 0.006, y), h * 0.006, petal)
		draw_circle(Vector2(x + h * 0.003, y + h * 0.005), h * 0.004, Color("e2ae51"))

func _draw_coop(w: float, h: float) -> void:
	var center := Vector2(w * 0.205, h * 0.645)
	draw_ellipse(center + Vector2(0, h * 0.07), Vector2(w * 0.17, h * 0.10), Color("537645", 0.26))
	# Low timber coop, with open wire and a straw roof.
	var body := PackedVector2Array([
		Vector2(w * 0.075, h * 0.56), Vector2(w * 0.29, h * 0.56),
		Vector2(w * 0.31, h * 0.71), Vector2(w * 0.09, h * 0.71)
	])
	draw_colored_polygon(body, Color("d6a868"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.055, h * 0.57), Vector2(w * 0.16, h * 0.50),
		Vector2(w * 0.32, h * 0.57), Vector2(w * 0.28, h * 0.60),
		Vector2(w * 0.16, h * 0.55), Vector2(w * 0.08, h * 0.61)
	]), Color("b97c45"))
	draw_rect(Rect2(w * 0.11, h * 0.61, w * 0.16, h * 0.075), Color("f3ddb0"))
	for i in range(6):
		var x := w * (0.125 + float(i) * 0.026)
		draw_line(Vector2(x, h * 0.61), Vector2(x, h * 0.685), Color("a58c65"), maxf(1.0, w * 0.003))
	draw_line(Vector2(w * 0.11, h * 0.635), Vector2(w * 0.27, h * 0.635), Color("a58c65"), maxf(1.0, w * 0.003))
	draw_line(Vector2(w * 0.11, h * 0.661), Vector2(w * 0.27, h * 0.661), Color("a58c65"), maxf(1.0, w * 0.003))
	_draw_sign(Rect2(w * 0.13, h * 0.515, w * 0.09, h * 0.032), "COOP", Color("fff0ca"))
	# Feed pan and scattered grain make the coop a visible place to tap.
	draw_ellipse(Vector2(w * 0.285, h * 0.70), Vector2(w * 0.04, h * 0.018), Color("778b50"))
	draw_ellipse(Vector2(w * 0.285, h * 0.694), Vector2(w * 0.03, h * 0.009), Color("d7b968"))
	for i in range(8):
		var gx := w * (0.10 + float(i) * 0.029)
		draw_circle(Vector2(gx, h * (0.72 + float(i % 2) * 0.008)), h * 0.0035, Color("e3bc63"))
	_draw_interaction_glow(Vector2(w * 0.20, h * 0.64), 0.0 if tutorial_step != 3 else 1.0, w, h)

func _draw_kitchen(w: float, h: float) -> void:
	var center := Vector2(w * 0.79, h * 0.65)
	draw_ellipse(center + Vector2(0, h * 0.07), Vector2(w * 0.17, h * 0.095), Color("537645", 0.25))
	# A little outdoor prep counter: tiled top, fryer, baskets, and a striped canopy.
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.65, h * 0.58), Vector2(w * 0.89, h * 0.58),
		Vector2(w * 0.91, h * 0.70), Vector2(w * 0.63, h * 0.70)
	]), Color("b46c44"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.63, h * 0.59), Vector2(w * 0.88, h * 0.57),
		Vector2(w * 0.91, h * 0.60), Vector2(w * 0.65, h * 0.63)
	]), Color("f4dfb5"))
	for i in range(5):
		var x := w * (0.67 + float(i) * 0.043)
		draw_line(Vector2(x, h * 0.595), Vector2(x + w * 0.018, h * 0.605), Color("d7bf90"), maxf(1.0, w * 0.002))
	# Fryer and chopping board are drawn as chunky, readable toy-like props.
	draw_ellipse(Vector2(w * 0.72, h * 0.574), Vector2(w * 0.047, h * 0.027), Color("536b59"))
	draw_ellipse(Vector2(w * 0.72, h * 0.567), Vector2(w * 0.036, h * 0.019), Color("e4a749"))
	draw_arc(Vector2(w * 0.72, h * 0.565), h * 0.025, PI, TAU, 28, Color("fff0c8"), maxf(1.0, h * 0.004))
	draw_rounded_rect(Rect2(w * 0.78, h * 0.55, w * 0.079, h * 0.045), Color("f8e8c5"), h * 0.01)
	draw_line(Vector2(w * 0.79, h * 0.57), Vector2(w * 0.85, h * 0.575), Color("b18b58"), maxf(1.0, w * 0.003))
	_draw_sign(Rect2(w * 0.73, h * 0.515, w * 0.13, h * 0.033), "KITCHEN", Color("fff0ca"))
	_draw_interaction_glow(Vector2(w * 0.78, h * 0.64), 0.0 if tutorial_step != 4 else 1.0, w, h)

func _draw_shop(w: float, h: float) -> void:
	var shop_left := w * 0.185
	var shop_width := w * (0.63 + float(shop_level) * 0.045)
	var wall_top := h * 0.255
	var wall_bottom := h * 0.49
	var shop_center := Vector2(shop_left + shop_width * 0.5, wall_bottom)
	draw_ellipse(Vector2(shop_center.x, wall_bottom + h * 0.035), Vector2(shop_width * 0.56, h * 0.08), Color("526f4a", 0.28))
	# Side wall and stucco facade, with a colored base to give the building depth.
	draw_colored_polygon(PackedVector2Array([
		Vector2(shop_left, wall_top + h * 0.015),
		Vector2(shop_left + shop_width * 0.10, wall_top + h * 0.055),
		Vector2(shop_left + shop_width * 0.10, wall_bottom + h * 0.04),
		Vector2(shop_left, wall_bottom)
	]), Color("e4d1a6"))
	draw_rect(Rect2(shop_left, wall_top, shop_width, wall_bottom - wall_top), Color("fff0cf"))
	draw_rect(Rect2(shop_left, wall_bottom - h * 0.02, shop_width, h * 0.048), Color("d2a76c"))
	# Roof is a distinct bright-red plane with a thick green eave.
	draw_colored_polygon(PackedVector2Array([
		Vector2(shop_left - w * 0.055, wall_top + h * 0.035),
		Vector2(shop_left + shop_width * 0.18, h * 0.13),
		Vector2(shop_left + shop_width * 0.84, h * 0.13),
		Vector2(shop_left + shop_width + w * 0.055, wall_top + h * 0.035),
		Vector2(shop_left + shop_width * 0.92, wall_top + h * 0.085),
		Vector2(shop_left + shop_width * 0.08, wall_top + h * 0.085)
	]), Color("345545"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(shop_left - w * 0.04, wall_top + h * 0.025),
		Vector2(shop_left + shop_width * 0.21, h * 0.145),
		Vector2(shop_left + shop_width * 0.79, h * 0.145),
		Vector2(shop_left + shop_width + w * 0.04, wall_top + h * 0.025),
		Vector2(shop_left + shop_width * 0.92, wall_top + h * 0.075),
		Vector2(shop_left + shop_width * 0.08, wall_top + h * 0.075)
	]), RED)
	# A little chimney puff and roof tiles help the shop read as a place in a game world.
	draw_rect(Rect2(shop_left + shop_width * 0.76, h * 0.14, shop_width * 0.075, h * 0.06), Color("a94736"))
	draw_rect(Rect2(shop_left + shop_width * 0.745, h * 0.132, shop_width * 0.105, h * 0.015), Color("733f37"))
	for i in range(5):
		var x := shop_left + shop_width * (0.27 + float(i) * 0.095)
		draw_line(Vector2(x, h * 0.173), Vector2(x + shop_width * 0.045, h * 0.183), Color("bd4937"), maxf(1.0, h * 0.003))
	# Shop sign.
	draw_rounded_rect(Rect2(shop_left + shop_width * 0.33, wall_top + h * 0.02, shop_width * 0.34, h * 0.065), Color("fff6df"), h * 0.013)
	var title := "FOR SALE" if tutorial_step == 0 else "AFC CHICKEN SHOP"
	var font_size := int(h * (0.027 if tutorial_step == 0 else 0.025))
	draw_string(ThemeDB.fallback_font, Vector2(shop_left + shop_width * 0.36, wall_top + h * 0.064), title, HORIZONTAL_ALIGNMENT_LEFT, shop_width * 0.29, font_size, INK)
	# Front windows with blue glass, reflections, and a warm sill.
	for side in [-1.0, 1.0]:
		var wx := shop_left + shop_width * (0.075 if side < 0 else 0.735)
		draw_rounded_rect(Rect2(wx, wall_top + h * 0.105, shop_width * 0.19, h * 0.115), Color("345545"), h * 0.012)
		draw_rounded_rect(Rect2(wx + w * 0.008, wall_top + h * 0.112, shop_width * 0.17, h * 0.098), Color("89c8c9"), h * 0.008)
		draw_line(Vector2(wx + shop_width * 0.085, wall_top + h * 0.112), Vector2(wx + shop_width * 0.085, wall_top + h * 0.21), Color("fff1d3"), maxf(1.0, w * 0.004))
		draw_line(Vector2(wx + w * 0.008, wall_top + h * 0.16), Vector2(wx + shop_width * 0.18, wall_top + h * 0.16), Color("fff1d3"), maxf(1.0, w * 0.004))
		draw_rect(Rect2(wx - w * 0.003, wall_top + h * 0.212, shop_width * 0.196, h * 0.012), Color("d7a768"))
	# Striped awning creates a strong silhouette at phone scale.
	var awning_y := wall_top + h * 0.23
	draw_rect(Rect2(shop_left - w * 0.025, awning_y, shop_width + w * 0.05, h * 0.055), Color("b64234"))
	for i in range(9):
		if i % 2 == 0:
			var stripe_x := shop_left - w * 0.025 + (shop_width + w * 0.05) * float(i) / 9.0
			draw_rect(Rect2(stripe_x, awning_y, (shop_width + w * 0.05) / 9.0, h * 0.055), Color("fff5df"))
	# Door, warm light, and a deep threshold.
	var door_x := shop_left + shop_width * 0.425
	var door_w := shop_width * 0.15
	var door_y := awning_y + h * 0.02
	var door_h := wall_bottom - door_y
	var door_is_open := tutorial_step >= 3 or (tutorial_step == 2 and ceremony_elapsed >= 1.35)
	if door_is_open:
		draw_rounded_rect(Rect2(door_x, door_y, door_w, door_h), Color("4d3d35"), h * 0.008)
		draw_colored_polygon(PackedVector2Array([
			Vector2(door_x, door_y), Vector2(door_x + door_w * 0.25, door_y + h * 0.01),
			Vector2(door_x + door_w * 0.25, door_y + door_h), Vector2(door_x, door_y + door_h)
		]), Color("a86d48"))
		draw_rect(Rect2(door_x + door_w * 0.25, door_y + door_h * 0.1, door_w * 0.68, door_h * 0.8), Color("f2c874", 0.22))
	else:
		draw_rounded_rect(Rect2(door_x, door_y, door_w, door_h), WOOD, h * 0.008)
		draw_rect(Rect2(door_x + door_w * 0.15, door_y + h * 0.025, door_w * 0.7, door_h * 0.38), Color("d5a06d"))
		draw_rect(Rect2(door_x + door_w * 0.15, door_y + door_h * 0.48, door_w * 0.7, door_h * 0.4), Color("9a6141"))
		draw_circle(Vector2(door_x + door_w * 0.78, door_y + door_h * 0.52), h * 0.006, Color("f4da92"))
	var ribbon_cut := tutorial_step >= 2 and ceremony_elapsed >= 0.65
	if tutorial_step >= 1 and not door_is_open:
		var ribbon_y := door_y + door_h * 0.48
		var mid_x := door_x + door_w * 0.5
		if not ribbon_cut:
			draw_line(Vector2(shop_left + shop_width * 0.1, ribbon_y), Vector2(shop_left + shop_width * 0.9, ribbon_y), RED, h * 0.014)
			draw_line(Vector2(shop_left + shop_width * 0.1, ribbon_y + h * 0.019), Vector2(shop_left + shop_width * 0.9, ribbon_y + h * 0.019), Color("fff1d3"), h * 0.006)
			draw_circle(Vector2(mid_x, ribbon_y + h * 0.008), h * 0.015, Color("e5a84f"))
		elif tutorial_step == 2:
			draw_line(Vector2(shop_left + shop_width * 0.1, ribbon_y), Vector2(mid_x - w * 0.03, ribbon_y), RED, h * 0.014)
			draw_line(Vector2(mid_x + w * 0.03, ribbon_y), Vector2(shop_left + shop_width * 0.9, ribbon_y), RED, h * 0.014)
			var scissors := Vector2(mid_x, ribbon_y - h * 0.01)
			draw_line(scissors + Vector2(-w * 0.026, -h * 0.026), scissors + Vector2(w * 0.026, h * 0.026), Color("fff8e7"), h * 0.007)
			draw_line(scissors + Vector2(w * 0.026, -h * 0.026), scissors + Vector2(-w * 0.026, h * 0.026), Color("fff8e7"), h * 0.007)
			draw_circle(scissors + Vector2(-w * 0.031, -h * 0.026), h * 0.01, Color("e5a84f"))
			draw_circle(scissors + Vector2(w * 0.031, -h * 0.026), h * 0.01, Color("e5a84f"))
	# Window ledges, planter boxes, and green leafy plants.
	for side in [-1.0, 1.0]:
		var px := shop_left + shop_width * (0.075 if side < 0 else 0.735)
		draw_rect(Rect2(px, wall_bottom - h * 0.005, shop_width * 0.19, h * 0.018), WOOD)
		draw_ellipse(Vector2(px + shop_width * 0.095, wall_bottom + h * 0.009), Vector2(shop_width * 0.078, h * 0.018), Color("678b4f"))
		for i in range(4):
			draw_circle(Vector2(px + shop_width * (0.04 + float(i) * 0.04), wall_bottom + h * 0.002), h * 0.013, Color("86ad5b"))
	# A hanging OPEN sign changes when the player enters the shop.
	var open_color := Color("8dc86e") if tutorial_step >= 3 else Color("f3ce7e")
	draw_rounded_rect(Rect2(shop_left + shop_width * 0.605, door_y + h * 0.022, shop_width * 0.09, h * 0.035), open_color, h * 0.009)
	draw_string(ThemeDB.fallback_font, Vector2(shop_left + shop_width * 0.618, door_y + h * 0.047), "OPEN" if tutorial_step >= 3 else "SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.016), INK)

func _draw_chickens(w: float, h: float) -> void:
	var visible_count := mini(maxi(chickens, 2), 7)
	for i in range(visible_count):
		var column := i % 4
		var row := i / 4
		var x := w * (0.105 + float(column) * 0.06)
		var y := h * (0.76 + float(row) * 0.038)
		var wobble := sin(animation_time * 3.4 + float(i) * 1.8) * h * 0.003
		_draw_chicken(Vector2(x, y + wobble), h * (0.046 if i == 0 else 0.038), i)
	if tutorial_step == 3:
		var pulse := 0.5 + 0.5 * sin(animation_time * 5.0)
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.08, h * 0.80), "PEEP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.022), Color(1.0, 0.97, 0.83, pulse))

func _draw_chicken(pos: Vector2, r: float, variant: int) -> void:
	draw_ellipse(pos + Vector2(0, r * 0.42), Vector2(r * 1.1, r * 0.42), Color("526e43", 0.24))
	draw_ellipse(pos, Vector2(r * 0.93, r * 0.69), Color("fff8e8"))
	draw_ellipse(pos + Vector2(-r * 0.38, -r * 0.32), Vector2(r * 0.46, r * 0.43), Color("fffaf0"))
	draw_circle(pos + Vector2(-r * 0.53, -r * 0.77), r * 0.13, RED)
	draw_circle(pos + Vector2(-r * 0.31, -r * 0.8), r * 0.12, Color("e9674b"))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-r, -r * 0.34), pos + Vector2(-r * 1.53, -r * 0.17), pos + Vector2(-r, -r * 0.02)]), Color("e6a54d"))
	draw_circle(pos + Vector2(-r * 0.52, -r * 0.43), r * 0.075, INK)
	draw_circle(pos + Vector2(-r * 0.54, -r * 0.455), r * 0.022, Color("fff8e8"))
	draw_circle(pos + Vector2(r * 0.23, -r * 0.12), r * 0.27, Color("f2eee1"))
	draw_line(pos + Vector2(-r * 0.1, r * 0.55), pos + Vector2(-r * 0.1, r * 0.93), Color("cf8d47"), maxf(1.0, r * 0.1))
	draw_line(pos + Vector2(r * 0.32, r * 0.54), pos + Vector2(r * 0.36, r * 0.91), Color("cf8d47"), maxf(1.0, r * 0.1))
	draw_line(pos + Vector2(-r * 0.24, r * 0.9), pos + Vector2(0, r * 0.9), Color("cf8d47"), maxf(1.0, r * 0.08))
	draw_line(pos + Vector2(r * 0.23, r * 0.89), pos + Vector2(r * 0.48, r * 0.89), Color("cf8d47"), maxf(1.0, r * 0.08))

func _draw_customers(w: float, h: float) -> void:
	if tutorial_step < 5:
		return
	var bob := sin(animation_time * 4.0) * h * 0.004
	var customer_pos := Vector2(w * 0.59, h * 0.645 + bob)
	_draw_person(customer_pos, w, h, Color("597eae"), Color("e6b48b"), 0.8)
	if tutorial_step == 5:
		var bubble := Rect2(w * 0.60, h * 0.57, w * 0.17, h * 0.055)
		draw_rounded_rect(bubble, Color("fff6df"), h * 0.018)
		draw_string(ThemeDB.fallback_font, Vector2(bubble.position.x + w * 0.025, bubble.position.y + h * 0.036), "1 CHICKEN!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.021), INK)
	else:
		draw_circle(customer_pos + Vector2(w * 0.044, -h * 0.13), h * 0.024, Color("f2cb73"))
		draw_string(ThemeDB.fallback_font, customer_pos + Vector2(w * 0.038, -h * 0.121), "$", HORIZONTAL_ALIGNMENT_CENTER, -1, int(h * 0.027), INK)

func _draw_player(w: float, h: float) -> void:
	if player_inside or (tutorial_step == 2 and ceremony_elapsed >= 3.0):
		return
	var pos := Vector2(player_position.x * w, player_position.y * h)
	var bob := sin(animation_time * (13.0 if player_walking else 3.0)) * h * (0.004 if player_walking else 0.0015)
	_draw_person(pos + Vector2(0, bob), w, h, Color("f4f0e4"), Color("a96743"), player_scale)

func _draw_person(pos: Vector2, w: float, h: float, shirt: Color, skin: Color, scale: float) -> void:
	var s := scale
	draw_ellipse(pos + Vector2(0, h * 0.048 * s), Vector2(w * 0.035 * s, h * 0.016 * s), Color("415d3e", 0.27))
	# Feet and legs.
	draw_line(pos + Vector2(-w * 0.011 * s, h * 0.01 * s), pos + Vector2(-w * 0.014 * s, h * 0.043 * s), Color("34483b"), h * 0.009 * s)
	draw_line(pos + Vector2(w * 0.011 * s, h * 0.01 * s), pos + Vector2(w * 0.014 * s, h * 0.043 * s), Color("34483b"), h * 0.009 * s)
	draw_ellipse(pos + Vector2(-w * 0.015 * s, h * 0.047 * s), Vector2(w * 0.014 * s, h * 0.007 * s), Color("293e35"))
	draw_ellipse(pos + Vector2(w * 0.015 * s, h * 0.047 * s), Vector2(w * 0.014 * s, h * 0.007 * s), Color("293e35"))
	# Apron torso, sleeves, arms, head, and cap.
	draw_rounded_rect(Rect2(pos.x - w * 0.027 * s, pos.y - h * 0.045 * s, w * 0.054 * s, h * 0.06 * s), shirt, h * 0.014 * s)
	draw_line(pos + Vector2(-w * 0.023 * s, -h * 0.026 * s), pos + Vector2(-w * 0.04 * s, h * 0.012 * s), skin, h * 0.011 * s)
	draw_line(pos + Vector2(w * 0.023 * s, -h * 0.026 * s), pos + Vector2(w * 0.04 * s, h * 0.012 * s), skin, h * 0.011 * s)
	draw_ellipse(pos + Vector2(0, -h * 0.069 * s), Vector2(w * 0.023 * s, h * 0.026 * s), skin)
	draw_ellipse(pos + Vector2(0, -h * 0.094 * s), Vector2(w * 0.028 * s, h * 0.012 * s), Color("345545"))
	draw_rect(Rect2(pos.x - w * 0.019 * s, pos.y - h * 0.109 * s, w * 0.038 * s, h * 0.012 * s), Color("345545"))
	draw_circle(pos + Vector2(-w * 0.008 * s, -h * 0.07 * s), h * 0.0022 * s, INK)
	draw_circle(pos + Vector2(w * 0.008 * s, -h * 0.07 * s), h * 0.0022 * s, INK)
	draw_line(pos + Vector2(-w * 0.018 * s, h * 0.002 * s), pos + Vector2(-w * 0.016 * s, h * 0.028 * s), Color("34483b"), h * 0.011 * s)
	draw_line(pos + Vector2(w * 0.018 * s, h * 0.002 * s), pos + Vector2(w * 0.016 * s, h * 0.028 * s), Color("34483b"), h * 0.011 * s)

func _draw_target_marker(w: float, h: float) -> void:
	var target := Vector2.ZERO
	if tutorial_step == 1:
		target = Vector2(w * 0.50, h * 0.535)
	elif tutorial_step == 3:
		target = Vector2(w * 0.205, h * 0.645)
	elif tutorial_step == 4:
		target = Vector2(w * 0.78, h * 0.64)
	elif tutorial_step == 5:
		target = Vector2(w * 0.59, h * 0.645)
	if target == Vector2.ZERO or player_walking:
		return
	var pulse := 0.5 + 0.5 * sin(animation_time * 5.0)
	var ring_radius := h * (0.035 + pulse * 0.009)
	draw_arc(target, ring_radius, 0.0, TAU, 48, Color("ffe08a"), h * 0.006)
	draw_arc(target, ring_radius * 1.55, 0.0, TAU, 48, Color(1.0, 0.87, 0.53, 0.32), h * 0.003)
	if tutorial_step == 1 or tutorial_step == 3 or tutorial_step == 4:
		var bob := sin(animation_time * 4.4) * h * 0.012
		var top := target + Vector2(0, -h * 0.115 + bob)
		var tip := target + Vector2(0, -h * 0.048)
		draw_line(top, tip, Color("fff4d6"), h * 0.012)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-w * 0.022, -h * 0.027), tip + Vector2(w * 0.022, -h * 0.027)]), Color("fff4d6"))

func _draw_status_sparkles(w: float, h: float) -> void:
	if celebration <= 0.0:
		return
	for i in range(12):
		var angle := float(i) * TAU / 12.0 + animation_time * 0.6
		var radius := h * (0.03 + (1.0 - celebration) * 0.11)
		var pos := Vector2(w * 0.5, h * 0.49) + Vector2(cos(angle) * radius, sin(angle) * radius * 0.55)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -h * 0.012), pos + Vector2(w * 0.008, 0), pos + Vector2(0, h * 0.012), pos + Vector2(-w * 0.008, 0)]), Color("ffe08a", celebration))

func _draw_interaction_glow(center: Vector2, strength: float, w: float, h: float) -> void:
	if strength <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(animation_time * 5.0)
	draw_ellipse(center + Vector2(0, h * 0.018), Vector2(w * (0.09 + pulse * 0.012), h * 0.035), Color(1.0, 0.88, 0.52, 0.12 + pulse * 0.1))

func _draw_sign(rect: Rect2, text: String, color: Color) -> void:
	draw_rounded_rect(rect, Color("345545"), rect.size.y * 0.24)
	draw_rounded_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2)), color, rect.size.y * 0.2)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + rect.size.x * 0.12, rect.position.y + rect.size.y * 0.7), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.8, int(rect.size.y * 0.52), INK)

func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - 2.0 * r, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - 2.0 * r), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + rect.size - Vector2(r, r), r, color)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := float(i) * TAU / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
