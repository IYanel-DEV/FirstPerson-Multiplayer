extends CharacterBody3D

@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 12.0
@export var ground_acceleration := 15.0
@export var ground_deceleration := 20.0
@export var air_control := 0.3

@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002
@export var camera_tilt_amount := 8.0
@export var fov_normal := 80.0
@export var fov_sprint := 120.0
@export var sway_smoothness := 10.0

@export_category("Network Settings")
@export var network_update_rate := 20.0  # 20 updates per second
@export var interpolation_time := 0.15  # 150ms smoothing

const GRAVITY_FORCE = 35.0
const POSITION_LERP_FACTOR = 0.3
const ROTATION_LERP_FACTOR = 0.5

@onready var camera := $Camera3D
@onready var sync := $MultiplayerSynchronizer

enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var wish_dir := Vector3.ZERO
var current_speed := 0.0
var was_on_floor := true

# Jump variables
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var can_jump := true
var jump_count := 0

# Camera effects
var camera_tilt := 0.0
var raw_input_dir := Vector2.ZERO

# Network interpolation
var network_position_buffer = []
var network_rotation_buffer = []
var network_timestamp_buffer = []
var last_network_update_time := 0.0
var input_enabled: bool = true

func _enter_tree():
	if name.contains("_"):
		var peer_id = name.get_slice("_", 1).to_int()
		set_multiplayer_authority(peer_id)
		if sync:
			sync.set_multiplayer_authority(peer_id)
			sync.replication_interval = 1.0 / network_update_rate
			sync.replication_config.add_property("global_position")
			sync.replication_config.add_property("rotation")
			sync.replication_config.add_property("velocity")

func _ready():
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera: 
			camera.current = true
	current_speed = walk_speed

func _input(event):
	if not input_enabled or not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event.is_action_pressed("jump"):
		jump_buffer_timer = 0.15

func _physics_process(delta):
	if not input_enabled:
		velocity = Vector3.ZERO
		return
		
	if is_multiplayer_authority():
		process_local_movement(delta)
		move_and_slide()
		send_network_update()
		update_camera_effects(delta)
	else:
		process_remote_movement(delta)

func process_local_movement(delta):
	# Input handling
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0.1
	wish_dir = (transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()
	
	# Handle jumping
	handle_jump_mechanics(delta)
	
	# Movement states
	update_movement_state()
	
	# Movement calculation
	handle_movement(delta)
	
	# Gravity
	apply_gravity(delta)

func handle_jump_mechanics(delta):
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	
	if is_on_floor():
		coyote_timer = 0.1
		if not was_on_floor:
			can_jump = true
			jump_count = 0
	else:
		coyote_timer = max(coyote_timer - delta, 0)
	
	was_on_floor = is_on_floor()
	
	if jump_buffer_timer > 0 and can_jump and (is_on_floor() or coyote_timer > 0):
		perform_jump()

func perform_jump():
	velocity.y = jump_velocity
	jump_buffer_timer = 0
	can_jump = false
	coyote_timer = 0
	jump_count += 1

func update_movement_state():
	if is_on_floor():
		if Input.is_action_pressed("sprint") and is_moving and raw_input_dir.y < 0:
			current_state = MovementState.SPRINTING
			current_speed = sprint_speed
		else:
			current_state = MovementState.WALKING
			current_speed = walk_speed
	else:
		current_state = MovementState.AIRBORNE

func handle_movement(delta):
	if is_on_floor():
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, ground_deceleration * delta)
		
		velocity.x = current_vel.x
		velocity.z = current_vel.y
	else:
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * air_control * delta)
			velocity.x = current_vel.x
			velocity.z = current_vel.y

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY_FORCE * delta

func update_camera_effects(delta):
	if not camera: return
	
	# Camera tilt (sway)
	var target_tilt = 0.0
	if is_moving and is_on_floor():
		target_tilt = -raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	# FOV changes
	if current_state == MovementState.SPRINTING and raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)

func send_network_update():
	rpc("_receive_network_update", 
		global_position,
		velocity,
		rotation,
		Time.get_ticks_msec() / 1000.0)

@rpc("unreliable_ordered", "any_peer")
func _receive_network_update(pos: Vector3, vel: Vector3, rot: Vector3, timestamp: float):
	if is_multiplayer_authority(): return
	
	network_position_buffer.append(pos)
	network_rotation_buffer.append(rot)
	network_timestamp_buffer.append(timestamp)
	
	# Keep buffer size reasonable
	if network_position_buffer.size() > 5:
		network_position_buffer.pop_front()
		network_rotation_buffer.pop_front()
		network_timestamp_buffer.pop_front()
	
	last_network_update_time = Time.get_ticks_msec() / 1000.0

func process_remote_movement(delta):
	if network_position_buffer.size() < 2: 
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var render_time = current_time - interpolation_time
	
	# Find the two most relevant states
	var prev_index = -1
	var next_index = -1
	
	for i in range(network_timestamp_buffer.size()):
		if network_timestamp_buffer[i] <= render_time:
			prev_index = i
		else:
			next_index = i
			break
	
	if next_index == -1:
		if network_timestamp_buffer.size() < 2: return
		prev_index = network_timestamp_buffer.size() - 2
		next_index = network_timestamp_buffer.size() - 1
	elif prev_index == -1:
		prev_index = 0
		next_index = 1
	
	# Interpolate between states
	var prev_time = network_timestamp_buffer[prev_index]
	var next_time = network_timestamp_buffer[next_index]
	var t = clamp((render_time - prev_time) / (next_time - prev_time), 0.0, 1.0)
	
	var target_pos = network_position_buffer[prev_index].lerp(
		network_position_buffer[next_index], t)
	var target_rot = network_rotation_buffer[prev_index].lerp(
		network_rotation_buffer[next_index], t)
	
	# Apply with smoothing
	global_position = global_position.lerp(target_pos, POSITION_LERP_FACTOR)
	rotation = rotation.lerp(target_rot, ROTATION_LERP_FACTOR)

func set_input_enabled(enabled: bool):
	input_enabled = enabled
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)
