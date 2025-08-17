# PlayerController.gd
# This script handles both local and remote player movement, including physics, camera, and networking

extends CharacterBody3D

# ===== EXPORTED SETTINGS =====
@export_category("Movement Settings")
@export var walk_speed := 5.0          # Normal movement speed
@export var sprint_speed := 8.0        # Sprinting speed
@export var jump_velocity := 12.0      # Jump force
@export var ground_acceleration := 15.0 # Acceleration on ground
@export var ground_deceleration := 20.0 # Deceleration on ground
@export var air_control := 0.3         # Air movement control factor

@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002 # Mouse sensitivity
@export var camera_tilt_amount := 8.0  # Amount of camera tilt when strafing
@export var fov_normal := 80.0         # Normal field of view
@export var fov_sprint := 120.0        # Sprinting field of view
@export var sway_smoothness := 10.0    # Camera sway smoothing

@export_category("Network Settings")
@export var network_update_rate := 20.0 # Network updates per second
@export var interpolation_time := 0.15  # Network interpolation smoothing time

# ===== CONSTANTS =====
const GRAVITY_FORCE = 35.0            # Gravity strength
const POSITION_LERP_FACTOR = 0.3      # Position interpolation factor
const ROTATION_LERP_FACTOR = 0.5      # Rotation interpolation factor

# ===== NODE REFERENCES =====
@onready var camera := $Camera3D       # Player camera
@onready var sync := $MultiplayerSynchronizer # Network sync component

# ===== MOVEMENT STATE =====
enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false                # Whether player is moving
var wish_dir := Vector3.ZERO          # Desired movement direction
var current_speed := 0.0              # Current movement speed
var was_on_floor := true              # Previous frame ground state

# ===== JUMP VARIABLES =====
var jump_buffer_timer := 0.0          # Jump input buffer timer
var coyote_timer := 0.0               # Coyote time timer
var can_jump := true                  # Can player jump
var jump_count := 0                   # Current jump count

# ===== CAMERA EFFECTS =====
var camera_tilt := 0.0                # Current camera tilt amount
var raw_input_dir := Vector2.ZERO     # Raw input direction

# ===== NETWORK INTERPOLATION =====
var network_position_buffer = []      # Buffer for network positions
var network_rotation_buffer = []      # Buffer for network rotations
var network_timestamp_buffer = []     # Buffer for network timestamps
var last_network_update_time := 0.0   # Last network update time
var input_enabled: bool = true        # Whether input is enabled

# ===== NETWORK SETUP =====
func _enter_tree():
	# Set multiplayer authority based on name
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
	# Setup for local player
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera: 
			camera.current = true
	current_speed = walk_speed

# ===== INPUT HANDLING =====
func _input(event):
	if not input_enabled or not is_multiplayer_authority():
		return
	
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	# Jump input buffering
	if event.is_action_pressed("jump"):
		jump_buffer_timer = 0.15

# ===== PHYSICS PROCESS =====
func _physics_process(delta):
	if not input_enabled:
		velocity = Vector3.ZERO
		return
		
	if is_multiplayer_authority():
		# Local player movement
		process_local_movement(delta)
		move_and_slide()
		send_network_update()
		update_camera_effects(delta)
	else:
		# Remote player movement interpolation
		process_remote_movement(delta)

# ===== LOCAL MOVEMENT =====
func process_local_movement(delta):
	# Get input direction
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0.1
	wish_dir = (transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()
	
	# Handle jumping
	handle_jump_mechanics(delta)
	
	# Update movement state
	update_movement_state()
	
	# Calculate movement
	handle_movement(delta)
	
	# Apply gravity
	apply_gravity(delta)

# ===== JUMP MECHANICS =====
func handle_jump_mechanics(delta):
	# Update timers
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	
	# Coyote time - allows jumping shortly after leaving ground
	if is_on_floor():
		coyote_timer = 0.1
		if not was_on_floor:
			can_jump = true
			jump_count = 0
	else:
		coyote_timer = max(coyote_timer - delta, 0)
	
	was_on_floor = is_on_floor()
	
	# Perform jump if conditions met
	if jump_buffer_timer > 0 and can_jump and (is_on_floor() or coyote_timer > 0):
		perform_jump()

func perform_jump():
	velocity.y = jump_velocity
	jump_buffer_timer = 0
	can_jump = false
	coyote_timer = 0
	jump_count += 1

# ===== MOVEMENT STATES =====
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

# ===== MOVEMENT CALCULATION =====
func handle_movement(delta):
	if is_on_floor():
		# Ground movement
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, ground_deceleration * delta)
		
		velocity.x = current_vel.x
		velocity.z = current_vel.y
	else:
		# Air movement
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * air_control * delta)
			velocity.x = current_vel.x
			velocity.z = current_vel.y

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY_FORCE * delta

# ===== CAMERA EFFECTS =====
func update_camera_effects(delta):
	if not camera: return
	
	# Camera tilt when strafing
	var target_tilt = 0.0
	if is_moving and is_on_floor():
		target_tilt = -raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	# FOV changes when sprinting
	if current_state == MovementState.SPRINTING and raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)

# ===== NETWORK UPDATES =====
func send_network_update():
	# Send position/rotation update to other players
	rpc("_receive_network_update", 
		global_position,
		velocity,
		rotation,
		Time.get_ticks_msec() / 1000.0)

@rpc("unreliable_ordered", "any_peer")
func _receive_network_update(pos: Vector3, vel: Vector3, rot: Vector3, timestamp: float):
	if is_multiplayer_authority(): return
	
	# Store update for interpolation
	network_position_buffer.append(pos)
	network_rotation_buffer.append(rot)
	network_timestamp_buffer.append(timestamp)
	
	# Maintain buffer size
	if network_position_buffer.size() > 5:
		network_position_buffer.pop_front()
		network_rotation_buffer.pop_front()
		network_timestamp_buffer.pop_front()
	
	last_network_update_time = Time.get_ticks_msec() / 1000.0

# ===== REMOTE PLAYER INTERPOLATION =====
func process_remote_movement(delta):
	if network_position_buffer.size() < 2: 
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var render_time = current_time - interpolation_time
	
	# Find closest states for interpolation
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
	
	# Calculate interpolation factor
	var prev_time = network_timestamp_buffer[prev_index]
	var next_time = network_timestamp_buffer[next_index]
	var t = clamp((render_time - prev_time) / (next_time - prev_time), 0.0, 1.0)
	
	# Interpolate position and rotation
	var target_pos = network_position_buffer[prev_index].lerp(
		network_position_buffer[next_index], t)
	var target_rot = network_rotation_buffer[prev_index].lerp(
		network_rotation_buffer[next_index], t)
	
	# Apply with smoothing
	global_position = global_position.lerp(target_pos, POSITION_LERP_FACTOR)
	rotation = rotation.lerp(target_rot, ROTATION_LERP_FACTOR)

# ===== INPUT CONTROL =====
func set_input_enabled(enabled: bool):
	input_enabled = enabled
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)
