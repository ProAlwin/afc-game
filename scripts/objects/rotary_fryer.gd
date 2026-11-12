extends Node3D

const MAX_LEVEL := 10

var level := 1
var cook_timer := 0.0
var shake_time := 0.0
var home_position := Vector3.ZERO
var spinner: Node3D
var raw_chicken_visual: Node3D
var fryer_oil_visual: Node3D
var oil_bubbles: Array[MeshInstance3D] = []
var level_label: Label3D
var speed_label: Label3D
var output_table: Node3D
var conveyor_food: Array[Dictionary] = []

func build(start_position: Vector3) -> void:
	name = "AFC integrated rotary fryer station"
	position = start_position
	home_position = start_position
	_build_cooker()
	_build_conveyor()
	_register_level_label()

func set_level(new_level: int) -> void:
	level = clampi(new_level, 1, MAX_LEVEL)
	if level_label:
		level_label.text = "ROTARY FRYER • LV.%d" % level
	if speed_label:
		speed_label.text = "%d PIECE / SECOND" % level

func advance(delta: float, available_raw: int, elapsed_time: float) -> int:
	if spinner:
		spinner.rotate_z(delta * (3.8 if available_raw > 0 else 0.65))
		spinner.position.y = 0.92 + sin(elapsed_time * 5.0) * 0.022
	if raw_chicken_visual:
		raw_chicken_visual.visible = available_raw > 0
	if fryer_oil_visual:
		fryer_oil_visual.visible = available_raw > 0
	for index in range(oil_bubbles.size()):
		var bubble := oil_bubbles[index]
		if is_instance_valid(bubble):
			bubble.visible = available_raw > 0
			bubble.position.y = -0.13 + sin(elapsed_time * 7.0 + float(index) * 1.7) * 0.035
			bubble.scale.y = 0.65 + absf(sin(elapsed_time * 5.0 + float(index))) * 0.55
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		var shake := sin(elapsed_time * 72.0) * 0.055 * (shake_time / 0.30)
		position = home_position + Vector3(shake, 0.0, -shake * 0.35)
	elif position != home_position:
		position = home_position

	var cooked := 0
	if available_raw > 0:
		cook_timer += delta * float(level)
		while cook_timer >= 1.0 and cooked < available_raw:
			cook_timer -= 1.0
			cooked += 1
			shake_time = 0.30
			_spawn_conveyor_chicken()
		if cooked >= available_raw:
			cook_timer = 0.0
	for item_data in conveyor_food:
		var food: Node3D = item_data["node"]
		if not is_instance_valid(food):
			continue
		var landing: Vector3 = item_data["landing"]
		food.global_position = food.global_position.move_toward(landing, delta * 3.8)
		food.rotate_y(delta * 5.5)
		if food.global_position.distance_to(landing) < 0.08:
			food.global_position = landing
	return cooked

func get_output_table() -> Node3D:
	return output_table

func remove_cooked_food(count: int) -> void:
	var remove_count := mini(count, conveyor_food.size())
	for index in range(remove_count):
		var food: Node3D = conveyor_food[0]["node"]
		if is_instance_valid(food):
			food.queue_free()
		conveyor_food.remove_at(0)

