# LocalPlayerController.gd
# This script handles local player input and movement, and synchronizes with the network

# Extends Node to handle input and processing
extends Node

# Player reference and input variables
var player: Node = null  # Will be set to Player node
var wish_dir := Vector3.ZERO  # Direction player wants to move
var raw_input_dir := Vector2.ZERO  # Raw input from keyboard/gamepad
var enabled: bool = false  # Whether controls are active
var mouse_sensitivity := 0.002  # Mouse sensitivity for camera control

# Movement state constants (matches Player's MovementState enum)
const STATE_WALKING = 0
const STATE_SPRINTING = 1
const STATE_AIRBORNE = 2

# Called when node enters scene tree
func _ready():
	# Get reference to parent Player node
	player = get_parent()

# Handle input events
func _input(event):
	# Only process input if enabled, player exists, and we have authority
	if not enabled or not player or not player.is_multiplayer_authority():
		return
	
	# Handle mouse movement for camera control
	if event is InputEventMouseMotion:
		# Horizontal rotation (turning left/right)
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Vertical rotation (looking up/down)
		if player.has_node("Camera3D"):
			var camera = player.get_node("Camera3D")
			var vertical_rotation = -event.relative.y * mouse_sensitivity
			camera.rotate_x(vertical_rotation)
			# Clamp vertical rotation to prevent over-rotation
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

# Physics process - handles movement and state updates
func _physics_process(delta):
	# Only process if enabled, player exists, and we have authority
	if not enabled or not player or not player.is_multiplayer_authority():
		return
	
	# Handle various movement aspects
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	
	# Apply gravity if player has the method
	if player.has_method("apply_gravity"):
		player.apply_gravity(delta)
	
	# Move the player
	player.move_and_slide()
	
	# Send network update if NetworkManager exists
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		if network_manager.has_method("send_player_update"):
			var camera_rotation = Vector3.ZERO
			if player.has_node("Camera3D"):
				camera_rotation = player.get_node("Camera3D").rotation
			
			# Send player state to server
			network_manager.send_player_update(
				player.global_position,
				player.velocity,
				player.rotation,
				camera_rotation
			)

# Handle keyboard/gamepad input
func handle_input():
	# Get raw input direction from input actions
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Update player's is_moving state if property exists
	if "is_moving" in player:
		player.is_moving = raw_input_dir.length() > 0.1
	
	# Convert 2D input to 3D movement direction relative to player's rotation
	wish_dir = (player.transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()

# Handle movement states (walking, sprinting, airborne)
func handle_states(delta: float):
	# Only update states when on floor
	if not player.is_on_floor():
		return
	
	# Update coyote timer if property exists
	if "coyote_timer" in player:
		player.coyote_timer -= delta
	
	# Check required properties exist
	if not ("current_state" in player) or not ("is_moving" in player):
		return
	
	# Set state based on input
	if Input.is_action_pressed("sprint") and player.is_moving and raw_input_dir.y < 0:
		player.current_state = STATE_SPRINTING
	else:
		player.current_state = STATE_WALKING

# Handle player movement physics
func handle_movement(delta: float):
	# Check required properties exist
	if not ("current_state" in player) or not ("sprint_speed" in player) or not ("walk_speed" in player):
		return
	
	# Get current speed based on state
	var current_speed = player.sprint_speed if player.current_state == STATE_SPRINTING else player.walk_speed
	
	# Ground movement
	if player.is_on_floor():
		if not ("velocity" in player) or not ("ground_acceleration" in player) or not ("ground_deceleration" in player):
			return
		
		# Handle acceleration/deceleration
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, player.ground_deceleration * delta)
		
		# Apply horizontal velocity
		player.velocity.x = current_vel.x
		player.velocity.z = current_vel.y
	# Air movement
	else:
		if not ("velocity" in player) or not ("ground_acceleration" in player) or not ("air_control" in player):
			return
		
		# Air control with reduced influence
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * player.air_control * delta)
			player.velocity.x = current_vel.x
			player.velocity.z = current_vel.y

# Handle jumping mechanics
func handle_jump(delta: float):
	# Check required properties exist
	if not ("jump_buffer_timer" in player) or not ("can_jump" in player) or not ("coyote_timer" in player):
		return
	
	# Update jump buffer timer
	player.jump_buffer_timer = max(player.jump_buffer_timer - delta, 0)
	
	# Update coyote timer (for jump forgiveness when leaving ledge)
	if player.is_on_floor():
		player.coyote_timer = 0.1
	else:
		player.coyote_timer = max(player.coyote_timer - delta, 0)
	
	# Execute jump if conditions are met
	if player.jump_buffer_timer > 0 and player.can_jump and (player.is_on_floor() or player.coyote_timer > 0):
		if "jump_velocity" in player:
			player.velocity.y = player.jump_velocity
		player.jump_buffer_timer = 0
		player.can_jump = false
		player.coyote_timer = 0
		if "jump_count" in player:
			player.jump_count += 1
