extends Control

signal door_reached
signal tutorial_completed

var shop_level: int = 0
var tutorial_step: int = 0
var owner_x_ratio: float = 0.15
var owner_walking: bool = false
var owner_inside: bool = false
var ceremony_elapsed: float = 0.0
var arrow_time: float = 0.0

func set_tutorial_step(step: int) -> void:
	if step == tutorial_step:
		return
	tutorial_step = step
	if tutorial_step == 2:
		owner_x_ratio = _door_x_ratio()
		owner_walking = false
		owner_inside = false
		ceremony_elapsed = 0.0
	elif tutorial_step >= 3:
		owner_x_ratio = _door_x_ratio()
		owner_inside = true
		owner_walking = false
	queue_redraw()

func _process(delta: float) -> void:
	if tutorial_step == 1:
		arrow_time += delta
		queue_redraw()
	if owner_walking:
		owner_x_ratio = move_toward(owner_x_ratio, _door_x_ratio(), delta * 0.55)
		if owner_x_ratio >= _door_x_ratio() - 0.005:
			owner_walking = false
			tutorial_step = 2
			ceremony_elapsed = 0.0
			door_reached.emit()
		queue_redraw()
	elif tutorial_step == 2:
		ceremony_elapsed += delta
		if ceremony_elapsed >= 3.25:
			tutorial_step = 3
			owner_inside = true
			tutorial_completed.emit()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if tutorial_step != 1 or owner_walking:
		return
	var tapped := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
		point = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		point = event.position
	if not tapped or size.x <= 0.0 or size.y <= 0.0:
		return
	var marker := Vector2(size.x * _door_x_ratio(), size.y * 0.81)
	var normalized_distance := Vector2((point.x - marker.x) / (size.x * 0.15), (point.y - marker.y) / (size.y * 0.19))
	if normalized_distance.length() <= 1.0:
		owner_walking = true
		queue_redraw()
		accept_event()

