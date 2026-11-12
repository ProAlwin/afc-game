extends Node3D

const TABLETOP_Y := 1.12
const SEAT_ROOT_Y := 0.31

var available_seats: Array[bool] = []
var seat_positions: Array[Vector3] = []
var tip_coins: Array[MeshInstance3D] = []
var serving_spot := Vector3(-0.88, TABLETOP_Y + 0.24, 0.0)

func build(is_tip_table: bool = false) -> void:
	name = "AFC premium dining table"
	_build_table()
	_build_chairs()
	_build_table_centerpiece()
	_build_table_lighting()
	if is_tip_table:
		_build_tip_setting()

func _build_table_lighting() -> void:
	var table_light := OmniLight3D.new()
	table_light.name = "Invisible warm light over dining table"
	table_light.position = Vector3(0.0, 2.45, 0.0)
	table_light.light_color = Color("ffe4ba")
	table_light.light_energy = 0.85
	table_light.omni_range = 5.2
	table_light.omni_attenuation = 1.35
	table_light.shadow_enabled = false
	add_child(table_light)

func reserve_seat() -> int:
	if available_seats.is_empty():
		return -1
	var available_indices: Array[int] = []
	for index in range(available_seats.size()):
		if available_seats[index]:
			available_indices.append(index)
	if available_indices.is_empty():
		return -1
	var chosen_index := available_indices[randi_range(0, available_indices.size() - 1)]
	available_seats[chosen_index] = false
	return chosen_index

func has_available_seat() -> bool:
	return available_seats.has(true)

func release_seat(index: int) -> void:
	if index >= 0 and index < available_seats.size():
		available_seats[index] = true

func get_seat_approach_position(index: int) -> Vector3:
	if index < 0 or index >= seat_positions.size():
		return Vector3(global_position.x, 0.22, global_position.z - 1.8)
	var seat := seat_positions[index]
	var approach_direction := Vector3(seat.x, 0.0, seat.z).normalized()
	var approach := to_global(seat + approach_direction * 0.72)
	approach.y = 0.22
	return approach

func get_seated_root_position(index: int) -> Vector3:
	if index < 0 or index >= seat_positions.size():
		return Vector3(global_position.x, SEAT_ROOT_Y, global_position.z - 1.8)
	var seat_position := to_global(seat_positions[index])
	seat_position.y = SEAT_ROOT_Y
	return seat_position

func get_serving_spot_position() -> Vector3:
	return to_global(serving_spot)

func get_surface_height() -> float:
	return TABLETOP_Y + 0.10

func _build_table() -> void:
	_build_dining_floor_tiles()
	_add_cylinder("Premium dark walnut table top", Vector3(0.0, TABLETOP_Y, 0.0), Vector3(1.90, 0.10, 1.28), Color("302723"), 0.16, 0.32)
	_add_cylinder("Champagne brass table edge", Vector3(0.0, TABLETOP_Y - 0.105, 0.0), Vector3(1.94, 0.045, 1.31), Color("bc9453"), 0.72, 0.28)
	_add_cylinder("Dark table underside", Vector3(0.0, TABLETOP_Y - 0.15, 0.0), Vector3(1.72, 0.10, 1.12), Color("242628"), 0.24, 0.38)
	_add_cylinder("Fluted pedestal foot", Vector3(0.0, 0.12, 0.0), Vector3(0.74, 0.12, 0.61), Color("25292b"), 0.42, 0.32)
	_add_cylinder("Pedestal gold foot trim", Vector3(0.0, 0.23, 0.0), Vector3(0.71, 0.035, 0.58), Color("b18c52"), 0.68, 0.27)
	_add_cylinder("Wide pedestal column", Vector3(0.0, 0.66, 0.0), Vector3(0.34, 0.43, 0.30), Color("32373a"), 0.42, 0.36)
	_add_cylinder("Pedestal upper collar", Vector3(0.0, 1.00, 0.0), Vector3(0.64, 0.065, 0.52), Color("ad854a"), 0.72, 0.30)

