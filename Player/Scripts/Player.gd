extends CharacterBody3D

## MOVEMENT PARAMETERS
@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 12.0
@export var ground_acceleration := 15.0
@export var ground_deceleration := 20.0
@export var air_control := 0.3

## CAMERA SETTINGS
@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002
@export var camera_tilt_amount := 8.0
@export var fov_normal := 75.0
@export var fov_sprint := 85.0

## HEAD BOBBING & SWAY
@export_category("Visual Effects")
@export var bob_frequency := 2.0
@export var bob_amplitude := 0.08
@export var sway_smoothness := 10.0

## NETWORK SETTINGS
@export_category("Network Settings")
@export var network_update_rate := 20 # Updates per second
@export var network_interpolation := true
@export var prediction_enabled := true
@export var max_prediction_time := 0.2 # Seconds

# Physics constants
const GRAVITY_FORCE = 35.0

# Nodes
@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D

# Movement state
enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var wish_dir := Vector3.ZERO
var current_speed := 0.0
var was_on_floor := true

# Jump system
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var can_jump := true
var last_jump_time := 0.0
var jump_count := 0

# Camera effects
var camera_tilt := 0.0
var raw_input_dir := Vector2.ZERO

# Network state
var network_clock := 0.0
var last_sync_time := 0.0
var snapshots := []
var input_queue := []
var current_input := {}
var last_processed_input := 0
var state_buffer := []
var confirmed_state := {}

# Debug state
var debug_info := {
	"position": Vector3.ZERO,
	"velocity": Vector3.ZERO,
	"is_on_floor": false,
	"jump_pressed": false,
	"jump_executed": false,
	"jump_velocity_applied": 0.0,
	"jump_count": 0,
	"can_jump": false,
	"coyote_time": 0.0,
	"jump_buffer": 0.0,
	"state": "WALKING",
	"network_id": 0,
	"is_local_player": false,
	"network_time": 0.0,
	"latency": 0.0,
	"input_queue_size": 0,
	"snapshots_size": 0
}

func _ready():
	# Set multiplayer authority based on node name (assuming name is peer ID)
	set_multiplayer_authority(str(name).to_int())
	# Add player to a group for easy access
	add_to_group("player")
	# Only capture mouse and enable camera for local player
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
		debug_info.is_local_player = true
	
	current_speed = walk_speed
	debug_info.network_id = str(name).to_int()

func _input(event):
	# Only process input for local player
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		# Handle mouse look
		rotate_y(-event.relative.x * mouse_sensitivity)
		var vertical_rotation = -event.relative.y * mouse_sensitivity
		camera.rotate_x(vertical_rotation)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
		# Sync rotation with other players
		rpc("_update_rotation", rotation, camera.rotation)
	
	if event is InputEventKey and event.keycode == KEY_SPACE:
		debug_info.jump_pressed = event.pressed
		if event.pressed:
			jump_buffer_timer = 0.15
			rpc("_set_jump_buffer", jump_buffer_timer)

func _physics_process(delta):
	network_clock += delta
	
	# Handle movement differently based on authority
	if is_multiplayer_authority():
		process_local_movement(delta)
	else:
		process_remote_movement(delta)
	
	# Apply movement
	move_and_slide()
	
	# Handle landing effects
	handle_landing()
	
	# Update visuals (bobbing, sway, etc.)
	update_visuals(delta)
	
	# Send network updates if we're the authority
	if is_multiplayer_authority() and network_clock - last_sync_time > (1.0 / network_update_rate):
		send_state_update()
		last_sync_time = network_clock
	
	# Update debug info
	update_debug_info()  # No parameter now


