# _Player.gd
extends CharacterBody3D

@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 12.0
@export var ground_acceleration := 15.0
@export var ground_deceleration := 20.0
@export var air_control := 0.3

@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002:
	set(value):
		mouse_sensitivity = value
		# Propagate to controllers
		if has_node("LocalPlayerController"):
			$LocalPlayerController.mouse_sensitivity = value
@export var camera_tilt_amount := 8.0
@export var fov_normal := 75.0
@export var fov_sprint := 85.0

@export_category("Visual Effects")
@export var sway_smoothness := 10.0

const GRAVITY_FORCE = 35.0
const NETWORK_UPDATE_INTERVAL = 0.05  # 20 updates per second
const NETWORK_SMOOTHING_TIME = 0.1  # 100ms smoothing

@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D

enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var wish_dir := Vector3.ZERO
var current_speed := 0.0
var was_on_floor := true

var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var can_jump := true
var jump_count := 0

var camera_tilt := 0.0
var raw_input_dir := Vector2.ZERO

# Network variables
var network_update_timer := 0.0
var last_network_update_time := 0.0
var network_position_buffer = []
var network_rotation_buffer = []
var network_camera_rotation_buffer = []
var network_velocity_buffer = []
var network_timestamp_buffer = []
var interpolation_start_time := 0.0
var interpolation_start_position := Vector3.ZERO
var interpolation_start_rotation := Vector3.ZERO
var interpolation_start_camera_rotation := Vector3.ZERO
var interpolation_target_position := Vector3.ZERO
var interpolation_target_rotation := Vector3.ZERO
var interpolation_target_camera_rotation := Vector3.ZERO
var is_interpolating := false

func _enter_tree():
	if name.contains("_"):
		var peer_id = name.get_slice("_", 1).to_int()
		set_multiplayer_authority(peer_id)

func _ready():
	if multiplayer == null:
		return
	add_to_group("player")
	# Apply settings sensitivity
	if Settings:
		mouse_sensitivity = Settings.settings.get("mouse_sensitivity", 0.002)
	if is_multiplayer_authority():
		setup_local_player()
	else:
		setup_remote_player()
	
	print("Player ready: ", name, " | Authority: ", get_multiplayer_authority(), " | Is local: ", is_multiplayer_authority())
	
	# Initialize network targets
	interpolation_target_position = global_position
	interpolation_target_rotation = rotation
	interpolation_target_camera_rotation = camera.rotation if camera else Vector3.ZERO
	last_network_update_time = Time.get_ticks_msec() / 1000.0

func setup_local_player():
	print("Setting up local player controls")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		camera.current = true
	current_speed = walk_speed

func setup_remote_player():
	print("Setting up remote player")
	if camera:
		camera.current = false
	current_speed = walk_speed

func _input(event):
	if not is_multiplayer_authority():
		return
	
	# Handle pause input
	if event.is_action_pressed("pause"):
		# Find pause menu in the scene
		var pause_menu = get_node_or_null("/root/GameMode/PauseMenu")
		if pause_menu:
			pause_menu.toggle_pause_menu()
		
		# Consume the event so it doesn't propagate
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var vertical_rotation = -event.relative.y * mouse_sensitivity
		if camera:
			camera.rotate_x(vertical_rotation)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		jump_buffer_timer = 0.15

func _physics_process(delta):
	if is_multiplayer_authority():
		process_local_movement(delta)
		handle_network_updates(delta)
		move_and_slide()
		handle_landing()
	else:
		process_remote_movement(delta)
	
	update_visuals(delta)

func handle_network_updates(delta):
	network_update_timer += delta
	if network_update_timer >= NETWORK_UPDATE_INTERVAL:
		network_update_timer = 0.0
		send_network_update()

func send_network_update():
	rpc("receive_network_update", 
		global_position, 
		velocity, 
		rotation, 
		camera.rotation if camera else Vector3.ZERO,
		Time.get_ticks_msec() / 1000.0)