func _door_x_ratio() -> float:
	return 0.25 + ((0.56 + 0.125) * (0.5 + float(shop_level) * 0.035))

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var sky := Color("c6e4e3")
	var grass := Color("c2cf9a")
	var wall := Color("fff0cf")
	var red := Color("d6533e")
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	draw_circle(Vector2(w * 0.83, h * 0.19), h * 0.09, Color("ffe29a"))
	draw_circle(Vector2(w * 0.13, h * 0.23), h * 0.055, Color("f5fbf5"))
	draw_circle(Vector2(w * 0.18, h * 0.20), h * 0.075, Color("f5fbf5"))
	draw_circle(Vector2(w * 0.23, h * 0.23), h * 0.055, Color("f5fbf5"))
	draw_rect(Rect2(0.0, h * 0.77, w, h * 0.23), grass)
	draw_rect(Rect2(0.0, h * 0.9, w, h * 0.1), Color("dfc9a1"))

	var bx := w * 0.25
	var by := h * 0.25
	var bw := w * 0.5 + float(shop_level) * w * 0.035
	var bh := h * 0.57
	var wall_right := bx + bw
	var extension_count := mini(shop_level, 2)
	if extension_count > 0:
		var wing_w := bw * 0.26
		draw_rect(Rect2(bx - wing_w, by + h * 0.22, wing_w, bh - h * 0.22), Color("f5e5c5"))
		draw_rect(Rect2(bx - wing_w + wing_w * 0.17, by + h * 0.32, wing_w * 0.63, h * 0.17), Color("83c6c2"))
	if extension_count > 1:
		var wing_w := bw * 0.26
		draw_rect(Rect2(wall_right, by + h * 0.22, wing_w, bh - h * 0.22), Color("f5e5c5"))
		draw_rect(Rect2(wall_right + wing_w * 0.18, by + h * 0.32, wing_w * 0.63, h * 0.17), Color("83c6c2"))
	draw_rect(Rect2(bx, by, bw, bh), wall)
	var roof_points := PackedVector2Array([
		Vector2(bx - w * 0.035, by + h * 0.025),
		Vector2(bx + bw * 0.5, by - h * 0.16),
		Vector2(bx + bw + w * 0.035, by + h * 0.025)
	])
	draw_colored_polygon(roof_points, Color("34534a"))
	draw_rect(Rect2(bx + bw * 0.12, by - h * 0.02, bw * 0.76, h * 0.18), red)
	draw_rect(Rect2(bx + bw * 0.12, by + h * 0.03, bw * 0.76, h * 0.085), Color("fff3d9"))
	var sign_font := ThemeDB.fallback_font
	var sign_size := int(h * 0.105)
	var shop_sign := "FOR SALE" if tutorial_step == 0 else "AFC"
	var sign_x := bx + bw * (0.18 if tutorial_step == 0 else 0.29)
	draw_string(sign_font, Vector2(sign_x, by + h * 0.104), shop_sign, HORIZONTAL_ALIGNMENT_LEFT, -1, sign_size, Color("34534a"))

	var awning_y := by + h * 0.22
	draw_rect(Rect2(bx - w * 0.025, awning_y, bw + w * 0.05, h * 0.11), red)
	var stripe_count := 7 + shop_level
	for i in range(stripe_count):
		if i % 2 == 1:
			var stripe_x := bx - w * 0.025 + (bw + w * 0.05) * float(i) / float(stripe_count)
			draw_rect(Rect2(stripe_x, awning_y, (bw + w * 0.05) / float(stripe_count), h * 0.11), Color("fff3d9"))
	draw_rect(Rect2(bx + bw * 0.14, awning_y + h * 0.15, bw * 0.29, h * 0.25), Color("83c6c2"))
	draw_rect(Rect2(bx + bw * 0.19, awning_y + h * 0.2, bw * 0.025, h * 0.2), Color("fff6df"))
	draw_rect(Rect2(bx + bw * 0.14, awning_y + h * 0.285, bw * 0.29, h * 0.025), Color("fff6df"))
	draw_rect(Rect2(bx + bw * 0.56, awning_y + h * 0.15, bw * 0.25, h * 0.42), Color("aa6948"))
	draw_rect(Rect2(bx + bw * 0.585, awning_y + h * 0.18, bw * 0.2, h * 0.39), Color("d6a477"))
	draw_circle(Vector2(bx + bw * 0.755, awning_y + h * 0.39), h * 0.012, Color("ffe5a5"))
	var door_left := bx + bw * 0.56
	var door_right := bx + bw * 0.81
	var ribbon_y := awning_y + h * 0.36
	var ribbon_cut := tutorial_step >= 2 and ceremony_elapsed >= 0.65
	var door_is_open := tutorial_step >= 3 or (tutorial_step == 2 and ceremony_elapsed >= 1.35)
	if door_is_open:
		draw_rect(Rect2(door_left, awning_y + h * 0.15, bw * 0.25, h * 0.42), Color("563d35"))
		var open_door := PackedVector2Array([
			Vector2(door_left, awning_y + h * 0.15),
			Vector2(door_left + bw * 0.055, awning_y + h * 0.18),
			Vector2(door_left + bw * 0.055, awning_y + h * 0.56),
			Vector2(door_left, awning_y + h * 0.57)
		])
		draw_colored_polygon(open_door, Color("aa6948"))
	elif tutorial_step == 2 and ribbon_cut:
		var ribbon_mid := (door_left + door_right) * 0.5
		draw_line(Vector2(door_left, ribbon_y), Vector2(ribbon_mid - w * 0.035, ribbon_y), Color("d6533e"), h * 0.035)
		draw_line(Vector2(ribbon_mid + w * 0.035, ribbon_y), Vector2(door_right, ribbon_y), Color("d6533e"), h * 0.035)
		draw_line(Vector2(door_left, ribbon_y + h * 0.055), Vector2(ribbon_mid - w * 0.035, ribbon_y + h * 0.055), Color("fff3d9"), h * 0.018)
		draw_line(Vector2(ribbon_mid + w * 0.035, ribbon_y + h * 0.055), Vector2(door_right, ribbon_y + h * 0.055), Color("fff3d9"), h * 0.018)
		var scissors_center := Vector2(ribbon_mid, ribbon_y - h * 0.025)
		draw_line(scissors_center + Vector2(-w * 0.035, -h * 0.045), scissors_center + Vector2(w * 0.035, h * 0.045), Color("fffaf0"), h * 0.014)
		draw_line(scissors_center + Vector2(w * 0.035, -h * 0.045), scissors_center + Vector2(-w * 0.035, h * 0.045), Color("fffaf0"), h * 0.014)
		draw_circle(scissors_center + Vector2(-w * 0.045, -h * 0.045), h * 0.018, Color("eaa653"))
		draw_circle(scissors_center + Vector2(w * 0.045, -h * 0.045), h * 0.018, Color("eaa653"))
	elif tutorial_step >= 1 and not ribbon_cut:
		draw_line(Vector2(door_left, ribbon_y), Vector2(door_right, ribbon_y), Color("d6533e"), h * 0.035)
		draw_line(Vector2(door_left, ribbon_y + h * 0.055), Vector2(door_right, ribbon_y + h * 0.055), Color("fff3d9"), h * 0.018)
		draw_circle(Vector2((door_left + door_right) * 0.5, ribbon_y + h * 0.025), h * 0.033, Color("eaa653"))

	# A cheerful shop owner and a hen make the scene read as a game world, not a dashboard.
	var owner_x := w * owner_x_ratio
	var owner_y := h * 0.61
	var owner_scale := 1.0
	if tutorial_step == 2 and ceremony_elapsed > 1.8:
		var entry_progress := clampf((ceremony_elapsed - 1.8) / 1.3, 0.0, 1.0)
		owner_x = lerpf(owner_x, w * _door_x_ratio(), entry_progress)
		owner_scale = lerpf(1.0, 0.15, entry_progress)
	if not owner_inside:
		_draw_owner(owner_x, owner_y, w, h, owner_scale)
	# Employees appear beside the owner as they join the crew.
	for employee_index in range(mini(shop_level + 1, 1 + int(shop_level > 0))):
		var staff_x := w * (0.27 + float(employee_index) * 0.095)
		var staff_y := h * 0.65
		draw_circle(Vector2(staff_x, staff_y - h * 0.06), h * 0.038, Color("b8794e"))
		draw_rect(Rect2(staff_x - w * 0.026, staff_y - h * 0.022, w * 0.052, h * 0.11), Color("d6533e"))
	draw_circle(Vector2(w * 0.87, h * 0.72), h * 0.035, Color("fffdf2"))
	draw_circle(Vector2(w * 0.9, h * 0.72), h * 0.035, Color("fffdf2"))
	draw_circle(Vector2(w * 0.885, h * 0.68), h * 0.042, Color("f1c849"))
	draw_circle(Vector2(w * 0.9, h * 0.674), h * 0.006, Color("3b3b32"))
	var beak := PackedVector2Array([Vector2(w * 0.92, h * 0.685), Vector2(w * 0.95, h * 0.697), Vector2(w * 0.92, h * 0.706)])
	draw_colored_polygon(beak, red)

	var caption := "A LITTLE ROADSIDE STALL" if shop_level == 0 else ("YOUR BUSY CHICKEN CAFE" if shop_level == 1 else "THE NEIGHBOURHOOD FAVOURITE")
	draw_string(sign_font, Vector2(w * 0.045, h * 0.91), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.048), Color("40534a"))
	if tutorial_step == 1 and not owner_walking:
		var marker := Vector2(w * _door_x_ratio(), h * 0.81)
		var bob := sin(arrow_time * 4.5) * h * 0.018
		draw_arc(marker, h * 0.075, 0.0, TAU, 40, Color("eaa653"), h * 0.018)
		draw_arc(marker, h * 0.12, 0.0, TAU, 40, Color(0.918, 0.651, 0.325, 0.35), h * 0.012)
		var arrow_top := marker - Vector2(0, h * 0.31) + Vector2(0, bob)
		var arrow_tip := marker - Vector2(0, h * 0.13)
		draw_line(arrow_top, arrow_tip, Color("345545"), h * 0.028)
		var arrow_head := PackedVector2Array([
			arrow_tip,
			arrow_tip + Vector2(-w * 0.045, -h * 0.075),
			arrow_tip + Vector2(w * 0.045, -h * 0.075)
		])
		draw_colored_polygon(arrow_head, Color("345545"))

func _draw_owner(owner_x: float, owner_y: float, w: float, h: float, scale: float) -> void:
	var center := Vector2(owner_x, owner_y)
	draw_circle(center + Vector2(0, -h * 0.11 * scale), h * 0.06 * scale, Color("9f633f"))
	draw_rect(Rect2(center.x - w * 0.035 * scale, center.y - h * 0.055 * scale, w * 0.07 * scale, h * 0.17 * scale), Color("f4f0e4"))
	draw_rect(Rect2(center.x - w * 0.038 * scale, center.y - h * 0.115 * scale, w * 0.076 * scale, h * 0.025 * scale), Color("34534a"))
	draw_rect(Rect2(center.x - w * 0.065 * scale, center.y + h * 0.09 * scale, w * 0.035 * scale, h * 0.11 * scale), Color("34534a"))
	draw_rect(Rect2(center.x + w * 0.03 * scale, center.y + h * 0.09 * scale, w * 0.035 * scale, h * 0.11 * scale), Color("34534a"))
