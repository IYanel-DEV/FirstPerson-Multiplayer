# GameMode.gd - Fixed version with proper weapon handling
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
		# Wait a bit to ensure everything is initialized
		await get_tree().create_timer(0.5).timeout
		spawn_player(multiplayer.get_unique_id())

# Called when a new peer connects
func _on_peer_connected(peer_id: int):
	# Only the server handles player spawning
	if multiplayer.is_server():
		print("Peer connected to GameMode: ", peer_id)
		# Wait a bit to ensure everything is initialized
		await get_tree().create_timer(0.5).timeout
		spawn_player(peer_id)

# Called when a peer disconnects
func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected from GameMode: ", peer_id)
	remove_player(peer_id)

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
	
	# Wait for player to be fully ready
	await get_tree().create_timer(0.5).timeout
	
	# Add a pistol to the player's inventory - only for the server player
	if multiplayer.is_server() and peer_id == 1:
		var pistol_scene = load("res://Weapons/Pistol/Pistol.tscn")
		if pistol_scene == null:
			print("Failed to load pistol scene")
			return
			
		var pistol_instance = pistol_scene.instantiate()
		
		# Find the WeaponBase component
		var pistol_weapon = null
		if pistol_instance is WeaponBase:
			pistol_weapon = pistol_instance
		elif pistol_instance.has_node("WeaponBase"):
			pistol_weapon = pistol_instance.get_node("WeaponBase")
		
		if pistol_weapon and is_instance_valid(pistol_weapon):
			# Store the weapon name BEFORE adding to inventory
			var weapon_name = pistol_weapon.weapon_name
			print("Weapon name stored: ", weapon_name)
			
			# Wait for player's inventory to be ready
			if player.has_method("get_inventory"):
				var inventory = player.get_inventory()
				if inventory and is_instance_valid(inventory):
					# Wait a bit more for inventory to be fully initialized
					await get_tree().create_timer(0.2).timeout
					
					# Check if the weapon is still valid before adding
					if is_instance_valid(pistol_weapon):
						var success = inventory.add_weapon(pistol_weapon)
						if success:
							print("Added pistol to player: ", player.name)
							
							# Sync weapon across network - use the stored weapon name
							if multiplayer.is_server():
								# Give clients time to fully initialize
								await get_tree().create_timer(0.2).timeout
								
								# Check if player is still valid before calling RPC
								if is_instance_valid(player):
									# Use absolute path to ensure we can find the player
									var player_path = player.get_path()
									rpc("_sync_weapon_assignment", player_path, weapon_name)
								else:
									print("Player was freed before weapon sync")
						else:
							print("Failed to add pistol to player: ", player.name)
							if is_instance_valid(pistol_instance):
								pistol_instance.queue_free()
					else:
						print("Weapon was freed before adding to inventory")
						if is_instance_valid(pistol_instance):
							pistol_instance.queue_free()
				else:
					print("Player inventory not found or invalid")
					if is_instance_valid(pistol_instance):
						pistol_instance.queue_free()
			else:
				print("Player doesn't have get_inventory method")
				if is_instance_valid(pistol_instance):
					pistol_instance.queue_free()
		else:
			print("Pistol instance doesn't have WeaponBase or is invalid")
			if is_instance_valid(pistol_instance):
				pistol_instance.queue_free()

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

# Sync weapon assignment with absolute path
@rpc("any_peer", "call_local")
func _sync_weapon_assignment(player_path: NodePath, weapon_name: String):
	var player = get_node_or_null(player_path)
	if player and player.has_method("_sync_weapon_assignment"):
		player._sync_weapon_assignment(weapon_name)
