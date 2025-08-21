# PlayerNetwork.gd - Handles network synchronization
class_name PlayerNetwork
extends Node

# ===== EXPORTED SETTINGS =====
@export_category("Network Settings")
@export var network_update_rate := 20.0
@export var interpolation_time := 0.15

# ===== CONSTANTS =====
const POSITION_LERP_FACTOR = 0.3
const ROTATION_LERP_FACTOR = 0.5

# ===== REFERENCES =====
var player: CharacterBody3D
var sync: MultiplayerSynchronizer

# ===== NETWORK INTERPOLATION =====
var network_position_buffer = []
var network_rotation_buffer = []
var network_timestamp_buffer = []
var last_network_update_time := 0.0

func _enter_tree():
	player = get_parent()
	sync = player.get_node("MultiplayerSynchronizer") if player.has_node("MultiplayerSynchronizer") else null
	
	# Set multiplayer authority based on name
	if player.name.contains("_"):
		var peer_id = player.name.get_slice("_", 1).to_int()
		player.set_multiplayer_authority(peer_id)
		if sync:
			sync.set_multiplayer_authority(peer_id)
			sync.replication_interval = 1.0 / network_update_rate
			
			# Clear and set replication config to avoid property errors
			if sync.replication_config:
				sync.replication_config = null
			
			# Create new replication config
			var new_config = SceneReplicationConfig.new()
			new_config.add_property("global_position")
			new_config.add_property("rotation")
			new_config.add_property("velocity")
			sync.replication_config = new_config

func _ready():
	pass

func _physics_process(delta):
	if player.is_multiplayer_authority():
		send_network_update()
	else:
		process_remote_movement(delta)

func send_network_update():
	# Send position/rotation update to other players
	player.rpc("_receive_network_update", 
		player.global_position,
		player.velocity,
		player.rotation,
		Time.get_ticks_msec() / 1000.0)

func process_remote_movement(_delta):  
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
	player.global_position = player.global_position.lerp(target_pos, POSITION_LERP_FACTOR)
	player.rotation = player.rotation.lerp(target_rot, ROTATION_LERP_FACTOR)

@rpc("unreliable_ordered", "any_peer")
func _receive_network_update(pos: Vector3, _vel: Vector3, rot: Vector3, timestamp: float):
	if player.is_multiplayer_authority(): return
	
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
