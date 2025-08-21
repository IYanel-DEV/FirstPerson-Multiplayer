# PlayerWeapons.gd - Fixed version with drop delay
class_name PlayerWeapons
extends Node

# ===== REFERENCES =====
var player: PlayerController
var inventory: Inventory
var weapon_socket: Node3D
var movement_controller: PlayerMovement
var is_ready := false

# Drop cooldown variables
var can_drop_weapon: bool = true
var drop_cooldown: float = 1.0

func _ready():
	player = get_parent() as PlayerController
	
	# Get inventory reference
	inventory = player.get_node("Inventory") if player.has_node("Inventory") else null
	if not inventory:
		push_error("Inventory not found in player")
	
	# Find weapon socket
	weapon_socket = player.get_node("Camera3D/HeadPosition/WeaponSocket") if player.has_node("Camera3D/HeadPosition/WeaponSocket") else null
	if not weapon_socket:
		push_error("WeaponSocket not found in player")
	
	# Connect to inventory signals only once
	if inventory and not inventory.weapon_changed.is_connected(_on_weapon_changed):
		inventory.weapon_changed.connect(_on_weapon_changed)
	
	is_ready = true
	
	# If this is a remote player, wait for weapon sync
	if not player.is_multiplayer_authority():
		await get_tree().create_timer(0.5).timeout

func _process(_delta):
	if not is_ready:
		return
		
	# Debug info for weapons
	if Engine.get_frames_drawn() % 120 == 0 and player.is_multiplayer_authority():
		print("Player weapon debug:")
		print("  Inventory: ", inventory != null)
		if inventory:
			print("  Weapons count: ", inventory.weapons.size())
			print("  Current weapon: ", inventory.current_weapon)
			if inventory.current_weapon and is_instance_valid(inventory.current_weapon):
				print("  Current weapon name: ", inventory.current_weapon.weapon_name)
				print("  Current weapon parent: ", inventory.current_weapon.get_parent())
		if weapon_socket:
			print("  Weapon socket children: ", weapon_socket.get_children().size())
			for child in weapon_socket.get_children():
				print("    - ", child.name, " (", child.get_class(), ")")
	
	# Update weapon movement state if we have a weapon
	if inventory and inventory.current_weapon and is_instance_valid(inventory.current_weapon):
		if not movement_controller:
			movement_controller = player.get_node("PlayerMovement") if player.has_node("PlayerMovement") else null
		if movement_controller:
			inventory.current_weapon.set_moving(movement_controller.is_moving)

func _input(event):
	if not is_ready or not player.is_multiplayer_authority():
		return
	
	# Only process weapon actions if we have an inventory and current weapon
	if not inventory or not inventory.current_weapon or not is_instance_valid(inventory.current_weapon):
		if (event.is_action_pressed("fire") or event.is_action_pressed("reload") or 
			event.is_action_pressed("aim") or event.is_action_pressed("drop_weapon")) and randf() < 0.01:
			print("No weapon equipped")
		return
	
	# Fire weapon
	if event.is_action_pressed("fire"):
		inventory.current_weapon.fire()
	
	# Reload weapon
	if event.is_action_pressed("reload"):
		inventory.current_weapon.reload()
	
	# Aim down sights
	if event.is_action_pressed("aim"):
		inventory.current_weapon.aim(true)
	if event.is_action_released("aim"):
		inventory.current_weapon.aim(false)
	
	# Drop weapon with cooldown
	if event.is_action_pressed("drop_weapon") and can_drop_weapon:
		if inventory and inventory.current_weapon and is_instance_valid(inventory.current_weapon):
			# Start drop cooldown
			can_drop_weapon = false
			get_tree().create_timer(drop_cooldown).timeout.connect(func(): can_drop_weapon = true)
			
			# Get drop info before dropping
			var drop_info = inventory.drop_current_weapon()
			if drop_info:
				print("Dropping weapon: ", drop_info["type"])
				
				# Server handles the actual weapon drop creation
				if player.is_multiplayer_authority():
					# Calculate drop position further in front of player
					var drop_direction = -player.global_transform.basis.z
					var drop_distance = 2.5  # Increased distance
					var drop_position = player.global_position + (drop_direction * drop_distance)
					
					player.rpc("_create_dropped_weapon", drop_info["type"], drop_position, drop_direction)

