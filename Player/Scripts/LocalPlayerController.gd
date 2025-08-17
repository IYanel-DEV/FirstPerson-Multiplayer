extends Node
class_name LocalPlayerController

# Reference to player
@onready var player: Player = get_parent()

# Input
var wish_dir := Vector3.ZERO
var raw_input_dir := Vector2.ZERO
var enabled: bool = false

func _input(event):
	if not enabled or not player.is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		# Handle mouse look
		player.rotate_y(-event.relative.x * player.mouse_sensitivity)
		var vertical_rotation = -event.relative.y * player.mouse_sensitivity
		if player.camera:
			player.camera.rotate_x(vertical_rotation)
			player.camera.rotation.x = clamp(player.camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		player.jump_buffer_timer = 0.15

func _physics_process(delta):
	if not enabled or not player.is_multiplayer_authority():
		return
	
	handle_input()
	handle_states(delta)
	handle_jump(delta)
	handle_movement(delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	
	# Send network update
	NetworkManager.send_player_update(
		player.global_position,
		player.velocity,
		player.rotation,
		player.camera.rotation if player.camera else Vector3.ZERO
	)

func handle_input():
	raw_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	player.is_moving = raw_input_dir.length() > 0.1
	wish_dir = (player.transform.basis * Vector3(raw_input_dir.x, 0, raw_input_dir.y)).normalized()

func handle_states(delta: float):
	if player.is_on_floor():
		if Input.is_action_pressed("sprint") and player.is_moving and raw_input_dir.y < 0:
			player.current_state = Player.MovementState.SPRINTING
		else:
			player.current_state = Player.MovementState.WALKING
	else:
		player.current_state = Player.MovementState.AIRBORNE
		player.coyote_timer -= delta

func handle_movement(delta: float):
	var current_speed = player.sprint_speed if player.current_state == Player.MovementState.SPRINTING else player.walk_speed
	
	if player.is_on_floor():
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * delta)
		else:
			current_vel = current_vel.move_toward(Vector2.ZERO, player.ground_deceleration * delta)
		
		player.velocity.x = current_vel.x
		player.velocity.z = current_vel.y
	else:
		var current_vel = Vector2(player.velocity.x, player.velocity.z)
		var target_vel = Vector2(wish_dir.x, wish_dir.z) * current_speed
		
		if wish_dir.length() > 0:
			current_vel = current_vel.move_toward(target_vel, player.ground_acceleration * player.air_control * delta)
			player.velocity.x = current_vel.x
			player.velocity.z = current_vel.y

func handle_jump(delta: float):
	player.jump_buffer_timer = max(player.jump_buffer_timer - delta, 0)
	
	if player.is_on_floor():
		player.coyote_timer = 0.1
	else:
		player.coyote_timer = max(player.coyote_timer - delta, 0)
	
	if player.jump_buffer_timer > 0 and player.can_jump and (player.is_on_floor() or player.coyote_timer > 0):
		player.velocity.y = player.jump_velocity
		player.jump_buffer_timer = 0
		player.can_jump = false
		player.coyote_timer = 0
		player.jump_count += 1