func process_local_movement(delta):
	# Get and process input
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	apply_gravity(delta)
	
	# Store input for reconciliation
	current_input = {
		"time": network_clock,
		"input": raw_input_dir,
		"jump": jump_buffer_timer > 0,
		"position": global_position,
		"velocity": velocity,
		"rotation": rotation,
		"camera_rotation": camera.rotation,
		"is_on_floor": is_on_floor()
	}
	input_queue.append(current_input)
	
	# Clean up old inputs
	while input_queue.size() > 0 and input_queue[0].time < network_clock - max_prediction_time:
		input_queue.pop_front()

func process_remote_movement(_delta):
	if network_interpolation and snapshots.size() > 1:
		# Calculate interpolation factor
		var snapshot_delta = snapshots[1].time - snapshots[0].time
		var interpolation_factor = (network_clock - snapshots[0].time) / snapshot_delta if snapshot_delta > 0 else 1.0
		
		# Interpolate between snapshots
		global_position = snapshots[0].position.lerp(snapshots[1].position, interpolation_factor)
		velocity = snapshots[0].velocity.lerp(snapshots[1].velocity, interpolation_factor)
		rotation = snapshots[0].rotation.lerp(snapshots[1].rotation, interpolation_factor)
		camera.rotation = snapshots[0].camera_rotation.lerp(snapshots[1].camera_rotation, interpolation_factor)
	elif snapshots.size() > 0:
		# Just snap to latest if not interpolating
		var latest = snapshots[-1]
		global_position = latest.position
		velocity = latest.velocity
		rotation = latest.rotation
		camera.rotation = latest.camera_rotation

func handle_input():
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0
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
			debug_info.state = "SPRINTING"
		else:
			current_state = MovementState.WALKING
			current_speed = walk_speed
			debug_info.state = "WALKING"
	else:
		current_state = MovementState.AIRBORNE
		coyote_timer -= delta
		debug_info.state = "AIRBORNE"

func handle_movement(delta: float):
	# Ground movement
	if is_on_floor():
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, ground_deceleration * delta)
		
		velocity.x = current_vel.x
		velocity.z = current_vel.y
	
	# Air movement
	else:
		var current_vel = Vector2(velocity.x, velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * air_control * delta)
			velocity.x = current_vel.x
			velocity.z = current_vel.y

func handle_jump(delta: float):
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	last_jump_time += delta
	debug_info.jump_executed = false
	
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
		
		debug_info.jump_executed = true
		debug_info.jump_velocity_applied = jump_velocity
		debug_info.jump_count = jump_count

func update_visuals(delta: float):
	# Camera sway
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

func send_state_update():
	var input_number = input_queue[-1].time if input_queue.size() > 0 else 0
	var state = {
		"time": network_clock,
		"position": global_position,
		"velocity": velocity,
		"rotation": rotation,
		"camera_rotation": camera.rotation,
		"state": current_state,
		"is_on_floor": is_on_floor(),
		"input_number": input_number
	}
	
	rpc("_receive_state_update", state)

@rpc("any_peer", "unreliable")
func _receive_state_update(state):
	if not is_multiplayer_authority():
		if network_interpolation:
			if snapshots.size() >= 2:
				snapshots.pop_front()
			snapshots.append(state)
		else:
			global_position = state.position
			velocity = state.velocity
			rotation = state.rotation
			camera.rotation = state.camera_rotation

@rpc("any_peer", "call_local", "reliable")
func _update_rotation(body_rot: Vector3, cam_rot: Vector3):
	rotation = body_rot
	camera.rotation = cam_rot

@rpc("any_peer", "call_local", "reliable")
func _set_jump_buffer(value: float):
	jump_buffer_timer = value

# Remove the parameter from this function
func update_debug_info():  # Removed _delta parameter
	debug_info.position = global_position
	debug_info.velocity = velocity
	debug_info.is_on_floor = is_on_floor()
	debug_info.can_jump = can_jump
	debug_info.coyote_time = coyote_timer
	debug_info.jump_buffer = jump_buffer_timer
	debug_info.network_time = network_clock
	debug_info.input_queue_size = input_queue.size()
	debug_info.snapshots_size = snapshots.size()
