extends Node3D

class AFCVirtualJoystick extends Control:
	signal direction_changed(direction: Vector2)
	var pointer_id := -2
	var knob_offset := Vector2.ZERO
	var knob_limit := 55.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(176, 176)
		queue_redraw()

	func begin_at(viewport_position: Vector2) -> void:
		global_position = viewport_position - size * 0.5
		visible = true
		knob_offset = Vector2.ZERO
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()

	func drag_at(viewport_position: Vector2) -> void:
		_update_knob(_to_local(viewport_position))

	func end_touch() -> void:
		knob_offset = Vector2.ZERO
		visible = false
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				pointer_id = event.index
				_update_knob(_to_local(event.position))
			else:
				if pointer_id == event.index:
					_release_stick()
				accept_event()
		elif event is InputEventScreenDrag and pointer_id == event.index:
			_update_knob(_to_local(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_id = -1
				_update_knob(_to_local(event.position))
			else:
				_release_stick()
		elif event is InputEventMouseMotion and pointer_id == -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_knob(_to_local(event.position))

	func _to_local(viewport_position: Vector2) -> Vector2:
		return get_global_transform_with_canvas().affine_inverse() * viewport_position

	func _update_knob(pointer_position: Vector2) -> void:
		var centered := pointer_position - size * 0.5
		knob_offset = centered.limit_length(knob_limit)
		var direction := Vector2(knob_offset.x, -knob_offset.y) / knob_limit
		if direction.length() < 0.12:
			direction = Vector2.ZERO
		elif direction.length() > 1.0:
			direction = direction.normalized()
		direction_changed.emit(direction)
		queue_redraw()

	func _release_stick() -> void:
		pointer_id = -2
		knob_offset = Vector2.ZERO
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 7.0
		draw_circle(center + Vector2(0, 5), radius, Color(0.10, 0.05, 0.04, 0.38))
		draw_circle(center, radius, Color("9d2823", 0.82))
		draw_arc(center, radius, 0.0, TAU, 48, Color("fff2d7"), 4.0, true)
		draw_arc(center, radius * 0.56, 0.0, TAU, 40, Color("ffc84b", 0.66), 2.0, true)
		var arrow_color := Color("fff8e9")
		_draw_arrow(center + Vector2(0, -radius * 0.63), Vector2.UP, arrow_color)
		_draw_arrow(center + Vector2(0, radius * 0.63), Vector2.DOWN, arrow_color)
		_draw_arrow(center + Vector2(-radius * 0.63, 0), Vector2.LEFT, arrow_color)
		_draw_arrow(center + Vector2(radius * 0.63, 0), Vector2.RIGHT, arrow_color)
		var knob_center := center + knob_offset
		draw_circle(knob_center + Vector2(0, 4), radius * 0.36, Color(0.10, 0.04, 0.03, 0.45))
		draw_circle(knob_center, radius * 0.34, Color("f1bd3d"))
		draw_arc(knob_center, radius * 0.34, 0.0, TAU, 40, Color("fff4d8"), 3.0, true)

	func _draw_arrow(at: Vector2, direction: Vector2, color: Color) -> void:
		var tip := at + direction * 10.0
		var side := Vector2(-direction.y, direction.x) * 7.0
		draw_colored_polygon(PackedVector2Array([tip, at - direction * 7.0 + side, at - direction * 7.0 - side]), color)

## Open-top isometric 3D chicken shop. Reusable low-poly geometry and Kenney CC0
## furniture models keep the shop readable while allowing detailed upgrades.

enum Step { COOK, LOAD, BILL, CASH, CUSTOMER, TIP }
enum ServiceStage { BUILD, COLLECT_RAW, LOAD_FRYER, FRYING, COLLECT_COOKED, STAGE_ORDER, WAIT_CUSTOMER, BILL_CUSTOMER, CUSTOMER, CLEAN_TABLE, DISPOSE_TRASH }
enum CustomerFlow { NONE, ARRIVING, WAITING, RECEIVING, WALKING_TO_TABLE, EATING, LEAVING }

const SAVE_PATH := "user://afc_game.cfg"
const PACK_PRICE := 18
const TIP_VALUE := 4
const CHICKEN_CRATE_PRICE := 12
const SHOP_PURCHASE_COST := 19500
const SHOP_PURCHASE_DEPOSIT := 500
const WALK_SPEED := 5.0
const CUSTOMER_EATING_DURATION_SECONDS := 60.0
const MAX_CARRIED_TRASH := 4
const STARTER_BILLING_COUNTER_POSITION := Vector3(4.6, 0.18, -9.3)
const BILLING_CUSTOMER_STAND_OFFSET := Vector3(0.0, 0.04, 2.1)
const BILLING_WORK_OFFSET := Vector3(0.0, 0.04, -2.25)
const BILLING_WORK_RADIUS := 2.6
const BILLING_PROCESS_DURATION := 2.8
const DINING_TABLE_COST := 100
const DINING_TABLE_COUNT := 4
const STANDARD_DINING_SALES_REQUIRED := 3
const HR_OFFICE_COST := 200
const HR_OFFICE_POSITION := Vector3(8.7, 0.18, -11.0)
const FRIES_MACHINE_COST := 350
const FRIES_MACHINE_POSITION := Vector3(0.0, 0.18, -9.4)
const CUSTOMER_NAV_CELL_SIZE := 0.5
const CUSTOMER_NAV_OFFSET := Vector2(-15.0, -25.0)
const CUSTOMER_NAV_REGION := Rect2i(0, 0, 61, 101)
const FLOOR_HALF_WIDTH := 13.8
const FLOOR_HALF_DEPTH := 19.2
const BUILD_INTERIOR_CONTENT := false

# World scale: 1 Godot unit = 1 metre. The toy-like owner is 1.85 m tall.
# This keeps doors, cars, lanes and parking spaces consistent as the shop grows.
const OWNER_HEIGHT_METRES := 2.55
const CAR_LENGTH_METRES := 4.4
const CAR_WIDTH_METRES := 1.85
const PARKING_BAY_WIDTH_METRES := 2.8
const PARKING_BAY_LENGTH_METRES := 5.0

const MAT_FLOOR_A := Color("e8d5bc")
const MAT_FLOOR_B := Color("f2e5d3")
const MAT_RED := Color("d92f25")
const MAT_RED_DARK := Color("972a25")
const MAT_BLUE := Color("2866a4")
const MAT_STEEL := Color("aab5ba")
const MAT_STEEL_DARK := Color("59656a")
const MAT_CREAM := Color("fff2d9")
const MAT_CHICKEN := Color("d87924")
const DiningTableObject = preload("res://scripts/objects/dining_table.gd")
const RotaryFryerObject = preload("res://scripts/objects/rotary_fryer.gd")
const KENNEY_POS_SCREEN_SCENE := preload("res://assets/kenney/furniture-kit/computerScreen.glb")
const KENNEY_POS_KEYBOARD_SCENE := preload("res://assets/kenney/furniture-kit/computerKeyboard.glb")
const KENNEY_POS_MOUSE_SCENE := preload("res://assets/kenney/furniture-kit/computerMouse.glb")
const CUSTOMER_ANIMALS := [
	{"name": "Lion", "fur": "e6ad3e", "muzzle": "f3d9a8", "inner_ear": "ce8037", "mane": "8b472c", "jacket": "243b55", "tail": "b97b31"},
	{"name": "Tiger", "fur": "ed8b2f", "muzzle": "f6dfbd", "inner_ear": "9e4935", "mane": "", "jacket": "4a3b56", "tail": "e28a31"},
	{"name": "Monkey", "fur": "86543b", "muzzle": "e6b987", "inner_ear": "c77f67", "mane": "", "jacket": "31534d", "tail": "75432f"},
	{"name": "Panda", "fur": "f1eee5", "muzzle": "fffaf0", "inner_ear": "302b2a", "mane": "", "jacket": "39455c", "tail": "29292a"},
	{"name": "Fox", "fur": "db7134", "muzzle": "f5e5c7", "inner_ear": "53332b", "mane": "", "jacket": "385171", "tail": "db7134"},
	{"name": "Bear", "fur": "79513a", "muzzle": "d6ad82", "inner_ear": "bc7960", "mane": "", "jacket": "524b40", "tail": "79513a"},
	{"name": "Zebra", "fur": "e8e2d6", "muzzle": "f5eee0", "inner_ear": "312d2c", "mane": "", "jacket": "40556b", "tail": "282829"},
	{"name": "Elephant", "fur": "89949a", "muzzle": "a9b0b1", "inner_ear": "bd7778", "mane": "", "jacket": "496b74", "tail": "737d82"},
	{"name": "Giraffe", "fur": "e7ad42", "muzzle": "f4d18c", "inner_ear": "b86c32", "mane": "", "jacket": "586d42", "tail": "9b5b2a"},
	{"name": "Wolf", "fur": "8b9296", "muzzle": "d8d1c4", "inner_ear": "bd7773", "mane": "", "jacket": "4b5368", "tail": "70777d"},
	{"name": "Rabbit", "fur": "e6d9cd", "muzzle": "fff1e6", "inner_ear": "d9828b", "mane": "", "jacket": "8a5571", "tail": "f4eee8"},
	{"name": "Deer", "fur": "a96e43", "muzzle": "f0d7b1", "inner_ear": "b96f68", "mane": "", "jacket": "4c765e", "tail": "8d5738"},
	{"name": "Penguin", "fur": "292f39", "muzzle": "fff1d2", "inner_ear": "292f39", "mane": "", "jacket": "536c86", "tail": "292f39"},
	{"name": "Koala", "fur": "8c9697", "muzzle": "f0e5d7", "inner_ear": "d8898d", "mane": "", "jacket": "64734d", "tail": "858d8d"},
	{"name": "Hippo", "fur": "8b747b", "muzzle": "b89399", "inner_ear": "c1848d", "mane": "", "jacket": "69546c", "tail": "806b72"},
]

var phase: Step = Step.COOK
var wallet := 20000
var raw_chicken := 0
var cooked_pieces := 0
var packed_orders := 0
var sales_count := 0
var employees := 0
var cash_waiting := 0
var tip_waiting := 0
# First launch: owner starts on the exterior pedestrian path, facing the locked
# doors and a short walk from the buy-shop footprint rather than inside it.
var player_position := Vector3(0.0, 0.22, 23.30)
var player_target := Vector3.ZERO
var player_walking := false
var player_root: Area3D
var player_legs: Array[Node3D] = []
var player_arms: Array[Node3D] = []
var player_velocity := Vector2.ZERO
var customer_root: Node3D
var customer_route: Array[Vector3] = []
var customer_route_failed := false
var customer_route_target := Vector3.ZERO
var customer_route_retry_time := 0.0
var customer_wait_indicator: Node3D
var customer_clock_icon: Node3D
var customer_happy_icon: Node3D
var customer_no_seat_icon: Node3D
var customer_bucket_icon: Node3D
var customer_bucket_count_background: Node3D
var customer_bucket_count_label: Label3D
var customer_box: Node3D
var customer_table_meal_boxes: Array[Node3D] = []
var billing_counter_root: Node3D
var billing_staff_root: Node3D
var hr_office_root: Node3D
var staged_order_root: Node3D
var customer_tail_pivot: Node3D
var customer_species_index := 0
var customer_is_female := false
var customer_formal := false
var customer_arriving := false
var customer_arrival_stage := 0
var customer_walking_to_table := false
var customer_at_table := false
var customer_sitting := false
var customer_leaving := false
var dining_table_root: Node3D
var dining_table_component: DiningTableObject
var customer_seat_index := -1
var customer_pose_blend := 0.0
var table_trash_items: Array[Node3D] = []
var carried_trash_items: Array[Node3D] = []
var table_trash_count := 0
var carried_trash_count := 0
var trash_pickup_in_progress := false
var trash_carry_badge: Node3D
var trash_carry_label: Label3D
var waste_bin_root: Node3D
var waste_bin_opening := Vector3.ZERO
var trash_disposal_position := Vector3(7.5, 0.17, 9.2)
var customer_arms: Array[Node3D] = []
var customer_legs: Array[Node3D] = []
var billing_staff_arms: Array[Node3D] = []
var billing_worker_handoff_active := false
var customer_flow: CustomerFlow = CustomerFlow.NONE
var customer_order_in_progress := false
var customer_eating_time := 0.0
var customer_wait_elapsed := 0.0
var customer_buckets_total := 1
var customer_buckets_remaining := 1
var customer_spawn_time := 0.0
var customer_sequence := 0
var hired_workers: Array[Node3D] = []
var action_time := 0.0
var action_duration := 0.0
var anim_time := 0.0
var staff_income_time := 0.0
var toast_time := 0.0
var toast_message := ""
var camera: Camera3D
var camera_look_target := Vector3(0.0, 0.4, 0.0)
var camera_dragging := false
var last_camera_touch := Vector2.ZERO
var move_direction := Vector2.ZERO
var touch_joystick: AFCVirtualJoystick
var joystick_touch_id := -1
var marker: Node3D
var marker_torus: MeshInstance3D
var service_floor_tiles: Dictionary = {}
var status_label: Label
var money_label: Label
var stock_label: Label
var staff_button: Button
var staff_panel: PanelContainer
var supply_button: Button
var toast_panel: PanelContainer
var tutorial_card: PanelContainer
var tutorial_label: Label
var guidance_arrow: Label
var world_guidance_arrow: Node3D
var staff_count_label: Label
var cash_bundle: Node3D
var cash_trigger: Area3D
var tip_coins: Array[MeshInstance3D] = []
var sales_cash_bundle: Node3D
var sales_cash_notes: Array[Node3D] = []
var sales_cash_label: Label3D
var billing_counter_position := STARTER_BILLING_COUNTER_POSITION
var cash_trigger_position := Vector3.ZERO
var cash_sound: AudioStreamPlayer
var floating_reward: Label3D
var wallet_display := 0
var entrance_left_door: Node3D
var entrance_right_door: Node3D
var entrance_open := false
var entrance_hold_time := 0.0
var entrance_lock_sign: Node3D
var entrance_closed_barrier: Node3D
var shop_closed_roof: Node3D
var owner_has_entered_shop := false
var shop_owned := false
var shop_purchase_paid := 0
var first_machine_intro_time := 0.0
var base_camera_size := 25.0
var shop_purchase_timer := 0.0
var shop_purchase_root: Node3D
var shop_purchase_label: Label3D
var shop_purchase_cash_layers: Array[MeshInstance3D] = []
var shop_purchase_light: OmniLight3D
var shop_purchase_progress: Dictionary = {}
var shop_opening_time := 0.0
var shop_opening_overlay: Control
var traffic_cars: Array[Node3D] = []
var customer_traffic_active := false
var static_obstacles: Array[Rect2] = []
var build_slots: Array[Dictionary] = []
var starter_fryer_paid := 0
var starter_table_paid := 0
var starter_table_count := 0
var starter_hut_paid := 0
var hr_office_paid := 0
var fries_machine_paid := 0
var fries_machine_root: Node3D
var fries_machine_products: Array[Node3D] = []
var carried_chickens := 0
var carried_chicken_models: Array[Node3D] = []
var carried_order_pieces := 0
var staged_order_pieces := 0
var staged_order_piece_counts: Array[int] = []
var staged_order_roots: Array[Node3D] = []
var order_staged_for_billing := false
const MAX_STAGED_ORDERS := 20
var carried_food_root: Node3D
var player_working := false
var service_action_time := 0.0
var service_action_duration := 0.0
var billing_worker_timer := 0.0
var service_stage: ServiceStage = ServiceStage.BUILD
var service_stage_position := Vector3.ZERO
var service_table_payment_time := 0.0
var first_service_guidance_complete := false
var hen_hut_root: Node3D
var hen_hut_door: Node3D
var rear_hen_door: Node3D
var fryer_station: RotaryFryerObject
var fryer_upgrade_level := 1

var station_stands := {
	Step.COOK: Vector3(-4.7, 0.22, -5.45),
	Step.LOAD: Vector3(1.7, 0.22, -5.35),
	Step.BILL: Vector3(4.65, 0.22, -2.15),
	Step.CASH: Vector3(3.05, 0.22, -0.35),
	Step.CUSTOMER: Vector3(4.65, 0.22, -2.15),
	Step.TIP: Vector3(0.0, 0.22, 3.25),
}

func _ready() -> void:
	_build_world()
	_build_ui()
	_load_game()
	wallet_display = wallet
	_refresh_service_stage()
	_update_ui()
	_update_marker()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_camera_framing()

func _process(delta: float) -> void:
	anim_time += delta
	_animate_fries_machine(delta)
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		if toast_time == 0.0 and toast_panel:
			toast_panel.visible = false
	if shop_opening_time > 0.0:
		shop_opening_time = maxf(0.0, shop_opening_time - delta)
		move_direction = Vector2.ZERO
		player_velocity = Vector2.ZERO
		_follow_owner_camera(delta)
		_update_guidance_arrow()
		_update_traffic(delta)
		_update_ui()
		if shop_opening_time == 0.0:
			_finish_shop_opening_sequence()
		return
	if first_machine_intro_time > 0.0:
		first_machine_intro_time = maxf(0.0, first_machine_intro_time - delta)
	if not shop_owned:
		_update_shop_purchase(delta)
	player_velocity = player_velocity.move_toward(move_direction, delta * 36.0)
	player_walking = player_velocity.length() > 0.04
	if player_walking:
		var previous_position := player_position
		player_position.x += player_velocity.x * WALK_SPEED * delta
		# Joystick up points into the restaurant, which is world -Z in this view.
		player_position.z -= player_velocity.y * WALK_SPEED * delta
		_apply_shop_boundaries(previous_position)
		_apply_object_collisions(previous_position)
		_apply_character_collisions(previous_position)
		player_root.position = player_position
		player_root.rotation.y = lerp_angle(player_root.rotation.y, atan2(-player_velocity.x, player_velocity.y), delta * 11.0)
		_animate_player()
	elif action_time > 0.0:
		action_time = maxf(0.0, action_time - delta)
		if action_time == 0.0:
			if trash_pickup_in_progress:
				_finish_table_trash_pickup()
			else:
				_finish_station_action()
	else:
		_animate_player()
	if BUILD_INTERIOR_CONTENT and phase == Step.CASH and cash_waiting > 0 and player_position.distance_to(cash_trigger_position) < 0.92:
		_collect_cash_stack()
	# Work circles activate when the owner walks onto them. There is no floor tap
	# command: movement and interaction both come from the on-screen control.
	if BUILD_INTERIOR_CONTENT and action_time <= 0.0 and phase not in [Step.CASH, Step.CUSTOMER]:
		if not (phase == Step.COOK and raw_chicken <= 0) and player_position.distance_to(station_stands[phase]) < 0.68:
			_player_arrived()
	if BUILD_INTERIOR_CONTENT and employees > 0:
		staff_income_time += delta
		if staff_income_time >= 24.0:
			staff_income_time = 0.0
			wallet += employees * 3
			_refresh_table_purchase_slot()
			_show_toast("Your crew earned $%d" % (employees * 3))
			_save_game()
	if customer_arriving and customer_root:
		_retry_failed_customer_route(delta)
		if _move_customer_along_route(delta, 1.35):
			if customer_arrival_stage == 0:
				customer_arrival_stage = 1
				_set_customer_route(billing_counter_position + BILLING_CUSTOMER_STAND_OFFSET)
			else:
				customer_arriving = false
				if not BUILD_INTERIOR_CONTENT:
					customer_flow = CustomerFlow.WAITING
					customer_wait_elapsed = 0.0
					customer_seat_index = -1
				var animal_name := String(CUSTOMER_ANIMALS[customer_species_index]["name"])
				_show_toast("%s customer is waiting at the AFC counter" % animal_name)
	if customer_walking_to_table and customer_root:
		_retry_failed_customer_route(delta)
		if _move_customer_along_route(delta, 1.35):
			customer_walking_to_table = false
			customer_at_table = true
			customer_sitting = true
			if BUILD_INTERIOR_CONTENT:
				tip_waiting = TIP_VALUE
				if phase == Step.CUSTOMER:
					phase = Step.TIP
				_show_toast("Customer is at the table — tip left for you")
				_save_game()
				_update_marker()
			else:
				_start_customer_sitting_animation()
				customer_flow = CustomerFlow.EATING
				customer_eating_time = 0.0
				_place_customer_meal_on_table()
				_show_toast("Customer is enjoying the AFC meal")
	if customer_leaving and customer_root:
		_retry_failed_customer_route(delta)
		if _move_customer_along_route(delta, 1.45):
			customer_leaving = false
			customer_root.visible = false
			if customer_box:
				customer_box.visible = false
			customer_sitting = false
			customer_route.clear()
			_release_customer_seat()
			if not BUILD_INTERIOR_CONTENT:
				customer_flow = CustomerFlow.NONE
				customer_spawn_time = 1.5
	if marker:
		marker.position.y = 0.18
	_update_customer_wait_indicator()
	if customer_root and customer_root.visible:
		var standing_y := 0.23 + (absf(sin(anim_time * 3.0)) * 0.025 if not customer_sitting else 0.0)
		var seated_y := dining_table_component.get_seated_root_position(customer_seat_index).y if dining_table_component and customer_seat_index >= 0 else standing_y
		customer_root.global_position.y = lerpf(standing_y, seated_y, customer_pose_blend)
		_animate_customer()
	if shop_owned:
		_update_build_slots(delta)
		_update_hen_hut_interaction(delta)
		_update_fryer_conveyor(delta)
		if not BUILD_INTERIOR_CONTENT:
			_update_live_service(delta)
			_animate_billing_staff(billing_worker_timer > 0.0 or billing_worker_handoff_active)
		_update_shop_shell_state()
	_follow_owner_camera(delta)
	_update_traffic(delta)
	_update_ui()
	_update_pickup_visuals()
	_update_guidance_arrow()

func _build_customer_wait_indicator() -> void:
	customer_wait_indicator = Node3D.new()
	customer_wait_indicator.name = "Customer status icon"
	customer_wait_indicator.position = Vector3(0.0, 2.42, 0.0)
	customer_root.add_child(customer_wait_indicator)
	_add_cylinder(customer_wait_indicator, "Status icon dark border", Vector3(0.0, 0.10, 0.0), 0.35, 0.35, 0.09, Color("17191b"), 24, Vector3(PI * 0.5, 0.0, 0.0))
	_add_cylinder(customer_wait_indicator, "Status icon white background", Vector3(0.0, 0.10, 0.05), 0.30, 0.30, 0.035, Color.WHITE, 24, Vector3(PI * 0.5, 0.0, 0.0))
	customer_clock_icon = Node3D.new()
	customer_clock_icon.name = "Customer waiting clock icon"
	customer_clock_icon.position = Vector3(0.0, 0.10, 0.11)
	customer_wait_indicator.add_child(customer_clock_icon)
	_add_cylinder(customer_clock_icon, "Clock gold rim", Vector3.ZERO, 0.205, 0.205, 0.035, Color("d69a24"), 24, Vector3(PI * 0.5, 0.0, 0.0))
	_add_cylinder(customer_clock_icon, "Clock cream dial", Vector3(0.0, 0.0, 0.022), 0.178, 0.178, 0.025, Color("fff7e7"), 24, Vector3(PI * 0.5, 0.0, 0.0))
	_add_cylinder(customer_clock_icon, "Clock center pin", Vector3(0.0, 0.0, 0.045), 0.020, 0.020, 0.014, Color("34302b"), 12, Vector3(PI * 0.5, 0.0, 0.0))
	var clock_minute_hand := _add_box(customer_clock_icon, "Clock minute hand", Vector3(0.0, 0.055, 0.050), Vector3(0.022, 0.100, 0.012), Color("34302b"), 0.008)
	clock_minute_hand.rotation.z = deg_to_rad(-12.0)
	var clock_hour_hand := _add_box(customer_clock_icon, "Clock hour hand", Vector3(0.035, -0.015, 0.052), Vector3(0.075, 0.022, 0.012), Color("34302b"), 0.008)
	clock_hour_hand.rotation.z = deg_to_rad(-24.0)
	customer_clock_icon.visible = false
	customer_happy_icon = Node3D.new()
	customer_happy_icon.name = "Customer happy face icon"
	customer_happy_icon.position = Vector3(0.0, 0.10, 0.11)
	customer_wait_indicator.add_child(customer_happy_icon)
	_add_cylinder(customer_happy_icon, "Happy face golden rim", Vector3.ZERO, 0.205, 0.205, 0.035, Color("d69a24"), 24, Vector3(PI * 0.5, 0.0, 0.0))
	_add_cylinder(customer_happy_icon, "Happy face warm yellow", Vector3(0.0, 0.0, 0.022), 0.178, 0.178, 0.025, Color("ffd45b"), 24, Vector3(PI * 0.5, 0.0, 0.0))
	for eye_x in [-0.065, 0.065]:
		_add_sphere(customer_happy_icon, "Happy face eye", Vector3(eye_x, 0.045, 0.052), Vector3(0.020, 0.030, 0.012), Color("3c3028"), 10, 6)
	for smile_point in [
		Vector3(-0.070, -0.040, 0.052),
		Vector3(-0.038, -0.070, 0.052),
		Vector3(0.0, -0.080, 0.052),
		Vector3(0.038, -0.070, 0.052),
		Vector3(0.070, -0.040, 0.052),
	]:
		_add_sphere(customer_happy_icon, "Happy face smile segment", smile_point, Vector3(0.022, 0.022, 0.010), Color("7a3928"), 8, 5)
	customer_happy_icon.visible = false
	customer_no_seat_icon = Node3D.new()
	customer_no_seat_icon.name = "No available seat icon"
	customer_no_seat_icon.position = Vector3(0.0, 0.10, 0.11)
	customer_wait_indicator.add_child(customer_no_seat_icon)
	var chair_color := Color("55575a")
	_add_box(customer_no_seat_icon, "No-seat chair back", Vector3(0.0, 0.050, 0.035), Vector3(0.17, 0.085, 0.025), chair_color, 0.018)
	_add_box(customer_no_seat_icon, "No-seat chair seat", Vector3(0.0, -0.020, 0.040), Vector3(0.20, 0.045, 0.025), chair_color, 0.012)
	for chair_leg_x in [-0.075, 0.075]:
		_add_box(customer_no_seat_icon, "No-seat chair leg", Vector3(chair_leg_x, -0.095, 0.035), Vector3(0.030, 0.115, 0.025), chair_color, 0.008)
	for angle in [-45.0, 45.0]:
		var cross_bar := _add_box(
			customer_no_seat_icon,
			"No-seat red cross bar",
			Vector3(0.0, 0.0, 0.065),
			Vector3(0.29, 0.045, 0.022),
			Color("bd3128"),
			0.014
		)
		cross_bar.rotation.z = deg_to_rad(angle)
	customer_no_seat_icon.visible = false
	customer_bucket_icon = Node3D.new()
	customer_bucket_icon.name = "Requested AFC bucket icon"
	customer_bucket_icon.position = Vector3(-0.085, 0.10, 0.11)
	customer_wait_indicator.add_child(customer_bucket_icon)
	_add_cylinder(customer_bucket_icon, "Red takeaway bucket", Vector3.ZERO, 0.12, 0.09, 0.19, MAT_RED, 12)
	_add_cylinder(customer_bucket_icon, "Bucket gold rim", Vector3(0.0, 0.105, 0.0), 0.13, 0.13, 0.035, Color("f0c84b"), 12)
	for index in range(3):
		_add_sphere(
			customer_bucket_icon,
			"Bucket chicken piece",
			Vector3(-0.06 + float(index) * 0.06, 0.17 + float(index % 2) * 0.025, 0.0),
			Vector3(0.045, 0.065, 0.045),
			Color("d99137"),
			8,
			5
		)
	customer_bucket_count_label = Label3D.new()
	customer_bucket_count_label.name = "Buckets remaining cartoon count"
	customer_bucket_count_label.font_size = 100
	customer_bucket_count_label.pixel_size = 0.0024
	customer_bucket_count_label.modulate = Color("a7222b")
	customer_bucket_count_label.outline_size = 10
	customer_bucket_count_label.outline_modulate = Color("fff7e8")
	customer_bucket_count_label.position = Vector3(0.13, 0.10, 0.155)
	customer_bucket_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	customer_bucket_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	customer_bucket_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	customer_wait_indicator.add_child(customer_bucket_count_label)
	customer_bucket_count_background = Node3D.new()
	customer_bucket_count_background.name = "Bucket count badge background"
	customer_wait_indicator.add_child(customer_bucket_count_background)
	_add_cylinder(customer_bucket_count_background, "Bucket count dark outline", Vector3(0.13, 0.10, 0.105), 0.13, 0.13, 0.025, Color("8c2525"), 20, Vector3(PI * 0.5, 0.0, 0.0))
	_add_cylinder(customer_bucket_count_background, "Bucket count white inset", Vector3(0.13, 0.10, 0.125), 0.105, 0.105, 0.025, Color("fff7e7"), 20, Vector3(PI * 0.5, 0.0, 0.0))
	customer_bucket_count_background.visible = false
	customer_wait_indicator.visible = false

func _update_customer_wait_indicator() -> void:
	if not customer_wait_indicator:
		return
	var waiting := customer_root != null and customer_root.visible and customer_flow == CustomerFlow.WAITING
	var receiving := customer_root != null and customer_root.visible and customer_flow == CustomerFlow.RECEIVING
	var happy := customer_root != null and customer_root.visible and customer_flow == CustomerFlow.EATING
	var no_seat := waiting and not _customer_has_available_seat()
	var order_in_progress := receiving or billing_worker_timer > 0.0 or (waiting and customer_buckets_remaining < customer_buckets_total)
	var clock_visible := waiting and not order_in_progress and customer_wait_elapsed >= 10.0 and fposmod(customer_wait_elapsed - 10.0, 6.0) < 3.0
	var show_bucket := order_in_progress or (receiving and customer_buckets_remaining > 0)
	customer_wait_indicator.visible = no_seat or clock_visible or happy or show_bucket
	if not customer_wait_indicator.visible:
		return
	if camera:
		customer_wait_indicator.global_basis = camera.global_basis
	customer_clock_icon.visible = clock_visible and not no_seat
	customer_happy_icon.visible = happy and not no_seat
	customer_no_seat_icon.visible = no_seat
	customer_bucket_icon.visible = show_bucket and not no_seat
	customer_bucket_count_background.visible = show_bucket and not no_seat
	customer_bucket_count_label.visible = show_bucket and not no_seat
	customer_bucket_count_label.text = str(customer_buckets_remaining)
	var pulse := 1.0 + sin(anim_time * 2.8) * 0.035
	customer_wait_indicator.scale = Vector3.ONE * pulse

func _follow_owner_camera(delta: float) -> void:
	if not camera or not player_root:
		return
	var desired_focus := player_position + Vector3(0.0, 0.3, 0.0)
	if first_machine_intro_time > 0.0 and shop_owned:
		for slot in build_slots:
			if String(slot["id"]) == "fryer" and not bool(slot["built"]):
				desired_focus = slot["position"] + Vector3(0.0, 0.3, 0.0)
				break
	var follow_amount := 1.0 - exp(-delta * 6.0)
	var next_focus := camera_look_target.lerp(desired_focus, follow_amount)
	var shift := next_focus - camera_look_target
	camera_look_target = next_focus
	camera.position += shift
	camera.look_at(camera_look_target, Vector3.UP)
	camera.size = lerpf(camera.size, minf(base_camera_size, 21.0) if first_machine_intro_time > 0.0 else base_camera_size, follow_amount)

func _update_shop_shell_state() -> void:
	# Keep the room visible while the owner is at or just beyond the entrance.
	# The exterior shell/roof returns only after they walk several metres into the
	# front apron, so it never pops in immediately as the doors are crossed.
	if shop_opening_time > 0.0:
		return
	var owner_inside := absf(player_position.x) < 13.70 and player_position.z < 17.80 and player_position.z > -17.80
	var near_front_door := absf(player_position.x) < 2.25 and player_position.z > 16.0 and player_position.z < 21.5
	var customer_near_door: bool = customer_root != null and customer_root.visible and absf(customer_root.position.x) < 2.25 and customer_root.position.z > 15.8 and customer_root.position.z < 21.7
	var far_outside := player_position.z > 22.40
	if owner_inside:
		owner_has_entered_shop = true
		if shop_closed_roof:
			shop_closed_roof.visible = false
		_open_entrance_doors()
		return
	if near_front_door or customer_near_door:
		if shop_closed_roof:
			shop_closed_roof.visible = false
		_open_entrance_doors()
		return
	if owner_has_entered_shop:
		if shop_closed_roof:
			shop_closed_roof.visible = far_outside
		_close_entrance_doors()

func _apply_shop_boundaries(previous_position: Vector3) -> void:
	# The owner can explore the exterior, but crosses the restaurant shell only
	# through the centered front entrance or the rear service entrance.
	# These are the inside faces of the visible 0.16–0.28 m thick shell walls.
	# Keeping the invisible stop line inside the mesh prevents corner clipping.
	var wall_x := 13.74
	var front_wall_z := 17.88
	var rear_wall_z := -17.88
	# 2.6 m clear double-door opening. Both the previous and current position
	# must be inside this opening, so diagonal movement cannot pass through a wall.
	var doorway_half_width := 1.65
	player_position.x = clampf(player_position.x, -20.5, 20.5)
	player_position.z = clampf(player_position.z, -24.5, 24.5)
	# Before purchase the owner may explore the landscaped entrance, parking
	# apron and front path, but cannot circle through the closed restaurant.
	if not shop_owned:
		player_position.x = clampf(player_position.x, -20.5, 20.5)
		player_position.z = clampf(player_position.z, 18.10, 26.85)
		return
	# Until the hen hut is fully purchased, the entire rear wall—including the
	# visually central service door—is a solid boundary. This absolute clamp also
	# catches high-speed movement that might otherwise cross in one frame.
	if starter_hut_paid < 200 and player_position.z < rear_wall_z + 0.02:
		player_position.z = rear_wall_z + 0.02
		return
	# The owner may explore the marked front apron only. Do not allow walking
	# around the exterior side or rear of the building; the rear remains a future
	# service route unlocked only by the hen-hut progression.
	if player_position.z >= front_wall_z:
		player_position.x = clampf(player_position.x, -14.15, 14.15)
	elif absf(player_position.x) > wall_x:
		player_position = previous_position
		return
	if previous_position.z <= front_wall_z and player_position.z > front_wall_z:
		if absf(previous_position.x) > doorway_half_width or absf(player_position.x) > doorway_half_width:
			player_position.z = front_wall_z - 0.02
	if previous_position.z >= front_wall_z and player_position.z < front_wall_z:
		if not shop_owned or absf(previous_position.x) > doorway_half_width or absf(player_position.x) > doorway_half_width:
			player_position.z = front_wall_z + 0.02
	if previous_position.z >= rear_wall_z and player_position.z < rear_wall_z:
		if starter_hut_paid < 200 or absf(previous_position.x) > doorway_half_width or absf(player_position.x) > doorway_half_width:
			player_position.z = rear_wall_z + 0.02
	if previous_position.z <= rear_wall_z and player_position.z > rear_wall_z:
		if starter_hut_paid < 200 or absf(previous_position.x) > doorway_half_width or absf(player_position.x) > doorway_half_width:
			player_position.z = rear_wall_z - 0.02
	# Side walls have no openings. Check both travel directions so returning from
	# the parking/road cannot enter through a solid side wall either.
	var within_side_wall_length := player_position.z >= rear_wall_z and player_position.z <= front_wall_z
	if within_side_wall_length:
		if previous_position.x <= wall_x and player_position.x > wall_x:
			player_position.x = wall_x - 0.02
		elif previous_position.x >= wall_x and player_position.x < wall_x:
			player_position.x = wall_x + 0.02
		if previous_position.x >= -wall_x and player_position.x < -wall_x:
			player_position.x = -wall_x + 0.02
		elif previous_position.x <= -wall_x and player_position.x > -wall_x:
			player_position.x = -wall_x - 0.02
	# The traffic road begins after the parking apron. The owner can reach cars
	# and parking bays but cannot walk into moving traffic.
	if player_position.z >= 26.85:
		player_position.z = 26.85

func _apply_object_collisions(previous_position: Vector3) -> void:
	# Each rectangle is a solid top-down footprint for exterior objects. A move
	# that would enter it is cancelled, so the owner cannot pass through cars,
	# planters, lights, bollards or canopy columns.
	var player_point := Vector2(player_position.x, player_position.z)
	var previous_point := Vector2(previous_position.x, previous_position.z)
	for obstacle in static_obstacles:
		if not obstacle.has_point(previous_point) and obstacle.has_point(player_point):
			player_position = previous_position
			return

func _apply_character_collisions(previous_position: Vector3) -> void:
	var player_point := Vector2(player_position.x, player_position.z)
	var previous_point := Vector2(previous_position.x, previous_position.z)
	var characters: Array[Node3D] = []
	if is_instance_valid(customer_root) and customer_root.visible:
		characters.append(customer_root)
	for worker in hired_workers:
		if is_instance_valid(worker) and worker.visible:
			characters.append(worker)
	for character in characters:
		var character_point := Vector2(character.global_position.x, character.global_position.z)
		var separation := player_point - character_point
		var minimum_distance := 0.92
		if separation.length_squared() >= minimum_distance * minimum_distance:
			continue
		var push_direction := separation.normalized()
		if separation.length_squared() < 0.0001:
			push_direction = (previous_point - character_point).normalized()
			if push_direction.length_squared() < 0.0001:
				push_direction = Vector2.RIGHT
		player_point = character_point + push_direction * minimum_distance
		player_position.x = player_point.x
		player_position.z = player_point.y

func _update_traffic(delta: float) -> void:
	for car in traffic_cars:
		if not is_instance_valid(car):
			continue
		var speed := float(car.get_meta("drive_speed", 3.0))
		var direction := float(car.get_meta("drive_direction", 1.0))
		car.position.x += speed * direction * delta
		# The loop points remain beyond the viewport but inside the extended
		# asphalt, so a car never visibly drives onto grass at either end.
		if car.position.x > 34.0:
			car.position.x = -34.0
		elif car.position.x < -34.0:
			car.position.x = 34.0

func _unhandled_input(event: InputEvent) -> void:
	# A touch in the lower half creates a temporary joystick under the thumb.
	# The camera remains locked and the touch never moves the restaurant itself.
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y >= get_viewport().get_visible_rect().size.y * 0.5 and joystick_touch_id == -1:
			joystick_touch_id = event.index
			if touch_joystick:
				touch_joystick.begin_at(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == joystick_touch_id:
			joystick_touch_id = -1
			if touch_joystick:
				touch_joystick.end_touch()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		if touch_joystick:
			touch_joystick.drag_at(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var keyboard_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): keyboard_dir.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): keyboard_dir.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): keyboard_dir.y += 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): keyboard_dir.y -= 1.0
		move_direction = keyboard_dir.normalized()

