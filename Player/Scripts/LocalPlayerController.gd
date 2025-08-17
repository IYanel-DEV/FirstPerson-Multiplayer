# LocalPlayerController.gd
extends Node

# Reference to player
var player: Node = null  # Will be set to Player node

# Input
var wish_dir := Vector3.ZERO
var raw_input_dir := Vector2.ZERO
var enabled: bool = false
var mouse_sensitivity := 0.002

# Define state constants to match Player's MovementState enum
const STATE_WALKING = 0
const STATE_SPRINTING = 1
const STATE_AIRBORNE = 2

func _ready():
	player = get_parent()

func _input(event):
	if not enabled or not player or not player.is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		# Use the sensitivity value
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Apply vertical rotation
		if player.has_node("Camera3D"):
			var camera = player.get_node("Camera3D")
			var vertical_rotation = -event.relative.y * mouse_sensitivity
			camera.rotate_x(vertical_rotation)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	if not enabled or not player or not player.is_multiplayer_authority():
		return
	
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	
	# Call apply_gravity if it exists
	if player.has_method("apply_gravity"):
		player.apply_gravity(delta)
	
	player.move_and_slide()
	
	# Send network update
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		if network_manager.has_method("send_player_update"):
			var camera_rotation = Vector3.ZERO
			if player.has_node("Camera3D"):
				camera_rotation = player.get_node("Camera3D").rotation
			
			network_manager.send_player_update(
				player.global_position,
				player.velocity,
				player.rotation,
				camera_rotation
			)

func handle_input():
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Set is_moving if property exists
	if "is_moving" in player:
		player.is_moving = raw_input_dir.length() > 0.1
	
	wish_dir = (player.transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()

func handle_states(delta: float):
	if not player.is_on_floor():
		return
	
	if "coyote_timer" in player:
		player.coyote_timer -= delta
	
	if not ("current_state" in player) or not ("is_moving" in player):
		return
	
	if Input.is_action_pressed("sprint") and player.is_moving and raw_input_dir.y < 0:
		player.current_state = STATE_SPRINTING
	else:
		player.current_state = STATE_WALKING

func handle_movement(delta: float):
	if not ("current_state" in player) or not ("sprint_speed" in player) or not ("walk_speed" in player):
		return
	
	var current_speed = player.sprint_speed if player.current_state == STATE_SPRINTING else player.walk_speed
	
	if player.is_on_floor():
		if not ("velocity" in player) or not ("ground_acceleration" in player) or not ("ground_deceleration" in player):
			return
		
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, player.ground_deceleration * delta)
		
		player.velocity.x = current_vel.x
		player.velocity.z = current_vel.y
	else:
		if not ("velocity" in player) or not ("ground_acceleration" in player) or not ("air_control" in player):
			return
		
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * player.air_control * delta)
			player.velocity.x = current_vel.x
			player.velocity.z = current_vel.y

func handle_jump(delta: float):
	if not ("jump_buffer_timer" in player) or not ("can_jump" in player) or not ("coyote_timer" in player):
		return
	
	player.jump_buffer_timer = max(player.jump_buffer_timer - delta, 0)
	
	if player.is_on_floor():
		player.coyote_timer = 0.1
	else:
		player.coyote_timer = max(player.coyote_timer - delta, 0)
	
	if player.jump_buffer_timer > 0 and player.can_jump and (player.is_on_floor() or player.coyote_timer > 0):
		if "jump_velocity" in player:
			player.velocity.y = player.jump_velocity
		player.jump_buffer_timer = 0
		player.can_jump = false
		player.coyote_timer = 0
		if "jump_count" in player:
			player.jump_count += 1
