# RemotePlayerController.gd
# This script handles interpolation and smoothing of remote players' movements

extends Node

# Interpolation settings
const SMOOTHING_TIME = 0.15  # 150ms smoothing buffer
const MAX_EXTRAPOLATION = 0.2  # Maximum 200ms extrapolation
const POSITION_LERP_FACTOR = 0.3  # Position interpolation strength
const ROTATION_LERP_FACTOR = 0.5  # Rotation interpolation strength
const VELOCITY_LERP_FACTOR = 0.2  # Velocity interpolation strength

# References
var player: Node = null  # Reference to the Player node
var enabled: bool = false  # Whether controller is active

# Network data buffers
var position_history = []  # Stores recent position updates
var rotation_history = []  # Stores recent rotation updates
var camera_rotation_history = []  # Stores recent camera rotations
var velocity_history = []  # Stores recent velocity updates
var timestamp_history = []  # Stores timestamps for each update

# Called when node enters scene tree
func _ready():
	# Get reference to parent Player node
	player = get_parent()
	
	if enabled:
		# Connect to NetworkManager if it exists
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			if network_manager.has_signal("player_update_received"):
				network_manager.player_update_received.connect(_on_player_update_received)

# Called when receiving player updates from network
func _on_player_update_received(peer_id, position, velocity, rotation, camera_rotation):
	# Only process updates for this player
	if !player || peer_id != player.get_multiplayer_authority():
		return
	
	# Store update with current timestamp
	var current_time = Time.get_ticks_msec() / 1000.0
	position_history.append(position)
	rotation_history.append(rotation)
	camera_rotation_history.append(camera_rotation)
	velocity_history.append(velocity)
	timestamp_history.append(current_time)
	
	# Maintain buffer size (keep last 5 updates)
	if position_history.size() > 5:
		position_history.pop_front()
		rotation_history.pop_front()
		camera_rotation_history.pop_front()
		velocity_history.pop_front()
		timestamp_history.pop_front()

# Physics process for smooth interpolation
func _physics_process(delta):
	if !enabled || !player:
		return
	interpolate_movement(delta)

# Handles interpolation between network updates
func interpolate_movement(delta):
	# Need at least 2 updates to interpolate
	if position_history.size() < 2:
		return
	
	# Calculate render time (current time minus smoothing delay)
	var current_time = Time.get_ticks_msec() / 1000.0
	var render_time = current_time - SMOOTHING_TIME
	
	# Find closest states before and after render time
	var prev_index = -1
	var next_index = -1
	
	for i in range(timestamp_history.size()):
		if timestamp_history[i] <= render_time:
			prev_index = i
		else:
			next_index = i
			break
	
	# Handle edge cases
	if next_index == -1:  # If render time is after all updates
		if timestamp_history.size() < 2:
			return
		prev_index = timestamp_history.size() - 2
		next_index = timestamp_history.size() - 1
	elif prev_index == -1:  # If render time is before all updates
		prev_index = 0
		next_index = 1
	
	# Get timestamps of bounding updates
	var prev_time = timestamp_history[prev_index]
	var next_time = timestamp_history[next_index]
	
	# Calculate interpolation factor (0-1)
	var t = 0.0
	if next_time > prev_time:
		t = (render_time - prev_time) / (next_time - prev_time)
	t = clamp(t, 0.0, 1.0)
	
	# Interpolate position between updates
	var target_pos = position_history[prev_index].lerp(
		position_history[next_index], t
	)
	
	# Interpolate body rotation
	var target_rot = rotation_history[prev_index].lerp(
		rotation_history[next_index], t
	)
	
	# Interpolate camera rotation
	var target_cam_rot = camera_rotation_history[prev_index].lerp(
		camera_rotation_history[next_index], t
	)
	
	# Apply smoothed position update
	player.global_position = player.global_position.lerp(target_pos, POSITION_LERP_FACTOR)
	
	# Apply smoothed rotation update
	player.rotation = player.rotation.lerp(target_rot, ROTATION_LERP_FACTOR)
	
	# Apply smoothed camera rotation if camera exists
	if player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		camera.rotation = camera.rotation.lerp(target_cam_rot, ROTATION_LERP_FACTOR)
	
	# Update velocity with smoothing
	player.velocity = player.velocity.lerp(
		velocity_history[prev_index].lerp(velocity_history[next_index], t),
		VELOCITY_LERP_FACTOR
	)