func _set_move_button(direction_name: String, is_down: bool) -> void:
	var delta := Vector2.ZERO
	match direction_name:
		"left": delta = Vector2.LEFT
		"right": delta = Vector2.RIGHT
		"up": delta = Vector2(0, 1)
		"down": delta = Vector2(0, -1)
	if is_down:
		move_direction += delta
	else:
		move_direction -= delta
	if move_direction.length() > 1.0:
		move_direction = move_direction.normalized()

func _on_joystick_direction_changed(direction: Vector2) -> void:
	move_direction = direction

func _build_world() -> void:
	_build_camera_and_lights()
	_build_platform()
	_build_backdrop()
	_build_front_entrance()
	_build_outside_details()
	_build_shop_purchase_pad()
	_build_dining_bins()
	_build_player()
	_build_world_guidance_arrow()
	_build_marker()
	_build_sound_fx()
	_center_camera_on_owner()
	_build_starter_purchase_slots()
	_update_guidance_arrow()
	if BUILD_INTERIOR_CONTENT:
		_build_fryer_station()
		_build_holding_cabinet()
		_build_packing_station()
		_build_service_counter()
		_build_dining_area()
		_build_customer()
		_build_cash_trigger()
		_build_hired_staff()

func _build_world_guidance_arrow() -> void:
	world_guidance_arrow = Node3D.new()
	world_guidance_arrow.name = "Green floor guidance arrow"
	add_child(world_guidance_arrow)
	var outline_material := StandardMaterial3D.new()
	outline_material.albedo_color = Color("fff0a8")
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var green_material := StandardMaterial3D.new()
	green_material.albedo_color = Color("37c95a")
	green_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold_shaft := MeshInstance3D.new()
	gold_shaft.name = "Cream arrow outline shaft"
	var gold_shaft_mesh := BoxMesh.new()
	gold_shaft_mesh.size = Vector3(0.30, 0.05, 0.62)
	gold_shaft.mesh = gold_shaft_mesh
	gold_shaft.material_override = outline_material
	gold_shaft.position = Vector3(0.0, 0.015, -0.31)
	world_guidance_arrow.add_child(gold_shaft)
	var green_shaft := MeshInstance3D.new()
	green_shaft.name = "Green arrow shaft"
	var green_shaft_mesh := BoxMesh.new()
	green_shaft_mesh.size = Vector3(0.20, 0.055, 0.48)
	green_shaft.mesh = green_shaft_mesh
	green_shaft.material_override = green_material
	green_shaft.position = Vector3(0.0, 0.04, -0.31)
	world_guidance_arrow.add_child(green_shaft)
	var gold_head := MeshInstance3D.new()
	gold_head.name = "Cream arrowhead outline"
	gold_head.mesh = _create_guidance_arrowhead(0.42, -0.25, 0.47)
	gold_head.material_override = outline_material
	gold_head.position.y = 0.018
	world_guidance_arrow.add_child(gold_head)
	var green_head := MeshInstance3D.new()
	green_head.name = "Green arrowhead"
	green_head.mesh = _create_guidance_arrowhead(0.32, -0.20, 0.39)
	green_head.material_override = green_material
	green_head.position.y = 0.045
	world_guidance_arrow.add_child(green_head)
	world_guidance_arrow.visible = false

func _create_guidance_arrowhead(half_width: float, base_z: float, tip_z: float) -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0.0, base_z),
		Vector3(half_width, 0.0, base_z),
		Vector3(0.0, 0.0, tip_z),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrowhead := ArrayMesh.new()
	arrowhead.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arrowhead

func _center_camera_on_owner() -> void:
	if not camera or not player_root:
		return
	camera_look_target = player_position + Vector3(0.0, 0.3, 0.0)
	camera.position = camera_look_target + Vector3(10.4, 68.0, 62.0)
	camera.look_at(camera_look_target, Vector3.UP)

func _build_starter_purchase_slots() -> void:
	# Each purchase belongs to a physical footprint. Standing on it loads visible
	# green cash into the pad; once fully funded, its actual object appears there.
	build_slots.clear()
	# Kitchen equipment sits along the rear wall; the former central fryer area is
	# intentionally reserved for the customer-facing billing/pickup counter.
	_add_purchase_slot("fryer", "FRYER", 150, Vector3(-9.0, 0.18, -15.0), true)
	_add_purchase_slot("hen_hut", "HEN HUT", 200, Vector3(0.0, 0.18, -14.6), starter_fryer_paid >= 150)
	_add_purchase_slot("table", "TABLE 1 + CHAIRS", DINING_TABLE_COST, _dining_table_position(0), starter_hut_paid >= 200)
	_add_purchase_slot("hr_office", "HR OFFICE", HR_OFFICE_COST, HR_OFFICE_POSITION, starter_table_count >= DINING_TABLE_COUNT)
	_add_purchase_slot("fries_machine", "FRIES CONVEYOR", FRIES_MACHINE_COST, FRIES_MACHINE_POSITION, employees >= 2)
	_restore_starter_slots()

func _dining_table_position(index: int) -> Vector3:
	var table_offsets := [
		Vector3.ZERO,
		Vector3(0.0, 0.0, 5.0),
		Vector3(5.2, 0.0, 0.0),
		Vector3(5.2, 0.0, 5.0),
	]
	return Vector3(-6.6, 0.18, -1.0) + table_offsets[clampi(index, 0, table_offsets.size() - 1)]

func _build_shop_purchase_pad() -> void:
	# The first progression action happens outside the locked double doors. It is
	# deliberately separate from build pads: this buys the restaurant itself.
	shop_purchase_root = Node3D.new()
	shop_purchase_root.name = "Buy AFC shop entrance footprint"
	shop_purchase_root.position = Vector3(0.0, 0.18, 20.95)
	add_child(shop_purchase_root)
	# This is a property-deed pedestal, not a standard machine footprint. The
	# dark burgundy and brass treatment separates the major shop purchase from
	# later white construction pads.
	_add_box(shop_purchase_root, "Shop deed dark plinth", Vector3.ZERO, Vector3(3.55, 0.12, 2.35), Color("36272a"), 0.14, 0.62)
	_add_box(shop_purchase_root, "Shop deed AFC red inset", Vector3(0, 0.075, 0), Vector3(3.25, 0.035, 2.05), MAT_RED_DARK, 0.12, 0.45)
	_add_box(shop_purchase_root, "Shop deed cream title plate", Vector3(0, 0.098, 0.76), Vector3(2.55, 0.025, 0.44), Color("fff1d6"), 0.08, 0.35)
	for x in [-1.30, -0.65, 0.0, 0.65, 1.30]:
		_add_box(shop_purchase_root, "Shop deed brass detail", Vector3(x, 0.10, -0.88), Vector3(0.30, 0.025, 0.06), Color("f1bd47"))
		_add_box(shop_purchase_root, "Shop deed brass detail", Vector3(x, 0.10, 0.88), Vector3(0.30, 0.025, 0.06), Color("f1bd47"))
	for z in [-0.42, 0.0, 0.42]:
		_add_box(shop_purchase_root, "Shop deed brass detail", Vector3(-1.58, 0.10, z), Vector3(0.06, 0.025, 0.26), Color("f1bd47"))
		_add_box(shop_purchase_root, "Shop deed brass detail", Vector3(1.58, 0.10, z), Vector3(0.06, 0.025, 0.26), Color("f1bd47"))
	shop_purchase_label = _add_label(shop_purchase_root, "AFC SHOP DEED\n$0 / $%d" % SHOP_PURCHASE_COST, Vector3(0, 0.115, 1.10), 0.18, Color("202124"))
	shop_purchase_label.outline_modulate = Color("fff1d6")
	shop_purchase_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shop_purchase_progress = _add_purchase_progress_bar(shop_purchase_root, Vector3(0, 0.125, 0.34), 2.35)
	_add_label(shop_purchase_root, "◆", Vector3(0, 0.13, -0.34), 0.22, Color("f1bd47"))
	shop_purchase_light = OmniLight3D.new()
	shop_purchase_light.name = "Shop purchase progress glow"
	shop_purchase_light.position = Vector3(0, 1.2, 0)
	shop_purchase_light.light_color = Color("fff0c2")
	shop_purchase_light.light_energy = 0.45
	shop_purchase_light.omni_range = 4.0
	shop_purchase_root.add_child(shop_purchase_light)
	for layer in range(7):
		var bill := _add_box(shop_purchase_root, "Shop purchase green cash", Vector3(0, 0.10 + float(layer) * 0.065, -0.10), Vector3(0.98, 0.052, 0.64), Color("38a852") if layer % 2 == 0 else Color("70cb5e"), 0.03, 0.40)
		bill.visible = false
		shop_purchase_cash_layers.append(bill)
		var band := _add_box(shop_purchase_root, "Shop purchase cash band", Vector3(0, 0.13 + float(layer) * 0.065, -0.10), Vector3(0.20, 0.012, 0.42), Color("f2dd80"), 0.005)
		band.visible = false
		shop_purchase_cash_layers.append(band)
	_update_shop_purchase_visuals()

func _update_shop_purchase(delta: float) -> void:
	if not shop_purchase_root or player_position.distance_to(shop_purchase_root.position) > 1.8:
		shop_purchase_timer = 0.0
		return
	shop_purchase_timer += delta
	if shop_purchase_timer < 0.20 or wallet <= 0:
		return
	shop_purchase_timer = 0.0
	var load_amount: int = mini(mini(SHOP_PURCHASE_DEPOSIT, wallet), SHOP_PURCHASE_COST - shop_purchase_paid)
	if load_amount <= 0:
		return
	shop_purchase_paid += load_amount
	wallet -= load_amount
	wallet_display = wallet
	_update_shop_purchase_visuals()
	shop_purchase_root.scale = Vector3(1.055, 1.055, 1.055)
	var pad_tween := create_tween()
	pad_tween.tween_property(shop_purchase_root, "scale", Vector3.ONE, 0.17)
	shop_purchase_light.light_color = Color("74ec79")
	shop_purchase_light.light_energy = 2.7
	var light_tween := create_tween()
	light_tween.tween_property(shop_purchase_light, "light_energy", 0.70, 0.26)
	_save_game()
	if shop_purchase_paid >= SHOP_PURCHASE_COST:
		_start_shop_opening_sequence()

func _update_shop_purchase_visuals() -> void:
	if not shop_purchase_label:
		return
	var fraction := float(shop_purchase_paid) / float(SHOP_PURCHASE_COST)
	shop_purchase_label.text = "AFC SHOP DEED\n$%d / $%d" % [shop_purchase_paid, SHOP_PURCHASE_COST]
	_set_purchase_progress(shop_purchase_progress, fraction)
	var visible_layers: int = ceili(float(shop_purchase_paid) / float(SHOP_PURCHASE_COST) * 7.0)
	for i in range(shop_purchase_cash_layers.size()):
		shop_purchase_cash_layers[i].visible = i < visible_layers * 2

func _add_purchase_progress_bar(parent: Node3D, position_value: Vector3, width: float) -> Dictionary:
	# A shared chunky AFC progress treatment: red outer rail, cream track, green
	# money fill, gold end cap and a physical cash icon beside the amount.
	var progress_root := Node3D.new()
	progress_root.name = "AFC purchase progress bar"
	progress_root.position = position_value
	parent.add_child(progress_root)
	_add_box(progress_root, "Progress bar red shadow", Vector3(0, 0.006, 0), Vector3(width + 0.16, 0.060, 0.28), MAT_RED_DARK, 0.08, 0.35)
	_add_box(progress_root, "Progress bar cream track", Vector3(0, 0.045, 0.002), Vector3(width, 0.045, 0.17), Color("fff3da"), 0.06, 0.45)
	var fill_root := Node3D.new()
	fill_root.name = "Animated green purchase fill"
	fill_root.position = Vector3(-width * 0.5 + 0.055, 0.075, 0.005)
	fill_root.scale = Vector3(0.01, 1.0, 1.0)
	progress_root.add_child(fill_root)
	_add_box(fill_root, "Green purchase fill", Vector3((width - 0.11) * 0.5, 0, 0), Vector3(width - 0.11, 0.055, 0.115), Color("4dbb5b"), 0.045, 0.28)
	_add_box(fill_root, "Purchase fill highlight", Vector3((width - 0.11) * 0.5, 0.032, -0.01), Vector3(width - 0.15, 0.014, 0.055), Color("9aeb78"), 0.025, 0.20)
	_add_box(progress_root, "Progress gold end cap", Vector3(width * 0.5 - 0.07, 0.082, 0.005), Vector3(0.10, 0.075, 0.16), Color("f2bf44"), 0.04, 0.24)
	_add_box(progress_root, "Progress money icon", Vector3(-width * 0.5 - 0.20, 0.075, 0.0), Vector3(0.22, 0.07, 0.17), Color("42a954"), 0.025, 0.35)
	var cash_icon := _add_label(progress_root, "$", Vector3(-width * 0.5 - 0.20, 0.085, 0.10), 0.085, Color("163c25"))
	cash_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var percentage := _add_label(progress_root, "0%", Vector3(width * 0.5 + 0.16, 0.085, 0.10), 0.085, Color("202124"))
	percentage.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return {"fill": fill_root, "percent": percentage}

func _set_purchase_progress(progress: Dictionary, fraction: float) -> void:
	if progress.is_empty():
		return
	var clamped_fraction := clampf(fraction, 0.0, 1.0)
	var fill_root: Node3D = progress["fill"]
	var percentage: Label3D = progress["percent"]
	percentage.text = "%d%%" % roundi(clamped_fraction * 100.0)
	var fill_tween := create_tween()
	fill_tween.set_trans(Tween.TRANS_QUAD)
	fill_tween.set_ease(Tween.EASE_OUT)
	fill_tween.tween_property(fill_root, "scale", Vector3(maxf(0.01, clamped_fraction), 1.0, 1.0), 0.22)

func _start_shop_opening_sequence() -> void:
	if shop_owned:
		return
	shop_owned = true
	shop_opening_time = 2.0
	_refresh_purchase_slot_visibility()
	if shop_purchase_root:
		shop_purchase_root.visible = false
	if entrance_lock_sign:
		entrance_lock_sign.visible = false
	if entrance_closed_barrier:
		entrance_closed_barrier.visible = false
	if shop_closed_roof:
		shop_closed_roof.visible = false
	_open_entrance_doors()
	if shop_opening_overlay:
		shop_opening_overlay.visible = true
		shop_opening_overlay.modulate = Color.WHITE
		var overlay_tween := create_tween()
		overlay_tween.tween_property(shop_opening_overlay, "modulate:a", 1.0, 0.12)
	_save_game()

func _finish_shop_opening_sequence() -> void:
	first_machine_intro_time = 2.6
	if shop_opening_overlay:
		var fade_tween := create_tween()
		fade_tween.tween_property(shop_opening_overlay, "modulate:a", 0.0, 0.20)
		fade_tween.tween_callback(func() -> void: shop_opening_overlay.visible = false)
	_show_toast("AFC shop is open — build your first fryer")
	_update_ui()

func _restore_owned_shop_visuals() -> void:
	if not shop_owned:
		return
	if shop_purchase_root:
		shop_purchase_root.visible = false
	if entrance_lock_sign:
		entrance_lock_sign.visible = false
	if entrance_closed_barrier:
		entrance_closed_barrier.visible = false
	if shop_closed_roof:
		shop_closed_roof.visible = false
	_refresh_purchase_slot_visibility()
	_open_entrance_doors()

func _refresh_purchase_slot_visibility() -> void:
	for slot in build_slots:
		var slot_root: Node3D = slot["root"]
		if is_instance_valid(slot_root):
			slot_root.visible = shop_owned and bool(slot["unlocked"]) and not bool(slot["built"])

func _open_entrance_doors() -> void:
	if entrance_open:
		return
	entrance_open = true
	if entrance_left_door:
		var left_tween := create_tween()
		left_tween.set_trans(Tween.TRANS_QUAD)
		left_tween.set_ease(Tween.EASE_OUT)
		left_tween.tween_property(entrance_left_door, "position:x", -1.65, 0.48)
	if entrance_right_door:
		var right_tween := create_tween()
		right_tween.set_trans(Tween.TRANS_QUAD)
		right_tween.set_ease(Tween.EASE_OUT)
		right_tween.tween_property(entrance_right_door, "position:x", 1.65, 0.48)

func _close_entrance_doors() -> void:
	if not entrance_open:
		return
	entrance_open = false
	if entrance_left_door:
		var left_tween := create_tween()
		left_tween.set_trans(Tween.TRANS_QUAD)
		left_tween.set_ease(Tween.EASE_IN_OUT)
		left_tween.tween_property(entrance_left_door, "position:x", -0.84, 0.38)
	if entrance_right_door:
		var right_tween := create_tween()
		right_tween.set_trans(Tween.TRANS_QUAD)
		right_tween.set_ease(Tween.EASE_IN_OUT)
		right_tween.tween_property(entrance_right_door, "position:x", 0.84, 0.38)

func _add_purchase_slot(id: String, title: String, cost: int, slot_position: Vector3, unlocked: bool) -> void:
	var slot := Node3D.new()
	slot.name = "%s footprint loader" % title
	slot.position = slot_position
	add_child(slot)
	slot.visible = shop_owned and unlocked
	var footprint := Vector2(8.6, 4.8) if id == "fries_machine" else (Vector2(4.8, 4.0) if id == "table" else (Vector2(5.4, 5.0) if id == "hr_office" else Vector2(2.35, 1.92)))
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	var base_color := Color("d8873d") if id == "table" else Color("fff9e9")
	var inset_color := Color("edae62") if id == "table" else Color("e8ded0")
	_add_box(slot, "Footprint loader base", Vector3(0, 0.025, 0), Vector3(footprint.x, 0.06, footprint.y), base_color, 0.10, 0.65)
	_add_box(slot, "Footprint loader inner panel", Vector3(0, 0.062, 0), Vector3(footprint.x - 0.28, 0.018, footprint.y - 0.28), inset_color, 0.08, 0.48)
	# White dotted boundary reads clearly as a build footprint in the isometric view.
	var horizontal_marks := 9 if id == "fries_machine" else (7 if id == "table" else 5)
	for index in range(horizontal_marks):
		var x := lerpf(-half_x + 0.16, half_x - 0.16, float(index) / float(horizontal_marks - 1))
		_add_box(slot, "Footprint dotted edge", Vector3(x, 0.065, -half_z + 0.10), Vector3(0.18, 0.025, 0.06), Color("fff7de"))
		_add_box(slot, "Footprint dotted edge", Vector3(x, 0.065, half_z - 0.10), Vector3(0.18, 0.025, 0.06), Color("fff7de"))
	var vertical_marks := 5 if id in ["table", "fries_machine"] else 3
	for index in range(vertical_marks):
		var z := lerpf(-half_z + 0.16, half_z - 0.16, float(index) / float(vertical_marks - 1))
		_add_box(slot, "Footprint dotted edge", Vector3(-half_x + 0.10, 0.065, z), Vector3(0.06, 0.025, 0.18), Color("fff7de"))
		_add_box(slot, "Footprint dotted edge", Vector3(half_x - 0.10, 0.065, z), Vector3(0.06, 0.025, 0.18), Color("fff7de"))
	if id != "table":
		for index in range(horizontal_marks):
			var x := lerpf(-half_x + 0.22, half_x - 0.22, float(index) / float(horizontal_marks - 1))
			_add_footprint_x(slot, Vector3(x, 0.09, -half_z + 0.18))
			_add_footprint_x(slot, Vector3(x, 0.09, half_z - 0.18))
		for index in range(vertical_marks):
			var z := lerpf(-half_z + 0.22, half_z - 0.22, float(index) / float(vertical_marks - 1))
			_add_footprint_x(slot, Vector3(-half_x + 0.18, 0.09, z))
			_add_footprint_x(slot, Vector3(half_x - 0.18, 0.09, z))
	var pad_label := _add_label(slot, "%s\n$0 / $%d" % [title, cost], Vector3(0, 0.10, half_z + 0.18), 0.13, Color("202124"))
	pad_label.outline_modulate = Color("fff9de")
	pad_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var purchase_progress := _add_purchase_progress_bar(slot, Vector3(0, 0.105, 0.45), 1.48)
	var loader_light := OmniLight3D.new()
	loader_light.name = "Green footprint loader light"
	loader_light.position = Vector3(0, 1.15, 0)
	loader_light.light_color = Color("fff1c5")
	loader_light.light_energy = 0.45
	loader_light.omni_range = 3.6 if id == "table" else 3.2
	slot.add_child(loader_light)
	var cash_layers: Array[MeshInstance3D] = []
	for layer in range(8):
		var bill := _add_box(slot, "Footprint loading cash", Vector3(0, 0.10 + float(layer) * 0.055, -0.05), Vector3(0.74, 0.045, 0.52), Color("3ea84f") if layer % 2 == 0 else Color("6cc95d"), 0.025, 0.42)
		bill.visible = false
		cash_layers.append(bill)
		var seal := _add_box(slot, "Cash stack band", Vector3(0, 0.13 + float(layer) * 0.055, -0.05), Vector3(0.18, 0.012, 0.32), Color("e7dd8e"), 0.005)
		seal.visible = false
		cash_layers.append(seal)
	var initial_paid := starter_fryer_paid if id == "fryer" else (starter_hut_paid if id == "hen_hut" else (hr_office_paid if id == "hr_office" else starter_table_paid))
	build_slots.append({
		"id": id,
		"title": title,
		"cost": cost,
		"paid": initial_paid,
		"load_timer": 0.0,
		"unlocked": unlocked,
		"built": false,
		"position": slot_position,
		"root": slot,
		"label": pad_label,
		"progress": purchase_progress,
		"cash_layers": cash_layers,
		"light": loader_light,
	})
	_update_purchase_slot_visuals(build_slots[build_slots.size() - 1])

func _add_footprint_x(parent: Node3D, position_value: Vector3) -> void:
	var mark := _add_label(parent, "X", position_value, 0.10, Color("111111"))
	mark.outline_modulate = Color("fff8e9")
	mark.outline_size = 8
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _update_build_slots(delta: float) -> void:
	for slot in build_slots:
		if bool(slot["built"]) or not bool(slot["unlocked"]):
			continue
		var slot_position: Vector3 = slot["position"]
		var interaction_radius := 2.8 if String(slot["id"]) in ["table", "fries_machine"] else (2.4 if String(slot["id"]) == "hr_office" else 1.8)
		if player_position.distance_to(slot_position) > interaction_radius:
			continue
		var load_timer: float = float(slot["load_timer"]) + delta
		if load_timer < 0.20:
			slot["load_timer"] = load_timer
			continue
		slot["load_timer"] = 0.0
		var paid: int = int(slot["paid"])
		var cost: int = int(slot["cost"])
		if paid < cost and wallet > 0:
			var load_amount: int = mini(mini(20, wallet), cost - paid)
			slot["paid"] = paid + load_amount
			if String(slot["id"]) == "fryer":
				starter_fryer_paid = int(slot["paid"])
			elif String(slot["id"]) == "hen_hut":
				starter_hut_paid = int(slot["paid"])
			elif String(slot["id"]) == "hr_office":
				hr_office_paid = int(slot["paid"])
			elif String(slot["id"]) == "fries_machine":
				fries_machine_paid = int(slot["paid"])
			else:
				starter_table_paid = int(slot["paid"])
			wallet -= load_amount
			wallet_display = wallet
			_update_purchase_slot_visuals(slot)
			_save_game()
			var loading_root: Node3D = slot["root"]
			loading_root.scale = Vector3(1.08, 1.08, 1.08)
			var pulse_tween := create_tween()
			pulse_tween.tween_property(loading_root, "scale", Vector3.ONE, 0.18)
			var loading_light: OmniLight3D = slot["light"]
			loading_light.light_energy = 2.4
			var light_tween := create_tween()
			light_tween.tween_property(loading_light, "light_energy", 0.70, 0.24)
			if int(slot["paid"]) >= cost:
				slot["built"] = true
				_spawn_bought_object(slot)
				_save_game()
			_update_ui()

func _update_purchase_slot_visuals(slot: Dictionary) -> void:
	var paid: int = int(slot["paid"])
	var cost: int = int(slot["cost"])
	var progress: Dictionary = slot["progress"]
	_set_purchase_progress(progress, float(paid) / float(cost))
	var visible_layers: int = ceili(float(paid) / float(cost) * 8.0)
	var cash_layers: Array[MeshInstance3D] = slot["cash_layers"]
	for i in range(cash_layers.size()):
		cash_layers[i].visible = i < visible_layers * 2
	var slot_label: Label3D = slot["label"]
	if String(slot["id"]) == "table" and starter_table_count > 0 and starter_table_count < DINING_TABLE_COUNT and not bool(slot["unlocked"]):
		slot_label.text = "STANDARD • TABLE %d\n$%d / $%d  •  %d / %d SALES" % [
			starter_table_count + 1,
			wallet,
			DINING_TABLE_COST,
			mini(sales_count, STANDARD_DINING_SALES_REQUIRED),
			STANDARD_DINING_SALES_REQUIRED,
		]
	else:
		slot_label.text = "%s\n$%d / $%d" % [String(slot["title"]), paid, cost]

func _refresh_table_purchase_slot() -> void:
	for slot in build_slots:
		if String(slot["id"]) != "table":
			continue
		slot["unlocked"] = _table_purchase_unlocked()
		if starter_table_count < DINING_TABLE_COUNT:
			slot["title"] = "BASIC • TABLE 1 + CHAIRS" if starter_table_count == 0 else "STANDARD • TABLE %d + CHAIRS" % (starter_table_count + 1)
			slot["position"] = _dining_table_position(starter_table_count)
			(slot["root"] as Node3D).position = slot["position"]
		_update_purchase_slot_visuals(slot)
	_refresh_purchase_slot_visibility()

func _table_purchase_unlocked() -> bool:
	if starter_table_count == 0:
		return starter_hut_paid >= 200
	if starter_table_count >= DINING_TABLE_COUNT:
		return false
	return sales_count >= STANDARD_DINING_SALES_REQUIRED and wallet >= DINING_TABLE_COST

func _spawn_bought_object(slot: Dictionary) -> void:
	var root: Node3D = slot["root"]
	root.visible = false
	var slot_position: Vector3 = slot["position"]
	var built_object: Node3D = null
	match String(slot["id"]):
		"fryer":
			built_object = _build_starter_fryer(slot_position)
			_build_starter_billing_counter(STARTER_BILLING_COUNTER_POSITION)
			for next_slot in build_slots:
				if String(next_slot["id"]) == "hen_hut":
					next_slot["unlocked"] = true
					var next_label: Label3D = next_slot["label"]
					next_label.text = "HEN HUT\n$0 / $200"
			_show_toast("AFC fryer installed — hen hut footprint unlocked")
		"hen_hut":
			built_object = _build_hen_hut()
			for next_slot in build_slots:
				if String(next_slot["id"]) == "table":
					next_slot["unlocked"] = true
					_update_purchase_slot_visuals(next_slot)
			_show_toast("Hen hut opened — collect up to 7 chickens")
		"table":
			built_object = _build_starter_table(slot_position, starter_table_count)
			starter_table_count += 1
			starter_table_paid = 0
			slot["paid"] = 0
			if starter_table_count < DINING_TABLE_COUNT:
				slot["built"] = false
				slot["position"] = _dining_table_position(starter_table_count)
				root.position = slot["position"]
				_refresh_table_purchase_slot()
				if bool(slot["unlocked"]):
					_show_toast("Table %d installed — the next table is ready to fund" % starter_table_count)
				else:
					_show_toast("Basic dining is ready — serve 3 customers to unlock standard dining")
			else:
				slot["built"] = true
				for next_slot in build_slots:
					if String(next_slot["id"]) == "hr_office":
						next_slot["unlocked"] = true
				_show_toast("All four tables installed — the HR office footprint is now unlocked")
			_save_game()
		"hr_office":
			built_object = _build_hr_office(slot_position)
			_show_toast("HR office opened — recruit your AFC team here")
		"fries_machine":
			built_object = _build_fries_conveyor_machine(slot_position)
			_show_toast("AFC fries conveyor installed — watch fresh fries travel through the lit tunnel")
	if built_object:
		# A new object grows from the glowing footprint instead of appearing flat.
		var final_scale := built_object.scale
		built_object.scale = final_scale * 0.08
		var reveal_light := OmniLight3D.new()
		reveal_light.light_color = Color("fff0a5")
		reveal_light.light_energy = 4.0
		reveal_light.omni_range = 5.0
		reveal_light.position = Vector3(0, 1.6, 0)
		built_object.add_child(reveal_light)
		var reveal_tween := create_tween()
		reveal_tween.set_trans(Tween.TRANS_BACK)
		reveal_tween.set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(built_object, "scale", final_scale, 0.55)
		reveal_tween.parallel().tween_property(reveal_light, "light_energy", 0.0, 0.75)
	_refresh_purchase_slot_visibility()

func _restore_starter_slots() -> void:
	for slot in build_slots:
		var id := String(slot["id"])
		if id == "fryer":
			slot["paid"] = starter_fryer_paid
			slot["unlocked"] = true
		elif id == "hen_hut":
			slot["paid"] = starter_hut_paid
			slot["unlocked"] = starter_fryer_paid >= 150
		elif id == "table":
			slot["position"] = _dining_table_position(starter_table_count)
			slot["title"] = "BASIC • TABLE 1 + CHAIRS" if starter_table_count == 0 else "STANDARD • TABLE %d + CHAIRS" % (starter_table_count + 1)
			(slot["root"] as Node3D).position = slot["position"]
			slot["paid"] = starter_table_paid
			slot["unlocked"] = _table_purchase_unlocked()
			slot["built"] = starter_table_count >= DINING_TABLE_COUNT
		elif id == "hr_office":
			slot["paid"] = hr_office_paid
			slot["unlocked"] = starter_table_count >= DINING_TABLE_COUNT
		elif id == "fries_machine":
			slot["paid"] = fries_machine_paid
			slot["unlocked"] = employees >= 2
		_update_purchase_slot_visuals(slot)
		var cost: int = int(slot["cost"])
		if id == "table" and starter_table_count >= DINING_TABLE_COUNT:
			slot["built"] = true
		elif int(slot["paid"]) >= cost and not bool(slot["built"]):
			slot["built"] = true
			_spawn_bought_object(slot)
	for table_index in range(starter_table_count):
		var table_name := "Bought dining table %d of %d" % [table_index + 1, DINING_TABLE_COUNT]
		if not find_child(table_name, true, false):
			_build_starter_table(_dining_table_position(table_index), table_index)
	_refresh_table_purchase_slot()

func _build_starter_fryer(slot_position: Vector3) -> Node3D:
	var fryer := RotaryFryerObject.new() as RotaryFryerObject
	fryer.name = "AFC level one rotary chicken cooker"
	add_child(fryer)
	fryer.build(slot_position)
	fryer.set_level(fryer_upgrade_level)
	_add_box(fryer, "Warm kitchen task light housing", Vector3(0, 3.48, -0.38), Vector3(1.40, 0.12, 0.90), Color("ddc995"), 0.06, 0.42)
	_add_warm_area_light(fryer, "Warm kitchen task light", Vector3(0, 3.38, -0.38), 2.0, 9.0)
	for light_x in [-2.7, 0.0, 2.7]:
		_add_warm_area_light(fryer, "Bright kitchen ceiling downlight", Vector3(light_x, 3.92, -0.65), 2.6, 8.5)
	fryer_station = fryer
	_add_service_floor_tile("load_fryer", slot_position + Vector3(0.0, 0.04, 2.15), Color("eabf45"), Vector2(1.24, 1.24), 0.055, 0.05, true)
	var output_table := fryer.get_output_table()
	if output_table:
		_add_service_floor_tile("collect_cooked", output_table.global_position + Vector3(0.0, 0.04, 2.30), Color("e07832"), Vector2(1.24, 1.24), 0.055, 0.05, true)
	_register_obstacle(Vector2(slot_position.x, slot_position.z), Vector2(3.55, 2.65))
	_register_obstacle(Vector2(slot_position.x + 2.55, slot_position.z), Vector2(5.9, 1.40))
	_register_obstacle(Vector2(slot_position.x + 5.70, slot_position.z), Vector2(2.15, 1.95))
	return fryer

func _update_fryer_conveyor(delta: float) -> void:
	if not fryer_station:
		return
	var produced := fryer_station.advance(delta, raw_chicken, anim_time)
	if produced > 0:
		raw_chicken -= produced
		cooked_pieces += produced
		_update_ui()

func set_fryer_upgrade_level(new_level: int) -> void:
	fryer_upgrade_level = clampi(new_level, 1, RotaryFryerObject.MAX_LEVEL)
	if fryer_station:
		fryer_station.set_level(fryer_upgrade_level)
	_save_game()

