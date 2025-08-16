extends CharacterBody3D

## MOVEMENT PARAMETERS
@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var crouch_speed := 3.0
@export var jump_velocity := 10.0  # Increased jump velocity
@export var air_control := 0.8
@export var ground_acceleration := 25.0
@export var ground_deceleration := 20.0
@export var air_deceleration := 5.0

## JUMP & BUNNYHOP SETTINGS
@export_category("Jump Settings")
@export var max_bunnyhop_speed := 25.0
@export var bunnyhop_acceleration := 1.2
@export var max_jumps := 2
@export var jump_cooldown := 0.1
@export var jump_buffer_time := 0.1
@export var coyote_time := 0.1

## CROUCH SETTINGS
@export_category("Crouch Settings")
@export var crouch_height := 1.0
@export var stand_height := 1.8
@export var crouch_transition_speed := 8.0
@export var stand_check_height_offset := 0.2

## CAMERA SETTINGS
@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002
@export var camera_tilt_amount := 8.0
@export var fov_normal := 75.0
@export var fov_sprint := 85.0
@export var vertical_angle_offset := 0.0

## HEAD BOBBING & SWAY
@export_category("Visual Effects")
@export var bob_frequency := 2.0
@export var bob_amplitude := 0.08
@export var sway_smoothness := 10.0
@export var landing_impact := 0.2
@export var breathing_frequency := 0.5
@export var breathing_amplitude := 0.02

# Physics constants
const GRAVITY_FORCE = 30.0  # Explicit gravity constant

# Nodes
@onready var camera := $Camera3D
@onready var head := $Camera3D/HeadPosition
@onready var collision_shape := $CollisionShape3D
@onready var stand_check := $Checkers/StandCheck
@onready var floor_ray := $Checkers/FloorRay  # New raycast for ground detection

# Movement state
enum MovementState { WALKING, SPRINTING, CROUCHING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var wish_dir := Vector3.ZERO
var current_speed := 0.0
var was_on_floor := true
var target_camera_height := 0.0

# Jump & bunnyhop
var jump_count := 0
var last_jump_time := 0.0
var stored_velocity := Vector3.ZERO
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var last_ground_velocity := Vector3.ZERO

# Camera effects
var default_head_position: Vector3
var head_bob_time := 0.0
var camera_tilt := 0.0
var landing_impact_offset := 0.0
var idle_time := 0.0
var raw_input_dir := Vector2.ZERO

func _ready():
	default_head_position = head.position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Configure stand check raycast
	stand_check.target_position = Vector3(0, stand_height - crouch_height + stand_check_height_offset, 0)
	stand_check.enabled = true
	current_speed = walk_speed
	target_camera_height = stand_height
	collision_shape.shape.height = stand_height
	
	# Configure floor detection ray
	floor_ray.target_position = Vector3(0, -0.2, 0)
	floor_ray.enabled = true

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var vertical_rotation = -event.relative.y * mouse_sensitivity
		camera.rotate_x(vertical_rotation)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		idle_time = 0.0

func _physics_process(delta):
	# Update ground detection
	update_ground_detection()
	
	# Process player mechanics
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	update_visuals(delta)
	
	# Store previous frame's ground state
	was_on_floor = is_on_floor()

# Improved ground detection system
func update_ground_detection():
	# Use raycast for more reliable ground detection
	floor_ray.force_raycast_update()
	
	# Update velocity based on ground state
	if is_on_floor():
		velocity.y = 0
	elif not floor_ray.is_colliding():
		velocity.y -= GRAVITY_FORCE * get_physics_process_delta_time()

func handle_states(delta: float):
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0
	wish_dir = (transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()
	
	if is_on_floor():
		coyote_timer = coyote_time
		
		if Input.is_action_pressed("crouch"):
			current_state = MovementState.CROUCHING
			target_camera_height = crouch_height
			current_speed = crouch_speed
		elif Input.is_action_pressed("sprint") and is_moving and raw_input_dir.y < 0:
			current_state = MovementState.SPRINTING
			current_speed = sprint_speed
		else:
			current_state = MovementState.WALKING
			current_speed = walk_speed
		
		if not Input.is_action_pressed("crouch") and current_state == MovementState.CROUCHING:
			if can_stand_up():
				current_state = MovementState.WALKING
				target_camera_height = stand_height
	else:
		current_state = MovementState.AIRBORNE
		coyote_timer -= delta
		
		if current_state == MovementState.SPRINTING:
			current_speed = sprint_speed
		elif current_state == MovementState.CROUCHING:
			current_speed = crouch_speed
		else:
			current_speed = walk_speed

func handle_movement(delta: float):
	# Store ground velocity for bunny hopping
	if is_on_floor():
		last_ground_velocity = Vector3(velocity.x, 0, velocity.z)
	
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
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, air_deceleration * delta)
		