func _build_cooker() -> void:
	_add_box("Premium fryer dark plinth", Vector3(0, 0.30, 0), Vector3(3.15, 0.42, 2.28), Color("282e31"), 0.14, 0.42)
	for x in [-1.28, 1.28]:
		for z in [-0.72, 0.72]:
			_add_cylinder("Fryer adjustable foot", Vector3(x, 0.12, z), Vector3(0.11, 0.13, 0.25), Color("202427"), 0.68, 0.34)
	_add_cylinder("Brushed steel rotary drum", Vector3(-0.20, 1.65, 0), Vector3(1.12, 1.12, 2.35), Color("aab5ba"), 0.72, 0.28)
	_add_cylinder("AFC red upper drum collar", Vector3(-0.20, 2.68, 0), Vector3(1.20, 1.20, 0.34), Color("d92f25"), 0.12, 0.35)
	_add_cylinder("Dark lower drum collar", Vector3(-0.20, 0.64, 0), Vector3(1.17, 1.17, 0.26), Color("972a25"), 0.18, 0.4)
	_add_cylinder("Round front loading hatch frame", Vector3(-0.20, 1.62, 1.14), Vector3(0.68, 0.68, 0.10), Color("30393d"), 0.68, 0.3, Vector3(PI * 0.5, 0, 0))
	_add_cylinder("Round glowing cooker hatch", Vector3(-0.20, 1.62, 1.21), Vector3(0.54, 0.54, 0.06), Color("e9892c"), 0.12, 0.28, Vector3(PI * 0.5, 0, 0))
	_add_cylinder("Hatch steel handle", Vector3(-0.20, 1.18, 1.28), Vector3(0.05, 0.05, 0.35), Color("59656a"), 0.68, 0.32, Vector3(0, 0, PI * 0.5))
	_add_box("Fryer digital control console", Vector3(1.18, 1.42, 0.68), Vector3(0.64, 1.35, 0.60), Color("303a3e"), 0.09, 0.4)
	_add_box("Fryer green timer display", Vector3(1.18, 1.75, 1.00), Vector3(0.39, 0.20, 0.025), Color("85da71"), 0.02, 0.25)
	_add_label("01:00", Vector3(1.18, 1.74, 1.03), 0.055, Color("173c24"))
	for y in [1.38, 1.14]:
		_add_cylinder("Fryer red control button", Vector3(1.04, y, 1.00), Vector3(0.050, 0.050, 0.024), Color("d92f25"), 0.1, 0.3, Vector3(PI * 0.5, 0, 0))
		_add_cylinder("Fryer gold control button", Vector3(1.32, y, 1.00), Vector3(0.050, 0.050, 0.024), Color("efbd41"), 0.45, 0.28, Vector3(PI * 0.5, 0, 0))
	_add_cylinder("Fryer exhaust vent", Vector3(-0.20, 3.12, 0), Vector3(0.19, 0.24, 0.72), Color("59656a"), 0.72, 0.33)

	spinner = Node3D.new()
	spinner.name = "Attached rotary chicken mill"
	spinner.position = Vector3(1.75, 0.92, 0.0)
	add_child(spinner)
	var mill_drum_mesh := CylinderMesh.new()
	mill_drum_mesh.top_radius = 1.0
	mill_drum_mesh.bottom_radius = 1.0
	mill_drum_mesh.height = 1.0
	mill_drum_mesh.radial_segments = 24
	mill_drum_mesh.cap_top = false
	mill_drum_mesh.cap_bottom = false
	var mill_drum := MeshInstance3D.new()
	mill_drum.name = "Open-sided mill steel drum"
	mill_drum.mesh = mill_drum_mesh
	mill_drum.scale = Vector3(0.48, 0.48, 0.76)
	mill_drum.rotation = Vector3(PI * 0.5, 0, 0)
	mill_drum.material_override = _material(Color("566267"), 0.72, 0.3)
	spinner.add_child(mill_drum)
	var front_rim_mesh := TorusMesh.new()
	front_rim_mesh.inner_radius = 0.34
	front_rim_mesh.outer_radius = 0.50
	front_rim_mesh.rings = 24
	front_rim_mesh.ring_segments = 8
	var front_rim := MeshInstance3D.new()
	front_rim.name = "Mill red open front rim"
	front_rim.mesh = front_rim_mesh
	front_rim.position = Vector3(0, 0, 0.40)
	front_rim.material_override = _material(Color("d92f25"), 0.14, 0.32)
	spinner.add_child(front_rim)
	var front_window := _add_cylinder_to(spinner, "Clear amber-tinted fryer viewing window", Vector3(0, 0, 0.40), Vector3(0.34, 0.34, 0.018), Color("f6c55b"), 0.12, 0.24, Vector3(PI * 0.5, 0, 0))
	var window_material := front_window.material_override as StandardMaterial3D
	window_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_material.albedo_color.a = 0.18
	window_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	fryer_oil_visual = Node3D.new()
	fryer_oil_visual.name = "Visible hot frying oil in rotary mill"
	spinner.add_child(fryer_oil_visual)
	_add_sphere_to(fryer_oil_visual, "Golden hot oil pool", Vector3(0.0, -0.17, 0.26), Vector3(0.34, 0.11, 0.06), Color("f0a52e"))
	_add_sphere_to(fryer_oil_visual, "Oil surface highlight", Vector3(0.0, -0.115, 0.30), Vector3(0.25, 0.025, 0.025), Color("ffd66b"))
	for index in range(5):
		var bubble := _add_sphere_to(
			fryer_oil_visual,
			"Hot oil bubble",
			Vector3(-0.19 + float(index) * 0.095, -0.13, 0.31),
			Vector3(0.035, 0.045, 0.025),
			Color("ffe39a")
		)
		oil_bubbles.append(bubble)
	raw_chicken_visual = Node3D.new()
	raw_chicken_visual.name = "Chicken pieces frying inside rotating oil mill"
	spinner.add_child(raw_chicken_visual)
	for index in range(4):
		var angle := float(index) * TAU / 4.0
		var meat := Vector3(cos(angle) * 0.17, sin(angle) * 0.17, 0.25)
		_add_sphere_to(raw_chicken_visual, "Golden chicken frying in hot oil", meat, Vector3(0.15, 0.105, 0.09), Color("d9822b"))
		_add_sphere_to(raw_chicken_visual, "Crispy chicken coating highlight", meat + Vector3(-0.02, 0.055, 0.055), Vector3(0.075, 0.035, 0.035), Color("f4bd55"))
	_add_label("ROTARY MILL", Vector3(1.85, 1.68, 0.53), 0.10, Color("fff5e6"))
	level_label = _add_label("", Vector3(-0.20, 2.70, 1.38), 0.12, Color("fff5e6"))
	speed_label = _add_label("", Vector3(-0.20, 0.77, 1.40), 0.08, Color("ffe4a5"))