func _build_starter_billing_counter(counter_position: Vector3) -> void:
	var counter := Node3D.new()
	counter.name = "First AFC billing and pickup counter"
	counter.position = counter_position
	add_child(counter)
	billing_counter_root = counter
	billing_counter_position = counter_position
	# Premium AFC service island: charcoal plinth, walnut fascia, brass details,
	# a pale stone worktop, and clearly separated packing and till zones.
	_add_box(counter, "Billing counter recessed shadow plinth", Vector3(0, 0.22, 0), Vector3(4.92, 0.22, 1.36), Color("202629"), 0.12, 0.36)
	_add_box(counter, "Billing counter walnut carcass", Vector3(0, 0.70, 0), Vector3(4.86, 0.76, 1.30), Color("332b28"), 0.12, 0.48)
	_add_box(counter, "Billing counter customer-facing charcoal fascia", Vector3(0, 0.72, 0.66), Vector3(4.72, 0.62, 0.045), Color("292f32"), 0.055, 0.42)
	_add_box(counter, "Billing counter warm red brand inset", Vector3(0, 0.75, 0.692), Vector3(1.55, 0.43, 0.025), MAT_RED_DARK, 0.05, 0.42)
	_add_box(counter, "Billing counter gold badge surround", Vector3(0, 0.75, 0.711), Vector3(1.18, 0.29, 0.018), Color("c29a58"), 0.035, 0.32)
	_add_box(counter, "Billing counter cream AFC badge", Vector3(0, 0.75, 0.724), Vector3(1.10, 0.23, 0.018), Color("f5ead2"), 0.025, 0.38)
	_add_label(counter, "AFC", Vector3(0, 0.73, 0.74), 0.15, Color("9b2825"))
	for x in [-2.20, -1.55, -0.90, 0.90, 1.55, 2.20]:
		_add_box(counter, "Billing counter vertical brass fascia inlay", Vector3(x, 0.70, 0.695), Vector3(0.025, 0.54, 0.015), Color("bd9657"), 0.008, 0.30)
	for z in [-0.62, 0.62]:
		_add_box(counter, "Billing counter walnut side end", Vector3(0, 0.70, z), Vector3(4.90, 0.07, 0.035), Color("826044"), 0.018, 0.42)
	_add_box(counter, "Billing counter brass toe kick", Vector3(0, 0.355, 0.0), Vector3(4.98, 0.035, 1.39), Color("b18c52"), 0.018, 0.30)
	_add_box(counter, "Billing counter quartz worktop", Vector3(0, 1.17, 0), Vector3(5.30, 0.16, 1.56), Color("eee3cf"), 0.12, 0.30)
	_add_box(counter, "Billing counter warm ceiling panel", Vector3(0, 3.35, 0), Vector3(2.4, 0.10, 1.0), Color("e6d5aa"), 0.06, 0.38)
	_add_warm_area_light(counter, "Warm billing counter light", Vector3(0, 3.22, 0), 1.15, 7.0)
	_add_box(counter, "Billing counter dark worktop edge", Vector3(0, 1.105, 0), Vector3(5.22, 0.035, 1.52), Color("46403a"), 0.035, 0.38)
	_add_box(counter, "Packing bay inset shadow", Vector3(-1.60, 1.255, 0.0), Vector3(2.20, 0.016, 1.40), Color("b8ad99"), 0.035, 0.62)
	_add_box(counter, "POS zone leather mat", Vector3(1.16, 1.258, -0.11), Vector3(1.18, 0.018, 0.96), Color("515653"), 0.06, 0.62)
	_add_label(counter, "PACKING • 20 BOXES", Vector3(-1.60, 0.78, 0.72), 0.075, Color("fff5e6"))
	_add_box(counter, "Billing POS brass pedestal base", Vector3(1.12, 1.31, -0.28), Vector3(0.48, 0.10, 0.36), Color("bd9657"), 0.055, 0.32)
	_add_box(counter, "Billing POS monitor stand", Vector3(1.12, 1.48, -0.28), Vector3(0.13, 0.30, 0.12), Color("596267"), 0.035, 0.38)
	_add_box(counter, "Billing POS monitor rear housing", Vector3(1.12, 1.77, -0.28), Vector3(0.92, 0.60, 0.11), Color("20282d"), 0.07, 0.35)
	_add_box(counter, "Billing POS screen inner bezel", Vector3(1.12, 1.78, -0.218), Vector3(0.80, 0.47, 0.018), Color("0d171c"), 0.035, 0.25)
	_add_box(counter, "Billing POS bright readable display", Vector3(1.12, 1.79, -0.205), Vector3(0.72, 0.39, 0.012), Color("a6e4dc"), 0.025, 0.22)
	_add_box(counter, "POS display header strip", Vector3(1.12, 1.94, -0.196), Vector3(0.68, 0.055, 0.008), Color("27685f"), 0.01, 0.32)
	_add_box(counter, "POS display header logo", Vector3(0.88, 1.94, -0.190), Vector3(0.12, 0.025, 0.008), Color("fff0d4"), 0.005, 0.24)
	for row in range(3):
		var line_y := 1.87 - float(row) * 0.085
		_add_box(counter, "POS display order text line", Vector3(1.05, line_y, -0.192), Vector3(0.35 - float(row % 2) * 0.06, 0.018, 0.008), Color("43877d"), 0.006, 0.4)
		_add_box(counter, "POS display price indicator", Vector3(1.38, line_y, -0.192), Vector3(0.10, 0.027, 0.008), Color("d88e37"), 0.006, 0.35)
	_add_box(counter, "POS display confirm button", Vector3(1.37, 1.62, -0.192), Vector3(0.20, 0.045, 0.008), Color("438b4d"), 0.012, 0.32)
	_add_box(counter, "Billing POS keyboard base", Vector3(1.03, 1.39, 0.20), Vector3(0.82, 0.055, 0.34), Color("32393d"), 0.045, 0.42)
	for row in range(3):
		for column in range(10):
			var key_x := 0.69 + float(column) * 0.075
			var key_z := 0.09 + float(row) * 0.085
			_add_box(counter, "Billing POS keyboard key", Vector3(key_x, 1.422, key_z), Vector3(0.052, 0.014, 0.050), Color("d4d8d2") if (row + column) % 4 != 0 else Color("c29a58"), 0.008, 0.5)
	_add_box(counter, "Billing POS space bar", Vector3(1.03, 1.423, 0.355), Vector3(0.30, 0.015, 0.035), Color("d4d8d2"), 0.008, 0.5)
	_add_box(counter, "Billing POS mouse", Vector3(1.57, 1.42, 0.22), Vector3(0.15, 0.06, 0.20), Color("30383d"), 0.055, 0.36)
	_add_box(counter, "Billing POS mouse button", Vector3(1.57, 1.454, 0.17), Vector3(0.025, 0.008, 0.07), Color("bd9657"), 0.004, 0.30)
	_add_box(counter, "Receipt printer", Vector3(2.05, 1.31, -0.18), Vector3(0.42, 0.24, 0.32), Color("d6dcda"), 0.05)
	_add_box(counter, "Receipt printer display", Vector3(2.05, 1.36, -0.005), Vector3(0.22, 0.075, 0.02), Color("a6e4dc"), 0.015, 0.24)
	_add_box(counter, "Receipt paper slot", Vector3(2.05, 1.44, -0.18), Vector3(0.24, 0.025, 0.035), Color("252a2d"), 0.008, 0.4)
	_add_box(counter, "Receipt paper", Vector3(2.05, 1.51, -0.18), Vector3(0.18, 0.13, 0.025), Color("fffdf5"))
	_add_label(counter, "AFC • ORDER & PICKUP", Vector3(0, 1.30, 0.76), 0.10, Color("fff5e6"))
	var cash_shelf := Node3D.new()
	cash_shelf.name = "Daily customer payment display"
	cash_shelf.position = Vector3(0.18, 1.28, 0.18)
	counter.add_child(cash_shelf)
	_add_box(cash_shelf, "Cash display tray", Vector3(0, 0.015, 0), Vector3(0.86, 0.07, 0.66), Color("59645b"), 0.04, 0.45)
	sales_cash_bundle = Node3D.new()
	sales_cash_bundle.name = "Growing customer banknote stack"
	sales_cash_bundle.position = Vector3(0, 0.07, 0)
	cash_shelf.add_child(sales_cash_bundle)
	sales_cash_label = _add_label(cash_shelf, "SALES $%d" % (sales_count * PACK_PRICE), Vector3(0, 0.12, 0.42), 0.065, Color("fff5e6"))
	sales_cash_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rebuild_sales_cash_stack()
	_register_obstacle(Vector2(counter_position.x, counter_position.z), Vector2(5.25, 1.72))
	_add_service_floor_tile("bill_customer", counter_position + BILLING_WORK_OFFSET, MAT_BLUE, Vector2(3.2, 2.8), 0.24)
	_activate_customer_exterior()
	_build_customer()
	if customer_root:
		customer_root.visible = false
		customer_flow = CustomerFlow.NONE
	_show_toast("Counter ready — build your first table to welcome customers")

func _build_starter_table(slot_position: Vector3, table_index: int) -> Node3D:
	var table := Node3D.new()
	table.name = "Bought dining table %d of %d" % [table_index + 1, DINING_TABLE_COUNT]
	table.position = slot_position
	table.scale = Vector3.ONE * 0.72
	add_child(table)
	if table_index == 0:
		dining_table_root = table
		_build_dining_table(table, false, true)
	else:
		_build_dining_table(table, false)
	_register_obstacle(Vector2(slot_position.x, slot_position.z), Vector2(3.24, 2.63))
	if table_index == 0:
		_add_service_floor_tile("clean_table", slot_position + Vector3(0.0, 0.04, -3.1), Color("4d9ac4"))
		_add_service_floor_tile("serve_customer", slot_position + Vector3(0.0, 0.04, 3.15), Color("42a85a"))
	return table

func _build_hr_office(slot_position: Vector3) -> Node3D:
	var office := Node3D.new()
	office.name = "AFC human resources office"
	office.position = slot_position
	add_child(office)
	hr_office_root = office
	_add_box(office, "HR office warm floor", Vector3(0.0, 0.035, 0.0), Vector3(4.8, 0.07, 4.4), Color("d8c8a9"), 0.08, 0.72)
	for wall in [
		{"position": Vector3(0.0, 1.15, -2.12), "size": Vector3(4.8, 2.3, 0.16)},
		{"position": Vector3(-2.32, 1.15, 0.0), "size": Vector3(0.16, 2.3, 4.4)},
		{"position": Vector3(2.32, 1.15, 0.0), "size": Vector3(0.16, 2.3, 4.4)},
		{"position": Vector3(-1.37, 1.15, 2.12), "size": Vector3(2.1, 2.3, 0.16)},
		{"position": Vector3(1.37, 1.15, 2.12), "size": Vector3(2.1, 2.3, 0.16)},
	]:
		_add_box(office, "HR office cream wall", wall["position"], wall["size"], Color("f4e7d2"), 0.04, 0.82)
	_add_box(office, "HR office red sign backing", Vector3(0.0, 1.95, -2.015), Vector3(1.75, 0.48, 0.05), MAT_RED_DARK, 0.045)
	var office_sign := _add_label(office, "AFC • HUMAN RESOURCES", Vector3(0.0, 2.0, -1.97), 0.105, Color("fff5e6"))
	office_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_add_box(office, "HR office manager desk", Vector3(0.0, 0.78, -0.75), Vector3(2.35, 0.16, 0.92), Color("634632"), 0.08, 0.46)
	_add_box(office, "HR office desk pedestal", Vector3(-0.88, 0.40, -0.75), Vector3(0.34, 0.72, 0.82), Color("493b32"), 0.05, 0.45)
	_add_box(office, "HR office application clipboard", Vector3(0.0, 0.90, -0.72), Vector3(0.58, 0.035, 0.42), Color("fff5df"), 0.025, 0.45)
	_add_label(office, "HIRE", Vector3(0.0, 0.93, -0.70), 0.09, Color("2c3235"))
	_add_box(office, "HR office employee chair seat", Vector3(0.0, 0.50, 0.05), Vector3(0.78, 0.12, 0.72), Color("a93831"), 0.08, 0.42)
	_add_box(office, "HR office employee chair back", Vector3(0.0, 0.90, 0.35), Vector3(0.78, 0.72, 0.12), Color("a93831"), 0.08, 0.42)
	_add_box(office, "HR office filing cabinet", Vector3(1.65, 0.68, -1.22), Vector3(0.72, 1.28, 0.66), Color("aeb8b7"), 0.06, 0.55)
	for drawer_y in [0.35, 0.69, 1.03]:
		_add_box(office, "HR office filing drawer", Vector3(1.65, drawer_y, -0.875), Vector3(0.58, 0.26, 0.025), Color("d8dfd8"), 0.025, 0.45)
		_add_box(office, "HR office filing drawer handle", Vector3(1.65, drawer_y, -0.85), Vector3(0.16, 0.025, 0.025), Color("4d5b5e"), 0.008)
	_add_box(office, "HR office ceiling pendant", Vector3(0.0, 2.36, 0.0), Vector3(1.45, 0.08, 1.1), Color("f5e7c7"), 0.05, 0.42)
	_add_warm_area_light(office, "HR office warm recruitment light", Vector3(0.0, 2.2, 0.0), 1.35, 7.0)
	_add_service_floor_tile("hr_recruit", slot_position + Vector3(0.0, 0.04, 3.1), Color("4d9ac4"), Vector2(2.8, 2.4))
	_register_obstacle(Vector2(slot_position.x, slot_position.z - 2.12), Vector2(4.8, 0.35))
	_register_obstacle(Vector2(slot_position.x - 2.32, slot_position.z), Vector2(0.35, 4.4))
	_register_obstacle(Vector2(slot_position.x + 2.32, slot_position.z), Vector2(0.35, 4.4))
	_register_obstacle(Vector2(slot_position.x - 1.9, slot_position.z + 2.12), Vector2(0.9, 0.35))
	_register_obstacle(Vector2(slot_position.x + 1.9, slot_position.z + 2.12), Vector2(0.9, 0.35))
	return office

func _build_fries_conveyor_machine(slot_position: Vector3) -> Node3D:
	var machine := Node3D.new()
	machine.name = "AFC fries tunnel conveyor machine"
	machine.position = slot_position
	add_child(machine)
	fries_machine_root = machine
	fries_machine_products.clear()

	_add_box(machine, "Fries line conveyor chassis", Vector3(0.0, 0.28, 0.0), Vector3(8.15, 0.48, 1.65), Color("286d69"), 0.12, 0.38)
	_add_box(machine, "Fries line stainless belt", Vector3(0.0, 0.55, 0.0), Vector3(8.0, 0.10, 1.42), Color("85d8d1"), 0.06, 0.30)
	for x in [-3.6, -2.4, -1.2, 0.0, 1.2, 2.4, 3.6]:
		_add_box(machine, "Conveyor belt cross slat", Vector3(x, 0.61, 0.0), Vector3(0.045, 0.025, 1.34), Color("b6eee8"), 0.008, 0.36)
	for x in [-3.8, -1.9, 0.0, 1.9, 3.8]:
		_add_cylinder(machine, "Conveyor roller", Vector3(x, 0.34, 0.0), 0.115, 0.115, 1.52, Color("50616a"), 12, Vector3(PI * 0.5, 0.0, 0.0))
		_add_cylinder(machine, "Conveyor roller end cap", Vector3(x, 0.34, 0.79), 0.15, 0.15, 0.09, Color("5278a0"), 12, Vector3(PI * 0.5, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_add_box(machine, "Conveyor raised safety rail", Vector3(0.0, 0.72, side * 0.76), Vector3(8.0, 0.18, 0.08), Color("197f79"), 0.03, 0.34)

	for x in [-2.05, 2.05]:
		_add_box(machine, "Mint tunnel support column", Vector3(x, 1.72, 0.0), Vector3(0.56, 3.10, 1.72), Color("22c5ae"), 0.10, 0.30)
		_add_box(machine, "Tunnel support foot", Vector3(x, 0.14, 0.0), Vector3(0.78, 0.20, 1.88), Color("159e91"), 0.06, 0.32)
	_add_box(machine, "Mint fries tunnel roof", Vector3(0.0, 3.25, 0.0), Vector3(4.62, 0.68, 1.72), Color("20c4ad"), 0.12, 0.32)
	_add_box(machine, "Dark visible tunnel interior", Vector3(0.0, 1.84, -0.78), Vector3(3.55, 2.12, 0.12), Color("244f50"), 0.04, 0.42)
	_add_box(machine, "Warm tunnel interior roof", Vector3(0.0, 2.78, 0.0), Vector3(3.50, 0.10, 1.42), Color("f5a85e"), 0.035, 0.35)
	var tunnel_light := OmniLight3D.new()
	tunnel_light.name = "Fries tunnel product light"
	tunnel_light.position = Vector3(0.0, 2.45, 0.15)
	tunnel_light.light_color = Color("ffe2a1")
	tunnel_light.light_energy = 1.8
	tunnel_light.omni_range = 4.2
	tunnel_light.shadow_enabled = false
	machine.add_child(tunnel_light)

	var machine_title := _add_label(machine, "FRESH FRIES", Vector3(0.0, 3.28, 0.90), 0.11, Color("fff5d8"))
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_title.outline_modulate = Color("176b62")

	for index in range(2):
		var product := _build_fries_tray(machine, "Moving fries batch %d" % (index + 1))
		product.position = Vector3(-2.75 + float(index) * 2.3, 0.64, 0.0)
		fries_machine_products.append(product)
	var output_box := _build_fries_tray(machine, "Finished fries in red AFC carton")
	output_box.position = Vector3(3.48, 0.64, 0.0)
	output_box.scale = Vector3.ONE * 1.22
	_register_obstacle(Vector2(slot_position.x, slot_position.z), Vector2(8.2, 1.85))
	return machine

func _build_fries_tray(parent: Node3D, tray_name: String) -> Node3D:
	var tray := Node3D.new()
	tray.name = tray_name
	parent.add_child(tray)
	_add_box(tray, "Red open-top fries carton base", Vector3(0.0, 0.10, 0.0), Vector3(0.76, 0.16, 0.62), Color("e23f32"), 0.045, 0.42)
	_add_box(tray, "Fries carton front wall", Vector3(0.0, 0.31, 0.29), Vector3(0.78, 0.35, 0.07), Color("ed4b39"), 0.04, 0.40)
	_add_box(tray, "Fries carton back wall", Vector3(0.0, 0.31, -0.29), Vector3(0.78, 0.35, 0.07), Color("d9362d"), 0.04, 0.42)
	for side in [-1.0, 1.0]:
		_add_box(tray, "Fries carton side wall", Vector3(side * 0.355, 0.31, 0.0), Vector3(0.07, 0.35, 0.52), Color("e34635"), 0.035, 0.42)
	_add_box(tray, "AFC carton yellow badge", Vector3(0.0, 0.24, 0.335), Vector3(0.26, 0.12, 0.025), Color("ffd84f"), 0.045, 0.38)
	for fry_index in range(8):
		var fry_x := -0.25 + float(fry_index % 4) * 0.16
		var fry_z := -0.14 + float(floori(float(fry_index) / 4)) * 0.28
		var fry_height := 0.46 + float((fry_index * 3) % 4) * 0.07
		_add_box(tray, "Visible golden potato fry", Vector3(fry_x, 0.48 + fry_height * 0.5, fry_z), Vector3(0.09, fry_height, 0.09), Color("ffce45") if fry_index % 2 == 0 else Color("f6ae30"), 0.018, 0.48)
	return tray

func _animate_fries_machine(delta: float) -> void:
	if not is_instance_valid(fries_machine_root):
		return
	for product in fries_machine_products:
		if not is_instance_valid(product):
			continue
		product.position.x += delta * 0.78
		if product.position.x > 2.55:
			product.position.x = -3.45

func _build_dining_bins() -> void:
	# The paired waste and recycling bins share one easy-to-find disposal bay.
	trash_disposal_position = Vector3(8.25, 0.17, 9.2)
	_add_service_floor_tile("dispose_trash", trash_disposal_position, Color("e07832"))
	_add_label(self, "THROW AWAY", Vector3(8.25, 0.22, 9.85), 0.08, Color("fff5e6"))
	for bin_data in [
		{"position": Vector3(9.55, 0.20, 9.2), "colour": Color("c6372e"), "label": "WASTE", "icon": "•"},
		{"position": Vector3(11.35, 0.20, 9.2), "colour": Color("3f934d"), "label": "RECYCLE", "icon": "↻"},
	]:
		var bin_root := Node3D.new()
		bin_root.name = "%s dining bin" % String(bin_data["label"])
		bin_root.position = bin_data["position"] as Vector3
		bin_root.scale = Vector3.ONE * 1.5
		add_child(bin_root)
		var bin_colour: Color = bin_data["colour"] as Color
		_add_box(bin_root, "Dining bin dark wheel base", Vector3(0, 0.18, 0), Vector3(0.86, 0.22, 0.76), Color("343a3d"), 0.08)
		_add_box(bin_root, "Dining bin coloured body", Vector3(0, 0.70, 0), Vector3(0.78, 0.96, 0.68), bin_colour, 0.10, 0.42)
		_add_box(bin_root, "Dining bin black lid", Vector3(0, 1.22, 0), Vector3(0.88, 0.14, 0.78), Color("252a2d"), 0.08)
		_add_box(bin_root, "Dining bin throw opening", Vector3(0, 1.30, -0.13), Vector3(0.40, 0.025, 0.29), Color("101416"), 0.03)
		_add_box(bin_root, "Dining bin cream sign", Vector3(0, 0.78, 0.36), Vector3(0.56, 0.34, 0.025), Color("fff0d5"), 0.03)
		var bin_icon := _add_label(bin_root, String(bin_data["icon"]), Vector3(0, 0.84, 0.39), 0.16, bin_colour)
		bin_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var bin_label := _add_label(bin_root, String(bin_data["label"]), Vector3(0, 0.53, 0.39), 0.075, Color("202124"))
		bin_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		for x in [-0.30, 0.30]:
			_add_cylinder(bin_root, "Dining bin wheel", Vector3(x, 0.13, 0.24), 0.10, 0.10, 0.10, Color("1c2022"), 10, Vector3(0, 0, PI * 0.5))
		_register_obstacle(Vector2(bin_root.position.x, bin_root.position.z), Vector2(1.45, 1.30))
		if String(bin_data["label"]) == "WASTE":
			waste_bin_root = bin_root
	waste_bin_opening = waste_bin_root.to_global(Vector3(0.0, 1.28, -0.13)) if waste_bin_root else Vector3.ZERO

func _build_hen_hut() -> Node3D:
	# The hut is outside the rear service door. Its fenced pen holds a visible
	# flock of 200 low-poly hens, built efficiently with two MultiMesh batches.
	var hut := Node3D.new()
	hut.name = "AFC 200 hen hut"
	hut.position = Vector3(0.0, -0.36, -23.4)
	add_child(hut)
	hen_hut_root = hut
	_add_service_floor_tile("collect_raw", Vector3(0.0, 0.04, -22.3), Color("eabf45"))
	_add_box(hut, "Hen hut timber base", Vector3(0, 0.30, -1.65), Vector3(7.4, 0.52, 3.75), Color("9a623d"), 0.10, 0.7)
	_add_box(hut, "Hen hut cream body", Vector3(0, 1.78, -1.65), Vector3(7.0, 2.52, 3.58), MAT_CREAM, 0.08, 0.72)
	# Open-top hen house: the camera can always see the flock in its fenced run.
	_add_box(hut, "Hen hut red wall cap", Vector3(0, 3.06, -1.65), Vector3(7.28, 0.16, 3.82), MAT_RED, 0.05, 0.5)
	_add_box(hut, "Hen hut door frame", Vector3(0, 1.35, 0.22), Vector3(1.85, 2.25, 0.11), Color("5d3625"), 0.06)
	hen_hut_door = Node3D.new()
	hen_hut_door.name = "Animated hen hut door"
	hen_hut_door.position = Vector3(-0.87, 0.24, 0.285)
	hut.add_child(hen_hut_door)
	_add_box(hen_hut_door, "Hen hut wooden door", Vector3(0.87, 1.12, 0), Vector3(1.68, 2.15, 0.07), Color("b66b3b"), 0.05, 0.7)
	_add_box(hut, "Hen hut AFC sign", Vector3(0, 2.58, 0.32), Vector3(3.35, 0.52, 0.04), MAT_RED, 0.03)
	_add_label(hut, "AFC HEN HUT • 200 HENS", Vector3(0, 2.52, 0.36), 0.13, Color.WHITE)
	_build_hen_fence(hut)
	_build_hen_flock(hut)
	return hut

func _build_hen_fence(hut: Node3D) -> void:
	var wood := Color("94613c")
	# Pen is six metres wide with a 2.2 m gate facing the rear shop door.
	for x in [-4.0, 4.0]:
		_add_box(hut, "Hen pen side fence", Vector3(x, 0.65, -1.3), Vector3(0.13, 1.25, 6.4), wood, 0.02)
	for x in [-4.0, -2.0, -1.1, 1.1, 2.0, 4.0]:
		_add_box(hut, "Hen pen front fence", Vector3(x, 0.65, 1.9), Vector3(1.65 if absf(x) > 1.5 else 0.75, 1.25, 0.13), wood, 0.02)
	_add_box(hut, "Hen pen rear fence", Vector3(0, 0.65, -4.5), Vector3(8.1, 1.25, 0.13), wood, 0.02)
	for x in [-4.0, -2.0, -1.1, 1.1, 2.0, 4.0]:
		for z in [1.9, -4.5]:
			_add_box(hut, "Hen pen fence post", Vector3(x, 0.72, z), Vector3(0.18, 1.48, 0.18), Color("70452e"), 0.03)
	# Fence blockers keep the player in the gate route rather than walking into hens.
	_register_obstacle(Vector2(-4.0, -24.7), Vector2(0.30, 6.6))
	_register_obstacle(Vector2(4.0, -24.7), Vector2(0.30, 6.6))
	_register_obstacle(Vector2(0.0, -27.9), Vector2(8.2, 0.30))
	_register_obstacle(Vector2(-2.55, -21.5), Vector2(2.9, 0.30))
	_register_obstacle(Vector2(2.55, -21.5), Vector2(2.9, 0.30))

func _build_hen_flock(hut: Node3D) -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radial_segments = 8
	body_mesh.rings = 5
	var body_multi := MultiMesh.new()
	body_multi.transform_format = MultiMesh.TRANSFORM_3D
	body_multi.mesh = body_mesh
	body_multi.instance_count = 200
	for i in range(200):
		var column := i % 20
		var row := i / 20
		# Put the flock in the front fenced run, fully visible from the shop.
		var local_pos := Vector3(-3.25 + float(column) * 0.34 + sin(float(i) * 1.7) * 0.05, 0.30 + float(i % 3) * 0.025, 0.28 + float(row) * 0.14)
		body_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.27, 0.25)), local_pos))
	var bodies := MultiMeshInstance3D.new()
	bodies.name = "200 white hens"
	bodies.multimesh = body_multi
	bodies.material_override = _material(Color("f4eee0"), 0.0, 0.8)
	hut.add_child(bodies)
	var comb_mesh := SphereMesh.new()
	comb_mesh.radial_segments = 7
	comb_mesh.rings = 4
	var comb_multi := MultiMesh.new()
	comb_multi.transform_format = MultiMesh.TRANSFORM_3D
	comb_multi.mesh = comb_mesh
	comb_multi.instance_count = 200
	for i in range(200):
		var column := i % 20
		var row := i / 20
		var local_pos := Vector3(-3.25 + float(column) * 0.34 + sin(float(i) * 1.7) * 0.05, 0.48 + float(i % 3) * 0.025, 0.33 + float(row) * 0.14)
		comb_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.065, 0.09, 0.07)), local_pos))
	var combs := MultiMeshInstance3D.new()
	combs.name = "200 red hen combs"
	combs.multimesh = comb_multi
	combs.material_override = _material(Color("d94836"), 0.0, 0.75)
	hut.add_child(combs)
	# A small set of foreground hens use full parts so the flock clearly reads
	# as chickens even on a phone screen; the remaining hens stay batched.
	for i in range(12):
		var featured_hen := Node3D.new()
		featured_hen.name = "Visible hen"
		featured_hen.position = Vector3(-2.8 + float(i % 6) * 1.08, 0.30, 0.55 + float(i / 6) * 0.62)
		hut.add_child(featured_hen)
		_add_sphere(featured_hen, "Hen body", Vector3.ZERO, Vector3(0.34, 0.38, 0.40), Color("f7f0e2"), 10, 6)
		_add_sphere(featured_hen, "Hen head", Vector3(0.24, 0.28, 0.12), Vector3(0.18, 0.20, 0.18), Color("fff8ea"), 9, 6)
		_add_sphere(featured_hen, "Hen red comb", Vector3(0.22, 0.48, 0.12), Vector3(0.07, 0.10, 0.07), Color("db4437"), 8, 5)
		_add_box(featured_hen, "Hen yellow beak", Vector3(0.42, 0.27, 0.12), Vector3(0.16, 0.08, 0.10), Color("f2b83c"), 0.02)
		_add_sphere(featured_hen, "Hen black eye", Vector3(0.33, 0.34, 0.255), Vector3(0.027, 0.035, 0.02), Color("202124"), 7, 4)
		_add_sphere(featured_hen, "Hen tail", Vector3(-0.30, 0.18, -0.05), Vector3(0.20, 0.24, 0.18), Color("eee5d3"), 8, 5)

func _update_hen_hut_interaction(delta: float) -> void:
	if starter_hut_paid < 200 or not hen_hut_root:
		return
	var hut_door_world := hen_hut_root.global_position + Vector3(0, 0, 0.2)
	var near_hut := player_position.distance_to(hut_door_world) < 2.1
	if hen_hut_door:
		var desired_angle := deg_to_rad(-88.0) if near_hut else 0.0
		hen_hut_door.rotation.y = lerp_angle(hen_hut_door.rotation.y, desired_angle, delta * 4.5)

func _service_is_ready() -> bool:
	return shop_owned and starter_fryer_paid >= 150 and starter_hut_paid >= 200 and starter_table_count >= 1 and fryer_station != null and hen_hut_root != null and dining_table_root != null

func _service_stand_position(stage: ServiceStage) -> Vector3:
	match stage:
		ServiceStage.COLLECT_RAW:
			return Vector3(0.0, 0.22, -22.3)
		ServiceStage.LOAD_FRYER, ServiceStage.FRYING:
			return fryer_station.global_position + Vector3(0.0, 0.04, 2.15) if fryer_station else Vector3.ZERO
		ServiceStage.COLLECT_COOKED:
			return fryer_station.get_output_table().global_position + Vector3(0.0, 0.04, 2.30) if fryer_station and fryer_station.get_output_table() else Vector3.ZERO
		ServiceStage.STAGE_ORDER, ServiceStage.WAIT_CUSTOMER, ServiceStage.BILL_CUSTOMER:
			return billing_counter_position + BILLING_WORK_OFFSET
		ServiceStage.CUSTOMER:
			return billing_counter_position + BILLING_WORK_OFFSET
		ServiceStage.CLEAN_TABLE:
			return dining_table_root.global_position + Vector3(0.0, 0.04, -3.1) if dining_table_root else Vector3.ZERO
		ServiceStage.DISPOSE_TRASH:
			return trash_disposal_position
	return Vector3.ZERO

func _refresh_service_stage() -> void:
	var next_stage := ServiceStage.BUILD
	if _service_is_ready():
		if table_trash_count > 0 and carried_trash_count < MAX_CARRIED_TRASH:
			next_stage = ServiceStage.CLEAN_TABLE
		elif carried_trash_count > 0:
			next_stage = ServiceStage.DISPOSE_TRASH
		elif customer_flow in [CustomerFlow.RECEIVING, CustomerFlow.WALKING_TO_TABLE, CustomerFlow.EATING, CustomerFlow.LEAVING]:
			next_stage = ServiceStage.CUSTOMER
		elif carried_chickens > 0:
			next_stage = ServiceStage.LOAD_FRYER
		elif raw_chicken > 0:
			next_stage = ServiceStage.FRYING
		elif cooked_pieces > 0 and carried_order_pieces == 0:
			next_stage = ServiceStage.COLLECT_COOKED
		elif carried_order_pieces > 0:
			next_stage = ServiceStage.STAGE_ORDER
		elif staged_order_pieces > 0 and order_staged_for_billing:
			next_stage = ServiceStage.BILL_CUSTOMER if customer_flow == CustomerFlow.WAITING else ServiceStage.WAIT_CUSTOMER
		else:
			next_stage = ServiceStage.COLLECT_RAW
	if next_stage == service_stage:
		return
	service_stage = next_stage
	_update_marker()
	_update_ui()

func _update_live_service(delta: float) -> void:
	if not _service_is_ready():
		_refresh_service_stage()
		return
	if service_action_time > 0.0:
		service_action_time = maxf(0.0, service_action_time - delta)
		player_working = true
		if service_stage == ServiceStage.BILL_CUSTOMER and status_label:
			var elapsed := service_action_duration - service_action_time
			if elapsed < BILLING_PROCESS_DURATION / 3.0:
				status_label.text = "Entering the order on the billing computer…"
			elif elapsed < BILLING_PROCESS_DURATION * 2.0 / 3.0:
				status_label.text = "Taking the fried chicken and packing the order…"
			else:
				status_label.text = "Handing the packed AFC box to the customer…"
		_animate_player()
		if service_action_time == 0.0:
			if trash_pickup_in_progress:
				_finish_table_trash_pickup()
			else:
				_finish_live_service_action()
		return
	if customer_flow == CustomerFlow.WAITING:
		if billing_worker_timer > 0.0:
			if player_position.distance_to(_service_stand_position(ServiceStage.BILL_CUSTOMER)) <= BILLING_WORK_RADIUS:
				billing_worker_timer = 0.0
			else:
				billing_worker_timer = maxf(0.0, billing_worker_timer - delta)
				if status_label:
					status_label.text = "Counter crew is billing the order…"
				if billing_worker_timer == 0.0 and customer_root and staged_order_pieces > 0:
					customer_flow = CustomerFlow.RECEIVING
					_deliver_order_to_customer(true)
					return
		else:
			customer_wait_elapsed += delta
	else:
		billing_worker_timer = 0.0
	if table_trash_count > 0 and carried_trash_count < MAX_CARRIED_TRASH and dining_table_root and player_position.distance_to(dining_table_root.global_position) <= 3.75:
		_start_table_trash_pickup()
		return
	if customer_flow == CustomerFlow.RECEIVING:
		player_working = not billing_worker_handoff_active
		_animate_player()
		return
	player_working = false
	if customer_flow == CustomerFlow.EATING:
		customer_eating_time += delta
		if customer_eating_time >= CUSTOMER_EATING_DURATION_SECONDS:
			_complete_customer_payment()
		return
	if customer_flow == CustomerFlow.NONE:
		customer_spawn_time = maxf(0.0, customer_spawn_time - delta)
		if customer_spawn_time == 0.0:
			_start_next_customer()
	_refresh_service_stage()
	if carried_trash_count > 0 and player_position.distance_to(trash_disposal_position) <= 1.8:
		service_stage = ServiceStage.DISPOSE_TRASH
		_start_live_service_action(float(carried_trash_items.size()) * 0.92 + 0.2, "Throwing the rubbish into the bin one piece at a time…")
		return
	if carried_chickens == 0 and player_position.distance_to(_service_stand_position(ServiceStage.COLLECT_RAW)) <= 2.0:
		service_stage = ServiceStage.COLLECT_RAW
		_start_live_service_action(1.7, "Collecting fresh chicken from the hen hut…")
		return
	if carried_chickens > 0 and player_position.distance_to(_service_stand_position(ServiceStage.LOAD_FRYER)) <= 2.0:
		service_stage = ServiceStage.LOAD_FRYER
		_start_live_service_action(1.5, "Loading fresh chicken into the rotary fryer…")
		return
	if cooked_pieces > 0 and carried_order_pieces == 0 and player_position.distance_to(_service_stand_position(ServiceStage.COLLECT_COOKED)) <= 2.0:
		service_stage = ServiceStage.COLLECT_COOKED
		_start_live_service_action(1.4, "Collecting crispy chicken into the AFC basket…")
		return
	if carried_order_pieces > 0 and player_position.distance_to(_service_stand_position(ServiceStage.STAGE_ORDER)) <= 2.0:
		if staged_order_piece_counts.size() < MAX_STAGED_ORDERS:
			service_stage = ServiceStage.STAGE_ORDER
			_start_live_service_action(1.0, "Placing the fried chicken on the order table…")
			return
		elif status_label:
			status_label.text = "Packing table full — bill a waiting customer first"
	var owner_at_billing := player_position.distance_to(_service_stand_position(ServiceStage.BILL_CUSTOMER)) <= BILLING_WORK_RADIUS
	if employees > 0 and is_instance_valid(billing_staff_root) and staged_order_pieces > 0 and order_staged_for_billing and customer_flow == CustomerFlow.WAITING and customer_root and not owner_at_billing and customer_seat_index < 0 and _customer_has_available_seat():
		customer_seat_index = dining_table_component.reserve_seat()
	if employees > 0 and is_instance_valid(billing_staff_root) and staged_order_pieces > 0 and order_staged_for_billing and customer_flow == CustomerFlow.WAITING and customer_root and customer_seat_index >= 0 and not owner_at_billing:
		if billing_worker_timer <= 0.0:
			billing_worker_timer = BILLING_PROCESS_DURATION
	if staged_order_pieces > 0 and order_staged_for_billing and customer_flow == CustomerFlow.WAITING and customer_root and player_position.distance_to(_service_stand_position(ServiceStage.BILL_CUSTOMER)) <= BILLING_WORK_RADIUS:
		if customer_seat_index < 0 and _customer_has_available_seat():
			customer_seat_index = dining_table_component.reserve_seat()
		if customer_seat_index >= 0:
			service_stage = ServiceStage.BILL_CUSTOMER
			_start_live_service_action(BILLING_PROCESS_DURATION, "Entering the order on the billing computer…")

