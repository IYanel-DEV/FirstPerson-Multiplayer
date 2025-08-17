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
	"state": "WALKING"
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_speed = walk_speed

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var vertical_rotation = -event.relative.y * mouse_sensitivity
		camera.rotate_x(vertical_rotation)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventKey and event.keycode == KEY_SPACE:
		debug_info.jump_pressed = event.pressed
		if event.pressed:
			jump_buffer_timer = 0.15

func _physics_process(delta):
	# Process player mechanics
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	apply_gravity(delta)
	
	# Move the character
	move_and_slide()
	
	# Handle landing and state transitions
	handle_landing()
	
	update_visuals(delta)
	update_debug_info()
	
	# Store previous frame's ground state
	was_on_floor = is_on_floor()

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
	jump_buffer_timer -= delta
	last_jump_time += delta
	debug_info.jump_executed = false
	
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

func update_debug_info():
	debug_info.position = global_position
	debug_info.velocity = velocity
	debug_info.is_on_floor = is_on_floor()
	debug_info.can_jump = can_jump
	debug_info.coyote_time = coyote_timer
	debug_info.jump_buffer = jump_buffer_timer
