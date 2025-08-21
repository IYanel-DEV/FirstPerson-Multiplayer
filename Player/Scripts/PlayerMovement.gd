# PlayerMovement.gd - Handles player movement physics
class_name PlayerMovement
extends Node

# ===== EXPORTED SETTINGS =====
@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 12.0  # This property is referenced by synchronizer
@export var ground_acceleration := 15.0
@export var ground_deceleration := 20.0
@export var air_control := 0.3

# ===== CONSTANTS =====
const GRAVITY_FORCE = 35.0

# ===== REFERENCES =====
var player: CharacterBody3D
var camera_controller: PlayerCamera

# ===== MOVEMENT STATE =====
enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var wish_dir := Vector3.ZERO
var current_speed := 0.0
var was_on_floor := true

# ===== JUMP VARIABLES =====
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var can_jump := true
var jump_count := 0
var input_enabled: bool = true
var raw_input_dir := Vector2.ZERO

func _ready():
	player = get_parent()
	current_speed = walk_speed

func _input(event):
	if not input_enabled or not player.is_multiplayer_authority():
		return
	
	# Jump input buffering
	if event.is_action_pressed("jump"):
		jump_buffer_timer = 0.15

func _physics_process(delta):
	if not input_enabled:
		player.velocity = Vector3.ZERO
		return
		
	# Update movement state
	is_moving = wish_dir.length() > 0.1
	
	if player.is_multiplayer_authority():
		process_local_movement(delta)
		player.move_and_slide()

func process_local_movement(delta):
	# Get input direction
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_moving = raw_input_dir.length() > 0.1
	wish_dir = (player.transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()
	
	# Handle jumping
	handle_jump_mechanics(delta)
	
	# Update movement state
	update_movement_state()
	
	# Calculate movement
	handle_movement(delta)
	
	# Apply gravity
	apply_gravity(delta)

func handle_jump_mechanics(delta):
	# Update timers
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	
	# Coyote time
	if player.is_on_floor():
		coyote_timer = 0.1
		if not was_on_floor:
			can_jump = true
			jump_count = 0
	else:
		coyote_timer = max(coyote_timer - delta, 0)
	
	was_on_floor = player.is_on_floor()
	
	# Perform jump if conditions met
	if jump_buffer_timer > 0 and can_jump and (player.is_on_floor() or player.coyote_timer > 0):
		perform_jump()

func perform_jump():
	player.velocity.y = jump_velocity
	jump_buffer_timer = 0
	can_jump = false
	coyote_timer = 0
	jump_count += 1

func update_movement_state():
	if player.is_on_floor():
		if Input.is_action_pressed("sprint") and is_moving and raw_input_dir.y < 0:
			current_state = MovementState.SPRINTING
			current_speed = sprint_speed
		else:
			current_state = MovementState.WALKING
			current_speed = walk_speed
	else:
		current_state = MovementState.AIRBORNE

func handle_movement(delta):
	if player.is_on_floor():
		# Ground movement
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, ground_deceleration * delta)
		
		player.velocity.x = current_vel.x
		player.velocity.z = current_vel.y
	else:
		# Air movement
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, ground_acceleration * air_control * delta)
			player.velocity.x = current_vel.x
			player.velocity.z = current_vel.y

func apply_gravity(delta):
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY_FORCE * delta

func set_input_enabled(enabled: bool):
	input_enabled = enabled

func get_random_spawn_position() -> Vector3:
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.size() > 0:
		var spawn_point = spawn_points[randi() % spawn_points.size()]
		return spawn_point.global_position
	return Vector3(0, 1, 0)