func _start_live_service_action(duration: float, message: String) -> void:
	service_action_time = duration
	service_action_duration = duration
	player_working = true
	move_direction = Vector2.ZERO
	player_velocity = Vector2.ZERO
	if service_stage == ServiceStage.BILL_CUSTOMER and customer_root:
		var pos_target := billing_counter_position + Vector3(1.12, 1.45, -0.28)
		_face_person_toward(player_root, pos_target, 1.0)
		customer_flow = CustomerFlow.RECEIVING
		_animate_customer()
	elif service_stage == ServiceStage.STAGE_ORDER:
		_face_person_toward(player_root, billing_counter_position, 1.0)
	elif service_stage == ServiceStage.DISPOSE_TRASH:
		_start_trash_disposal_animation()
	if status_label:
		status_label.text = message
	_animate_player()

func _finish_live_service_action() -> void:
	player_working = false
	trash_pickup_in_progress = false
	first_service_guidance_complete = true
	match service_stage:
		ServiceStage.COLLECT_RAW:
			if carried_chickens == 0:
				carried_chickens = 7
				_update_carried_food_visuals()
				_show_toast("Collected 7 fresh chickens in your AFC basket")
		ServiceStage.LOAD_FRYER:
			if carried_chickens > 0:
				raw_chicken += carried_chickens
				carried_chickens = 0
				_update_carried_food_visuals()
				_show_toast("Fresh chicken loaded — the rotary mill is starting")
		ServiceStage.COLLECT_COOKED:
			carried_order_pieces = mini(cooked_pieces, 4)
			cooked_pieces -= carried_order_pieces
			staged_order_pieces = 0
			order_staged_for_billing = false
			_remove_conveyor_food(carried_order_pieces)
			_update_carried_food_visuals()
			_show_toast("Collected %d crispy pieces for the AFC order" % carried_order_pieces)
		ServiceStage.STAGE_ORDER:
			_stage_order_on_counter()
		ServiceStage.BILL_CUSTOMER:
			_deliver_order_to_customer()
		ServiceStage.DISPOSE_TRASH:
			for item in carried_trash_items:
				if is_instance_valid(item):
					item.queue_free()
			carried_trash_items.clear()
			carried_trash_count = 0
			_update_carried_trash_display()
			_show_toast("All rubbish has been sorted into the waste bin")
	service_action_time = 0.0
	_save_game()
	_refresh_service_stage()
	_update_ui()

func _stage_order_on_counter() -> void:
	if carried_order_pieces <= 0 or not billing_counter_root:
		return
	if staged_order_piece_counts.size() >= MAX_STAGED_ORDERS:
		if status_label:
			status_label.text = "Packing table full — bill a waiting customer first"
		return
	staged_order_piece_counts.append(carried_order_pieces)
	staged_order_pieces += carried_order_pieces
	carried_order_pieces = 0
	order_staged_for_billing = true
	_update_carried_food_visuals()
	_create_staged_order_visual(true)
	_show_toast("Order packed on the counter — %d of %d boxes ready" % [staged_order_piece_counts.size(), MAX_STAGED_ORDERS])

func _create_staged_order_visual(animate: bool) -> void:
	if not billing_counter_root:
		return
	for old_order in staged_order_roots:
		if is_instance_valid(old_order):
			old_order.queue_free()
	staged_order_roots.clear()
	staged_order_root = null
	for index in range(staged_order_piece_counts.size()):
		var column := index % 5
		var row := floori(float(index) / 5.0)
		var position := Vector3(-1.60 + (float(column) - 2.0) * 0.42, 1.47, -0.44 + float(row) * 0.31)
		var order_root := _build_afc_box(billing_counter_root, position, 1.0)
		order_root.scale = Vector3.ONE * 0.90
		order_root.name = "Packed order box %02d of %02d" % [index + 1, MAX_STAGED_ORDERS]
		var order_count := _add_label(order_root, "%d PCS" % staged_order_piece_counts[index], Vector3(0.0, 0.30, 0.0), 0.075, Color("fff5e6"))
		order_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		staged_order_roots.append(order_root)
		if index == 0:
			staged_order_root = order_root
		if animate and index == staged_order_piece_counts.size() - 1:
			order_root.scale = Vector3(0.07, 0.07, 0.07)
			var stage_tween := create_tween()
			stage_tween.set_trans(Tween.TRANS_BACK)
			stage_tween.set_ease(Tween.EASE_OUT)
			stage_tween.tween_property(order_root, "scale", Vector3.ONE * 0.90, 0.42)

func _remove_conveyor_food(count: int) -> void:
	if fryer_station:
		fryer_station.remove_cooked_food(count)

func _start_next_customer() -> void:
	customer_sequence += 1
	customer_species_index = (customer_sequence - 1) % CUSTOMER_ANIMALS.size()
	customer_buckets_total = randi_range(1, 3)
	customer_buckets_remaining = customer_buckets_total
	customer_wait_elapsed = 0.0
	_build_customer(customer_species_index)
	customer_root.set_meta("customer_ticket_number", customer_sequence)
	customer_root.set_meta("customer_buckets_total", customer_buckets_total)
	customer_root.set_meta("customer_buckets_remaining", customer_buckets_remaining)
	customer_root.position = Vector3(0.0, 0.22, 21.55)
	customer_route.clear()
	_set_customer_route(Vector3(0.0, 0.22, 16.55))
	customer_root.rotation.y = 0.0
	customer_root.visible = true
	customer_box.visible = false
	customer_arrival_stage = 0
	customer_arriving = true
	customer_walking_to_table = false
	customer_at_table = false
	customer_sitting = false
	customer_leaving = false
	customer_pose_blend = 0.0
	customer_flow = CustomerFlow.ARRIVING

func _set_customer_route(target: Vector3) -> bool:
	customer_route.clear()
	customer_route_failed = false
	customer_route_target = target
	customer_route_retry_time = 0.0
	if not is_instance_valid(customer_root):
		return false
	var static_blocked_rectangles: Array[Rect2] = []
	for obstacle in static_obstacles:
		static_blocked_rectangles.append(obstacle.grow(0.46))
	var blocked_rectangles: Array[Rect2] = []
	blocked_rectangles.append_array(static_blocked_rectangles)
	var start_id := _customer_navigation_id(customer_root.global_position)
	var target_id := _customer_navigation_id(target)
	if not CUSTOMER_NAV_REGION.has_point(start_id) or not CUSTOMER_NAV_REGION.has_point(target_id):
		push_warning("Customer route endpoint lies outside the navigation region")
		customer_route_failed = true
		customer_route_retry_time = 0.8
		return false
	var path_ids := _find_customer_path(start_id, target_id, blocked_rectangles)
	if path_ids.is_empty():
		customer_route_failed = true
		customer_route_retry_time = 0.8
		if status_label:
			status_label.text = "Customer is waiting for a clear walking path…"
		return false
	for path_id in path_ids:
		var path_point := CUSTOMER_NAV_OFFSET + Vector2(path_id.x, path_id.y) * CUSTOMER_NAV_CELL_SIZE
		var route_point := Vector3(path_point.x, 0.22, path_point.y)
		if customer_route.is_empty() or customer_route.back().distance_to(route_point) > 0.1:
			customer_route.append(route_point)
	if customer_route.is_empty() or customer_route.back().distance_to(target) > 0.1:
		customer_route.append(Vector3(target.x, 0.22, target.z))
	return true

func _retry_failed_customer_route(delta: float) -> void:
	if not customer_route_failed:
		return
	customer_route_retry_time -= delta
	if customer_route_retry_time <= 0.0:
		if _set_customer_route(customer_route_target) and status_label:
			status_label.text = "Customer found a clear walking path"

func _find_customer_path(start_id: Vector2i, target_id: Vector2i, obstacles: Array[Rect2]) -> PackedVector2Array:
	var astar := AStarGrid2D.new()
	astar.region = CUSTOMER_NAV_REGION
	astar.cell_size = Vector2.ONE * CUSTOMER_NAV_CELL_SIZE
	astar.offset = CUSTOMER_NAV_OFFSET
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for obstacle in obstacles:
		var min_x := maxi(0, floori((obstacle.position.x - CUSTOMER_NAV_OFFSET.x) / CUSTOMER_NAV_CELL_SIZE))
		var min_z := maxi(0, floori((obstacle.position.y - CUSTOMER_NAV_OFFSET.y) / CUSTOMER_NAV_CELL_SIZE))
		var max_x := mini(CUSTOMER_NAV_REGION.size.x - 1, ceili((obstacle.end.x - CUSTOMER_NAV_OFFSET.x) / CUSTOMER_NAV_CELL_SIZE))
		var max_z := mini(CUSTOMER_NAV_REGION.size.y - 1, ceili((obstacle.end.y - CUSTOMER_NAV_OFFSET.y) / CUSTOMER_NAV_CELL_SIZE))
		for cell_x in range(min_x, max_x + 1):
			for cell_z in range(min_z, max_z + 1):
				astar.set_point_solid(Vector2i(cell_x, cell_z), true)
	astar.set_point_solid(start_id, false)
	astar.set_point_solid(target_id, false)
	return astar.get_id_path(start_id, target_id)

func _customer_navigation_id(position: Vector3) -> Vector2i:
	return Vector2i(
		roundi((position.x - CUSTOMER_NAV_OFFSET.x) / CUSTOMER_NAV_CELL_SIZE),
		roundi((position.z - CUSTOMER_NAV_OFFSET.y) / CUSTOMER_NAV_CELL_SIZE)
	)

func _move_customer_along_route(delta: float, speed: float) -> bool:
	if not is_instance_valid(customer_root):
		return true
	while not customer_route.is_empty():
		var next_point := customer_route[0]
		customer_root.position = customer_root.position.move_toward(next_point, delta * speed)
		_face_person_toward(customer_root, next_point, delta)
		if customer_root.position.distance_to(next_point) <= 0.10:
			customer_route.pop_front()
			continue
		return false
	return not customer_route_failed

func _start_customer_sitting_animation() -> void:
	if not customer_root or not dining_table_component or customer_seat_index < 0:
		return
	customer_pose_blend = 0.0
	var seated_position := dining_table_component.get_seated_root_position(customer_seat_index)
	var sit_tween := create_tween()
	sit_tween.set_trans(Tween.TRANS_QUAD)
	sit_tween.set_ease(Tween.EASE_OUT)
	sit_tween.tween_property(self, "customer_pose_blend", 1.0, 0.48)
	sit_tween.parallel().tween_property(customer_root, "position:x", seated_position.x, 0.48)
	sit_tween.parallel().tween_property(customer_root, "position:z", seated_position.z, 0.48)

func _place_customer_meal_on_table() -> void:
	if not customer_box or not dining_table_component:
		return
	var target := dining_table_component.get_serving_spot_position()
	customer_table_meal_boxes.clear()
	var place_tween := create_tween()
	place_tween.set_trans(Tween.TRANS_QUAD)
	place_tween.set_ease(Tween.EASE_IN_OUT)
	place_tween.tween_property(customer_box, "global_position", target + Vector3(0.0, 0.48, 0.0), 0.34)
	place_tween.tween_property(customer_box, "global_position", target, 0.34)
	place_tween.tween_callback(func() -> void:
		if not customer_box or not is_instance_valid(customer_box) or not dining_table_component:
			return
		customer_box.reparent(dining_table_component, true)
		customer_box.global_position = target
		customer_box.rotation = Vector3.ZERO
		customer_box.scale = Vector3.ONE * 0.72
		customer_box.visible = true
		customer_table_meal_boxes.append(customer_box)
		for index in range(1, customer_buckets_total):
			var extra_box := _build_afc_box(dining_table_component, Vector3.ZERO, 0.72)
			extra_box.name = "Additional customer bucket %d on table" % (index + 1)
			extra_box.global_position = target + Vector3(0.0, 0.015, (float(index) - float(customer_buckets_total - 1) * 0.5) * 0.34)
			extra_box.rotation = Vector3.ZERO
			customer_table_meal_boxes.append(extra_box)
	)

func _deliver_order_to_customer(served_by_staff: bool = false) -> void:
	if not customer_root or customer_flow != CustomerFlow.RECEIVING or staged_order_pieces <= 0 or not staged_order_root:
		return
	if not dining_table_component or customer_seat_index < 0:
		customer_flow = CustomerFlow.WAITING
		customer_seat_index = -1
		player_working = false
		_show_toast("No dining seat is available — the order is ready when a seat opens")
		return
	var service_actor: Node3D = billing_staff_root if served_by_staff else player_root
	if not is_instance_valid(service_actor):
		customer_flow = CustomerFlow.WAITING
		player_working = false
		return
	billing_worker_handoff_active = served_by_staff
	_face_person_toward(service_actor, customer_root.global_position, 1.0)
	var handoff_box := staged_order_root
	handoff_box.reparent(self, true)
	handoff_box.name = "Animated AFC meal handoff from packing table"
	staged_order_root = null
	var service_hand := service_actor.global_position + Vector3(0.0, 1.55, -0.12)
	var target := customer_root.global_position + Vector3(0.0, 1.38, -0.30)
	var handoff_tween := create_tween()
	handoff_tween.set_trans(Tween.TRANS_QUAD)
	handoff_tween.set_ease(Tween.EASE_IN_OUT)
	handoff_tween.tween_property(handoff_box, "global_position", service_hand, 0.65)
	handoff_tween.tween_property(handoff_box, "global_position", target, 1.10)
	handoff_tween.tween_callback(func() -> void:
		player_working = false
		billing_worker_handoff_active = false
		if is_instance_valid(handoff_box):
			handoff_box.queue_free()
		if not customer_root or not is_instance_valid(customer_root):
			return
		customer_buckets_remaining = maxi(0, customer_buckets_remaining - 1)
		customer_root.set_meta("customer_buckets_remaining", customer_buckets_remaining)
		staged_order_piece_counts.pop_front()
		staged_order_pieces = 0
		for remaining_order_pieces in staged_order_piece_counts:
			staged_order_pieces += remaining_order_pieces
		order_staged_for_billing = not staged_order_piece_counts.is_empty()
		_create_staged_order_visual(false)
		if customer_buckets_remaining > 0:
			customer_flow = CustomerFlow.WAITING
			customer_wait_elapsed = 0.0
			customer_box.visible = false
			customer_order_in_progress = false
			_show_toast("%d bucket%s left for this customer" % [
				customer_buckets_remaining,
				"" if customer_buckets_remaining == 1 else "s"
			])
		else:
			customer_box.visible = true
			customer_flow = CustomerFlow.WALKING_TO_TABLE
			customer_walking_to_table = true
			customer_at_table = false
			customer_sitting = false
			var table_goal := _reserve_customer_seat()
			_set_customer_route(table_goal)
			customer_order_in_progress = true
		_save_game()
		_refresh_service_stage()
	)

func _complete_customer_payment() -> void:
	if customer_flow != CustomerFlow.EATING:
		return
	customer_flow = CustomerFlow.LEAVING
	customer_leaving = true
	customer_at_table = false
	customer_sitting = false
	var exit_goal := Vector3(0.0, 0.22, 10.65) if BUILD_INTERIOR_CONTENT else Vector3(0.0, 0.22, 21.55)
	_set_customer_route(exit_goal)
	customer_order_in_progress = false
	var customer_box_is_tracked := false
	for meal_box in customer_table_meal_boxes:
		if is_instance_valid(meal_box):
			customer_box_is_tracked = customer_box_is_tracked or meal_box == customer_box
			meal_box.queue_free()
	customer_table_meal_boxes.clear()
	if customer_box:
		if customer_box_is_tracked or customer_box.get_parent() != customer_root:
			customer_box.queue_free()
		else:
			customer_box.visible = false
		customer_box = null
	var stand_tween := create_tween()
	stand_tween.set_trans(Tween.TRANS_QUAD)
	stand_tween.set_ease(Tween.EASE_OUT)
	stand_tween.tween_property(self, "customer_pose_blend", 0.0, 0.32)
	_spawn_table_trash()
	var paid_buckets := maxi(customer_buckets_total, 1)
	var revenue := PACK_PRICE * paid_buckets
	var previous_wallet := wallet
	var standard_dining_was_unlocked := _table_purchase_unlocked()
	wallet += revenue
	sales_count += paid_buckets
	_refresh_table_purchase_slot()
	var standard_dining_unlocked := not standard_dining_was_unlocked and _table_purchase_unlocked()
	for bucket_index in range(paid_buckets):
		_create_sales_cash_note(
			sales_count - paid_buckets + bucket_index,
			customer_root.global_position + Vector3(0.0, 1.45 + float(bucket_index) * 0.05, 0.0),
			true
		)
	if sales_cash_label:
		sales_cash_label.text = "SALES $%d" % (sales_count * PACK_PRICE)
	if cash_sound:
		cash_sound.play()
	if floating_reward:
		floating_reward.text = "+$%d" % revenue
		floating_reward.global_position = customer_root.global_position + Vector3(0.0, 2.3, 0.0)
		floating_reward.visible = true
		var reward_tween := create_tween()
		reward_tween.tween_property(floating_reward, "position:y", floating_reward.position.y + 0.8, 0.85)
		reward_tween.tween_callback(func() -> void: floating_reward.visible = false)
	var wallet_tween := create_tween()
	wallet_tween.tween_method(_set_wallet_display, previous_wallet, wallet, 0.45)
	if standard_dining_unlocked:
		_show_toast("Standard dining unlocked — you can now fund the next table")
	else:
		_show_toast("Customer paid $%d for %d bucket%s" % [
			revenue,
			paid_buckets,
			"" if paid_buckets == 1 else "s"
		])
	_save_game()
	_refresh_service_stage()
	_update_ui()

func _spawn_table_trash(count: int = MAX_CARRIED_TRASH) -> void:
	if not dining_table_root or not table_trash_items.is_empty():
		return
	var leftover_height := dining_table_component.get_surface_height() + 0.06 if dining_table_component else 1.18
	for i in range(count):
		var remnant := _create_trash_piece(dining_table_root, Vector3(0.35 + float(i) * 0.28, leftover_height, -0.40 + float(i % 2) * 0.25), i)
		table_trash_items.append(remnant)
	table_trash_count = table_trash_items.size()

func _create_trash_piece(parent: Node3D, position: Vector3, index: int) -> Node3D:
	var remnant := Node3D.new()
	remnant.name = "Visible leftover food piece %d" % (index + 1)
	remnant.position = position
	remnant.scale = Vector3.ONE * 2.0
	parent.add_child(remnant)
	_add_fried_chicken_piece(remnant, Vector3.ZERO, 0.34)
	_add_box(remnant, "Chicken wrapper", Vector3(0.06, 0.015, 0.05), Vector3(0.25, 0.025, 0.17), Color("fff0d5"), 0.015)
	return remnant

func _restore_trash_visuals() -> void:
	if table_trash_count > 0:
		_spawn_table_trash(table_trash_count)
	if carried_trash_count > 0:
		for i in range(mini(carried_trash_count, MAX_CARRIED_TRASH)):
			var item := _create_trash_piece(player_root, _carried_trash_hand_position(i), i)
			carried_trash_items.append(item)
		carried_trash_count = carried_trash_items.size()
	_update_carried_trash_display()

func _carried_trash_hand_position(index: int) -> Vector3:
	var column := index % 2
	var row := floori(float(index) / 2.0)
	return Vector3((float(column) - 0.5) * 0.30, 0.90 + float(row) * 0.20, -0.40)

func _start_table_trash_pickup() -> void:
	if table_trash_items.is_empty():
		return
	var item := table_trash_items[0]
	if not is_instance_valid(item):
		table_trash_items.pop_front()
		table_trash_count = table_trash_items.size()
		return
	trash_pickup_in_progress = true
	service_action_time = 0.58
	service_action_duration = service_action_time
	player_working = true
	move_direction = Vector2.ZERO
	player_velocity = Vector2.ZERO
	status_label.text = "Picking up table rubbish…"
	item.reparent(player_root, true)
	var carry_position := _carried_trash_hand_position(carried_trash_items.size())
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item, "position", carry_position, 0.52)
	_animate_player()

func _finish_table_trash_pickup() -> void:
	trash_pickup_in_progress = false
	player_working = false
	service_action_time = 0.0
	if table_trash_items.is_empty():
		_refresh_service_stage()
		return
	var item: Node3D = table_trash_items.pop_front()
	if is_instance_valid(item):
		carried_trash_items.append(item)
	carried_trash_count = carried_trash_items.size()
	table_trash_count = table_trash_items.size()
	_update_carried_trash_display()
	_save_game()
	_refresh_service_stage()
	_update_ui()

func _update_carried_trash_display() -> void:
	if not player_root:
		return
	if carried_trash_count <= 0:
		if trash_carry_badge:
			trash_carry_badge.visible = false
		return
	if not trash_carry_badge:
		trash_carry_badge = Node3D.new()
		trash_carry_badge.name = "Owner carried rubbish count text"
		trash_carry_badge.position = Vector3(0.48, 2.42, -0.08)
		player_root.add_child(trash_carry_badge)
		trash_carry_label = Label3D.new()
		trash_carry_label.name = "Rubbish count above hand"
		trash_carry_label.font_size = 112
		trash_carry_label.pixel_size = 0.0016
		trash_carry_label.modulate = Color("9b1c25")
		trash_carry_label.outline_size = 12
		trash_carry_label.outline_modulate = Color("fff4df")
		trash_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trash_carry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		trash_carry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		trash_carry_badge.add_child(trash_carry_label)
	trash_carry_badge.visible = true
	trash_carry_label.text = "DUST %d/%d" % [carried_trash_count, MAX_CARRIED_TRASH]
	for index in range(carried_trash_items.size()):
		var item := carried_trash_items[index]
		if is_instance_valid(item):
			item.position = _carried_trash_hand_position(index)

func _start_trash_disposal_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	for item in carried_trash_items:
		if not is_instance_valid(item):
			continue
		tween.tween_property(item, "global_position", waste_bin_opening + Vector3(0.0, 0.35, 0.0), 0.32)
		tween.tween_property(item, "global_position", waste_bin_opening, 0.22)
		tween.tween_property(item, "scale", Vector3.ZERO, 0.18)

func _rebuild_sales_cash_stack() -> void:
	if not sales_cash_bundle:
		return
	for note in sales_cash_notes:
		if is_instance_valid(note):
			note.queue_free()
	sales_cash_notes.clear()
	for i in range(mini(sales_count, 48)):
		_create_sales_cash_note(i, Vector3.ZERO, false)
	if sales_cash_label:
		sales_cash_label.text = "SALES $%d" % (sales_count * PACK_PRICE)

func _create_sales_cash_note(index: int, from_position: Vector3, animate: bool) -> void:
	if not sales_cash_bundle or index >= 48:
		return
	var note := Node3D.new()
	note.name = "Customer payment banknote %d" % (index + 1)
	sales_cash_bundle.add_child(note)
	var layer := index / 3
	var slot := index % 3
	var target := Vector3((float(slot) - 1.0) * 0.11 + float(layer % 2) * 0.025, 0.035 + float(layer) * 0.043, float(slot % 2) * 0.035)
	note.position = target
	note.rotation.y = float((index % 3) - 1) * 0.035
	_add_box(note, "Green customer banknote", Vector3.ZERO, Vector3(0.62, 0.028, 0.34), Color("3aa957") if index % 2 == 0 else Color("58bd65"), 0.012, 0.48)
	_add_box(note, "Banknote gold center seal", Vector3(0, 0.016, 0), Vector3(0.13, 0.008, 0.20), Color("e6d98b"), 0.004, 0.55)
	sales_cash_notes.append(note)
	if animate:
		note.global_position = from_position
		var note_tween := create_tween()
		note_tween.set_trans(Tween.TRANS_BACK)
		note_tween.set_ease(Tween.EASE_OUT)
		note_tween.tween_property(note, "global_position", sales_cash_bundle.to_global(target), 0.55)

func _update_carried_chicken_visuals() -> void:
	_update_carried_food_visuals()

func _update_carried_food_visuals() -> void:
	if carried_food_root and is_instance_valid(carried_food_root):
		carried_food_root.queue_free()
	carried_chicken_models.clear()
	carried_food_root = null
	if not player_root or (carried_chickens <= 0 and carried_order_pieces <= 0):
		return
	carried_food_root = Node3D.new()
	carried_food_root.name = "AFC chicken carry basket"
	carried_food_root.position = Vector3(0.0, 0.65, -0.42)
	player_root.add_child(carried_food_root)
	_add_box(carried_food_root, "Chicken basket base", Vector3(0, 0, 0), Vector3(0.58, 0.13, 0.44), Color("9b6039"), 0.035, 0.68)
	for x in [-0.28, 0.28]:
		_add_box(carried_food_root, "Chicken basket side", Vector3(x, 0.13, 0), Vector3(0.045, 0.25, 0.44), Color("b77a48"), 0.015, 0.68)
	for z in [-0.20, 0.20]:
		_add_box(carried_food_root, "Chicken basket end", Vector3(0, 0.13, z), Vector3(0.58, 0.25, 0.045), Color("b77a48"), 0.015, 0.68)
	for x in [-0.34, 0.34]:
		_add_box(carried_food_root, "Basket hand grip", Vector3(x, 0.23, 0.0), Vector3(0.12, 0.07, 0.18), Color("754628"), 0.025, 0.55)
	_add_box(carried_food_root, "AFC basket front badge", Vector3(0, 0.12, -0.225), Vector3(0.22, 0.09, 0.018), MAT_CREAM, 0.015)
	_add_label(carried_food_root, "AFC", Vector3(0, 0.12, -0.24), 0.04, MAT_RED)
	var food_count := carried_order_pieces if carried_order_pieces > 0 else carried_chickens
	for i in range(mini(food_count, 7)):
		var x := -0.16 + float(i % 3) * 0.16
		var z := -0.09 + float(i / 3) * 0.15
		var raw_color := Color("bd765b") if carried_order_pieces == 0 else Color("c98232")
		_add_sphere(carried_food_root, "Raw chicken piece" if carried_order_pieces == 0 else "Fried chicken piece", Vector3(x, 0.25 + float(i / 6) * 0.07, z), Vector3(0.12, 0.075, 0.10), raw_color, 10, 6)
		_add_sphere(carried_food_root, "Chicken bone end", Vector3(x + 0.10, 0.25 + float(i / 6) * 0.07, z), Vector3(0.045, 0.04, 0.045), Color("fff0d6"), 8, 5)

func _build_camera_and_lights() -> void:
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(10.4, 68.0, 62.0)
	camera.current = true
	add_child(camera)
	camera_look_target = Vector3(0.0, 0.3, 0.0)
	camera.look_at(camera_look_target, Vector3.UP)
	_update_camera_framing()
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("18232d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aab7c5")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 0.96
	environment.adjustment_saturation = 0.94
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("a9bdd5")
	sun.light_energy = 0.34
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 14.0, 2.0)
	fill.light_color = Color("b8c5d5")
	fill.light_energy = 0.08
	fill.omni_range = 42.0
	add_child(fill)

func _update_camera_framing() -> void:
	if not camera:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	# Fixed wide framing: the full 100-seat restaurant and front entrance stay
	# visible while only the owner changes position on screen.
	# Close portrait framing: the camera follows the owner through the large shop.
	# Temporary wide testing view: twice the current orthographic framing.
	base_camera_size = maxf(25.0, 14.5 / maxf(aspect, 0.35))
	camera.size = base_camera_size

func _build_platform() -> void:
	# The asphalt road and pavement go down first; the restaurant is built above them.
	_add_box(self, "Grass land around AFC plot", Vector3(0, -0.96, 0), Vector3(64.0, 0.16, 72.0), Color("78ad5d"), 0.0, 0.95)
	_add_box(self, "Street asphalt around shop", Vector3(0, -0.78, 0), Vector3(44.0, 0.12, 52.0), Color("44464a"), 0.0, 0.96)
	_add_box(self, "Concrete sidewalk apron", Vector3(0, -0.60, 0), Vector3(36.0, 0.18, 45.6), Color("bfc0ba"), 0.0, 0.88)
	_add_box(self, "Road curb highlight", Vector3(0, -0.48, 0), Vector3(30.5, 0.09, 42.3), Color("ede5d8"), 0.0, 0.76)
	# Dark plinth, cream bevel, zoned tile surface, front curb and painted entry.
	_add_box(self, "Floating shop plinth", Vector3(0, -0.18, 0), Vector3(28.4, 0.42, 39.0), Color("927d68"), 0.0, 0.92)
	_add_box(self, "Cream floor edge", Vector3(0, 0.045, 0), Vector3(28.08, 0.16, 38.64), Color("fff0d9"), 0.0, 0.8)
	_add_checker_floor()
	# Low curb on the back only: the open camera side remains cut away.
	_add_box(self, "Rear skirting", Vector3(0, 0.24, -18.5), Vector3(27.72, 0.22, 0.1), Color("d4c6b3"))
	_add_box(self, "Front threshold", Vector3(0, 0.17, 18.5), Vector3(27.8, 0.12, 0.13), Color("e2d3bd"))
	_add_box(self, "Welcome mat", Vector3(0, 0.28, 17.85), Vector3(2.5, 0.045, 0.8), Color("8d352d"))
	for i in range(5):
		_add_box(self, "Mat stripe %d" % i, Vector3(-0.9 + i * 0.45, 0.31, 17.85), Vector3(0.13, 0.008, 0.60), Color("f6dfbc"))
	# A broad, continuous carpet and narrow gold binding read as a ceremonial
	# entrance instead of a segmented walkway.
	_add_box(self, "Continuous deep red entrance carpet", Vector3(0.0, 0.215, 9.875), Vector3(1.72, 0.045, 14.65), Color("a7222b"), 0.025, 0.94)
	for side in [-1.0, 1.0]:
		_add_box(self, "Entrance carpet gold edge", Vector3(side * 0.79, 0.241, 9.875), Vector3(0.055, 0.012, 14.58), Color("e6bd68"), 0.01, 0.48)
	for side in [-1.0, 1.0]:
		_add_walkway_barrier_segment(
			Vector3(0.0, 0.0, 4.1),
			Vector3(0.0, 0.0, 17.15),
			Vector3(side * 1.10, 0.0, 0.0)
		)
	_add_carpet_path_lighting()
	for i in range(9):
		_add_box(self, "Road center dash %d" % i, Vector3(-10.0 + i * 2.5, -0.70, 22.5), Vector3(1.05, 0.018, 0.08), Color("f2dfa8"))

func _add_carpet_path_lighting() -> void:
	for side in [-1.0, 1.0]:
		for z in [5.4, 8.6, 11.8, 15.0]:
			var lamp_position := Vector3(side * 1.40, 0.0, z)
			_add_box(self, "Carpet edge light brass base", lamp_position + Vector3(0.0, 0.08, 0.0), Vector3(0.28, 0.14, 0.28), Color("78613b"), 0.045, 0.35)
			_add_box(self, "Carpet edge light golden diffuser", lamp_position + Vector3(0.0, 0.17, 0.0), Vector3(0.22, 0.045, 0.22), Color("ffe28a"), 0.025, 0.25)
			var path_light := _add_warm_area_light(self, "Golden red carpet guide light", lamp_position + Vector3(0.0, 0.22, 0.0), 0.65, 3.2)
			path_light.light_color = Color("ffd66e")
	for side in [-1.0, 1.0]:
		for x in [0.95, 2.35, 3.75]:
			var lamp_position := Vector3(x, 0.0, 2.65 + side * 1.42)
			_add_box(self, "Billing carpet edge light brass base", lamp_position + Vector3(0.0, 0.08, 0.0), Vector3(0.28, 0.14, 0.28), Color("78613b"), 0.045, 0.35)
			_add_box(self, "Billing carpet edge light golden diffuser", lamp_position + Vector3(0.0, 0.17, 0.0), Vector3(0.22, 0.045, 0.22), Color("ffe28a"), 0.025, 0.25)
			var billing_light := _add_warm_area_light(self, "Golden billing carpet guide light", lamp_position + Vector3(0.0, 0.22, 0.0), 0.65, 3.2)
			billing_light.light_color = Color("ffd66e")

func _add_walkway_barrier_segment(start: Vector3, finish: Vector3, side_offset: Vector3) -> void:
	var distance := start.distance_to(finish)
	var segment_count := maxi(1, ceili(distance / 2.15))
	var post_positions: Array[Vector3] = []
	for index in range(segment_count + 1):
		var center := start.lerp(finish, float(index) / float(segment_count)) + side_offset
		post_positions.append(center)
		_add_cylinder(self, "Slim polished steel ribbon stanchion", center + Vector3(0.0, 0.36, 0.0), 0.032, 0.042, 0.68, Color("aeb9bd"), 12)
		_add_cylinder(self, "Steel stanchion weighted foot", center + Vector3(0.0, 0.055, 0.0), 0.12, 0.12, 0.11, Color("77848a"), 12)
		_add_cylinder(self, "Gold stanchion cap", center + Vector3(0.0, 0.72, 0.0), 0.065, 0.065, 0.07, Color("d8b15f"), 12)
	for index in range(segment_count):
		var first := post_positions[index]
		var second := post_positions[index + 1]
		var span_length := first.distance_to(second)
		var along_x := absf(second.x - first.x) > absf(second.z - first.z)
		var ribbon_size := Vector3(span_length, 0.22, 0.045) if along_x else Vector3(0.045, 0.22, span_length)
		_add_box(self, "Wide red velvet queue ribbon", (first + second) * 0.5 + Vector3(0.0, 0.49, 0.0), ribbon_size, Color("ad2630"), 0.035, 0.62)