func _register_level_label() -> void:
	set_level(level)

func _build_conveyor() -> void:
	var belt := Node3D.new()
	belt.name = "Integrated fryer-to-mill conveyor"
	belt.position = Vector3(2.55, 0.0, 0.0)
	add_child(belt)
	_add_box_to(belt, "Conveyor steel support", Vector3(0, 0.34, 0), Vector3(5.8, 0.22, 1.25), Color("606d70"), 0.08, 0.35)
	_add_box_to(belt, "Conveyor black moving belt", Vector3(0, 0.50, 0), Vector3(5.55, 0.12, 1.02), Color("252b2e"), 0.05, 0.52)
	for x in [-2.35, -1.55, -0.75, 0.05, 0.85, 1.65, 2.35]:
		_add_box_to(belt, "Conveyor belt stripe", Vector3(x, 0.575, 0), Vector3(0.10, 0.018, 0.94), Color("889497"), 0.0, 0.35)
	for x in [-2.45, 2.45]:
		for z in [-0.44, 0.44]:
			_add_box_to(belt, "Conveyor leg", Vector3(x, -0.10, z), Vector3(0.12, 0.72, 0.12), Color("4a5559"), 0.03, 0.45)

	output_table = Node3D.new()
	output_table.name = "Integrated fried chicken collection tray"
	output_table.position = Vector3(5.70, 0.18, 0.0)
	add_child(output_table)
	_add_box_to(output_table, "Landing table legs", Vector3(0, 0.52, 0), Vector3(1.65, 0.95, 1.50), Color("555e61"), 0.08, 0.45)
	_add_box_to(output_table, "Landing table steel top", Vector3(0, 1.05, 0), Vector3(2.05, 0.16, 1.85), Color("dbe2df"), 0.10, 0.3)
	_add_box_to(output_table, "Landing table AFC tray", Vector3(0, 1.16, 0), Vector3(1.62, 0.08, 1.38), Color("566166"), 0.06, 0.4)
	_add_label_to(output_table, "FRIED CHICKEN", Vector3(0, 1.18, 0.95), 0.10, Color("d92f25"))

func _spawn_conveyor_chicken() -> void:
	var food := Node3D.new()
	food.name = "Fresh fried chicken on conveyor"
	get_parent().add_child(food)
	food.global_position = global_position + Vector3(2.78, 1.78, 0.0)
	_add_sphere_to(food, "Golden fried chicken", Vector3.ZERO, Vector3(0.33, 0.19, 0.26), Color("d87924"))
	_add_sphere_to(food, "Chicken drumstick", Vector3(0.22, -0.035, 0.02), Vector3(0.12, 0.13, 0.12), Color("e99a36"))
	var landing_number := conveyor_food.size() % 8
	var landing := output_table.global_position + Vector3(-0.60 + float(landing_number % 3) * 0.54, 1.25 + float(landing_number / 3) * 0.10, -0.40 + float(landing_number / 3) * 0.42)
	conveyor_food.append({"node": food, "landing": landing})

func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.5) -> MeshInstance3D:
	return _add_box_to(self, node_name, position, size, color, metallic, roughness)

func _add_box_to(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.5) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position
	instance.material_override = _material(color, metallic, roughness)
	parent.add_child(instance)
	return instance

func _add_cylinder(node_name: String, position: Vector3, dimensions: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.5, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add_cylinder_to(self, node_name, position, dimensions, color, metallic, roughness, rotation)

func _add_cylinder_to(parent: Node3D, node_name: String, position: Vector3, dimensions: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.5, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 24
	instance.mesh = cylinder
	instance.position = position
	instance.scale = dimensions
	instance.rotation = rotation
	instance.material_override = _material(color, metallic, roughness)
	parent.add_child(instance)
	return instance

func _add_sphere_to(parent: Node3D, node_name: String, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 8
	instance.mesh = sphere
	instance.position = position
	instance.scale = dimensions
	instance.material_override = _material(color, 0.0, 0.56)
	parent.add_child(instance)
	return instance

func _add_label(node_name: String, position: Vector3, size: float, color: Color) -> Label3D:
	return _add_label_to(self, node_name, position, size, color)

func _add_label_to(parent: Node3D, node_name: String, position: Vector3, size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = node_name if not node_name.is_empty() else "Fryer status label"
	label.text = node_name
	label.position = position
	label.font_size = 48
	label.pixel_size = size / 36.0
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color("252a2d")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