func _build_dining_floor_tiles() -> void:
	var tile_colors := [Color("9c5843"), Color("c08357")]
	for x_index in range(10):
		for z_index in range(8):
			var tile_color: Color = tile_colors[(x_index + z_index) % tile_colors.size()]
			var tile := _add_glass_box(
				"Warm terracotta dining floor tile",
				Vector3(-2.88 + float(x_index) * 0.64, 0.0, -2.275 + float(z_index) * 0.65),
				Vector3(0.61, 0.012, 0.62),
				tile_color,
				0.34
			)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_chairs() -> void:
	var chair_positions := [
		Vector3(0.0, 0.0, -2.05),
		Vector3(2.62, 0.0, 0.0),
		Vector3(0.0, 0.0, 2.05),
		Vector3(-2.62, 0.0, 0.0),
	]
	for chair_position in chair_positions:
		_build_chair(chair_position)
		seat_positions.append(chair_position)
	available_seats.resize(seat_positions.size())
	available_seats.fill(true)

func _build_chair(chair_position: Vector3) -> void:
	var chair := Node3D.new()
	chair.position = chair_position
	var toward_table := -Vector3(chair_position.x, 0.0, chair_position.z).normalized()
	chair.rotation.y = atan2(-toward_table.x, -toward_table.z)
	add_child(chair)
	_add_cylinder_to(chair, "Rounded red upholstered seat", Vector3(0.0, 0.67, 0.0), Vector3(0.46, 0.085, 0.43), Color("812f2a"), 0.0, 0.48)
	_add_cylinder_to(chair, "Brass seat piping", Vector3(0.0, 0.605, 0.0), Vector3(0.47, 0.025, 0.44), Color("ae884d"), 0.66, 0.32)
	for x in [-0.31, 0.31]:
		for z in [-0.27, 0.27]:
			_add_cylinder_to(chair, "Dark steel chair leg", Vector3(x, 0.32, z), Vector3(0.045, 0.31, 0.045), Color("282c2e"), 0.68, 0.3)
	var back := MeshInstance3D.new()
	back.name = "Soft rounded chair back"
	var back_mesh := CapsuleMesh.new()
	back_mesh.radius = 0.35
	back_mesh.height = 0.78
	back.mesh = back_mesh
	back.scale = Vector3(1.0, 1.0, 0.28)
	back.position = Vector3(0.0, 1.04, 0.32)
	back.material_override = _material(Color("812f2a"), 0.0, 0.48)
	chair.add_child(back)
	var back_trim := MeshInstance3D.new()
	back_trim.name = "Brass chair-back accent"
	var trim_mesh := CapsuleMesh.new()
	trim_mesh.radius = 0.37
	trim_mesh.height = 0.80
	back_trim.mesh = trim_mesh
	back_trim.scale = Vector3(1.0, 1.0, 0.18)
	back_trim.position = Vector3(0.0, 1.04, 0.355)
	back_trim.material_override = _material(Color("ae884d"), 0.62, 0.3)
	chair.add_child(back_trim)