		velocity.x = current_vel.x
		velocity.z = current_vel.y
	
	# Move the character
	var motion = velocity * delta
	var collision = move_and_collide(motion)
	
	# Handle collisions
	if collision:
		velocity = velocity.slide(collision.get_normal())
	
	# Update collision shape height
	collision_shape.shape.height = lerp(
		collision_shape.shape.height, 
		target_camera_height, 
		delta * crouch_transition_speed
	)
	
	# Update stand check position
	stand_check.global_position = global_position + Vector3(0, collision_shape.shape.height, 0)

func handle_jump(delta: float):
	jump_buffer_timer -= delta
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if is_on_floor() and not was_on_floor:
		jump_count = 0
		landing_impact_offset = -landing_impact
	
	last_jump_time += delta
	
	# Jump conditions
	var can_jump = false
	if jump_buffer_timer > 0 and last_jump_time > jump_cooldown:
		if (is_on_floor() or coyote_timer > 0) and current_state != MovementState.CROUCHING:
			can_jump = true
		elif jump_count < max_jumps:
			can_jump = true
	
	# Execute jump
	if can_jump:
		jump_buffer_timer = 0
		velocity.y = jump_velocity
		
		# Apply movement direction
		if is_moving:
			velocity.x = wish_dir.x * current_speed
			velocity.z = wish_dir.z * current_speed
		
		# Bunny hop acceleration
		if jump_count > 0 and last_ground_velocity.length() < max_bunnyhop_speed:
			velocity.x = last_ground_velocity.x * bunnyhop_acceleration
			velocity.z = last_ground_velocity.z * bunnyhop_acceleration
		
		# Store velocity for bunny hopping
		stored_velocity = Vector3(velocity.x, 0, velocity.z)
		
		jump_count += 1
		last_jump_time = 0
		coyote_timer = 0
		
		print("JUMP! Velocity: ", velocity, " | Position: ", global_position)

func can_stand_up() -> bool:
	stand_check.global_position = global_position + Vector3(0, collision_shape.shape.height, 0)
	stand_check.force_raycast_update()
	return not stand_check.is_colliding()

func update_visuals(delta: float):
	landing_impact_offset = lerp(landing_impact_offset, 0.0, delta * 5.0)
	
	# Head bobbing
	if is_moving and is_on_floor() and current_state != MovementState.CROUCHING:
		head_bob_time += delta * current_speed
	else:
		head_bob_time = 0.0
	
	var bob_offset = Vector3.ZERO
	if is_moving and is_on_floor() and current_state != MovementState.CROUCHING:
		bob_offset = Vector3(
			sin(head_bob_time * bob_frequency) * bob_amplitude,
			cos(head_bob_time * bob_frequency * 2) * bob_amplitude * 0.5,
			0
		)
	
	# Camera sway
	var target_tilt = 0.0
	if is_moving and is_on_floor():
		target_tilt = -raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	
	# Breathing effect
	var breathing_offset = Vector3.ZERO
	if !is_moving && is_on_floor():
		idle_time += delta
		breathing_offset.y = sin(idle_time * breathing_frequency) * breathing_amplitude
		breathing_offset.x = cos(idle_time * breathing_frequency * 0.7) * breathing_amplitude * 0.3
	
	# Apply effects
	head.position = default_head_position + bob_offset + Vector3(0, landing_impact_offset, 0) + breathing_offset
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	# FOV changes
	if current_state == MovementState.SPRINTING and raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)
	
	# Sprint zoom effect
	if current_state == MovementState.SPRINTING and is_moving and raw_input_dir.y < 0:
		head.position.z = default_head_position.z + sin(head_bob_time * bob_frequency * 1.5) * bob_amplitude * 0.2
	else:
		head.position.z = default_head_position.z