func _on_weapon_changed(weapon: WeaponBase):
	if not is_ready or not is_instance_valid(weapon):
		print("Weapon changed but not ready or invalid weapon")
		return
	
	print("Weapon changed to: ", weapon.weapon_name)
	
	# Remove any existing weapons from socket
	if weapon_socket:
		for child in weapon_socket.get_children():
			# Only remove weapon nodes, not other potential children
			if child is WeaponBase or child.has_method("is_weapon"):
				print("Removing old weapon: ", child.name)
				# Make sure to properly clean up the weapon
				if child.get_parent():
					child.get_parent().remove_child(child)
				child.queue_free()
	
	# Small delay to ensure cleanup
	await get_tree().process_frame
	
	# Add new weapon to socket
	if weapon and weapon_socket and is_instance_valid(weapon):
		print("Adding weapon to socket: ", weapon.weapon_name)
		
		# Make sure weapon is visible
		weapon.visible = true
		
		# If weapon already has a parent, remove it first
		if weapon.get_parent():
			weapon.get_parent().remove_child(weapon)
		
		# Add to socket
		weapon_socket.add_child(weapon)
		
		# Reset transform to ensure proper positioning
		weapon.position = Vector3.ZERO
		weapon.rotation = Vector3.ZERO
		weapon.scale = Vector3.ONE
		
		# Force update to ensure visibility
		weapon.process_mode = Node.PROCESS_MODE_INHERIT
		
		print("Weapon successfully added to socket")
		
		# Sync weapon visibility across network for remote players
		if player.is_multiplayer_authority():
			player.rpc("_sync_weapon_visibility", weapon.weapon_name, true)

# Add this RPC method to sync weapon visibility
@rpc("any_peer", "call_local")
func _sync_weapon_visibility(weapon_name: String, visible: bool):
	if not player.is_multiplayer_authority() and inventory:
		for weapon in inventory.weapons:
			if is_instance_valid(weapon) and weapon.weapon_name == weapon_name:
				weapon.visible = visible
				break

@rpc("any_peer", "call_local")
func _sync_weapon_assignment(weapon_name: String):
	if not is_ready:
		return
		
	# This function handles weapon assignment synchronization
	print("Syncing weapon assignment: ", weapon_name)
	
	# Find the weapon in inventory by name
	if inventory:
		for i in range(inventory.weapons.size()):
			var weapon = inventory.weapons[i]
			if is_instance_valid(weapon) and weapon.weapon_name == weapon_name:
				# Equip this weapon
				inventory.equip_weapon(i)
				break

@rpc("any_peer", "call_local", "reliable")
func _create_dropped_weapon(weapon_type: String, position: Vector3, direction: Vector3):
	# Only server should create the actual dropped weapon
	if not multiplayer.is_server():
		return
	
	# Load the dropped weapon scene
	var dropped_weapon_scene = load("res://Weapons/Pistol/DroppedPistol.tscn")
	if dropped_weapon_scene:
		var dropped_weapon = dropped_weapon_scene.instantiate()
		
		# Add to the scene tree
		player.get_parent().add_child(dropped_weapon)
		
		# Position the dropped weapon further away
		dropped_weapon.global_position = position
		
		# Set weapon properties - make sure weapon_type is not empty
		var actual_weapon_type = weapon_type
		if weapon_type == "" or weapon_type == "Base Weapon":
			actual_weapon_type = "Pistol"  # Default to pistol
		
		if dropped_weapon.has_method("set_weapon_properties"):
			var weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"
			dropped_weapon.set_weapon_properties(load(weapon_scene_path), actual_weapon_type, position)
		
		# Apply force to make it look natural and move it away from player
		var throw_force = 5.0  # Increased force
		dropped_weapon.apply_central_impulse(direction * throw_force + Vector3.UP * 2)
		dropped_weapon.apply_torque_impulse(
			Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		)
		
		print("Dropped weapon created on server: ", actual_weapon_type)

func set_input_enabled(enabled: bool):
	# No special handling needed for weapons
	pass
