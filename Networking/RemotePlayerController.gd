extends Node
class_name RemotePlayerController

# Interpolation settings
const SMOOTHING_TIME = 0.15  # 150ms smoothing
const MAX_EXTRAPOLATION = 0.2  # 200ms max

# References
@onready var player: Player = get_parent()

# Network data
var position_history = []
var rotation_history = []
var camera_rotation_history = []
var velocity_history = []
var timestamp_history = []
var enabled: bool = false

func _ready():
	if enabled:
		NetworkManager.player_update_received.connect(_on_player_update_received)

func _on_player_update_received(peer_id, position, velocity, rotation, camera_rotation):
	if peer_id != player.get_multiplayer_authority():
		return
	
	# Store update with current time
	var current_time = Time.get_ticks_msec() / 1000.0
	position_history.append(position)
	rotation_history.append(rotation)
	camera_rotation_history.append(camera_rotation)
	velocity_history.append(velocity)
	timestamp_history.append(current_time)
	
	# Keep buffer size manageable
	if position_history.size() > 5:
		position_history.pop_front()
		rotation_history.pop_front()
		camera_rotation_history.pop_front()
		velocity_history.pop_front()
		timestamp_history.pop_front()

func _physics_process(delta):
	if not enabled:
		return
	interpolate_movement(delta)

func interpolate_movement(delta):
	if position_history.size() < 2:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var render_time = current_time - SMOOTHING_TIME
	
	# Find closest states
	var prev_index = -1
	var next_index = -1
	
	for i in range(timestamp_history.size()):
		if timestamp_history[i] <= render_time:
			prev_index = i
		else:
			next_index = i
			break
	
	# Handle edge cases
	if next_index == -1:
		if timestamp_history.size() < 2:
			return
		prev_index = timestamp_history.size() - 2
		next_index = timestamp_history.size() - 1
	elif prev_index == -1:
		prev_index = 0
		next_index = 1
	
	# Get states
	var prev_time = timestamp_history[prev_index]
	var next_time = timestamp_history[next_index]
	
	# Calculate interpolation factor
	var t = 0.0
	if next_time > prev_time:
		t = (render_time - prev_time) / (next_time - prev_time)
	t = clamp(t, 0.0, 1.0)
	
	# Interpolate position
	var target_pos = position_history[prev_index].lerp(
		position_history[next_index], t
	)
	
	# Interpolate rotation
	var target_rot = rotation_history[prev_index].lerp(
		rotation_history[next_index], t
	)
	
	# Interpolate camera rotation
	var target_cam_rot = camera_rotation_history[prev_index].lerp(
		camera_rotation_history[next_index], t
	)
	
	# Apply with smoothing
	var smoothing_factor = clamp(delta * 20.0, 0.0, 1.0)
	player.global_position = player.global_position.lerp(target_pos, smoothing_factor)
	player.rotation = player.rotation.lerp(target_rot, smoothing_factor)
	if player.camera:
		player.camera.rotation = player.camera.rotation.lerp(target_cam_rot, smoothing_factor)
	
	# Update velocity
	player.velocity = velocity_history[prev_index].lerp(
		velocity_history[next_index], t
	)