func _add_checker_floor() -> void:
	var tile_size := 0.48
	var square := BoxMesh.new()
	square.size = Vector3(tile_size - 0.018, 0.025, tile_size - 0.018)
	# Rear kitchen uses sanitary cool-grey tiles; the front dining zone uses
	# warmer terracotta/cream tiles. Both remain batched for Android performance.
	for zone in range(2):
		for parity in range(2):
			var transforms := PackedVector3Array()
			for x in range(58):
				for z in range(80):
					var world_z := -19.2 + float(z) * tile_size + tile_size * 0.5
					# Rear 30% is kitchen; front 70% stays warm dining floor so guests,
					# tables and billing never stand on kitchen-grey tiles.
					var is_kitchen := world_z < -7.70
					if (zone == 0 and not is_kitchen) or (zone == 1 and is_kitchen) or (x + z) % 2 != parity:
						continue
					transforms.append(Vector3(-13.92 + float(x) * tile_size + tile_size * 0.5, 0.145, world_z))
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = square
			multi.instance_count = transforms.size()
			for i in range(transforms.size()):
				multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, transforms[i]))
			var tile_batch := MultiMeshInstance3D.new()
			var zone_name := "Kitchen" if zone == 0 else "Dining"
			tile_batch.name = "%s floor tile batch %d" % [zone_name, parity]
			tile_batch.multimesh = multi
			var tile_color: Color
			if zone == 0:
				tile_color = Color("aeb8bd") if parity == 0 else Color("d6dcda")
			else:
				tile_color = Color("e4c39f") if parity == 0 else Color("f3ddba")
			tile_batch.material_override = _material(tile_color, 0.0, 0.92, true)
			tile_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile_batch)

func _build_backdrop() -> void:
	if not BUILD_INTERIOR_CONTENT:
		# Rear kitchen wall: deep charcoal panels make the red AFC fascia, warm
		# lights, menu photos and stainless equipment stand out from a distance.
		_add_box(self, "Large rear charcoal wall", Vector3(0, 1.4, -18.1), Vector3(27.8, 2.75, 0.28), Color("394247"))
		_add_box(self, "Large rear lower terracotta rail", Vector3(0, 0.57, -17.92), Vector3(27.7, 0.20, 0.16), Color("8f4034"))
		_add_box(self, "Large rear AFC fascia", Vector3(0, 2.93, -17.9), Vector3(14.2, 0.82, 0.20), MAT_RED)
		_add_label(self, "AFC • KITCHEN", Vector3(0, 2.88, -17.77), 0.34, Color.WHITE)
		for x in [-10.3, -5.1, 5.1, 10.3]:
			_add_box(self, "Rear framed food photo dark frame", Vector3(x, 1.75, -17.72), Vector3(3.65, 1.78, 0.10), Color("20272b"), 0.08)
			_add_box(self, "Rear framed food photo inner mount", Vector3(x, 1.75, -17.655), Vector3(3.35, 1.49, 0.025), Color("4c3431"), 0.05)
			_add_box(self, "Rear framed food photo warm background", Vector3(x, 1.75, -17.635), Vector3(3.10, 1.31, 0.020), Color("d96837") if absf(x) > 7.0 else Color("b64f3a"), 0.04)
			_add_fried_whole_chicken(self, Vector3(x - 0.30, 1.73, -17.59), 1.18)
			_add_afc_carton(self, Vector3(x + 0.95, 1.42, -17.59), Vector3(0.54, 0.44, 0.22))
			_add_label(self, "AFC CRISPY", Vector3(x, 2.41, -17.58), 0.075, Color("fff6df"))
		# Centre rear service entrance: it is the only rear-wall crossing point.
		_add_box(self, "Rear service door surround", Vector3(0, 1.75, -18.26), Vector3(2.5, 3.25, 0.08), Color("363d42"), 0.04)
		var rear_door := _add_box(self, "Rear hen hut double door", Vector3(0, 1.72, -18.31), Vector3(2.12, 3.05, 0.035), Color("48545a"), 0.03)
		rear_hen_door = rear_door
		_add_box(self, "Rear door centre seam", Vector3(0, 1.72, -18.34), Vector3(0.045, 2.90, 0.02), Color("202629"))
		for x in [-0.44, 0.44]:
			_add_box(self, "Rear door pull", Vector3(x, 1.70, -18.36), Vector3(0.055, 0.72, 0.025), Color("d6dbd6"), 0.02, 0.3)
		_add_label(self, "HEN HUT", Vector3(0, 2.88, -18.40), 0.12, Color("fff0cc"))
		for x in [-13.94, 13.94]:
			_add_box(self, "Large open side wall", Vector3(x, 0.92, 0.0), Vector3(0.16, 1.45, 36.5), Color("4a3937"))
			_add_box(self, "Large side red cap", Vector3(x, 1.68, 0.0), Vector3(0.22, 0.12, 36.5), MAT_RED)
			_add_box(self, "Large side lower base", Vector3(x, 0.27, 0.0), Vector3(0.22, 0.16, 36.5), Color("555d60"))
			for z in range(-15, 17, 4):
				_add_box(self, "Side wall AFC red pillar", Vector3(x, 1.62, float(z)), Vector3(0.30, 3.20, 0.32), MAT_RED_DARK, 0.05, 0.42)
				_add_box(self, "Side wall cream pillar inset", Vector3(x * 0.996, 1.58, float(z)), Vector3(0.315, 1.95, 0.10), Color("fff1dc"), 0.03, 0.36)
				_add_cylinder(self, "Side wall LEGO top stud", Vector3(x, 1.90, float(z)), 0.13, 0.13, 0.10, MAT_RED, 12)
			for z in [-10.5, -2.5, 5.5, 13.5]:
				_add_box(self, "Side wall AFC accent panel", Vector3(x * 0.996, 1.18, z), Vector3(0.09, 0.66, 2.30), Color("d65b46"), 0.03, 0.40)
			for z in [-7.0, 9.0]:
				_add_box(self, "Side dining photo black frame", Vector3(x * 0.996, 1.45, z), Vector3(0.095, 1.22, 1.72), Color("252a2e"), 0.04)
				_add_box(self, "Side dining photo cream mount", Vector3(x * 0.991, 1.45, z), Vector3(0.035, 1.00, 1.48), Color("f4d7a0"), 0.02)
				_add_box(self, "Side dining photo red art", Vector3(x * 0.989, 1.45, z), Vector3(0.020, 0.76, 1.20), MAT_RED, 0.02)
				_add_cylinder(self, "Side dining photo gold medallion", Vector3(x * 0.986, 1.48, z), 0.23, 0.23, 0.025, Color("efbd41"), 12, Vector3(0, 0, PI * 0.5))
		return
	# One partial rear wall and menu boards make this read as a shop, while the
	# open sides and missing ceiling preserve the readable toy-diorama camera.
	_add_box(self, "Rear wall", Vector3(0, 1.4, -9.05), Vector3(13.8, 2.75, 0.28), Color("f5eee1"))
	_add_box(self, "Blue wall rail", Vector3(0, 0.57, -8.87), Vector3(13.7, 0.17, 0.16), MAT_BLUE)
	_add_box(self, "AFC red fascia", Vector3(0, 2.93, -8.84), Vector3(7.8, 0.82, 0.2), MAT_RED)
	_add_label(self, "AFC • CHICKEN", Vector3(0, 2.88, -4.91), 0.31, Color.WHITE)
	# Stainless trim breaks the wall into framed kitchen windows.
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		_add_box(self, "Window mullion", Vector3(x, 1.92, -8.855), Vector3(0.09, 1.18, 0.12), MAT_BLUE, 0.1)
	for x in [-4.5, 0.0, 4.5]:
		_add_box(self, "Blue window glass", Vector3(x, 1.95, -8.865), Vector3(2.8, 1.17, 0.035), Color("91cddd", 0.82), 0.0, 0.18)
		_add_box(self, "Window bottom ledge", Vector3(x, 1.31, -8.71), Vector3(2.92, 0.11, 0.24), Color("e7e4dc"), 0.0, 0.45)
	# Menu panels are physical boards with individual colored food tiles.
	for x in [-4.5, 0.0, 4.5]:
		_add_box(self, "Menu board frame", Vector3(x, 2.8, -8.71), Vector3(2.55, 0.76, 0.13), Color("252c33"))
		_add_box(self, "Menu board face", Vector3(x, 2.81, -8.62), Vector3(2.39, 0.60, 0.035), Color("293d4b"))
		for i in range(3):
			_add_box(self, "Menu item tile", Vector3(x - 0.68 + i * 0.68, 2.8, -8.58), Vector3(0.46, 0.27, 0.025), Color("f2c277") if i == 0 else MAT_RED)
	# Wall mounted warm lights.
	for x in [-5.8, 5.8]:
		_add_box(self, "Wall lamp body", Vector3(x, 2.55, -8.75), Vector3(0.32, 0.16, 0.2), Color("f6d891"), 0.0, 0.25)
	# Low side walls give the restaurant an edge without closing the roofless view.
	for x in [-6.94, 6.94]:
		_add_box(self, "Open cutaway side wall", Vector3(x, 0.92, 0.0), Vector3(0.16, 1.45, 18.25), Color("eee6d9"))
		_add_box(self, "Side wall red cap", Vector3(x, 1.68, 0.0), Vector3(0.22, 0.12, 18.25), MAT_RED)
		_add_box(self, "Side wall blue base", Vector3(x, 0.27, 0.0), Vector3(0.22, 0.16, 18.25), MAT_BLUE)

func _build_front_entrance() -> void:
	if not BUILD_INTERIOR_CONTENT:
		var shell_z := 18.08
		for side in [-1.0, 1.0]:
			_add_box(self, "Front wall window sill base", Vector3(side * 7.985, 0.42, shell_z), Vector3(12.33, 0.60, 0.22), Color("f4eee2"))
			_add_box(self, "Front wall above mirror window", Vector3(side * 7.985, 3.66, shell_z), Vector3(12.33, 1.23, 0.22), Color("f4eee2"))
			_add_box(self, "Front wall inner window pier", Vector3(side * 2.36, 1.94, shell_z), Vector3(0.92, 2.44, 0.22), Color("f4eee2"))
			_add_box(self, "Front wall outer window pier", Vector3(side * 13.365, 1.94, shell_z), Vector3(1.57, 2.44, 0.22), Color("f4eee2"))
			var window_side := "left" if side < 0.0 else "right"
			_add_box(self, "Large clear storefront mirror glass " + window_side, Vector3(side * 7.65, 1.94, shell_z + 0.245), Vector3(9.50, 2.20, 0.035), Color("c4edf2", 0.24), 0.01, 0.12)
			for frame_x in [2.82, 12.48]:
				_add_box(self, "Large mirror storefront window vertical frame", Vector3(side * frame_x, 1.94, shell_z + 0.28), Vector3(0.16, 2.44, 0.16), Color("343d42"), 0.035, 0.28)
			for frame_y in [0.72, 3.16]:
				_add_box(self, "Large mirror storefront window horizontal frame", Vector3(side * 7.65, frame_y, shell_z + 0.28), Vector3(9.84, 0.16, 0.16), Color("343d42"), 0.035, 0.28)
			_add_box(self, "Storefront window bottom ledge", Vector3(side * 7.65, 0.72, shell_z + 0.18), Vector3(9.88, 0.20, 0.24), Color("d9d4c9"), 0.025, 0.38)
			_add_box(self, "Storefront window top ledge", Vector3(side * 7.65, 3.16, shell_z + 0.18), Vector3(9.88, 0.20, 0.24), Color("d9d4c9"), 0.025, 0.38)
			for mullion_x in [6.05, 9.25]:
				_add_box(self, "Storefront mirror window mullion", Vector3(side * mullion_x, 1.94, shell_z + 0.28), Vector3(0.075, 2.12, 0.055), Color("68777c"), 0.012, 0.3)
		_add_box(self, "Large entrance red header", Vector3(0, 3.22, shell_z), Vector3(3.65, 0.34, 0.28), MAT_RED_DARK)
		_add_box(self, "Large AFC entrance banner frame", Vector3(0, 3.98, shell_z + 0.20), Vector3(14.25, 1.14, 0.30), MAT_RED_DARK, 0.06, 0.42)
		_add_box(self, "Large AFC entrance banner", Vector3(0, 3.98, shell_z + 0.37), Vector3(13.88, 0.92, 0.06), MAT_RED, 0.025, 0.48)
		_add_box(self, "Large AFC banner gold top pinstripe", Vector3(0, 4.40, shell_z + 0.415), Vector3(12.9, 0.035, 0.012), Color("dfbd79"), 0.008, 0.38)
		_add_box(self, "Large AFC banner gold bottom pinstripe", Vector3(0, 3.56, shell_z + 0.415), Vector3(12.9, 0.035, 0.012), Color("dfbd79"), 0.008, 0.38)
		_add_label(self, "AFC CHICKEN", Vector3(0, 3.98, shell_z + 0.43), 0.52, Color("fff7e8"))
		_add_box(self, "LEGO front roof cap", Vector3(0, 4.34, shell_z), Vector3(27.8, 0.18, 0.42), MAT_RED_DARK, 0.04, 0.55)
		for x in range(-13, 14):
			_add_cylinder(self, "Round LEGO front wall stud", Vector3(float(x), 4.49, shell_z - 0.08), 0.13, 0.13, 0.11, MAT_RED, 12)
		for x in [-1.75, 1.75]:
			_add_box(self, "Tall glass door post", Vector3(x, 1.58, shell_z + 0.03), Vector3(0.14, 2.92, 0.26), Color("444d53"))
			_add_box(self, "Tall door pull handle", Vector3(x * 0.48, 1.52, shell_z + 0.19), Vector3(0.045, 0.72, 0.055), Color("d5e0df"), 0.02, 0.3)
		_add_box(self, "Tall door top frame", Vector3(0, 3.01, shell_z + 0.02), Vector3(3.64, 0.12, 0.27), Color("444d53"))
		entrance_left_door = Node3D.new()
		entrance_left_door.name = "Locked AFC entrance left glass door"
		entrance_left_door.position = Vector3(-0.84, 0, shell_z + 0.025)
		add_child(entrance_left_door)
		_add_box(entrance_left_door, "Tall entrance glass left", Vector3(0, 1.52, 0), Vector3(1.58, 2.75, 0.045), Color("eef8f4", 0.44), 0.01, 0.14)
		_add_box(entrance_left_door, "Closed door red lock stripe", Vector3(0, 1.56, 0.055), Vector3(1.45, 0.18, 0.025), MAT_RED_DARK, 0.02)
		entrance_right_door = Node3D.new()
		entrance_right_door.name = "Locked AFC entrance right glass door"
		entrance_right_door.position = Vector3(0.84, 0, shell_z + 0.025)
		add_child(entrance_right_door)
		_add_box(entrance_right_door, "Tall entrance glass right", Vector3(0, 1.52, 0), Vector3(1.58, 2.75, 0.045), Color("f5fbfa", 0.44), 0.01, 0.14)
		_add_box(entrance_right_door, "Closed door red lock stripe", Vector3(0, 1.56, 0.055), Vector3(1.45, 0.18, 0.025), MAT_RED_DARK, 0.02)
		entrance_closed_barrier = Node3D.new()
		entrance_closed_barrier.name = "AFC shop closed entrance barrier"
		entrance_closed_barrier.position = Vector3(0, 0, shell_z + 0.12)
		add_child(entrance_closed_barrier)
		_add_box(entrance_closed_barrier, "Closed shop chain bar", Vector3(0, 1.55, 0.08), Vector3(3.45, 0.16, 0.06), Color("f4c84b"), 0.04, 0.30)
		entrance_lock_sign = Node3D.new()
		entrance_lock_sign.name = "AFC closed shop sign"
		entrance_lock_sign.position = Vector3(0, 2.20, shell_z + 0.18)
		add_child(entrance_lock_sign)
		_add_box(entrance_lock_sign, "Closed shop sign board", Vector3.ZERO, Vector3(2.70, 0.64, 0.04), Color("fff5df"), 0.06, 0.45)
		_add_label(entrance_lock_sign, "CLOSED • BUY SHOP", Vector3(0, 0, 0.035), 0.16, Color("202124"))
		# The playable shop is roofless after purchase for the isometric camera.
		# Before purchase, this temporary cover makes the locked state unmistakable
		# instead of showing a ready-to-use interior from above.
		shop_closed_roof = Node3D.new()
		shop_closed_roof.name = "Closed AFC shop roof cover"
		add_child(shop_closed_roof)
		_add_box(shop_closed_roof, "Closed shop red roof rim", Vector3(0, 4.55, 0.0), Vector3(27.55, 0.22, 35.85), MAT_RED_DARK, 0.10, 0.62)
		_add_box(shop_closed_roof, "Closed shop cream roof", Vector3(0, 4.68, 0.0), Vector3(26.95, 0.12, 35.20), Color("f5ebd9"), 0.08, 0.68)
		_add_box(shop_closed_roof, "Closed shop AFC roof badge", Vector3(0, 4.77, 1.4), Vector3(8.5, 0.05, 2.3), MAT_RED, 0.12, 0.35)
		var roof_message := _add_label(shop_closed_roof, "AFC SHOP CLOSED", Vector3(0, 4.82, 1.4), 0.35, Color.WHITE)
		roof_message.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_add_box(self, "Large front red lower band", Vector3(0, 0.42, shell_z + 0.13), Vector3(27.65, 0.35, 0.08), MAT_RED)
		return
	# Front wall is split around a real glass doorway, with the AFC banner above it.
	var z := 9.08
	_add_box(self, "Front wall left wing", Vector3(-4.35, 1.28, z), Vector3(5.55, 2.12, 0.22), Color("f4eee2"))
	_add_box(self, "Front wall right wing", Vector3(4.35, 1.28, z), Vector3(5.55, 2.12, 0.22), Color("f4eee2"))
	_add_box(self, "Front doorway header", Vector3(0, 2.25, z), Vector3(1.65, 0.25, 0.24), MAT_RED_DARK)
	_add_box(self, "Front AFC banner", Vector3(0, 2.78, z + 0.04), Vector3(8.2, 0.82, 0.24), MAT_RED)
	_add_label(self, "AFC  •  CHICKEN", Vector3(0, 2.72, z + 0.19), 0.28, Color.WHITE)
	# Door posts, transom, pale glass leaves and twin vertical pull handles.
	for x in [-0.82, 0.82]:
		_add_box(self, "Glass door frame post", Vector3(x, 1.2, z + 0.03), Vector3(0.11, 1.8, 0.24), MAT_BLUE)
		_add_box(self, "Brushed steel pull handle", Vector3(x * 0.58, 1.12, z + 0.2), Vector3(0.035, 0.45, 0.045), Color("c9d3d5"), 0.015, 0.26)
	_add_box(self, "Door top glass frame", Vector3(0, 2.04, z + 0.02), Vector3(1.72, 0.09, 0.25), MAT_BLUE)
	_add_box(self, "Left entrance glass", Vector3(-0.39, 1.17, z + 0.025), Vector3(0.7, 1.62, 0.035), Color("91cad8", 0.42), 0.01, 0.14)
	_add_box(self, "Right entrance glass", Vector3(0.39, 1.17, z + 0.025), Vector3(0.7, 1.62, 0.035), Color("a4d7e0", 0.42), 0.01, 0.14)
	_add_box(self, "Front wall red lower band", Vector3(0, 0.42, z + 0.13), Vector3(13.65, 0.35, 0.08), MAT_RED)
	_add_box(self, "AFC logo sign left", Vector3(-5.55, 1.88, z + 0.14), Vector3(1.65, 0.82, 0.08), MAT_RED)
	_add_label(self, "AFC", Vector3(-5.55, 1.8, z + 0.20), 0.26, Color.WHITE)
	_add_box(self, "AFC logo sign right", Vector3(5.55, 1.88, z + 0.14), Vector3(1.65, 0.82, 0.08), MAT_RED)
	_add_label(self, "AFC", Vector3(5.55, 1.8, z + 0.20), 0.26, Color.WHITE)
	# Windowed photo panels with actual chicken and carton silhouettes.
	for x in [-2.3, 2.3]:
		_add_box(self, "Chicken menu photo frame", Vector3(x, 1.5, z + 0.16), Vector3(1.6, 0.72, 0.06), Color("343b42"))
		_add_box(self, "Chicken menu photo", Vector3(x, 1.5, z + 0.20), Vector3(1.46, 0.6, 0.025), Color("fff4df"))
		_add_drumstick(self, Vector3(x - 0.14, 1.49, z + 0.235), 0.75)
		_add_afc_carton(self, Vector3(x + 0.2, 1.45, z + 0.25), Vector3(0.26, 0.27, 0.22))

func _build_outside_details() -> void:
	if not BUILD_INTERIOR_CONTENT:
		_build_large_road_and_parking()
		_build_detailed_landscape()
		_build_exterior_lighting_and_signage()
		for x in [-17.0, 17.0]:
			for z in [-16.0, 16.0]:
				_add_tree(self, Vector3(x, -0.48, z))
		var shell_sign := Node3D.new()
		shell_sign.name = "Large AFC roadside poster"
		shell_sign.position = Vector3(16.25, 0.0, 4.5)
		add_child(shell_sign)
		_add_box(shell_sign, "Large poster body", Vector3(0, 0.82, 0), Vector3(1.25, 1.8, 0.16), MAT_RED_DARK, 0.04)
		_add_box(shell_sign, "Large poster face", Vector3(0, 0.86, 0.10), Vector3(1.04, 1.5, 0.025), Color("fff2db"), 0.02)
		_add_label(shell_sign, "AFC", Vector3(0, 1.20, 0.13), 0.24, MAT_RED)
		_add_drumstick(shell_sign, Vector3(0, 0.60, 0.14), 1.15)
		return
	# Roadside A-frame chicken advertisement, visible from the entrance path.
	var sign := Node3D.new()
	sign.name = "AFC roadside chicken poster"
	sign.position = Vector3(8.25, 0.0, 2.3)
	add_child(sign)
	_add_box(sign, "A-frame poster body", Vector3(0, 0.82, 0), Vector3(0.78, 1.32, 0.13), MAT_RED_DARK, 0.03)
	_add_box(sign, "A-frame poster face", Vector3(0, 0.84, 0.08), Vector3(0.64, 1.08, 0.025), Color("fff2db"), 0.02)
	_add_label(sign, "AFC", Vector3(0, 1.15, 0.11), 0.18, MAT_RED)
	_add_drumstick(sign, Vector3(0, 0.66, 0.12), 0.8)
	for x in [-8.55, 8.55]:
		for z in [-8.2, 8.0]:
			_add_tree(self, Vector3(x, -0.48, z))
	# Raised planters with leafy shrubs soften the road/building boundary.
	for x in [-7.75, 7.75]:
		_add_box(self, "AFC entry planter", Vector3(x, 0.05, 8.35), Vector3(0.72, 0.42, 0.72), Color("d8c7a5"), 0.06)
		for i in range(5):
			_add_sphere(self, "Planter leaves", Vector3(x - 0.2 + float(i) * 0.1, 0.42 + float(i % 2) * 0.07, 8.35), Vector3(0.18, 0.16, 0.18), Color("4e974f"), 9, 6)

func _build_large_road_and_parking() -> void:
	static_obstacles.clear()
	# A visible layered road in front of the store: raised kerbs, pale shoulders,
	# yellow centre markings and a separate customer parking apron.
	# Everything in this function sits outside the front wall at z = 18.08.
	# The walkway comes first, then parking bays, then the main traffic road.
	_add_box(self, "Front parking asphalt", Vector3(0, -0.43, 23.2), Vector3(28.8, 0.13, 6.4), Color("252a2f"), 0.0, 0.94)
	for z in [19.94, 26.46]:
		_add_box(self, "Parking dark curb edge", Vector3(0, -0.36, z), Vector3(28.8, 0.035, 0.12), Color("343a3e"), 0.015, 0.78)
	for x in [-14.45, 14.45]:
		_add_box(self, "Parking dark curb edge", Vector3(x, -0.36, 23.2), Vector3(0.12, 0.035, 6.50), Color("343a3e"), 0.015, 0.78)
	_add_box(self, "Main front road surface", Vector3(0, -0.51, 30.5), Vector3(72.0, 0.18, 6.7), Color("303237"), 0.0, 0.95)
	_add_box(self, "Road front kerb", Vector3(0, -0.34, 27.23), Vector3(72.0, 0.16, 0.24), Color("e1ddd3"), 0.01, 0.72)
	_add_box(self, "Road outside kerb", Vector3(0, -0.34, 33.78), Vector3(72.0, 0.16, 0.24), Color("d8d3c8"), 0.01, 0.72)
	for x in range(-33, 34, 5):
		_add_box(self, "Road yellow centre line", Vector3(float(x), -0.395, 30.5), Vector3(2.6, 0.025, 0.14), Color("f4c84f"), 0.02, 0.5)
	# Two parking rows flank the straight entrance route, leaving the middle open.
	for side in [-1.0, 1.0]:
		for i in range(5):
			var bay_x: float = float(side) * (3.15 + float(i) * PARKING_BAY_WIDTH_METRES)
			_add_box(self, "Parking bay side line", Vector3(bay_x, -0.345, 23.2), Vector3(0.10, 0.022, PARKING_BAY_LENGTH_METRES), Color("f8f5e8"), 0.0, 0.5)
		_add_box(self, "Parking row boundary", Vector3(side * 14.35, -0.345, 23.2), Vector3(0.11, 0.022, PARKING_BAY_LENGTH_METRES + 0.25), Color("f8f5e8"), 0.0, 0.5)
	_add_box(self, "Parking front boundary", Vector3(0, -0.345, 20.60), Vector3(28.7, 0.022, 0.1), Color("f8f5e8"), 0.0, 0.5)
	_add_box(self, "Parking back boundary", Vector3(0, -0.345, 25.80), Vector3(28.7, 0.022, 0.1), Color("f8f5e8"), 0.0, 0.5)
	# Pedestrian route, bollards and small red AFC welcome panels direct players
	# from the parking area to the tall glass entry.
	_add_box(self, "Traditional entrance path base", Vector3(0, -0.30, 22.2), Vector3(2.45, 0.05, 8.20), Color("6c4539"), 0.03, 0.72)
	for row in range(17):
		var brick_colour: Color = Color("a85f45") if row % 2 == 0 else Color("94513e")
		_add_box(self, "Traditional entrance brick paver", Vector3(0, -0.262, 18.45 + float(row) * 0.46), Vector3(2.24, 0.025, 0.39), brick_colour, 0.025, 0.56)
	for x in [-1.45, 1.45]:
		for z in [19.3, 22.1, 25.0]:
			_add_cylinder(self, "Entrance safety bollard", Vector3(x, 0.10, z), 0.11, 0.14, 0.72, Color("707a7d"), 12)
			_add_cylinder(self, "Bollard red band", Vector3(x, 0.32, z), 0.145, 0.145, 0.10, MAT_RED, 12)
	for x in [-4.1, 4.1]:
		_add_box(self, "Parking direction arrow stem", Vector3(x, -0.31, 23.2), Vector3(0.20, 0.024, 1.15), Color("f5f0df"), 0.0, 0.5)
		_add_box(self, "Parking direction arrow head", Vector3(x, -0.31, 22.67), Vector3(0.62, 0.024, 0.35), Color("f5f0df"), 0.0, 0.5)
	# Parking islands, lamps and bollards are solid objects for the owner.
	_register_obstacle(Vector2(-11.8, 20.15), Vector2(1.2, 1.2))
	_register_obstacle(Vector2(11.8, 20.15), Vector2(1.2, 1.2))
	for x in [-1.45, 1.45]:
		for z in [19.3, 22.1, 25.0]:
			_register_obstacle(Vector2(x, z), Vector2(0.38, 0.38))

func _register_obstacle(center: Vector2, dimensions: Vector2) -> void:
	static_obstacles.append(Rect2(center - dimensions * 0.5, dimensions))

func _build_parked_lego_cars() -> void:
	# Parking cars face the shop. They use the same brick construction as traffic
	# but are static, so the marked bays immediately read as a real car park.
	var parking_specs: Array[Dictionary] = [
		{"colour": Color("d94a37"), "position": Vector3(-11.15, -0.42, 23.2)},
		{"colour": Color("f0b533"), "position": Vector3(-7.95, -0.42, 23.2)},
		{"colour": Color("4e9fbe"), "position": Vector3(7.95, -0.42, 23.2)},
		{"colour": Color("62a65a"), "position": Vector3(11.15, -0.42, 23.2)},
	]
	for parked_data in parking_specs:
		var parked_car: Node3D = _build_low_poly_car(parked_data["colour"] as Color, parked_data["position"] as Vector3, false)
		parked_car.name = "Parked LEGO customer car"
		parked_car.rotation.y = PI * 0.5
		# The cars are rotated to face the restaurant, so their long 4.4 m axis
		# lies along Z and their narrow axis lies along X.
		var parked_position: Vector3 = parked_data["position"] as Vector3
		_register_obstacle(Vector2(parked_position.x, parked_position.z), Vector2(CAR_WIDTH_METRES + 0.25, CAR_LENGTH_METRES + 0.25))

func _activate_customer_exterior() -> void:
	# Customer cars are a consequence of opening the billing counter, not generic
	# scenery. This makes the first arrivals communicate that service has begun.
	if customer_traffic_active:
		return
	customer_traffic_active = true
	_build_parked_lego_cars()
	_build_traffic()

func _build_detailed_landscape() -> void:
	# Ground variation makes the surrounding grass feel like a landscaped plot,
	# rather than a single flat colour.
	for patch_data in [
		[Vector3(-26.0, -0.865, -23.0), Vector3(7.0, 0.025, 10.0), Color("6c9f50")],
		[Vector3(26.0, -0.865, -22.0), Vector3(8.0, 0.025, 11.0), Color("82b85f")],
		[Vector3(-26.0, -0.865, 25.0), Vector3(7.0, 0.025, 9.0), Color("86b966")],
		[Vector3(26.0, -0.865, 25.0), Vector3(8.0, 0.025, 10.0), Color("699d50")],
	]:
		_add_box(self, "Mown grass colour patch", patch_data[0], patch_data[1], patch_data[2], 0.06, 0.94)
	for grass_position in [
		Vector3(-28, -0.79, -28), Vector3(-24, -0.79, -26), Vector3(-20, -0.79, -30),
		Vector3(22, -0.79, -28), Vector3(27, -0.79, -24), Vector3(29, -0.79, -30),
		Vector3(-28, -0.79, 28), Vector3(-23, -0.79, 31), Vector3(-19, -0.79, 26),
		Vector3(20, -0.79, 28), Vector3(25, -0.79, 31), Vector3(30, -0.79, 27),
		Vector3(-24, -0.79, 4), Vector3(24, -0.79, -2), Vector3(-25, -0.79, -7), Vector3(26, -0.79, 7),
	]:
		_add_grass_clump(grass_position, 1.0)
	for flower_position in [
		Vector3(-25.5, -0.79, -20), Vector3(-22, -0.79, -27), Vector3(24, -0.79, -26),
		Vector3(27, -0.79, 27), Vector3(-25, -0.79, 27), Vector3(22, -0.79, 30),
	]:
		_add_flower_bed(flower_position)
	for rock_position in [Vector3(-29, -0.76, -16), Vector3(29, -0.76, -12), Vector3(-28, -0.76, 17), Vector3(28, -0.76, 19)]:
		_add_sphere(self, "Garden decorative rock", rock_position, Vector3(0.55, 0.24, 0.42), Color("9a9b8d"), 8, 5)
	# Planters frame the front door without blocking the pedestrian route.
	for x in [-3.65, 3.65]:
		_add_box(self, "Entrance garden planter", Vector3(x, -0.10, 17.08), Vector3(1.45, 0.58, 1.12), Color("d4b47b"), 0.08, 0.72)
		_register_obstacle(Vector2(x, 17.08), Vector2(1.55, 1.22))
		for i in range(6):
			_add_sphere(self, "Entrance shrub foliage", Vector3(x - 0.40 + float(i % 3) * 0.38, 0.33 + float(i / 3) * 0.15, 16.95 + float(i % 2) * 0.22), Vector3(0.33, 0.30, 0.30), Color("3d893f") if i % 2 == 0 else Color("62a94c"), 9, 6)
	_build_property_fence()

func _build_exterior_lighting_and_signage() -> void:
	# Parking lighting uses simplified block pieces so it shares the toy-brick
	# language of the cars, owner and storefront.
	for x in [-11.8, 11.8]:
		_add_box(self, "Parking lamp square base", Vector3(x, -0.24, 20.15), Vector3(0.72, 0.22, 0.72), Color("697277"), 0.06, 0.55)
		_add_cylinder(self, "Parking lamp pole", Vector3(x, 2.0, 20.15), 0.095, 0.12, 4.15, Color("4f5659"), 10)
		_add_box(self, "Parking lamp head", Vector3(x, 4.12, 20.15), Vector3(0.78, 0.23, 0.62), Color("464f53"), 0.06, 0.4)
		_add_box(self, "Warm parking lamp lens", Vector3(x, 4.00, 20.15), Vector3(0.58, 0.035, 0.44), Color("ffe5a2"), 0.02, 0.25)
		_add_warm_area_light(self, "Parking and road floodlight", Vector3(x, 3.92, 20.15), 2.2, 15.0)
	for x in [-13.1, 13.1]:
		_add_cylinder(self, "Roadside path light post", Vector3(x, 1.85, 26.0), 0.075, 0.10, 3.85, Color("515b60"), 10)
		_add_box(self, "Roadside path light head", Vector3(x, 3.78, 26.0), Vector3(0.62, 0.18, 0.52), Color("464f53"), 0.05, 0.4)
		_add_box(self, "Roadside path light warm lens", Vector3(x, 3.68, 26.0), Vector3(0.46, 0.025, 0.36), Color("f0d99f"), 0.015, 0.28)
		_add_warm_area_light(self, "Road edge light", Vector3(x, 3.62, 26.0), 1.7, 12.0)
		_register_obstacle(Vector2(x, 26.0), Vector2(0.42, 0.42))
	# Branded pylon gives the entrance a landmark visible from the passing road.
	var pylon := Node3D.new()
	pylon.name = "AFC roadside pylon sign"
	pylon.position = Vector3(-16.8, -0.40, 21.0)
	add_child(pylon)
	_register_obstacle(Vector2(-16.8, 21.0), Vector2(1.55, 1.30))
	_add_box(pylon, "Pylon base", Vector3(0, 0.22, 0), Vector3(1.35, 0.45, 1.05), Color("747a74"), 0.08)
	_add_box(pylon, "Pylon post", Vector3(0, 2.20, 0), Vector3(0.46, 3.55, 0.36), MAT_RED_DARK, 0.06)
	_add_box(pylon, "AFC pylon sign", Vector3(0, 4.25, 0), Vector3(3.00, 1.72, 0.32), MAT_RED, 0.10, 0.45)
	_add_box(pylon, "Pylon cream inset", Vector3(0, 4.25, 0.18), Vector3(2.52, 1.28, 0.025), MAT_CREAM, 0.05, 0.55)
	_add_label(pylon, "AFC", Vector3(0, 4.40, 0.21), 0.39, MAT_RED)
	_add_label(pylon, "CHICKEN", Vector3(0, 3.95, 0.21), 0.20, Color("57211e"))
	# Curbed planted islands protect parking lights and give the apron a clear edge.
	for x in [-11.8, 11.8]:
		_add_box(self, "Parking planted island", Vector3(x, -0.31, 20.1), Vector3(2.35, 0.16, 1.08), Color("d1c5aa"), 0.10, 0.72)
		for i in range(4):
			_add_sphere(self, "Parking island shrub", Vector3(x - 0.55 + float(i) * 0.37, 0.10 + float(i % 2) * 0.10, 20.08 + float(i % 2) * 0.18), Vector3(0.28, 0.28, 0.28), Color("4c9746") if i % 2 == 0 else Color("6cad50"), 9, 6)
	# Canopy projects forward over the actual double doors and has visible supports.
	_add_box(self, "AFC entrance canopy top", Vector3(0, 4.36, 19.15), Vector3(7.5, 0.22, 2.15), MAT_RED, 0.08, 0.44)
	_add_box(self, "AFC entrance canopy underside", Vector3(0, 4.20, 19.15), Vector3(7.25, 0.06, 2.0), MAT_CREAM, 0.03, 0.55)
	for x in [-3.15, 3.15]:
		_add_box(self, "Canopy support column", Vector3(x, 2.12, 20.15), Vector3(0.22, 3.9, 0.22), Color("50575a"), 0.03, 0.45)
		_add_cylinder(self, "Canopy column foot", Vector3(x, 0.22, 20.15), 0.32, 0.32, 0.14, Color("717877"), 12)
		_register_obstacle(Vector2(x, 20.15), Vector2(0.72, 0.72))
	for x in [-2.15, 2.15]:
		_add_box(self, "Entrance canopy warm light fixture", Vector3(x, 4.14, 19.15), Vector3(0.72, 0.08, 0.55), Color("f0dfaF"), 0.04, 0.3)
		_add_warm_area_light(self, "Entrance canopy downlight", Vector3(x, 4.08, 19.15), 1.8, 9.5)

