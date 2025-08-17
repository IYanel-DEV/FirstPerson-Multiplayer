

# This script extends Node3D, making it a 3D scene root
extends Node3D

# Called when the node enters the scene tree
func _enter_tree():
	# Connect multiplayer signals if multiplayer is available
	if multiplayer != null:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Called when the node is ready
func _ready():
	print("GameMode ready")
	
	# If this is the server, spawn the host player
	if multiplayer != null && multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())

# Called when a new peer connects
func _on_peer_connected(peer_id: int):
	# Only the server handles player spawning
	if multiplayer.is_server():
		print("Peer connected to GameMode: ", peer_id)
		spawn_player(peer_id)

# Called when a peer disconnects
func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected from GameMode: ", peer_id)
	remove_player(peer_id)

# Spawns a player for the given peer_id
func spawn_player(peer_id: int):
	# Don't spawn if player already exists
	if has_node("Player_" + str(peer_id)):
		return
	
	# Load and instantiate the player scene
	var player_scene = load("res://Player/_Player.tscn")
	var player = player_scene.instantiate()
	
	# Set player name and add to scene
	player.name = "Player_" + str(peer_id)
	add_child(player, true)
	# Position player at random spawn point
	player.global_position = get_random_spawn_position()
	
	print("Spawned player: ", player.name)

# Removes a player when they disconnect
func remove_player(peer_id: int):
	var player = get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()
		print("Removed player: ", peer_id)

# Returns a random spawn position from spawn points in the scene
func get_random_spawn_position() -> Vector3:
	# Try to find spawn points node
	var spawn_points_node = get_node_or_null("SpawnPoints")
	if spawn_points_node:
		# Get all spawn point children
		var spawn_points = spawn_points_node.get_children()
		if spawn_points.size() > 0:
			# Select random spawn point
			var spawn_point = spawn_points[randi() % spawn_points.size()]
			return spawn_point.global_position
	# Default spawn position if no points found
	return Vector3(0, 1, 0)