@rpc("unreliable", "any_peer")
func receive_network_update(pos: Vector3, vel: Vector3, rot: Vector3, cam_rot: Vector3, timestamp: float):
	if is_multiplayer_authority():
		return
	
	# Store update in buffer
	network_position_buffer.append(pos)
	network_rotation_buffer.append(rot)
	network_camera_rotation_buffer.append(cam_rot)
	network_velocity_buffer.append(vel)
	network_timestamp_buffer.append(timestamp)
	
	# Keep buffer size manageable
	if network_position_buffer.size() > 5:
		network_position_buffer.pop_front()
		network_rotation_buffer.pop_front()
		network_camera_rotation_buffer.pop_front()
		network_velocity_buffer.pop_front()
		network_timestamp_buffer.pop_front()
	
	# Update last network time
	last_network_update_time = Time.get_ticks_msec() / 1000.0

func process_remote_movement(delta):
	# Don't interpolate if we don't have enough data
	if network_position_buffer.size() < 2:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var render_time = current_time - NETWORK_SMOOTHING_TIME
	
	# Find the two states to interpolate between
	var prev_index = -1
	var next_index = -1
	
	for i in range(network_timestamp_buffer.size()):
		if network_timestamp_buffer[i] <= render_time:
			prev_index = i
		else:
			next_index = i
			break
	
	# If we don't have a next state, use the last two states
	if next_index == -1:
		if network_timestamp_buffer.size() < 2:
			return
		prev_index = network_timestamp_buffer.size() - 2
		next_index = network_timestamp_buffer.size() - 1
	elif prev_index == -1:
		prev_index = 0
		next_index = 1
	
	# Get the two states to interpolate between
	var prev_state_time = network_timestamp_buffer[prev_index]
	var next_state_time = network_timestamp_buffer[next_index]
	
	# Calculate interpolation factor
	var t = 0.0
	if next_state_time > prev_state_time:
		t = (render_time - prev_state_time) / (next_state_time - prev_state_time)
	t = clamp(t, 0.0, 1.0)
	
	# Interpolate position
	var prev_pos = network_position_buffer[prev_index]
	var next_pos = network_position_buffer[next_index]
	interpolation_target_position = prev_pos.lerp(next_pos, t)
	
	# Interpolate rotation
	var prev_rot = network_rotation_buffer[prev_index]
	var next_rot = network_rotation_buffer[next_index]
	interpolation_target_rotation = prev_rot.lerp(next_rot, t)
	
	# Interpolate camera rotation
	var prev_cam_rot = network_camera_rotation_buffer[prev_index]
	var next_cam_rot = network_camera_rotation_buffer[next_index]
	interpolation_target_camera_rotation = prev_cam_rot.lerp(next_cam_rot, t)
	
	# Set velocity
	velocity = network_velocity_buffer[prev_index].lerp(network_velocity_buffer[next_index], t)
	
	# Apply smoothing to current position
	var smoothing_factor = clamp(delta * 20.0, 0.0, 1.0)
	global_position = global_position.lerp(interpolation_target_position, smoothing_factor)
	rotation = rotation.lerp(interpolation_target_rotation, smoothing_factor)
	if camera:
		camera.rotation = camera.rotation.lerp(interpolation_target_camera_rotation, smoothing_factor)

func process_local_movement(delta):
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	apply_gravity(delta)

func handle_input():
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0.1
	wish_dir = (transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY_FORCE * delta

func handle_landing():
	if not was_on_floor and is_on_floor():
		can_jump = true
		jump_count = 0
	was_on_floor = is_on_floor()

func handle_states(delta: float):
	if is_on_floor():
		if Input.is_action_pressed("sprint") and is_moving and raw_input_dir.y < 0:
			current_state = MovementState.SPRINTING
			current_speed = sprint_speed
		else:
			current_state = MovementState.WALKING
			current_speed = walk_speed
	else:
		current_state = MovementState.AIRBORNE
		coyote_timer -= delta

func handle_movement(delta: float):
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

func handle_jump(delta: float):
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	
	if is_on_floor():
		coyote_timer = 0.1
	else:
		coyote_timer = max(coyote_timer - delta, 0)
	
	if jump_buffer_timer > 0 and can_jump and (is_on_floor() or coyote_timer > 0):
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		can_jump = false
		coyote_timer = 0
		jump_count += 1

func update_visuals(delta: float):
	if not camera or not is_multiplayer_authority():
		return
		
	var target_tilt = 0.0
	if is_moving and is_on_floor():
		target_tilt = -raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	if current_state == MovementState.SPRINTING and raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)