func _add_warm_area_light(parent: Node3D, light_name: String, local_position: Vector3, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = local_position
	light.light_color = Color("ffe1ad")
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.25
	light.shadow_enabled = false
	parent.add_child(light)
	return light

func _add_grass_clump(position_value: Vector3, scale_value: float) -> void:
	for i in range(5):
		var angle := float(i) * TAU / 5.0
		var offset := Vector3(cos(angle) * 0.14, 0.17 + float(i % 2) * 0.05, sin(angle) * 0.14)
		var blade := _add_cylinder(self, "Tall grass blade", position_value + offset, 0.0, 0.045 * scale_value, (0.45 + float(i % 2) * 0.12) * scale_value, Color("4f993f") if i % 2 == 0 else Color("73b951"), 5)
		blade.rotation.x = 0.12 * cos(angle)
		blade.rotation.z = 0.12 * sin(angle)

func _add_flower_bed(position_value: Vector3) -> void:
	_add_sphere(self, "Flower bed leaves", position_value + Vector3(0, 0.15, 0), Vector3(0.72, 0.22, 0.54), Color("3d873f"), 9, 6)
	for i in range(5):
		var angle := float(i) * TAU / 5.0
		var flower_colour: Color = [Color("f6d14c"), Color("ef6e70"), Color("fff1d6")][i % 3]
		_add_sphere(self, "Garden flower", position_value + Vector3(cos(angle) * 0.32, 0.35 + float(i % 2) * 0.04, sin(angle) * 0.24), Vector3(0.13, 0.13, 0.13), flower_colour, 8, 5)

func _build_property_fence() -> void:
	var fence_wood := Color("8b603d")
	var fence_cap := Color("d6b47a")
	# Fence only the rear and side gardens. The side runs stop before the parking
	# and road, leaving the entire front approach and driveway unobstructed.
	for x in [-30.0, 30.0]:
		_add_box(self, "Perimeter fence upper rail", Vector3(x, 0.18, -2.0), Vector3(0.10, 0.10, 56.0), fence_wood, 0.02, 0.8)
		_add_box(self, "Perimeter fence lower rail", Vector3(x, -0.24, -2.0), Vector3(0.10, 0.10, 56.0), fence_wood, 0.02, 0.8)
		for z in range(-30, 27, 5):
			_add_box(self, "Perimeter fence post", Vector3(x, 0.12, float(z)), Vector3(0.18, 1.0, 0.18), fence_wood, 0.03, 0.78)
			_add_box(self, "Fence post cap", Vector3(x, 0.66, float(z)), Vector3(0.25, 0.10, 0.25), fence_cap, 0.03, 0.65)
	_add_box(self, "Rear fence upper rail", Vector3(0, 0.18, -30.0), Vector3(60.0, 0.10, 0.10), fence_wood, 0.02, 0.8)
	_add_box(self, "Rear fence lower rail", Vector3(0, -0.24, -30.0), Vector3(60.0, 0.10, 0.10), fence_wood, 0.02, 0.8)
	for x in range(-30, 31, 5):
		_add_box(self, "Rear fence post", Vector3(float(x), 0.12, -30.0), Vector3(0.18, 1.0, 0.18), fence_wood, 0.03, 0.78)

func _build_traffic() -> void:
	traffic_cars.clear()
	var car_specs := [
		# Separate lanes prevent cars from overtaking or visually passing through.
		[Color("e55b47"), -16.0, 28.65, 3.0, 1.0],
		[Color("4fa7c6"), 4.0, 30.50, 2.5, -1.0],
		[Color("f2ba39"), 18.0, 32.35, 3.7, 1.0],
	]
	for spec in car_specs:
		var car := _build_low_poly_car(spec[0], Vector3(spec[1], -0.42, spec[2]), spec[4] < 0.0)
		car.set_meta("drive_speed", spec[3])
		car.set_meta("drive_direction", spec[4])
		traffic_cars.append(car)

func _build_low_poly_car(body_color: Color, position_value: Vector3, face_left: bool) -> Node3D:
	var car := Node3D.new()
	car.name = "Passing LEGO style road car"
	car.position = position_value
	car.rotation.y = PI if face_left else 0.0
	add_child(car)
	# LEGO-like build: a black chassis, simple rectangular bricks, exposed roof
	# studs and deliberately chunky wheels rather than a smooth realistic car.
	_add_box(car, "Car shadow", Vector3(0, 0.02, 0), Vector3(CAR_LENGTH_METRES, 0.04, CAR_WIDTH_METRES), Color(0.06, 0.07, 0.08, 0.32), 0.12)
	_add_box(car, "Black LEGO car chassis", Vector3(0, 0.25, 0), Vector3(4.52, 0.18, 1.96), Color("24272a"), 0.05, 0.5)
	_add_box(car, "LEGO car body brick", Vector3(0, 0.55, 0), Vector3(CAR_LENGTH_METRES, 0.55, CAR_WIDTH_METRES), body_color, 0.07, 0.52)
	_add_box(car, "LEGO front bonnet", Vector3(1.33, 0.82, 0), Vector3(1.52, 0.16, 1.68), body_color.lightened(0.07), 0.04, 0.5)
	_add_box(car, "LEGO roof brick", Vector3(-0.42, 1.02, 0), Vector3(2.18, 0.38, 1.46), body_color.lightened(0.13), 0.05, 0.45)
	_add_box(car, "Car windscreen brick", Vector3(0.70, 1.05, -0.01), Vector3(0.055, 0.32, 1.24), Color("a8dbe5", 0.78), 0.01, 0.10)
	_add_box(car, "Car rear window brick", Vector3(-1.45, 1.05, -0.01), Vector3(0.055, 0.30, 1.24), Color("8fc9d7", 0.78), 0.01, 0.10)
	for x in [-0.93, -0.36, 0.21, 0.78]:
		for z in [-0.42, 0.42]:
			_add_cylinder(car, "Round LEGO roof stud", Vector3(x, 1.25, z), 0.12, 0.12, 0.10, body_color.lightened(0.18), 12)
	for x in [-1.52, 1.52]:
		for z in [-0.94, 0.94]:
			_add_cylinder(car, "Chunky LEGO tyre", Vector3(x, 0.27, z), 0.29, 0.29, 0.20, Color("1e2024"), 12, Vector3(PI / 2.0, 0.0, 0.0))
			_add_cylinder(car, "LEGO wheel hub", Vector3(x, 0.27, z * 1.035), 0.13, 0.13, 0.215, Color("e6e7dd"), 12, Vector3(PI / 2.0, 0.0, 0.0))
	_add_box(car, "LEGO front bumper", Vector3(2.25, 0.42, 0), Vector3(0.14, 0.18, 1.78), Color("d7dad5"), 0.03, 0.35)
	_add_box(car, "Car headlight", Vector3(2.31, 0.60, -0.55), Vector3(0.045, 0.15, 0.28), Color("fff0a5"), 0.02)
	_add_box(car, "Car headlight", Vector3(2.31, 0.60, 0.55), Vector3(0.045, 0.15, 0.28), Color("fff0a5"), 0.02)
	_add_box(car, "LEGO rear bumper", Vector3(-2.25, 0.42, 0), Vector3(0.14, 0.18, 1.78), Color("d7dad5"), 0.03, 0.35)
	for z in [-0.56, 0.56]:
		_add_box(car, "Car red rear light", Vector3(-2.31, 0.60, z), Vector3(0.045, 0.14, 0.24), Color("df3832"), 0.02)
	for z in [-0.94, 0.94]:
		_add_box(car, "LEGO car door seam", Vector3(-0.15, 0.58, z * 0.97), Vector3(0.82, 0.36, 0.025), body_color.darkened(0.20), 0.01)
	return car

func _add_tree(parent: Node3D, pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "Roadside low-poly tree"
	tree.position = pos
	parent.add_child(tree)
	_add_cylinder(tree, "Tree trunk", Vector3(0, 1.05, 0), 0.19, 0.26, 2.1, Color("806044"), 8)
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		var offset := Vector3(cos(angle) * 0.58, 2.4 + float(i % 3) * 0.16, sin(angle) * 0.58)
		_add_sphere(tree, "Leaf crown", offset, Vector3(0.75, 0.62, 0.72), Color("368b48") if i % 2 == 0 else Color("58a84d"), 10, 7)
	_add_sphere(tree, "Tree top leaves", Vector3(0, 3.0, 0), Vector3(0.78, 0.8, 0.78), Color("60aa4a"), 10, 7)

func _build_fryer_station() -> void:
	var pos := Vector3(-4.7, 0.2, -6.75)
	var station := Node3D.new()
	station.name = "Pressure Fryer Station"
	station.position = pos
	add_child(station)
	# Commercial stainless cabinet on adjustable legs, with vented sides.
	for x in [-0.52, 0.52]:
		for z in [-0.42, 0.42]:
			_add_box(station, "Fryer leg", Vector3(x, 0.28, z), Vector3(0.13, 0.42, 0.13), MAT_STEEL_DARK)
	_add_box(station, "Fryer cabinet", Vector3(0, 0.82, 0), Vector3(1.42, 1.05, 1.18), MAT_STEEL, 0.3, 0.42)
	_add_box(station, "Fryer front fascia", Vector3(0, 0.94, 0.606), Vector3(1.25, 0.55, 0.025), Color("849198"), 0.25, 0.34)
	_add_box(station, "Fryer service door", Vector3(0, 0.64, 0.625), Vector3(0.78, 0.38, 0.035), Color("66747a"), 0.35, 0.43)
	_add_box(station, "Fryer door handle", Vector3(0, 0.84, 0.66), Vector3(0.36, 0.045, 0.045), Color("d8dfe1"), 0.55)
	for i in range(6):
		_add_box(station, "Fryer air vent", Vector3(-0.47 + i * 0.18, 0.51, 0.64), Vector3(0.09, 0.025, 0.03), Color("424c52"))
	# Deep oil vat, basket rails and hinged pressure lid.
	_add_box(station, "Vat rim", Vector3(0, 1.37, -0.05), Vector3(1.12, 0.12, 0.98), Color("536168"), 0.3, 0.37)
	_add_box(station, "Fryer oil", Vector3(0, 1.445, -0.05), Vector3(0.92, 0.025, 0.77), Color("322d27"), 0.0, 0.2)
	for x in [-0.32, 0.0, 0.32]:
		_add_cylinder(station, "Basket rail", Vector3(x, 1.52, -0.05), 0.035, 0.035, 0.76, Color("c1c9cb"), 12, Vector3(PI / 2.0, 0, 0))
	# Steel pressure lid hinged up at the rear, gauge and locking handle.
	_add_box(station, "Pressure lid", Vector3(0, 1.66, -0.37), Vector3(1.13, 0.11, 0.3), Color("c4ccce"), 0.2, 0.3)
	_add_cylinder(station, "Pressure dial", Vector3(0.43, 1.25, 0.64), 0.12, 0.12, 0.055, Color("343c42"), 20, Vector3(PI / 2.0, 0, 0))
	_add_cylinder(station, "Dial face", Vector3(0.43, 1.25, 0.68), 0.085, 0.085, 0.02, Color("f5ead6"), 20, Vector3(PI / 2.0, 0, 0))
	_add_box(station, "Pressure handle", Vector3(0, 1.78, -0.23), Vector3(0.5, 0.075, 0.12), Color("333a3f"), 0.08)
	# Control panel, chunky tactile buttons and status lamps.
	_add_box(station, "Fryer control panel", Vector3(0.45, 1.18, 0.66), Vector3(0.46, 0.37, 0.09), Color("29343a"), 0.08)
	_add_box(station, "Fryer control screen", Vector3(0.45, 1.24, 0.716), Vector3(0.29, 0.17, 0.025), Color("7ac5bd"), 0.02)
	for i in range(3):
		_add_cylinder(station, "Fryer control button", Vector3(0.33 + i * 0.12, 1.04, 0.72), 0.035, 0.035, 0.04, [MAT_RED, Color("e9b54e"), Color("73bd73")][i], 12, Vector3(PI / 2.0, 0, 0))
	# Basket with golden chicken; oil glow and steam curl sell the hot food.
	_add_box(station, "Fryer basket", Vector3(-0.3, 1.5, 0.0), Vector3(0.43, 0.09, 0.42), Color("68757a"), 0.15, 0.35)
	for i in range(4):
		_add_drumstick(station, Vector3(-0.42 + float(i % 2) * 0.2, 1.62, -0.12 + float(i / 2) * 0.2), 0.27)
	_add_label(station, "AFC FRYER", Vector3(0, 1.0, 0.69), 0.12, Color("fff5e6"))
	_add_machine_status_light(station, Vector3(-0.45, 1.2, 0.67))
	_add_floor_station_ring(station, Vector3(0, 0.21, 0.8), Color("e9ae37"))

func _build_holding_cabinet() -> void:
	var pos := Vector3(-1.7, 0.22, -6.75)
	var cabinet := Node3D.new()
	cabinet.name = "Heated chicken holding cabinet"
	cabinet.position = pos
	add_child(cabinet)
	_add_box(cabinet, "Hot cabinet base", Vector3(0, 0.25, 0), Vector3(1.18, 0.32, 1.12), MAT_STEEL_DARK, 0.1)
	_add_box(cabinet, "Hot cabinet body", Vector3(0, 1.13, 0), Vector3(1.1, 1.5, 0.98), Color("b5c0c4"), 0.18, 0.38)
	_add_box(cabinet, "Cabinet top cap", Vector3(0, 1.92, 0), Vector3(1.25, 0.14, 1.1), Color("d7dfe0"), 0.15, 0.32)
	# Two framed clear doors with visible rails and product trays inside.
	for x in [-0.26, 0.26]:
		_add_box(cabinet, "Glass cabinet door", Vector3(x, 1.2, 0.51), Vector3(0.47, 1.18, 0.045), Color("9acbd2", 0.46), 0.0, 0.13)
		_add_box(cabinet, "Door frame", Vector3(x - 0.23, 1.2, 0.55), Vector3(0.035, 1.24, 0.045), Color("59666b"), 0.05)
		_add_box(cabinet, "Door frame", Vector3(x + 0.23, 1.2, 0.55), Vector3(0.035, 1.24, 0.045), Color("59666b"), 0.05)
		_add_box(cabinet, "Door handle", Vector3(x + 0.17, 1.18, 0.59), Vector3(0.04, 0.26, 0.04), Color("e6e9e6"), 0.08)
	for y in [0.82, 1.22, 1.62]:
		_add_box(cabinet, "Warming rack", Vector3(0, y, 0.48), Vector3(0.87, 0.045, 0.07), Color("647176"), 0.06)
	for i in range(5):
		_add_drumstick(cabinet, Vector3(-0.33 + float(i % 3) * 0.3, 0.92 + float(i / 3) * 0.38, 0.29), 0.24)
	_add_box(cabinet, "Cabinet temperature display", Vector3(0, 1.85, 0.56), Vector3(0.3, 0.14, 0.05), Color("29353a"), 0.03)
	_add_label(cabinet, "HOLD  •  HOT", Vector3(0, 1.87, 0.59), 0.07, Color("9de0a9"))
	_add_floor_station_ring(cabinet, Vector3(0, 0.205, 0.75), Color("77c6b0"))

func _build_packing_station() -> void:
	var pos := Vector3(1.7, 0.2, -6.7)
	var station := Node3D.new()
	station.name = "AFC meal packing line"
	station.position = pos
	add_child(station)
	# Food-safe work table with welded legs, shelf, lip and ingredient pans.
	for x in [-0.58, 0.58]:
		for z in [-0.38, 0.38]:
			_add_box(station, "Packing table leg", Vector3(x, 0.53, z), Vector3(0.09, 0.9, 0.09), MAT_STEEL_DARK)
	_add_box(station, "Packing table shelf", Vector3(0, 0.34, 0), Vector3(1.28, 0.075, 0.9), Color("7f8d91"), 0.08, 0.4)
	_add_box(station, "Stainless packing top", Vector3(0, 1.0, 0), Vector3(1.5, 0.14, 1.18), Color("d9e0df"), 0.14, 0.28)
	_add_box(station, "Chopping board", Vector3(-0.32, 1.095, 0.03), Vector3(0.54, 0.06, 0.62), Color("ddbd8c"), 0.08, 0.75)
	_add_box(station, "Chicken tray", Vector3(0.42, 1.11, -0.16), Vector3(0.42, 0.09, 0.48), Color("747d7e"), 0.1, 0.4)
	for i in range(4):
		_add_drumstick(station, Vector3(0.3 + float(i % 2) * 0.2, 1.19, -0.29 + float(i / 2) * 0.22), 0.22)
	# Packaging dispenser: stacked AFC boxes with visible red print and chicken emblem.
	_add_box(station, "Packaging rack", Vector3(0.43, 1.37, 0.3), Vector3(0.5, 0.48, 0.34), Color("f0e9dc"), 0.12, 0.5)
	for i in range(3):
		_add_afc_carton(station, Vector3(0.43, 1.59 + i * 0.18, 0.3), Vector3(0.62, 0.15, 0.43))
	_add_box(station, "Packing line pedal", Vector3(0, 0.13, 0.59), Vector3(0.35, 0.09, 0.25), Color("465259"), 0.05)
	_add_label(station, "AFC  •  PACK", Vector3(0, 0.89, 0.61), 0.11, MAT_RED)
	_add_floor_station_ring(station, Vector3(0, 0.21, 0.86), Color("e9ae37"))

func _build_service_counter() -> void:
	var counter := Node3D.new()
	counter.name = "Billing and takeaway counter"
	counter.position = Vector3(4.65, 0.2, -3.25)
	add_child(counter)
	_activate_customer_exterior()
	# Base plinth, red front panels, stainless toe-kick, pale countertop.
	_add_box(counter, "Counter carcass", Vector3(0, 0.62, 0), Vector3(3.2, 1.0, 0.82), MAT_RED_DARK)
	_add_box(counter, "Counter front enamel", Vector3(0, 0.67, 0.43), Vector3(3.08, 0.78, 0.035), MAT_RED)
	for x in [-1.1, 0.0, 1.1]:
		_add_box(counter, "Counter front inset", Vector3(x, 0.68, 0.46), Vector3(0.78, 0.48, 0.025), Color("bd3128"), 0.04)
	_add_box(counter, "Counter toe kick", Vector3(0, 0.17, 0.46), Vector3(3.08, 0.13, 0.08), MAT_STEEL_DARK, 0.04)
	_add_box(counter, "Counter worktop", Vector3(0, 1.15, 0), Vector3(3.38, 0.16, 1.0), Color("f3efe6"), 0.1, 0.37)
	_add_box(counter, "Counter top edge", Vector3(0, 1.22, 0), Vector3(3.42, 0.045, 1.04), Color("fffaf0"), 0.03, 0.34)
	# POS terminal faces the customer. Separate customer display, keypad, receipt roll.
	_add_box(counter, "POS terminal base", Vector3(0.88, 1.31, -0.05), Vector3(0.48, 0.09, 0.38), Color("41484c"), 0.06)
	var terminal := _add_box(counter, "POS touch screen", Vector3(0.88, 1.58, -0.02), Vector3(0.42, 0.48, 0.075), Color("30383e"), 0.07)
	terminal.rotation.x = deg_to_rad(-12.0)
	_add_box(counter, "POS display glow", Vector3(0.88, 1.59, 0.025), Vector3(0.32, 0.31, 0.025), Color("80c9d2"), 0.025)
	_add_box(counter, "Customer display", Vector3(0.43, 1.38, -0.24), Vector3(0.26, 0.21, 0.16), Color("28383f"), 0.04)
	_add_box(counter, "Customer display screen", Vector3(0.43, 1.4, -0.15), Vector3(0.21, 0.13, 0.035), Color("a4d8d9"), 0.02)
	_add_box(counter, "Receipt printer", Vector3(1.34, 1.34, -0.26), Vector3(0.38, 0.25, 0.3), Color("d4d8d6"), 0.05)
	_add_box(counter, "Receipt slot", Vector3(1.34, 1.49, -0.1), Vector3(0.23, 0.035, 0.03), MAT_STEEL_DARK)
	_add_box(counter, "Receipt paper", Vector3(1.34, 1.55, -0.11), Vector3(0.16, 0.1, 0.018), Color("fffdf4"))
	# Distinct jar for tips on the counter, plus a clean order pickup landing.
	_add_box(counter, "Order pickup mat", Vector3(-0.45, 1.255, -0.18), Vector3(0.72, 0.025, 0.55), Color("e3ddce"), 0.04)
	_add_floor_station_ring(counter, Vector3(0.1, 0.22, 0.82), Color("e9ae37"))
	# Side collection table for sales cash: separate from the counter's tip jar.
	var cash_table := Node3D.new()
	cash_table.name = "Cash pickup side table"
	cash_table.position = Vector3(3.0, 0.2, -1.2)
	add_child(cash_table)
	_add_box(cash_table, "Cash table pedestal", Vector3(0, 0.48, 0), Vector3(0.68, 0.78, 0.56), Color("54764f"), 0.1)
	_add_box(cash_table, "Cash table top", Vector3(0, 0.9, 0), Vector3(0.86, 0.12, 0.72), Color("b8c995"), 0.07, 0.55)
	_add_box(cash_table, "Cash tray", Vector3(0, 0.98, -0.03), Vector3(0.56, 0.055, 0.44), Color("495359"), 0.04)
	_add_label(cash_table, "CASH", Vector3(0, 1.04, 0.2), 0.09, Color("fff9eb"))
	cash_bundle = Node3D.new()
	cash_bundle.name = "Collected sale notes"
	cash_bundle.position = Vector3(0.0, 0.12, 0.78)
	cash_table.add_child(cash_bundle)
	for pile in range(3):
		for layer in range(6):
			var note_pos := Vector3(-0.36 + pile * 0.34, 0.035 + layer * 0.026, (pile % 2) * 0.12 - 0.08)
			_add_box(cash_bundle, "Green cash bill", note_pos, Vector3(0.3, 0.024, 0.22), Color("39a84e") if layer % 2 == 0 else Color("5dc864"), 0.006, 0.42)
			_add_box(cash_bundle, "Cash bill seal", note_pos + Vector3(0, 0.014, 0), Vector3(0.08, 0.008, 0.11), Color("e5dc8e"))
	cash_trigger_position = cash_table.to_global(cash_bundle.position + Vector3(0, 0.32, 0))
	cash_bundle.visible = false

func _build_dining_area() -> void:
	# Five rows by five columns create 25 four-seat tables: capacity 100.
	var table_columns := [-5.0, -2.5, 0.0, 2.5, 5.0]
	var table_rows := [-0.1, 2.0, 4.1, 6.2, 8.1]
	for row_z in table_rows:
		for column_x in table_columns:
			var table := Node3D.new()
			table.name = "AFC dining table"
			table.position = Vector3(column_x, 0.2, row_z)
			add_child(table)
			var is_tip_table := is_equal_approx(column_x, 0.0) and is_equal_approx(row_z, 4.1)
			if is_tip_table:
				dining_table_root = table
			_build_dining_table(table, is_tip_table)

func _build_dining_table(table: Node3D, is_tip_table: bool, is_starter_table: bool = false) -> void:
	var table_object := DiningTableObject.new() as DiningTableObject
	table.add_child(table_object)
	table_object.build(is_tip_table)
	if is_starter_table or is_tip_table:
		dining_table_component = table_object
		customer_seat_index = -1
		tip_coins.append_array(table_object.tip_coins)

func _reserve_customer_seat() -> Vector3:
	if not dining_table_component:
		return dining_table_root.global_position + Vector3(-1.22, 0.22, 0.0) if dining_table_root else Vector3.ZERO
	if customer_seat_index < 0:
		customer_seat_index = dining_table_component.reserve_seat()
	return dining_table_component.get_seat_approach_position(customer_seat_index)

func _customer_has_available_seat() -> bool:
	return table_trash_count == 0 and dining_table_component != null and (customer_seat_index >= 0 or dining_table_component.has_available_seat())

func _release_customer_seat() -> void:
	if dining_table_component:
		dining_table_component.release_seat(customer_seat_index)
	customer_seat_index = -1

func _build_player() -> void:
	player_legs.clear()
	player_arms.clear()
	player_root = _create_person("Owner", player_position, true, Color("2866a4")) as Area3D
	player_root.scale = Vector3.ONE * 1.35
	player_position = player_root.position
	player_root.area_entered.connect(_on_player_area_entered)
	player_root.rotation.y = 0.0

func _build_customer(species_index: int = -1) -> void:
	if customer_root:
		customer_root.queue_free()
	if species_index >= 0:
		customer_species_index = posmod(species_index, CUSTOMER_ANIMALS.size())
	customer_is_female = customer_sequence % 2 == 0
	customer_formal = customer_sequence % 3 == 0
	var animal: Dictionary = CUSTOMER_ANIMALS[customer_species_index]
	var jacket_color := Color(String(animal["jacket"]))
	customer_root = _create_person("Waiting customer", Vector3(5.85, 0.22, -2.2), false, jacket_color, animal, customer_is_female, customer_formal)
	customer_root.name = "%s customer" % String(animal["name"])
	customer_root.scale = Vector3.ONE * 1.30
	customer_root.rotation.y = 0.0
	_build_customer_wait_indicator()
	customer_box = _build_afc_box(customer_root, Vector3(0.36, 1.02, -0.30), 0.58)
	customer_root.visible = false
	customer_box.visible = false
	customer_flow = CustomerFlow.NONE

func _build_hired_staff() -> void:
	for worker in hired_workers:
		worker.queue_free()
	hired_workers.clear()
	billing_staff_root = null
	billing_staff_arms.clear()
	var shirt_colors := [Color("467da0"), Color("ab4939"), Color("5d8054"), Color("4b4d76")]
	for i in range(employees):
		var spot: Vector3 = [Vector3(-4.7, 0.22, -5.35), Vector3(-1.7, 0.22, -5.35), Vector3(1.7, 0.22, -5.3), Vector3(4.6, 0.22, -1.95)][mini(i, 3)]
		var worker := _create_person("AFC Staff %d" % (i + 1), spot, false, shirt_colors[i])
		if i == 0:
			worker.name = "AFC counter billing crew"
			worker.position = billing_counter_position + Vector3(2.85, 0.04, -0.65)
			billing_staff_root = worker
		hired_workers.append(worker)

func _create_person(
	person_name: String,
	pos: Vector3,
	owner: bool,
	shirt_color: Color,
	animal: Dictionary = {},
	is_female: bool = false,
	is_formal: bool = false
) -> Node3D:
	var root: Node3D
	if owner:
		var player_area := Area3D.new()
		player_area.collision_layer = 2
		player_area.collision_mask = 4
		player_area.monitorable = true
		var player_shape_node := CollisionShape3D.new()
		var player_shape := SphereShape3D.new()
		player_shape.radius = 0.48
		player_shape_node.shape = player_shape
		player_shape_node.position.y = 0.75
		player_area.add_child(player_shape_node)
		root = player_area
	else:
		root = Node3D.new()
	root.name = person_name
	root.position = pos
	add_child(root)
	if owner:
		_build_blocky_owner(root)
		return root
	if person_name == "Waiting customer":
		_build_lego_customer(root, shirt_color, animal, is_female, is_formal)
		return root
	_add_sphere(root, "soft foot shadow", Vector3(0, 0.035, 0), Vector3(0.38, 0.035, 0.29), Color(0.13, 0.15, 0.16, 0.18), 16, 8)
	# Brown trousers and articulated shins, facing from the camera into the shop.
	var legs: Array[Node3D] = []
	for x in [-0.12, 0.12]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.54, 0)
		root.add_child(leg)
		_add_capsule(leg, "Trouser leg", Vector3(0, -0.18, 0), 0.085, 0.43, Color("554438"), 10, 5)
		_add_box(leg, "Work shoe", Vector3(0, -0.4, 0.035), Vector3(0.16, 0.10, 0.27), Color("302b2a"), 0.045)
		legs.append(leg)
	# Blue polo shirt, shoulders, apron, seams, and AFC name patch.
	_add_capsule(root, "Blue uniform torso", Vector3(0, 1.03, 0), 0.235, 0.61, shirt_color, 12, 7)
	_add_box(root, "Uniform collar", Vector3(0, 1.32, 0.025), Vector3(0.19, 0.07, 0.08), Color("d9e2e3"), 0.025)
	_add_box(root, "AFC uniform patch", Vector3(0.0, 1.1, 0.229), Vector3(0.16, 0.12, 0.025), MAT_CREAM, 0.02)
	_add_label(root, "AFC", Vector3(0.0, 1.08, 0.246), 0.043, MAT_RED)
	if person_name == "Waiting customer":
		# A distinguishable smart-casual guest with phone and shoulder bag. This
		# separates customers from AFC staff without permanent text overhead.
		_add_box(root, "Customer smart jacket", Vector3(0, 1.04, 0.01), Vector3(0.46, 0.48, 0.32), shirt_color, 0.08)
		_add_box(root, "Customer shirt collar", Vector3(0, 1.29, -0.17), Vector3(0.16, 0.07, 0.025), Color("edf2f3"), 0.01)
		_add_box(root, "Customer bag strap", Vector3(-0.18, 1.04, -0.18), Vector3(0.05, 0.48, 0.03), Color("4a3429"), 0.01)
	if owner:
		_add_box(root, "Owner apron", Vector3(0, 0.88, 0.205), Vector3(0.27, 0.35, 0.055), Color("e9e2d3"), 0.04)
		_add_box(root, "Apron chest", Vector3(0, 1.08, 0.224), Vector3(0.22, 0.18, 0.045), Color("eee7d9"), 0.035)
	# Head, ears, neck and small nose. Face points toward the service area (-Z).
	_add_cylinder(root, "Neck", Vector3(0, 1.39, 0), 0.085, 0.08, 0.12, Color("b97c5d"), 10)
	_add_sphere(root, "Head", Vector3(0, 1.61, 0), Vector3(0.205, 0.245, 0.195), Color("c98f6b"), 16, 10)
	_add_sphere(root, "Nose", Vector3(0, 1.60, -0.19), Vector3(0.044, 0.055, 0.025), Color("dba17b"), 10, 6)
	for x in [-0.075, 0.075]:
		_add_sphere(root, "Eye", Vector3(x, 1.67, -0.174), Vector3(0.018, 0.024, 0.015), Color("302926"), 8, 5)
	# Red baseball cap with curved crown and broad brim.
	_add_sphere(root, "Red cap crown", Vector3(0, 1.83, 0), Vector3(0.225, 0.105, 0.21), MAT_RED, 14, 8)
	_add_box(root, "Cap visor", Vector3(0, 1.79, -0.16), Vector3(0.34, 0.045, 0.24), Color("b7221d"), 0.07)
	_add_box(root, "Cap AFC badge", Vector3(0, 1.87, -0.198), Vector3(0.09, 0.06, 0.018), MAT_CREAM, 0.015)
	# Arms parented at shoulders; opposing swing makes walking legible.
	var arms: Array[Node3D] = []
	for x in [-0.26, 0.26]:
		var arm := Node3D.new()
		arm.position = Vector3(x, 1.25, 0)
		root.add_child(arm)
		_add_capsule(arm, "Blue sleeve", Vector3(0, -0.13, 0), 0.09, 0.28, shirt_color, 10, 6)
		_add_capsule(arm, "Forearm", Vector3(0, -0.34, 0), 0.062, 0.24, Color("c98f6b"), 10, 6)
		_add_sphere(arm, "Hand", Vector3(0, -0.47, -0.01), Vector3(0.073, 0.07, 0.07), Color("c98f6b"), 10, 6)
		arms.append(arm)
	if person_name == "Waiting customer":
		_add_box(root, "Customer smartphone", Vector3(0.32, 0.88, -0.11), Vector3(0.09, 0.17, 0.035), Color("1c252a"), 0.018)
		_add_box(root, "Customer phone screen", Vector3(0.32, 0.88, -0.135), Vector3(0.064, 0.115, 0.012), Color("73cbd2"), 0.01)
	if owner:
		player_legs = legs
		player_arms = arms
	elif person_name == "AFC Staff 1":
		billing_staff_arms.assign(arms)
	return root

func _build_lego_customer(root: Node3D, jacket_color: Color, animal: Dictionary, is_female: bool, is_formal: bool) -> void:
	customer_arms.clear()
	customer_legs.clear()
	customer_tail_pivot = null
	_add_cylinder(root, "Customer minifigure foot shadow", Vector3(0, 0.035, 0), 0.31, 0.31, 0.045, Color(0.10, 0.11, 0.12, 0.18), 12)
	var trouser_color := Color("343c49") if is_formal else Color("536276")
	for x in [-0.16, 0.16]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.48, 0)
		root.add_child(leg)
		_add_box(leg, "Customer trousers", Vector3(0, -0.16, 0), Vector3(0.20, 0.40, 0.24), trouser_color, 0.025, 0.52)
		_add_box(leg, "Customer polished shoes", Vector3(0, -0.39, -0.05), Vector3(0.23, 0.12, 0.32), Color("282522"), 0.035, 0.34)
		customer_legs.append(leg)
	_add_box(root, "Customer white dress shirt", Vector3(0, 0.98, 0.0), Vector3(0.53, 0.65, 0.34), Color("fff4df"), 0.055, 0.48)
	if is_female:
		_add_box(root, "Customer shaped waist", Vector3(0, 0.75, 0.0), Vector3(0.46, 0.30, 0.34), Color("fff4df"), 0.045, 0.48)
		_add_box(root, "Customer feminine skirt hips", Vector3(0, 0.61, 0.0), Vector3(0.62, 0.32, 0.40), trouser_color, 0.055, 0.54)
	if is_formal:
		_add_box(root, "Customer formal jacket", Vector3(0, 1.00, 0.075), Vector3(0.70, 0.66, 0.36), jacket_color, 0.07, 0.46)
		_add_box(root, "Customer shirt front", Vector3(0, 1.00, -0.115), Vector3(0.22, 0.58, 0.035), Color("fff8e9"), 0.02)
		if not is_female:
			_add_box(root, "Customer formal tie", Vector3(0, 0.98, -0.15), Vector3(0.09, 0.40, 0.035), MAT_RED, 0.02)
			_add_box(root, "Customer tie knot", Vector3(0, 1.24, -0.16), Vector3(0.12, 0.09, 0.045), MAT_RED_DARK, 0.025)
		for side in [-1.0, 1.0]:
			var lapel := _add_box(root, "Customer formal lapel", Vector3(side * 0.16, 1.20, -0.14), Vector3(0.13, 0.29, 0.045), jacket_color.lightened(0.14), 0.025, 0.40)
			lapel.rotation.z = side * deg_to_rad(-22.0)
		_add_box(root, "Customer jacket pocket", Vector3(-0.23, 0.91, -0.15), Vector3(0.16, 0.12, 0.025), jacket_color.darkened(0.12), 0.015)
	else:
		_add_box(root, "Customer colorful casual top", Vector3(0, 1.00, 0.075), Vector3(0.68, 0.60, 0.35), jacket_color.lightened(0.12), 0.07, 0.62)
		_add_box(root, "Customer casual shirt front", Vector3(0, 1.00, -0.11), Vector3(0.18, 0.48, 0.025), Color("fff4df"), 0.015)
		_add_box(root, "Customer casual collar", Vector3(0, 1.25, -0.14), Vector3(0.24, 0.09, 0.035), Color("fff4df"), 0.025)
	if is_female:
		_add_sphere(root, "Customer necklace pendant", Vector3(0, 1.20, -0.18), Vector3(0.035, 0.045, 0.025), Color("e9c76c"), 8, 5)
	for i in range(3):
		_add_sphere(root, "Customer clothing button", Vector3(0.18, 0.92 - i * 0.12, -0.17), Vector3(0.025, 0.025, 0.018), Color("e8c76d"), 8, 5)
	for x in [-0.39, 0.39]:
		var arm := Node3D.new()
		arm.position = Vector3(x, 1.22, 0)
		root.add_child(arm)
		_add_box(arm, "Customer jacket or shirt sleeve", Vector3(0, -0.17, 0), Vector3(0.20, 0.43, 0.25), jacket_color, 0.055, 0.45)
		_add_cylinder(arm, "Customer white cuff", Vector3(0, -0.36, -0.015), 0.11, 0.11, 0.12, Color("fff4df"), 10)
		_add_sphere(arm, "Customer toy hand", Vector3(0, -0.46, -0.04), Vector3(0.12, 0.11, 0.10), Color("f2c43f"), 10, 6)
		customer_arms.append(arm)
	_build_animal_customer_head(root, animal, is_female)
	_build_animal_customer_tail(root, animal)