func _build_table_centerpiece() -> void:
	_add_cylinder("Centerpiece brass vase foot", Vector3(0.0, 1.20, 0.0), Vector3(0.16, 0.035, 0.16), Color("b18c52"), 0.55, 0.32)
	_add_cylinder("Centerpiece cream ceramic vase", Vector3(0.0, 1.30, 0.0), Vector3(0.13, 0.13, 0.13), Color("e8ddc8"), 0.04, 0.34)
	_add_cylinder("Centerpiece vase neck", Vector3(0.0, 1.42, 0.0), Vector3(0.075, 0.10, 0.075), Color("eee3cf"), 0.03, 0.32)
	var stem_positions := [
		Vector3(0.0, 1.56, 0.0),
		Vector3(-0.09, 1.53, 0.025),
		Vector3(0.08, 1.55, -0.035),
		Vector3(0.025, 1.58, 0.08),
		Vector3(-0.035, 1.54, -0.09),
	]
	var flower_colors := [
		Color("c98278"),
		Color("e4c887"),
		Color("d99b86"),
		Color("dfd0a6"),
		Color("b87870"),
	]
	for index in range(stem_positions.size()):
		var flower_position: Vector3 = stem_positions[index]
		_add_cylinder(
			"Centerpiece flower stem",
			Vector3(flower_position.x * 0.55, 1.47, flower_position.z * 0.55),
			Vector3(0.012, 0.20, 0.012),
			Color("71815b"),
			0.0,
			0.7
		)
		_add_sphere("Centerpiece flower %d" % index, flower_position, Vector3(0.075, 0.055, 0.075), flower_colors[index], 10, 6)
		_add_sphere(
			"Centerpiece flower center %d" % index,
			flower_position + Vector3(0.0, 0.008, 0.0),
			Vector3(0.025, 0.025, 0.025),
			Color("d8b15f"),
			8,
			5
		)
	_add_sphere("Centerpiece vase leaf", Vector3(-0.12, 1.48, 0.015), Vector3(0.09, 0.035, 0.045), Color("788566"), 8, 5)
	_add_sphere("Centerpiece vase leaf", Vector3(0.11, 1.49, -0.025), Vector3(0.09, 0.035, 0.045), Color("84906a"), 8, 5)

func _add_glass_box(node_name: String, position: Vector3, dimensions: Vector3, color: Color, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = dimensions
	instance.mesh = box
	instance.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)
	return instance

func _add_box(node_name: String, position: Vector3, dimensions: Vector3, color: Color, bevel: float = 0.0, roughness: float = 0.72) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = dimensions
	box.subdivide_width = 1
	box.subdivide_depth = 1
	box.subdivide_height = 1
	instance.mesh = box
	instance.position = position
	instance.material_override = _material(color, 0.0, roughness)
	add_child(instance)
	return instance

func _build_tip_setting() -> void:
	_add_cylinder("Porcelain sauce dish", Vector3(0.65, TABLETOP_Y + 0.09, 0.54), Vector3(0.16, 0.035, 0.14), Color("eee3cf"), 0.0, 0.3)
	for index in range(4):
		var coin := MeshInstance3D.new()
		coin.name = "Customer table tip coin"
		var coin_mesh := CylinderMesh.new()
		coin_mesh.top_radius = 0.07
		coin_mesh.bottom_radius = 0.07
		coin_mesh.height = 0.025
		coin.mesh = coin_mesh
		coin.position = Vector3(0.50 + float(index % 2) * 0.10, TABLETOP_Y + 0.13 + float(index / 2) * 0.03, -0.40 + float(index / 2) * 0.10)
		coin.material_override = _material(Color("e5b34e"), 0.7, 0.26)
		add_child(coin)
		tip_coins.append(coin)
		coin.visible = false

func _add_cylinder(node_name: String, position: Vector3, dimensions: Vector3, color: Color, metallic: float, roughness: float) -> MeshInstance3D:
	return _add_cylinder_to(self, node_name, position, dimensions, color, metallic, roughness)

func _add_cylinder_to(parent: Node3D, node_name: String, position: Vector3, dimensions: Vector3, color: Color, metallic: float, roughness: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 32
	instance.mesh = cylinder
	instance.position = position
	instance.scale = dimensions
	instance.material_override = _material(color, metallic, roughness)
	parent.add_child(instance)
	return instance

func _add_sphere(node_name: String, position: Vector3, dimensions: Vector3, color: Color, radial_segments: int, rings: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	instance.mesh = sphere
	instance.position = position
	instance.scale = dimensions
	instance.material_override = _material(color, 0.0, 0.58)
	add_child(instance)
	return instance

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