func _build_animal_customer_head(root: Node3D, animal: Dictionary, is_female: bool) -> void:
	var species := String(animal["name"])
	var fur := Color(String(animal["fur"]))
	var muzzle := Color(String(animal["muzzle"]))
	var inner_ear := Color(String(animal["inner_ear"]))
	var face_color := Color("292827")
	var head_center := Vector3(0.0, 1.72, 0.0)
	if species == "Lion":
		var mane_color := Color(String(animal["mane"]))
		_add_sphere(root, "Lion flowing dark mane", head_center + Vector3(0, 0.01, 0.035), Vector3(0.44, 0.45, 0.36), mane_color, 16, 10)
		for x in [-0.29, 0.29]:
			_add_sphere(root, "Lion mane cheek tuft", head_center + Vector3(x, -0.08, -0.01), Vector3(0.12, 0.22, 0.20), mane_color.lightened(0.08), 12, 8)
	elif species == "Tiger":
		face_color = Color("201f20")
	elif species == "Panda":
		face_color = Color("17191b")
	elif species == "Fox":
		face_color = Color("302723")
	_add_sphere(root, "%s animal face" % species, head_center, Vector3(0.33, 0.345, 0.28), fur, 16, 10)

	if species == "Elephant":
		for x in [-0.29, 0.29]:
			var ear := _add_sphere(root, "Elephant broad floppy ear", head_center + Vector3(x, -0.01, 0.015), Vector3(0.24, 0.28, 0.075), fur, 12, 8)
			ear.rotation.z = -signf(x) * 0.20
		_add_sphere(root, "Elephant trunk bridge", head_center + Vector3(0.0, -0.16, -0.275), Vector3(0.105, 0.20, 0.105), fur.darkened(0.04), 12, 8)
		_add_sphere(root, "Elephant curved trunk tip", head_center + Vector3(0.025, -0.30, -0.30), Vector3(0.085, 0.10, 0.09), fur.darkened(0.04), 12, 8)
		_add_sphere(root, "Elephant ivory tusk", head_center + Vector3(-0.15, -0.15, -0.28), Vector3(0.045, 0.10, 0.05), Color("fff0d4"), 10, 6)
	elif species == "Giraffe":
		for x in [-0.13, 0.13]:
			_add_cylinder(root, "Giraffe ossicone", head_center + Vector3(x, 0.29, 0.0), 0.035, 0.035, 0.17, fur.darkened(0.12), 10)
			_add_sphere(root, "Giraffe ossicone tip", head_center + Vector3(x, 0.39, 0.0), Vector3(0.065, 0.06, 0.06), Color("80512f"), 10, 6)
		for x in [-0.18, 0.0, 0.18]:
			for y in [-0.05, 0.08]:
				_add_sphere(root, "Giraffe brown face spot", head_center + Vector3(x, y, -0.286), Vector3(0.047, 0.055, 0.022), Color("a9632f"), 8, 5)
	elif species == "Zebra":
		for x in [-1.0, 1.0]:
			for stripe in range(3):
				var mark := _add_box(root, "Zebra face stripe", head_center + Vector3(x * (0.12 + stripe * 0.052), -0.015 + stripe * 0.07, -0.285), Vector3(0.032, 0.15, 0.024), Color("282a2b"), 0.012, 0.8)
				mark.rotation.z = -x * deg_to_rad(20.0 + stripe * 10.0)
	elif species == "Deer":
		for x in [-0.14, 0.14]:
			_add_cylinder(root, "Deer antler stem", head_center + Vector3(x, 0.31, 0.02), 0.028, 0.045, 0.20, Color("805638"), 8, Vector3(0.0, 0.0, -signf(x) * 0.12))
			for branch in [-1.0, 1.0]:
				var tine := _add_cylinder(root, "Deer antler tine", head_center + Vector3(x + branch * 0.055, 0.40, 0.02), 0.018, 0.026, 0.13, Color("805638"), 8, Vector3(0.0, 0.0, branch * 0.38))
	elif species == "Penguin":
		for x in [-0.095, 0.095]:
			_add_sphere(root, "Penguin dark eye patch", head_center + Vector3(x, 0.045, -0.285), Vector3(0.095, 0.125, 0.035), Color("15191f"), 10, 7)
		_add_sphere(root, "Penguin golden beak", head_center + Vector3(0.0, -0.07, -0.35), Vector3(0.095, 0.065, 0.065), Color("e6a836"), 10, 6)
	elif species == "Koala":
		_add_sphere(root, "Koala broad dark nose", head_center + Vector3(0.0, -0.065, -0.354), Vector3(0.085, 0.105, 0.045), Color("252729"), 10, 7)
	elif species == "Hippo":
		for x in [-0.13, 0.13]:
			_add_sphere(root, "Hippo wide muzzle pad", head_center + Vector3(x, -0.11, -0.30), Vector3(0.14, 0.105, 0.09), muzzle, 12, 8)
		for x in [-0.075, 0.075]:
			_add_sphere(root, "Hippo nostril", head_center + Vector3(x, -0.035, -0.377), Vector3(0.025, 0.035, 0.015), Color("513f45"), 8, 5)
	elif species == "Rabbit":
		_add_sphere(root, "Rabbit fluffy cheek", head_center + Vector3(0.0, -0.19, -0.27), Vector3(0.16, 0.09, 0.055), muzzle, 10, 6)

	for x in [-1.0, 1.0]:
		if species == "Elephant":
			continue
		var ear_scale := Vector3(0.115, 0.12, 0.095)
		if species == "Koala":
			ear_scale = Vector3(0.21, 0.22, 0.075)
		elif species == "Elephant":
			ear_scale = Vector3(0.01, 0.01, 0.01)
		var ear_height := 0.20 if species == "Fox" else (0.10 if species == "Panda" else 0.0)
		if species == "Rabbit":
			ear_scale = Vector3(0.09, 0.24, 0.065)
			ear_height = 0.20
		elif species in ["Wolf", "Deer", "Giraffe"]:
			ear_scale = Vector3(0.095, 0.18, 0.075)
			ear_height = 0.04
		var ear_position := head_center + Vector3(x * 0.215, 0.21 + ear_height, -0.01)
		var ear := _add_sphere(root, "%s rounded animal ear" % species, ear_position, ear_scale, fur, 12, 8)
		if species == "Fox":
			ear.scale = Vector3(0.10, 0.20, 0.08)
		if species != "Elephant":
			var inner_size := Vector3(0.064, 0.067, 0.025)
			if species == "Rabbit":
				inner_size = Vector3(0.045, 0.16, 0.022)
			elif species == "Koala":
				inner_size = Vector3(0.12, 0.13, 0.025)
			elif species in ["Wolf", "Deer", "Giraffe"]:
				inner_size = Vector3(0.05, 0.10, 0.025)
			_add_sphere(root, "%s inner ear" % species, ear_position + Vector3(0, 0, -0.073), inner_size, inner_ear, 10, 6)

	if species == "Panda":
		for x in [-0.095, 0.095]:
			var patch := _add_sphere(root, "Panda dark eye patch", head_center + Vector3(x, 0.015, -0.285), Vector3(0.095, 0.12, 0.045), face_color, 12, 8)
			patch.rotation.z = -signf(x) * 0.32
	elif species == "Tiger":
		for x in [-1.0, 1.0]:
			for stripe in range(2):
				var cheek_mark := _add_box(root, "Tiger cheek stripe", head_center + Vector3(x * (0.19 + stripe * 0.035), -0.09 + stripe * 0.095, -0.279), Vector3(0.045, 0.12, 0.025), face_color, 0.018, 0.82)
				cheek_mark.rotation.z = -x * deg_to_rad(20.0 + stripe * 15.0)
			var brow_mark := _add_box(root, "Tiger forehead stripe", head_center + Vector3(x * 0.055, 0.19, -0.270), Vector3(0.045, 0.13, 0.022), face_color, 0.015, 0.8)
			brow_mark.rotation.z = x * deg_to_rad(18.0)

	for x in [-0.105, 0.105]:
		_add_sphere(root, "%s bright eye" % species, head_center + Vector3(x, 0.055, -0.306), Vector3(0.052, 0.060, 0.026), Color("fff7e8"), 10, 6)
		_add_sphere(root, "%s dark pupil" % species, head_center + Vector3(x, 0.052, -0.331), Vector3(0.026, 0.037, 0.014), face_color, 8, 5)
		_add_sphere(root, "%s eye glint" % species, head_center + Vector3(x - 0.008, 0.067, -0.345), Vector3(0.010, 0.014, 0.008), Color.WHITE, 7, 4)
		var brow := _add_box(root, "%s expressive eyebrow" % species, head_center + Vector3(x, 0.135, -0.30), Vector3(0.105, 0.035, 0.025), face_color, 0.015, 0.8)
		brow.rotation.z = -signf(x) * deg_to_rad(8.0)
	var muzzle_dimensions := Vector3(0.12, 0.09, 0.075) if species == "Monkey" else Vector3(0.105, 0.078, 0.075)
	for x in [-0.055, 0.055]:
		_add_sphere(root, "%s soft muzzle" % species, head_center + Vector3(x, -0.10, -0.282), muzzle_dimensions, muzzle, 12, 8)
	_add_sphere(root, "%s animal nose" % species, head_center + Vector3(0, -0.065, -0.35), Vector3(0.048, 0.033, 0.026), face_color, 10, 6)
	var smile := _add_box(root, "%s friendly mouth" % species, head_center + Vector3(0, -0.17, -0.337), Vector3(0.11, 0.018, 0.012), Color("51342e"), 0.008, 0.9)
	smile.rotation.z = deg_to_rad(-5.0)
	_add_box(root, "%s visible front teeth" % species, head_center + Vector3(0.0, -0.19, -0.35), Vector3(0.10, 0.04, 0.018), Color("fff4df"), 0.008, 0.4)
	if species in ["Lion", "Tiger", "Fox"]:
		for x in [-1.0, 1.0]:
			_add_sphere(root, "%s cheek whisker pad" % species, head_center + Vector3(x * 0.18, -0.115, -0.32), Vector3(0.105, 0.075, 0.055), muzzle, 10, 6)
			for whisker in range(2):
				var whisker_line := _add_box(
					root,
					"%s fine whisker" % species,
					head_center + Vector3(x * 0.27, -0.105 - float(whisker) * 0.045, -0.34),
					Vector3(0.15, 0.012, 0.009),
					Color("f2e7d4"),
					0.004,
					0.8
				)
				whisker_line.rotation.z = -x * deg_to_rad(8.0)
	if is_female:
		var hair_color := Color("493126")
		_add_sphere(root, "Customer hair crown", head_center + Vector3(0.0, 0.24, 0.12), Vector3(0.34, 0.17, 0.29), hair_color, 12, 8)
		for x in [-1.0, 1.0]:
			_add_sphere(root, "Customer long side hair", head_center + Vector3(x * 0.27, -0.015, 0.055), Vector3(0.105, 0.25, 0.13), hair_color, 10, 7)
	if species == "Monkey":
		_add_sphere(root, "Monkey forehead brow", head_center + Vector3(0, 0.13, -0.255), Vector3(0.17, 0.075, 0.05), fur.darkened(0.08), 10, 6)
	if species == "Fox":
		_add_sphere(root, "Fox white chin bib", head_center + Vector3(0, -0.13, -0.27), Vector3(0.14, 0.10, 0.055), muzzle, 12, 7)
	if species == "Lion":
		_add_sphere(root, "Lion gold forehead", head_center + Vector3(0, 0.19, -0.22), Vector3(0.14, 0.10, 0.05), fur.lightened(0.08), 10, 6)

func _build_animal_customer_tail(root: Node3D, animal: Dictionary) -> void:
	var species := String(animal["name"])
	var tail_color := Color(String(animal["tail"]))
	customer_tail_pivot = Node3D.new()
	customer_tail_pivot.name = "%s animated tail" % species
	customer_tail_pivot.position = Vector3(0, 0.70, 0.16)
	customer_tail_pivot.rotation.x = PI * 0.5
	root.add_child(customer_tail_pivot)
	var segment_count := 5 if species in ["Monkey", "Fox"] else 4
	for index in range(segment_count):
		var segment_color := tail_color
		if species in ["Tiger", "Zebra"] and index % 2 == 1:
			segment_color = Color("292321")
		if species == "Panda" and index == segment_count - 1:
			segment_color = Color("fff7e9")
		var segment := _add_capsule(
			customer_tail_pivot,
			"%s tail segment %d" % [species, index + 1],
			Vector3(0, 0.13 + float(index) * 0.14, 0),
			0.075 if species != "Monkey" else 0.060,
			0.24,
			segment_color,
			10,
			6
		)
		segment.rotation.x = deg_to_rad(-12.0) if species in ["Fox", "Monkey"] and index >= 3 else 0.0
	if species == "Lion":
		_add_sphere(customer_tail_pivot, "Lion tail tuft", Vector3(0, 0.70, 0), Vector3(0.11, 0.13, 0.12), Color(String(animal["mane"])), 10, 7)
	elif species == "Rabbit":
		_add_sphere(customer_tail_pivot, "Rabbit fluffy tail", Vector3(0, 0.68, 0), Vector3(0.12, 0.12, 0.12), Color("fff4e8"), 10, 7)
	elif species == "Fox":
		_add_sphere(customer_tail_pivot, "Fox white tail tip", Vector3(0, 0.73, 0), Vector3(0.085, 0.12, 0.095), Color(String(animal["muzzle"])), 10, 7)
	elif species == "Monkey":
		var curl := _add_capsule(customer_tail_pivot, "Monkey curled tail end", Vector3(0.055, 0.72, 0), 0.045, 0.23, tail_color, 10, 6)
		curl.rotation.z = PI * 0.5

func _build_blocky_owner(root: Node3D) -> void:
	# Toy-like block figure: square uniform, cylindrical yellow head, red cap,
	# simple printed AFC badge and chunky hinged limbs. No external model needed.
	_add_sphere(root, "Soft foot shadow", Vector3(0, 0.035, 0), Vector3(0.39, 0.035, 0.30), Color(0.13, 0.15, 0.16, 0.18), 16, 8)
	var yellow := Color("f4c43f")
	var white := Color("fff4dc")
	# Two straight black toy legs and broad shoes.
	for x in [-0.13, 0.13]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.48, 0.0)
		root.add_child(leg)
		_add_box(leg, "Block trouser leg", Vector3(0, -0.16, 0), Vector3(0.19, 0.36, 0.22), Color("26282c"), 0.025)
		_add_box(leg, "Square work shoe", Vector3(0, -0.38, -0.045), Vector3(0.23, 0.12, 0.31), Color("17191c"), 0.035)
		player_legs.append(leg)
	# White short sleeve shirt under a bright AFC-red rectangular apron torso.
	_add_box(root, "White staff shirt", Vector3(0, 0.93, 0), Vector3(0.47, 0.53, 0.29), white, 0.045)
	_add_box(root, "AFC red apron torso", Vector3(0, 0.94, -0.165), Vector3(0.39, 0.49, 0.055), MAT_RED, 0.035)
	_add_box(root, "AFC apron waist band", Vector3(0, 0.73, -0.17), Vector3(0.40, 0.07, 0.06), Color("b92520"), 0.015)
	_add_box(root, "AFC chest badge", Vector3(0, 1.08, -0.204), Vector3(0.15, 0.14, 0.018), white, 0.018)
	_add_label(root, "AFC", Vector3(0, 1.075, -0.219), 0.047, MAT_RED)
	# Yellow cylindrical toy head, front-facing eyes and a curved red cap with a visor.
	_add_cylinder(root, "Yellow toy neck", Vector3(0, 1.24, 0), 0.09, 0.09, 0.12, yellow, 12)
	_add_cylinder(root, "Round yellow toy head", Vector3(0, 1.48, 0), 0.235, 0.235, 0.40, yellow, 20)
	for x in [-0.075, 0.075]:
		_add_sphere(root, "Friendly dark eye", Vector3(x, 1.51, -0.255), Vector3(0.028, 0.045, 0.022), Color("202124"), 10, 6)
	_add_box(root, "Simple curved smile", Vector3(0, 1.39, -0.255), Vector3(0.10, 0.018, 0.020), Color("714322"), 0.008)
	_add_sphere(root, "Red cap crown", Vector3(0, 1.72, 0), Vector3(0.25, 0.15, 0.235), MAT_RED, 16, 8)
	_add_box(root, "Cap crown dark seam", Vector3(0, 1.745, 0.16), Vector3(0.26, 0.025, 0.055), Color("a71f1b"), 0.015)
	_add_box(root, "Forward cap brim", Vector3(0, 1.68, -0.19), Vector3(0.36, 0.055, 0.23), Color("b9221d"), 0.025)
	_add_box(root, "Cap visor highlight", Vector3(0, 1.715, -0.27), Vector3(0.22, 0.015, 0.075), Color("f05a4f"), 0.01)
	_add_box(root, "AFC cap badge", Vector3(0, 1.76, -0.232), Vector3(0.105, 0.075, 0.018), white, 0.012)
	_add_label(root, "AFC", Vector3(0, 1.75, -0.247), 0.03, MAT_RED)
	# Block arms swing from the shoulders; yellow hands read as toy figure hands.
	for x in [-0.30, 0.30]:
		var arm := Node3D.new()
		arm.position = Vector3(x, 1.12, 0)
		root.add_child(arm)
		_add_box(arm, "White staff sleeve", Vector3(0, -0.095, 0), Vector3(0.16, 0.25, 0.23), white, 0.04)
		_add_box(arm, "Red apron strap", Vector3(0, -0.10, -0.13), Vector3(0.09, 0.23, 0.025), MAT_RED, 0.012)
		_add_cylinder(arm, "Yellow toy forearm", Vector3(0, -0.30, 0), 0.075, 0.075, 0.22, yellow, 10)
		_add_sphere(arm, "Yellow toy hand", Vector3(0, -0.43, -0.01), Vector3(0.10, 0.10, 0.095), Color("f2bd35"), 10, 6)
		player_arms.append(arm)

func _animate_player() -> void:
	if not player_root:
		return
	var walk_cycle_rate := 7.0 * WALK_SPEED / 2.4
	var stride := sin(anim_time * walk_cycle_rate) if player_walking and not player_working else 0.0
	for i in range(player_legs.size()):
		player_legs[i].rotation.x = stride * (0.52 if i == 0 else -0.52)
	for i in range(player_arms.size()):
		var carrying := carried_chickens > 0 or carried_order_pieces > 0 or carried_trash_count > 0
		if carrying and not player_working:
			_animate_carrying_pose(i)
		elif player_working and service_stage == ServiceStage.BILL_CUSTOMER:
			_animate_billing_pose(i, service_action_duration - service_action_time)
		elif player_working:
			player_arms[i].rotation.x = -0.75 + sin(anim_time * walk_cycle_rate + float(i) * PI) * 0.18
			player_arms[i].rotation.z = 0.0
		else:
			player_arms[i].rotation.x = stride * (-0.38 if i == 0 else 0.38)
			player_arms[i].rotation.z = 0.0
	player_root.position.y = 0.22 + (absf(stride) * 0.035 if player_walking else (sin(anim_time * 7.0) * 0.012 if player_working else 0.0))

func _animate_carrying_pose(arm_index: int) -> void:
	var side := -1.0 if arm_index == 0 else 1.0
	player_arms[arm_index].rotation.x = 1.10 + sin(anim_time * 3.0 + float(arm_index) * PI) * 0.025
	player_arms[arm_index].rotation.z = side * 0.035

func _animate_billing_pose(arm_index: int, elapsed: float) -> void:
	var side := -1.0 if arm_index == 0 else 1.0
	if elapsed < BILLING_PROCESS_DURATION / 3.0:
		player_arms[arm_index].rotation.x = 0.72 + sin(anim_time * 12.0 + float(arm_index) * PI) * 0.13
		player_arms[arm_index].rotation.z = side * 0.07
	elif elapsed < BILLING_PROCESS_DURATION * 2.0 / 3.0:
		player_arms[arm_index].rotation.x = (1.02 if arm_index == 0 else 0.86) + sin(anim_time * 5.0 + float(arm_index) * PI) * 0.06
		player_arms[arm_index].rotation.z = side * 0.11
	else:
		player_arms[arm_index].rotation.x = 1.20 + sin(anim_time * 4.0 + float(arm_index) * PI) * 0.05
		player_arms[arm_index].rotation.z = side * 0.04

func _animate_billing_staff(is_working: bool) -> void:
	for index in range(billing_staff_arms.size()):
		var arm := billing_staff_arms[index]
		if not is_instance_valid(arm):
			continue
		var side := -1.0 if index == 0 else 1.0
		var target_x := 0.78 + sin(anim_time * 8.0 + float(index) * PI) * 0.12 if is_working else 0.0
		var target_z := side * 0.08 if is_working else 0.0
		arm.rotation.x = lerpf(arm.rotation.x, target_x, 0.22)
		arm.rotation.z = lerpf(arm.rotation.z, target_z, 0.22)

func _animate_customer() -> void:
	if not customer_root:
		return
	if customer_sitting:
		if customer_tail_pivot:
			customer_tail_pivot.rotation.y = 0.0
			customer_tail_pivot.rotation.x = PI * 0.5
		for leg in customer_legs:
			leg.rotation.x = 1.28
		for arm in customer_arms:
			arm.rotation.x = -0.55
			arm.rotation.z = 0.0
		return
	if customer_tail_pivot:
		customer_tail_pivot.rotation.y = sin(anim_time * 2.8) * 0.20
		customer_tail_pivot.rotation.x = PI * 0.5 + sin(anim_time * 2.1 + float(customer_species_index)) * 0.07
	var moving := customer_flow in [CustomerFlow.ARRIVING, CustomerFlow.WALKING_TO_TABLE, CustomerFlow.LEAVING]
	var walk_rate := 5.3 if customer_is_female else 6.4
	var stride := sin(anim_time * walk_rate) if moving else 0.0
	for i in range(customer_legs.size()):
		var walking_pose := stride * (0.48 if i == 0 else -0.48)
		customer_legs[i].rotation.x = walking_pose
	for i in range(customer_arms.size()):
		if customer_flow == CustomerFlow.RECEIVING:
			customer_arms[i].rotation.x = -0.72 + sin(anim_time * 7.0 + float(i) * PI) * 0.16
		elif customer_flow == CustomerFlow.EATING:
			var eating_motion := (sin(anim_time * 2.0 + float(i) * PI) + 1.0) * 0.5
			customer_arms[i].rotation.x = lerpf(-0.18, -1.02, eating_motion)
			customer_arms[i].rotation.z = (-0.12 if i == 0 else 0.12) * eating_motion
		else:
			customer_arms[i].rotation.x = stride * (-0.32 if i == 0 else 0.32)
			customer_arms[i].rotation.z = (sin(anim_time * walk_rate * 0.5) * 0.035 if customer_is_female else 0.0)

func _face_person_toward(person: Node3D, target: Vector3, delta: float) -> void:
	var direction := target - person.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	person.rotation.y = lerp_angle(person.rotation.y, target_yaw, delta * 5.0)

func _build_marker() -> void:
	marker = Node3D.new()
	marker.name = "Current marked floor tile"
	add_child(marker)
	var floor_mark := BoxMesh.new()
	floor_mark.size = Vector3(1.20, 0.008, 1.20)
	marker_torus = MeshInstance3D.new()
	marker_torus.name = "Subtle transparent floor marker"
	marker_torus.mesh = floor_mark
	marker_torus.position.y = -0.005
	marker_torus.material_override = _transparent_floor_material(Color("d8d1c5"), 0.07)
	marker.add_child(marker_torus)

func _add_service_floor_tile(
	tile_id: String,
	tile_position: Vector3,
	accent: Color,
	tile_size: Vector2 = Vector2(1.24, 1.24),
	alpha: float = 0.055,
	border_width: float = 0.0,
	cross_lines: bool = false
) -> void:
	if service_floor_tiles.has(tile_id):
		return
	var tile := Node3D.new()
	tile.name = "%s service floor tile" % tile_id.replace("_", " ").capitalize()
	tile.position = Vector3(tile_position.x, 0.18, tile_position.z)
	add_child(tile)
	var center := _add_box(tile, "Transparent colored tile wash", Vector3(0.0, 0.008, 0.0), Vector3(tile_size.x, 0.008, tile_size.y), accent, 0.0, 0.5)
	center.material_override = _transparent_floor_material(accent, alpha)
	if cross_lines:
		var line_material := _material(Color("f4e4bc"), 0.0, 0.62, true)
		var line_width := 0.075
		for angle in [-PI / 4.0, PI / 4.0]:
			var cross_line := _add_box(
				tile,
				"Light crossed station marking",
				Vector3(0.0, 0.019, 0.0),
				Vector3(minf(tile_size.x, tile_size.y) * 0.72, 0.014, line_width),
				Color("f4e4bc")
			)
			cross_line.rotation.y = angle
			cross_line.material_override = line_material
			cross_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if border_width > 0.0:
		var border_color := Color("d7c7a5")
		var border_material := _material(border_color, 0.0, 0.7, true)
		var border_height := 0.014
		for side in [-1.0, 1.0]:
			var horizontal_border := _add_box(
				tile,
				"Light tile border",
				Vector3(0.0, 0.014, side * (tile_size.y - border_width) * 0.5),
				Vector3(tile_size.x, border_height, border_width),
				border_color
			)
			horizontal_border.material_override = border_material
			horizontal_border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var vertical_border := _add_box(
				tile,
				"Light tile border",
				Vector3(side * (tile_size.x - border_width) * 0.5, 0.014, 0.0),
				Vector3(border_width, border_height, tile_size.y - border_width),
				border_color
			)
			vertical_border.material_override = border_material
			vertical_border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	service_floor_tiles[tile_id] = tile

func _transparent_floor_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_cash_trigger() -> void:
	cash_trigger = Area3D.new()
	cash_trigger.name = "Cash pickup trigger"
	cash_trigger.collision_layer = 4
	cash_trigger.collision_mask = 2
	var trigger_shape_node := CollisionShape3D.new()
	var trigger_shape := SphereShape3D.new()
	trigger_shape.radius = 1.15
	trigger_shape_node.shape = trigger_shape
	trigger_shape_node.position.y = 0.55
	cash_trigger.add_child(trigger_shape_node)
	add_child(cash_trigger)
	cash_trigger.position = cash_trigger_position
	cash_trigger.area_entered.connect(_on_cash_area_entered)
	cash_trigger.monitoring = false

func _on_cash_area_entered(other: Area3D) -> void:
	if other == player_root:
		_collect_cash_stack()

func _on_player_area_entered(other: Area3D) -> void:
	if other == cash_trigger:
		_collect_cash_stack()

func _build_sound_fx() -> void:
	cash_sound = AudioStreamPlayer.new()
	cash_sound.name = "Cash pickup sound"
	cash_sound.stream = _make_cash_sound()
	cash_sound.volume_db = -8.0
	add_child(cash_sound)
	floating_reward = Label3D.new()
	floating_reward.name = "Cash pickup amount popup"
	floating_reward.font_size = 64
	floating_reward.pixel_size = 0.006
	floating_reward.modulate = Color("7ee65e")
	floating_reward.outline_size = 8
	floating_reward.outline_modulate = Color("244427")
	floating_reward.visible = false
	add_child(floating_reward)

func _make_cash_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := 4200
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(stream.mix_rate)
		var envelope := exp(-t * 19.0)
		var sample := (sin(TAU * 1250.0 * t) * 0.62 + sin(TAU * 1880.0 * t) * 0.38) * envelope
		bytes.encode_s16(i * 2, int(sample * 21000.0))
	stream.data = bytes
	return stream

func _collect_cash_stack() -> void:
	if phase != Step.CASH or cash_waiting <= 0:
		return
	var collected := cash_waiting
	var standard_dining_was_unlocked := _table_purchase_unlocked()
	cash_waiting = 0
	wallet += collected
	_refresh_table_purchase_slot()
	var standard_dining_unlocked := not standard_dining_was_unlocked and _table_purchase_unlocked()
	if cash_trigger:
		cash_trigger.monitoring = false
	if cash_sound:
		cash_sound.play()
	if floating_reward:
		floating_reward.text = "+$%d" % collected
		floating_reward.global_position = player_position + Vector3(0, 2.65, 0)
		floating_reward.visible = true
		var text_tween := create_tween()
		text_tween.tween_property(floating_reward, "position:y", floating_reward.position.y + 1.0, 0.9)
		text_tween.finished.connect(func(): floating_reward.visible = false)
	if cash_bundle:
		var fly_tween := create_tween()
		fly_tween.tween_property(cash_bundle, "global_position", player_position + Vector3(0, 1.2, 0), 0.32)
		fly_tween.parallel().tween_property(cash_bundle, "scale", Vector3(0.12, 0.12, 0.12), 0.32)
		fly_tween.finished.connect(func():
			cash_bundle.visible = false
			cash_bundle.scale = Vector3.ONE
		)
	var before := wallet_display
	var wallet_tween := create_tween()
	wallet_tween.tween_method(_set_wallet_display, before, wallet, 0.45)
	phase = Step.TIP if customer_at_table else Step.CUSTOMER
	if standard_dining_unlocked:
		_show_toast("Standard dining unlocked — you can now fund the next table")
	else:
		_show_toast("+$%d cash collected" % collected)
	_save_game()
	_update_marker()
	_update_ui()

func _set_wallet_display(value: int) -> void:
	wallet_display = value
	if money_label:
		money_label.text = "%d" % wallet_display

func _add_floor_station_ring(parent: Node3D, local_position: Vector3, color: Color) -> void:
	var tile := Node3D.new()
	tile.name = "Subtle transparent station floor marker"
	tile.position = Vector3(local_position.x, 0.17 - parent.global_position.y, local_position.z)
	parent.add_child(tile)
	var center := MeshInstance3D.new()
	center.name = "Transparent service floor wash"
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(1.08, 0.008, 1.08)
	center.mesh = center_mesh
	center.material_override = _transparent_floor_material(color, 0.055)
	tile.add_child(center)

func _player_arrived() -> void:
	_animate_player()
	if player_position.distance_to(station_stands[phase]) > 0.82:
		return
	match phase:
		Step.COOK:
			if raw_chicken <= 0:
				_show_toast("Buy raw chicken to refill the fryer")
				return
			_start_station_action(3.5, "Frying a fresh chicken batch…")
		Step.LOAD:
			if cooked_pieces <= 0:
				phase = Step.COOK
				_update_marker()
				_update_ui()
				return
			_start_station_action(2.2, "Loading the AFC holding and pack line…")
		Step.BILL:
			if packed_orders <= 0:
				phase = Step.LOAD if cooked_pieces > 0 else Step.COOK
				_update_marker()
				_update_ui()
				return
			packed_orders -= 1
			cash_waiting += PACK_PRICE
			sales_count += 1
			_refresh_table_purchase_slot()
			phase = Step.CASH
			customer_at_table = false
			customer_walking_to_table = true
			if customer_root:
				customer_root.visible = true
				if customer_box:
					customer_box.visible = true
			_show_toast("Customer got the AFC meal — taking it to a table")
			_save_game()
			_update_marker()
			_update_ui()
		Step.CASH:
			# The cash is collected by walking into its physical floor trigger.
			pass
		Step.CUSTOMER:
			_show_toast("Your customer is heading to the dining table")
		Step.TIP:
			if tip_waiting > 0:
				wallet += tip_waiting
				_refresh_table_purchase_slot()
				_show_toast("+$%d tip collected" % tip_waiting)
				tip_waiting = 0
			if customer_root:
				customer_root.visible = false
			customer_at_table = false
			phase = Step.BILL if packed_orders > 0 else (Step.LOAD if cooked_pieces > 0 else Step.COOK)
			_save_game()
			_update_marker()
			_update_ui()

func _start_station_action(duration: float, text: String) -> void:
	action_time = duration
	action_duration = duration
	status_label.text = text
	_update_ui()

func _finish_station_action() -> void:
	if phase == Step.COOK:
		var batch := mini(raw_chicken, 4)
		raw_chicken -= batch
		cooked_pieces += batch
		phase = Step.LOAD
		_show_toast("4 crispy chicken pieces are ready")
	elif phase == Step.LOAD:
		var batch := mini(cooked_pieces, 4)
		cooked_pieces -= batch
		packed_orders += 1
		phase = Step.BILL
		_show_toast("AFC chicken box packed — customer is waiting")
	_save_game()
	_update_marker()
	_update_ui()

func _update_pickup_visuals() -> void:
	if cash_bundle:
		cash_bundle.visible = cash_waiting > 0
	if cash_trigger:
		cash_trigger.monitoring = cash_waiting > 0
	for coin in tip_coins:
		coin.visible = tip_waiting > 0

func _update_marker() -> void:
	if not marker:
		return
	if not BUILD_INTERIOR_CONTENT:
		marker.visible = false
		return
	marker.position = station_stands[phase]
	marker.visible = true
	if marker_torus:
		marker_torus.material_override = _transparent_floor_material(Color("d8d1c5"), 0.07)

func _guidance_target() -> Dictionary:
	if not shop_owned:
		return {"visible": shop_purchase_root != null, "position": shop_purchase_root.global_position if shop_purchase_root else Vector3.ZERO}
	for slot in build_slots:
		if bool(slot["unlocked"]) and not bool(slot["built"]):
			return {"visible": true, "position": slot["position"] as Vector3}
	if carried_trash_count >= MAX_CARRIED_TRASH:
		return {"visible": true, "position": trash_disposal_position}
	if table_trash_count > 0 and carried_trash_count < MAX_CARRIED_TRASH:
		return {"visible": true, "position": _service_stand_position(ServiceStage.CLEAN_TABLE)}
	if carried_trash_count > 0:
		return {"visible": true, "position": trash_disposal_position}
	if customer_flow in [CustomerFlow.ARRIVING, CustomerFlow.RECEIVING, CustomerFlow.WALKING_TO_TABLE, CustomerFlow.EATING, CustomerFlow.LEAVING]:
		return {"visible": false, "position": Vector3.ZERO}
	if not _service_is_ready():
		return {"visible": false, "position": Vector3.ZERO}
	match service_stage:
		ServiceStage.COLLECT_RAW, ServiceStage.LOAD_FRYER, ServiceStage.COLLECT_COOKED, ServiceStage.STAGE_ORDER, ServiceStage.BILL_CUSTOMER:
			return {"visible": true, "position": _service_stand_position(service_stage)}
		ServiceStage.WAIT_CUSTOMER:
			return {"visible": customer_flow == CustomerFlow.WAITING, "position": _service_stand_position(ServiceStage.BILL_CUSTOMER)}
		ServiceStage.FRYING:
			var output_table := fryer_station.get_output_table() if fryer_station else null
			return {"visible": output_table != null, "position": output_table.global_position if output_table else Vector3.ZERO}
		_:
			return {"visible": false, "position": Vector3.ZERO}

func _update_guidance_arrow() -> void:
	if not world_guidance_arrow or not player_root:
		return
	var guidance := _guidance_target()
	if first_service_guidance_complete and _service_is_ready():
		guidance["visible"] = false
	world_guidance_arrow.visible = bool(guidance["visible"])
	if not world_guidance_arrow.visible:
		return
	var target_position: Vector3 = guidance["position"] as Vector3
	var direction := target_position - player_root.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, player_root.rotation.y)
	else:
		direction = direction.normalized()
	world_guidance_arrow.global_position = player_root.global_position + direction * 0.86 + Vector3(0.0, 0.24, 0.0)
	world_guidance_arrow.rotation.y = atan2(direction.x, direction.z)
	var pulse := 1.0 + 0.045 * sin(anim_time * 5.0)
	world_guidance_arrow.scale = Vector3(pulse, 1.0, pulse)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PASS lets the joystick receive every touch while empty screen touches
	# remain harmless because the camera has no touch movement.
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	var top := VBoxContainer.new()
	top.name = "TopHud"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 18
	top.offset_right = -18
	top.offset_bottom = 202
	top.add_theme_constant_override("separation", 8)
	ui.add_child(top)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	top.add_child(summary_row)
	var wallet_contents := HBoxContainer.new()
	wallet_contents.add_theme_constant_override("separation", 7)
	var wallet_icon := Control.new()
	wallet_icon.custom_minimum_size = Vector2(34, 30)
	var wallet_body := PanelContainer.new()
	wallet_body.position = Vector2(3, 5)
	wallet_body.size = Vector2(28, 21)
	var wallet_body_style := StyleBoxFlat.new()
	wallet_body_style.bg_color = Color("754b30")
	wallet_body_style.border_color = Color("39281f")
	wallet_body_style.set_border_width_all(1)
	wallet_body_style.set_corner_radius_all(5)
	wallet_body.add_theme_stylebox_override("panel", wallet_body_style)
	wallet_icon.add_child(wallet_body)
	var wallet_flap := PanelContainer.new()
	wallet_flap.position = Vector2(3, 3)
	wallet_flap.size = Vector2(21, 14)
	var wallet_flap_style := StyleBoxFlat.new()
	wallet_flap_style.bg_color = Color("a66d3e")
	wallet_flap_style.border_color = Color("573923")
	wallet_flap_style.set_border_width_all(1)
	wallet_flap_style.set_corner_radius_all(4)
	wallet_flap.add_theme_stylebox_override("panel", wallet_flap_style)
	wallet_icon.add_child(wallet_flap)
	var wallet_clasp := PanelContainer.new()
	wallet_clasp.position = Vector2(23, 10)
	wallet_clasp.size = Vector2(7, 7)
	var wallet_clasp_style := StyleBoxFlat.new()
	wallet_clasp_style.bg_color = Color("e6bd63")
	wallet_clasp_style.border_color = Color("6c4a26")
	wallet_clasp_style.set_border_width_all(1)
	wallet_clasp_style.set_corner_radius_all(3)
	wallet_clasp.add_theme_stylebox_override("panel", wallet_clasp_style)
	wallet_icon.add_child(wallet_clasp)
	wallet_contents.add_child(wallet_icon)
	money_label = _make_hud_label("0", 27)
	money_label.custom_minimum_size = Vector2(68, 0)
	wallet_contents.add_child(money_label)
	var money_panel := _hud_panel(wallet_contents)
	money_panel.custom_minimum_size = Vector2(122, 68)
	summary_row.add_child(money_panel)
	stock_label = _make_hud_label("RAW 8  •  COOKED 0  •  PACKS 0", 14)
	stock_label.custom_minimum_size = Vector2(0, 68)
	stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stock_panel := _hud_panel(stock_label)
	stock_panel.custom_minimum_size = Vector2(0, 68)
	stock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(stock_panel)
	var staff_box := VBoxContainer.new()
	staff_box.custom_minimum_size = Vector2(0, 68)
	staff_count_label = _make_hud_label("STAFF 0", 16)
	staff_count_label.name = "StaffCount"
	staff_box.add_child(staff_count_label)
	supply_button = Button.new()
	supply_button.custom_minimum_size = Vector2(0, 30)
	supply_button.add_theme_font_size_override("font_size", 11)
	supply_button.pressed.connect(_buy_chicken_crate)
	staff_box.add_child(supply_button)
	staff_button = Button.new()
	staff_button.custom_minimum_size = Vector2(0, 30)
	staff_button.add_theme_font_size_override("font_size", 12)
	staff_button.pressed.connect(_hire_next_employee)
	staff_box.add_child(staff_button)
	staff_panel = _hud_panel(staff_box)
	staff_panel.custom_minimum_size = Vector2(0, 112)
	staff_panel.visible = BUILD_INTERIOR_CONTENT
	top.add_child(staff_panel)
	var bottom := PanelContainer.new()
	bottom.name = "MissionCard"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_top = -148
	bottom.offset_right = -18
	bottom.offset_bottom = -16
	_style_panel(bottom, Color(0.11, 0.15, 0.17, 0.92))
	ui.add_child(bottom)
	tutorial_card = bottom
	tutorial_card.visible = false
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	bottom.add_child(body)
	tutorial_label = _make_hud_label("", 20)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(tutorial_label)
	status_label = _make_hud_label("", 14)
	status_label.add_theme_color_override("font_color", Color("d9d3c7"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status_label)
	var direction_footer := PanelContainer.new()
	direction_footer.name = "Red direction arrow footer"
	direction_footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	direction_footer.offset_left = -50
	direction_footer.offset_top = -112
	direction_footer.offset_right = 50
	direction_footer.offset_bottom = -12
	direction_footer.custom_minimum_size = Vector2(100, 100)
	_style_panel(direction_footer, Color(0.10, 0.12, 0.14, 0.92))
	direction_footer.visible = false
	ui.add_child(direction_footer)
	guidance_arrow = _make_hud_label("▲", 64)
	guidance_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guidance_arrow.add_theme_color_override("font_color", Color("ed2939"))
	guidance_arrow.add_theme_color_override("font_shadow_color", Color("fff4df"))
	guidance_arrow.add_theme_constant_override("shadow_offset_x", 1)
	guidance_arrow.add_theme_constant_override("shadow_offset_y", 1)
	direction_footer.add_child(guidance_arrow)
	touch_joystick = AFCVirtualJoystick.new()
	touch_joystick.name = "Touch anywhere movement joystick"
	touch_joystick.set_anchors_preset(Control.PRESET_TOP_LEFT)
	touch_joystick.size = Vector2(176, 176)
	touch_joystick.visible = false
	touch_joystick.direction_changed.connect(_on_joystick_direction_changed)
	ui.add_child(touch_joystick)
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.offset_left = -220
	toast_panel.offset_top = 120
	toast_panel.offset_right = 220
	toast_panel.offset_bottom = 170
	_style_panel(toast_panel, Color("fff4de", 0.96))
	ui.add_child(toast_panel)
	var toast_label := _make_hud_label("", 17)
	toast_label.name = "ToastText"
	toast_label.add_theme_color_override("font_color", Color("293a40"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	_build_shop_opening_overlay(ui)

func _build_shop_opening_overlay(ui: Control) -> void:
	shop_opening_overlay = Control.new()
	shop_opening_overlay.name = "Shop purchase celebration"
	shop_opening_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_opening_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shop_opening_overlay)
	var white_background := ColorRect.new()
	white_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white_background.color = Color("fffdf8")
	shop_opening_overlay.add_child(white_background)
	var celebration := VBoxContainer.new()
	celebration.set_anchors_preset(Control.PRESET_CENTER)
	celebration.offset_left = -290
	celebration.offset_top = -145
	celebration.offset_right = 290
	celebration.offset_bottom = 145
	celebration.alignment = BoxContainer.ALIGNMENT_CENTER
	celebration.add_theme_constant_override("separation", 12)
	shop_opening_overlay.add_child(celebration)
	var confetti := _make_hud_label("🎉   ✦   🎊   ✦   🎉", 42)
	confetti.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confetti.add_theme_color_override("font_color", MAT_RED)
	celebration.add_child(confetti)
	var title := _make_hud_label("CONGRATULATIONS!", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", MAT_RED_DARK)
	celebration.add_child(title)
	var message := _make_hud_label("YOU BOUGHT YOUR AFC SHOP", 21)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color("202124"))
	celebration.add_child(message)
	var subtitle := _make_hud_label("The doors are opening…", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("785c45"))
	celebration.add_child(subtitle)
	celebration.scale = Vector2(0.72, 0.72)
	var celebrate_tween := create_tween()
	celebrate_tween.set_trans(Tween.TRANS_BACK)
	celebrate_tween.set_ease(Tween.EASE_OUT)
	celebrate_tween.tween_property(celebration, "scale", Vector2.ONE, 0.42)
	celebrate_tween.parallel().tween_property(confetti, "rotation", 0.12, 0.42)
	shop_opening_overlay.visible = false


func _hud_panel(child: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 68
	_style_panel(panel, Color(0.11, 0.15, 0.17, 0.88))
	panel.add_child(child)
	return panel

func _style_panel(panel: Control, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

func _make_hud_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size + 2)
	label.add_theme_color_override("font_color", Color("fff5e5"))
	label.add_theme_color_override("font_outline_color", Color("172024"))
	label.add_theme_constant_override("outline_size", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _update_ui() -> void:
	if not money_label:
		return
	money_label.text = "%d" % wallet
	if not BUILD_INTERIOR_CONTENT:
		if _service_is_ready():
			stock_label.text = "ORDERS %d  •  RAW %d  •  FRIED %d  •  BASKET %d" % [sales_count, raw_chicken, cooked_pieces, carried_order_pieces]
		else:
			stock_label.text = "BUY AFC SHOP" if not shop_owned else "BUILD AFC SHOP"
		var at_hr_office := hr_office_root != null and player_position.distance_to(hr_office_root.global_position + Vector3(0.0, 0.0, 3.1)) <= 2.6
		if staff_panel:
			staff_panel.visible = at_hr_office
		if staff_button:
			staff_button.visible = at_hr_office
			_update_hire_button()
		if supply_button:
			supply_button.visible = false
		if staff_count_label:
			staff_count_label.visible = at_hr_office
		if tutorial_label and status_label:
			var mission := _service_mission_text() if _service_is_ready() else _starter_build_mission()
			tutorial_label.text = mission[0]
			status_label.text = mission[1] if service_action_time <= 0.0 else ("Working… %.0f%%" % ((1.0 - service_action_time / service_action_duration) * 100.0))
		return
	stock_label.text = "RAW %d  •  COOKED %d  •  AFC PACKS %d" % [raw_chicken, cooked_pieces, packed_orders]
	if staff_count_label:
		staff_count_label.text = "STAFF  %d" % employees
	if staff_button:
		_update_hire_button()
	if supply_button:
		supply_button.text = "BUY CHICKEN  $%d" % CHICKEN_CRATE_PRICE
		supply_button.visible = raw_chicken <= 0
		supply_button.disabled = wallet < CHICKEN_CRATE_PRICE
	if tutorial_label and status_label:
		var mission := _mission_text()
		tutorial_label.text = mission[0]
		status_label.text = mission[1] if action_time <= 0.0 else ("Working… %.0f%%" % ((1.0 - action_time / action_duration) * 100.0))

func _mission_text() -> Array[String]:
	if not BUILD_INTERIOR_CONTENT:
		return _service_mission_text() if _service_is_ready() else _starter_build_mission()
	match phase:
		Step.COOK:
			if raw_chicken <= 0:
				return ["RESTOCK CHICKEN FOR THE FRYER", "Buy a chicken crate to start the next batch."]
			return ["1  •  COOK A CHICKEN BATCH", "Move to the yellow fryer circle and wait."]
		Step.LOAD: return ["2  •  LOAD THE AFC PACK LINE", "Move to the steel prep table and load the cooked batch."]
		Step.BILL: return ["3  •  BILL THE WAITING CUSTOMER", "Stand inside the billing circle. The customer takes one AFC meal."]
		Step.CASH: return ["4  •  COLLECT THE SALES CASH", "Walk to the green cash stand beside the counter."]
		Step.CUSTOMER: return ["THE CUSTOMER IS TAKING THE MEAL TO A TABLE", "Their tip will appear on the dining table."]
		Step.TIP: return ["5  •  COLLECT THE TIP", "Pick up the tip the customer left on the dining table."]
	return ["AFC CHICKEN SHOP", "Move with the on-screen joystick."]

func _service_mission_text() -> Array[String]:
	match service_stage:
		ServiceStage.COLLECT_RAW:
			return ["1  •  COLLECT FRESH CHICKEN", "Step onto the gold floor tile in the hen pen."]
		ServiceStage.LOAD_FRYER:
			return ["2  •  LOAD THE ROTARY FRYER", "Carry your AFC basket to the gold fryer tile."]
		ServiceStage.FRYING:
			return ["3  •  FRYING CHICKEN", "The attached rotary mill is cooking; wait for the output tray."]
		ServiceStage.COLLECT_COOKED:
			return ["4  •  COLLECT THE FRIED CHICKEN", "Step onto the orange tray tile to fill your order basket."]
		ServiceStage.STAGE_ORDER:
			return ["PLACE THE CHICKEN ON THE TABLE", "Bring the fried chicken to the packing table before billing."]
		ServiceStage.WAIT_CUSTOMER:
			return ["ORDER READY — CUSTOMER ON THE WAY", "Wait at the marked staff spot; the meal is ready to hand over."]
		ServiceStage.BILL_CUSTOMER:
			return ["5  •  BILL THE CUSTOMER", "Stand on the blue tile behind the billing counter; billing starts automatically."]
		ServiceStage.CLEAN_TABLE:
			return ["CLEAR THE TABLE", "Touch the table to pick up rubbish; carry up to 4 pieces at a time."]
		ServiceStage.DISPOSE_TRASH:
			return ["EMPTY YOUR HANDS", "Walk to the orange bin tile. Your rubbish stays with you until dropped in the bin."]
		ServiceStage.CUSTOMER:
			return ["CUSTOMER AT THE TABLE", "They are eating; payment and a growing cash stack are on the way."]
	return ["BUILD YOUR AFC SHOP", "Finish the fryer, hen hut, and first table."]

func _starter_build_mission() -> Array[String]:
	if not shop_owned:
		return ["BUY YOUR AFC SHOP", "Stand on the white purchase pad at the locked entrance."]
	if starter_fryer_paid < 150:
		return ["BUILD THE FIRST AFC FRYER", "Stand on the green fryer loader to invest cash."]
	if starter_hut_paid < 200:
		return ["BUILD THE 200-HEN HUT", "Use the rear green loader to open the hen-hut door."]
	if starter_table_paid < 100:
		return ["BUILD THE FIRST TABLE", "Use the green table loader in the left dining area."]
	return _service_mission_text()

func _find_named(parent: Node, child_name: String) -> Node:
	if parent.name == child_name:
		return parent
	for child in parent.get_children():
		var found := _find_named(child, child_name)
		if found:
			return found
	return null

func _hire_next_employee() -> void:
	var roles := ["COUNTER CREW", "CHICKEN COOK", "SHIFT LEADER", "ASSISTANT MANAGER"]
	var prices := [32, 120, 300, 650]
	if not BUILD_INTERIOR_CONTENT and (not hr_office_root or player_position.distance_to(hr_office_root.global_position + Vector3(0.0, 0.0, 3.1)) > 2.6):
		_show_toast("Recruitment is available at the HR office")
		return
	if employees >= roles.size():
		_show_toast("AFC team is fully staffed")
		return
	var cost: int = prices[employees]
	if wallet < cost:
		_show_toast("%s costs $%d" % [roles[employees], cost])
		return
	wallet -= cost
	employees += 1
	_build_hired_staff()
	_refresh_fries_machine_slot()
	if employees == 2:
		_show_toast("Hired %s — the fries conveyor footprint is now unlocked" % roles[employees - 1])
	else:
		_show_toast("Hired %s" % roles[employees - 1])
	_save_game()
	_update_ui()

func _refresh_fries_machine_slot() -> void:
	for slot in build_slots:
		if String(slot["id"]) != "fries_machine":
			continue
		slot["unlocked"] = employees >= 2
		_update_purchase_slot_visuals(slot)
	_refresh_purchase_slot_visibility()

func _update_hire_button() -> void:
	if not staff_button:
		return
	var roles := ["COUNTER CREW", "CHICKEN COOK", "SHIFT LEADER", "ASSISTANT MANAGER"]
	var prices := [32, 120, 300, 650]
	if employees >= roles.size():
		staff_button.text = "TEAM FULL"
		staff_button.disabled = true
	else:
		staff_button.text = "HIRE %s  $%d" % [roles[employees], prices[employees]]
		staff_button.disabled = wallet < prices[employees]

func _buy_chicken_crate() -> void:
	if wallet < CHICKEN_CRATE_PRICE:
		_show_toast("A chicken crate costs $%d" % CHICKEN_CRATE_PRICE)
		return
	wallet -= CHICKEN_CRATE_PRICE
	raw_chicken += 8
	phase = Step.COOK
	_show_toast("8 fresh chickens delivered to the fryer")
	_save_game()
	_update_marker()
	_update_ui()

func _show_toast(text: String) -> void:
	toast_message = text
	toast_time = 2.2
	if not toast_panel:
		return
	var label := toast_panel.get_node_or_null("ToastText")
	if label is Label:
		label.text = text
	toast_panel.visible = true

func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "save_version", 10)
	cfg.set_value("shop", "wallet", wallet)
	cfg.set_value("shop", "shop_owned", shop_owned)
	cfg.set_value("shop", "shop_purchase_paid", shop_purchase_paid)
	cfg.set_value("shop", "raw_chicken", raw_chicken)
	cfg.set_value("shop", "cooked_pieces", cooked_pieces)
	cfg.set_value("shop", "packed_orders", packed_orders)
	cfg.set_value("shop", "sales_count", sales_count)
	cfg.set_value("shop", "employees", employees)
	cfg.set_value("shop", "cash_waiting", cash_waiting)
	cfg.set_value("shop", "tip_waiting", tip_waiting)
	cfg.set_value("shop", "starter_fryer_paid", starter_fryer_paid)
	cfg.set_value("shop", "fryer_upgrade_level", fryer_upgrade_level)
	cfg.set_value("shop", "starter_hut_paid", starter_hut_paid)
	cfg.set_value("shop", "starter_table_paid", starter_table_paid)
	cfg.set_value("shop", "starter_table_count", starter_table_count)
	cfg.set_value("shop", "hr_office_paid", hr_office_paid)
	cfg.set_value("shop", "fries_machine_paid", fries_machine_paid)
	cfg.set_value("shop", "carried_chickens", carried_chickens)
	cfg.set_value("shop", "carried_order_pieces", carried_order_pieces)
	cfg.set_value("shop", "staged_order_pieces", staged_order_pieces)
	cfg.set_value("shop", "staged_order_piece_counts", staged_order_piece_counts.duplicate())
	cfg.set_value("shop", "order_staged_for_billing", order_staged_for_billing)
	cfg.set_value("shop", "customer_order_in_progress", customer_order_in_progress)
	cfg.set_value("shop", "customer_sequence", customer_sequence)
	cfg.set_value("shop", "customer_species_index", customer_species_index)
	cfg.set_value("shop", "customer_buckets_total", customer_buckets_total)
	cfg.set_value("shop", "customer_buckets_remaining", customer_buckets_remaining)
	cfg.set_value("shop", "table_trash_count", table_trash_count)
	cfg.set_value("shop", "carried_trash_count", carried_trash_count)
	cfg.set_value("shop", "first_service_guidance_complete", first_service_guidance_complete)
	cfg.save(SAVE_PATH)

func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if int(cfg.get_value("shop", "save_version", 0)) != 10:
		wallet = 20000
		shop_owned = false
		shop_purchase_paid = 0
		raw_chicken = 0
		cooked_pieces = 0
		packed_orders = 0
		sales_count = 0
		employees = 0
		cash_waiting = 0
		tip_waiting = 0
		carried_chickens = 0
		carried_order_pieces = 0
		customer_order_in_progress = false
		table_trash_count = 0
		carried_trash_count = 0
		starter_fryer_paid = 0
		fryer_upgrade_level = 1
		starter_hut_paid = 0
		starter_table_paid = 0
		starter_table_count = 0
		hr_office_paid = 0
		fries_machine_paid = 0
		_save_game()
		return
	wallet = int(cfg.get_value("shop", "wallet", wallet))
	shop_owned = bool(cfg.get_value("shop", "shop_owned", false))
	shop_purchase_paid = int(cfg.get_value("shop", "shop_purchase_paid", 0))
	_update_shop_purchase_visuals()
	raw_chicken = int(cfg.get_value("shop", "raw_chicken", raw_chicken))
	cooked_pieces = int(cfg.get_value("shop", "cooked_pieces", cooked_pieces))
	packed_orders = int(cfg.get_value("shop", "packed_orders", packed_orders))
	sales_count = int(cfg.get_value("shop", "sales_count", sales_count))
	employees = int(cfg.get_value("shop", "employees", employees))
	cash_waiting = int(cfg.get_value("shop", "cash_waiting", cash_waiting))
	tip_waiting = int(cfg.get_value("shop", "tip_waiting", tip_waiting))
	starter_fryer_paid = int(cfg.get_value("shop", "starter_fryer_paid", 0))
	fryer_upgrade_level = clampi(int(cfg.get_value("shop", "fryer_upgrade_level", 1)), 1, RotaryFryerObject.MAX_LEVEL)
	starter_hut_paid = int(cfg.get_value("shop", "starter_hut_paid", 0))
	starter_table_paid = int(cfg.get_value("shop", "starter_table_paid", 0))
	starter_table_count = clampi(
		int(cfg.get_value("shop", "starter_table_count", 4 if starter_table_paid >= DINING_TABLE_COST else 0)),
		0,
		DINING_TABLE_COUNT
	)
	hr_office_paid = int(cfg.get_value("shop", "hr_office_paid", 0))
	fries_machine_paid = int(cfg.get_value("shop", "fries_machine_paid", 0))
	carried_chickens = int(cfg.get_value("shop", "carried_chickens", 0))
	carried_order_pieces = int(cfg.get_value("shop", "carried_order_pieces", 0))
	staged_order_pieces = int(cfg.get_value("shop", "staged_order_pieces", 0))
	order_staged_for_billing = bool(cfg.get_value("shop", "order_staged_for_billing", false))
	staged_order_piece_counts.clear()
	var saved_order_counts: Variant = cfg.get_value("shop", "staged_order_piece_counts", [])
	if saved_order_counts is Array:
		for value in saved_order_counts:
			staged_order_piece_counts.append(clampi(int(value), 1, 4))
	if staged_order_piece_counts.is_empty() and order_staged_for_billing and staged_order_pieces > 0:
		staged_order_piece_counts.append(clampi(staged_order_pieces, 1, 4))
	staged_order_pieces = 0
	for order_pieces in staged_order_piece_counts:
		staged_order_pieces += order_pieces
	order_staged_for_billing = not staged_order_piece_counts.is_empty()
	customer_order_in_progress = bool(cfg.get_value("shop", "customer_order_in_progress", false))
	customer_sequence = int(cfg.get_value("shop", "customer_sequence", customer_sequence))
	customer_species_index = posmod(int(cfg.get_value("shop", "customer_species_index", customer_species_index)), CUSTOMER_ANIMALS.size())
	customer_buckets_total = clampi(int(cfg.get_value("shop", "customer_buckets_total", 1)), 1, 3)
	customer_buckets_remaining = clampi(int(cfg.get_value("shop", "customer_buckets_remaining", customer_buckets_total)), 0, customer_buckets_total)
	_build_customer(customer_species_index)
	table_trash_count = int(cfg.get_value("shop", "table_trash_count", 0))
	carried_trash_count = int(cfg.get_value("shop", "carried_trash_count", 0))
	first_service_guidance_complete = bool(cfg.get_value("shop", "first_service_guidance_complete", false))
	if cash_waiting > 0:
		phase = Step.CASH
	elif tip_waiting > 0:
		phase = Step.TIP
	elif packed_orders > 0:
		phase = Step.BILL
	elif cooked_pieces > 0:
		phase = Step.LOAD
	else:
		phase = Step.COOK
	player_root.queue_free()
	_build_player()
	_update_carried_food_visuals()
	_center_camera_on_owner()
	_restore_starter_slots()
	_restore_owned_shop_visuals()
	if employees > 0:
		_build_hired_staff()
	if order_staged_for_billing:
		_create_staged_order_visual(false)
	_restore_trash_visuals()
	if not BUILD_INTERIOR_CONTENT and customer_order_in_progress and customer_root and dining_table_root:
		customer_root.visible = true
		_reserve_customer_seat()
		if dining_table_component:
			customer_root.global_position = dining_table_component.get_seated_root_position(customer_seat_index)
			customer_box.reparent(dining_table_component, true)
			customer_box.global_position = dining_table_component.get_serving_spot_position()
			customer_box.rotation = Vector3.ZERO
			customer_box.scale = Vector3.ONE * 0.72
		customer_pose_blend = 1.0
		_face_person_toward(customer_root, dining_table_root.global_position, 1.0)
		customer_at_table = true
		customer_sitting = true
		customer_flow = CustomerFlow.EATING
		_place_customer_meal_on_table()
	if BUILD_INTERIOR_CONTENT:
		_build_customer()
		if tip_waiting > 0 and customer_root:
			customer_root.visible = true
			customer_at_table = true
		elif cash_waiting > 0 and customer_root:
			customer_root.visible = true
			customer_walking_to_table = true
func _build_afc_box(parent: Node3D, pos: Vector3, scale_value: float) -> Node3D:
	var box := Node3D.new()
	box.position = pos
	box.scale = Vector3.ONE * scale_value
	parent.add_child(box)
	_add_box(box, "AFC cream chicken carton", Vector3.ZERO, Vector3(0.50, 0.48, 0.42), MAT_CREAM, 0.045, 0.55)
	_add_box(box, "AFC red carton lid", Vector3(0, 0.245, 0), Vector3(0.54, 0.045, 0.46), MAT_RED_DARK, 0.025, 0.48)
	_add_box(box, "AFC carton front red label panel", Vector3(0, -0.005, 0.216), Vector3(0.43, 0.31, 0.018), MAT_RED_DARK, 0.025, 0.42)
	_add_box(box, "AFC carton front cream badge", Vector3(0, -0.005, 0.228), Vector3(0.34, 0.24, 0.012), Color("fff2d9"), 0.018, 0.46)
	_add_box(box, "AFC carton gold badge accent", Vector3(0, -0.005, 0.237), Vector3(0.29, 0.19, 0.008), Color("c29a58"), 0.012, 0.38)
	_add_box(box, "AFC carton cream badge center", Vector3(0, -0.005, 0.243), Vector3(0.27, 0.17, 0.008), Color("fff2d9"), 0.01, 0.46)
	_add_label(box, "AFC", Vector3(0, 0.035, 0.253), 0.12, MAT_RED_DARK)
	var chicken_label := _add_label(box, "CRISPY CHICKEN", Vector3(0, -0.065, 0.253), 0.043, MAT_RED_DARK)
	chicken_label.outline_size = 3
	chicken_label.outline_modulate = Color("fff2d9")
	for side in [-1.0, 1.0]:
		_add_box(box, "AFC carton side red panel", Vector3(side * 0.254, -0.005, 0), Vector3(0.012, 0.29, 0.31), MAT_RED, 0.01, 0.48)
		_add_box(box, "AFC carton side cream stripe", Vector3(side * 0.262, -0.005, 0), Vector3(0.008, 0.21, 0.045), Color("fff2d9"), 0.005, 0.46)
	_add_drumstick(box, Vector3(-0.09, 0.30, 0.0), 0.72)
	_add_drumstick(box, Vector3(0.12, 0.29, 0.025), 0.55)
	return box

func _add_afc_carton(parent: Node3D, pos: Vector3, dimensions: Vector3) -> void:
	_add_box(parent, "AFC chicken meal carton", pos, dimensions, MAT_CREAM, 0.045, 0.6)
	_add_box(parent, "Carton red front stripe", pos + Vector3(0, 0, dimensions.z * 0.51), Vector3(dimensions.x * 0.96, dimensions.y * 0.28, 0.018), MAT_RED, 0.012)
	_add_label(parent, "AFC", pos + Vector3(0, 0.005, dimensions.z * 0.53 + 0.012), 0.075, Color.WHITE)
	_add_drumstick(parent, pos + Vector3(0, dimensions.y * 0.56, 0), 0.32)

func _add_drumstick(parent: Node3D, pos: Vector3, scale_value: float) -> void:
	var meat := _add_sphere(parent, "Crispy chicken thigh", pos, Vector3(0.23, 0.15, 0.17) * scale_value, MAT_CHICKEN, 12, 8)
	meat.rotation.z = -0.25
	_add_sphere(parent, "Golden crispy edge", pos + Vector3(0.035, 0.025, 0), Vector3(0.17, 0.12, 0.145) * scale_value, Color("ed9a37"), 10, 7)
	_add_cylinder(parent, "Drumstick bone", pos + Vector3(-0.2, 0.01, 0), 0.035 * scale_value, 0.035 * scale_value, 0.25 * scale_value, Color("f3e2c2"), 8, Vector3(0, 0, PI / 2.0))
	_add_sphere(parent, "Bone knob", pos + Vector3(-0.32, 0.01, 0), Vector3(0.055, 0.05, 0.05) * scale_value, Color("fff0d7"), 8, 5)

func _add_fried_chicken_piece(parent: Node3D, pos: Vector3, scale_value: float) -> void:
	# A readable fried-chicken serving: large crispy thigh, small wing, visible
	# drumstick bone, and textured crust. It stays oversized enough for the
	# orthographic mobile camera rather than reading as an orange sphere.
	var food := Node3D.new()
	food.name = "Detailed fried chicken serving"
	food.position = pos
	parent.add_child(food)
	_add_sphere(food, "Fried chicken thigh", Vector3(0.05, 0.02, 0), Vector3(0.28, 0.19, 0.22) * scale_value, Color("cf6d20"), 12, 8)
	_add_sphere(food, "Fried chicken crunchy crust", Vector3(0.11, 0.08, -0.04), Vector3(0.21, 0.13, 0.17) * scale_value, Color("f29a2d"), 10, 7)
	_add_sphere(food, "Fried chicken wing", Vector3(-0.19, 0.02, 0.11), Vector3(0.20, 0.11, 0.13) * scale_value, Color("d97a22"), 10, 6)
	_add_sphere(food, "Fried chicken wing tip", Vector3(-0.33, 0.015, 0.16), Vector3(0.10, 0.07, 0.08) * scale_value, Color("ed922d"), 9, 6)
	_add_cylinder(food, "Fried chicken leg bone", Vector3(0.30, -0.01, 0), 0.040 * scale_value, 0.040 * scale_value, 0.28 * scale_value, Color("fff0d4"), 8, Vector3(0, 0, PI * 0.5))
	_add_sphere(food, "Fried chicken bone end", Vector3(0.44, -0.01, 0), Vector3(0.070, 0.060, 0.060) * scale_value, Color("fff5df"), 8, 5)
	for crumb in [Vector3(0.05, 0.19, -0.10), Vector3(0.20, 0.14, 0.09), Vector3(-0.10, 0.15, 0.12)]:
		_add_sphere(food, "Crispy chicken crumb", crumb * scale_value, Vector3(0.035, 0.025, 0.035) * scale_value, Color("ffbd48"), 7, 4)

func _add_fried_whole_chicken(parent: Node3D, pos: Vector3, scale_value: float) -> void:
	# Full serving silhouette: a muscular central breast with two legs, two wings,
	# and a small neck. This creates an unmistakable whole-chicken shape at LV.1.
	var chicken := Node3D.new()
	chicken.name = "Whole fried chicken 1 kilogram"
	chicken.position = pos
	parent.add_child(chicken)
	_add_sphere(chicken, "Whole chicken muscular breast", Vector3(0, 0.14, 0), Vector3(0.38, 0.24, 0.30) * scale_value, Color("d57220"), 14, 9)
	_add_sphere(chicken, "Whole chicken crisp breast", Vector3(0.08, 0.22, -0.04), Vector3(0.29, 0.16, 0.23) * scale_value, Color("ef942b"), 12, 8)
	for side in [-1.0, 1.0]:
		_add_fried_chicken_piece(chicken, Vector3(0.27 * side, 0.08, 0.08), 0.50 * scale_value)
		_add_sphere(chicken, "Whole chicken wing", Vector3(0.41 * side, 0.16, -0.08), Vector3(0.17, 0.10, 0.18) * scale_value, Color("dc7a22"), 10, 6)
	_add_capsule(chicken, "Whole chicken neck", Vector3(0, 0.30, 0.22), 0.075 * scale_value, 0.27 * scale_value, Color("df8427"), 10, 6)
	_add_sphere(chicken, "Whole chicken neck crisp", Vector3(0, 0.43, 0.25), Vector3(0.11, 0.09, 0.10) * scale_value, Color("f0a139"), 9, 6)

func _add_machine_status_light(parent: Node3D, pos: Vector3) -> void:
	_add_sphere(parent, "Machine green status LED", pos, Vector3(0.065, 0.065, 0.035), Color("82db7b"), 10, 6)

func _add_box(parent: Node, object_name: String, pos: Vector3, dimensions: Vector3, color: Color, bevel := 0.0, roughness := 0.72) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var item := MeshInstance3D.new()
	item.name = object_name
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color, 0.0, roughness)
	if color.a < 1.0:
		item.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if color == MAT_STEEL or color == MAT_STEEL_DARK or color == Color("d9e0df") or color == Color("d8dfe1"):
		item.material_override.metallic = 0.48
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(item)
	return item

func _add_cylinder(parent: Node, object_name: String, pos: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color, radial_segments := 16, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var item := MeshInstance3D.new()
	item.name = object_name
	item.mesh = mesh
	item.position = pos
	item.rotation = rotation
	item.material_override = _material(color, 0.18 if color == MAT_STEEL else 0.0, 0.38 if color == MAT_STEEL else 0.68)
	parent.add_child(item)
	return item

func _add_sphere(parent: Node, object_name: String, pos: Vector3, dimensions: Vector3, color: Color, radial_segments := 12, rings := 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	var item := MeshInstance3D.new()
	item.name = object_name
	item.mesh = mesh
	item.position = pos
	item.scale = dimensions
	item.material_override = _material(color, 0.0, 0.74)
	parent.add_child(item)
	return item

func _add_capsule(parent: Node, object_name: String, pos: Vector3, radius: float, height: float, color: Color, radial_segments := 10, rings := 6) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	var item := MeshInstance3D.new()
	item.name = object_name
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color, 0.0, 0.74)
	parent.add_child(item)
	return item

func _add_label(parent: Node3D, text: String, pos: Vector3, size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 48
	label.pixel_size = size / 36.0
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color("3b3330")
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _material(color: Color, metallic := 0.0, roughness := 0.72, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material
