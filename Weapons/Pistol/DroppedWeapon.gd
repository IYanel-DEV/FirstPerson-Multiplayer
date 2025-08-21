extends RigidBody3D
class_name DroppedWeapon

@export var weapon_scene: PackedScene
var weapon_name: String = ""
var weapon_picked_up: bool = false
var spawn_position: Vector3 = Vector3.ZERO

# Pickup cooldown to prevent immediate re-pickup
var pickup_cooldown: bool = false
var cooldown_time: float = 1.0

# Network synchronization
var sync_timer: float = 0.0
var sync_interval: float = 0.1

func _ready():
	# Enable physics
	freeze = false
	
	# Start pickup cooldown
	pickup_cooldown = true
	get_tree().create_timer(cooldown_time).timeout.connect(func(): pickup_cooldown = false)
	
	# Connect area signal
	$Area3D.body_entered.connect(_on_body_entered)
	print("Dropped weapon ready: ", weapon_name)
	
	# Set multiplayer authority to server
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(1)  # Server has authority

func _physics_process(delta):
	# Sync position periodically if we're the server
	if multiplayer.is_server() and not weapon_picked_up:
		sync_timer += delta
		if sync_timer >= sync_interval:
			sync_timer = 0
			rpc("_sync_position", global_position, linear_velocity, angular_velocity)

func _on_body_entered(body):
	print("Body entered dropped weapon: ", body.name)
	
	# Prevent multiple pickups and immediate re-pickup
	if weapon_picked_up or pickup_cooldown:
		return
	
	# Only process on server
	if not multiplayer.is_server():
		# Client sends pickup request to server
		if body.is_in_group("player") and body.is_multiplayer_authority():
			rpc_id(1, "_request_pickup", body.get_path())
		return
	
	# Server handles pickup
	if body.is_in_group("player"):
		print("Player touched weapon: ", weapon_name)
		_handle_pickup(body)

@rpc("any_peer", "reliable")
func _request_pickup(player_path: NodePath):
	if multiplayer.is_server():
		var player = get_node_or_null(player_path)
		if player:
			_handle_pickup(player)

@rpc("any_peer", "call_local")
func _sync_position(pos: Vector3, lin_vel: Vector3, ang_vel: Vector3):
	if not multiplayer.is_server():
		global_position = pos
		linear_velocity = lin_vel
		angular_velocity = ang_vel

func set_weapon_properties(scene: PackedScene, name: String, position: Vector3 = Vector3.ZERO):
	weapon_scene = scene
	weapon_name = name
	spawn_position = position
	
	print("Dropped weapon set: ", name, " with scene: ", scene != null)
	
	# Set initial position
	if position != Vector3.ZERO:
		global_position = position
	
	# Also update the visual representation if needed
	if has_node("MeshInstance3D") and name != "":
		get_node("MeshInstance3D").visible = true
		
	# Set a proper name for the dropped weapon
	self.name = "Dropped_" + name
	
	# Sync across network if server
	if multiplayer.is_server():
		rpc("_sync_weapon_properties", name, position)

@rpc("any_peer", "call_local")
func _sync_weapon_properties(name: String, position: Vector3):
	if not multiplayer.is_server():
		weapon_name = name
		if position != Vector3.ZERO:
			global_position = position
		
		if has_node("MeshInstance3D") and name != "":
			get_node("MeshInstance3D").visible = true
		
		self.name = "Dropped_" + name
		print("Synced dropped weapon: ", name)

func _handle_pickup(player):
	# Only server should handle pickups
	if not multiplayer.is_server():
		return
	
	# Prevent multiple pickups
	if weapon_picked_up:
		return
	
	weapon_picked_up = true
	
	var weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"  # Default
	if weapon_name == "Pistol":
		weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"
	# Add more weapon types here as needed
	
	var weapon_scene = load(weapon_scene_path)
	if weapon_scene == null:
		print("Failed to load weapon scene: ", weapon_scene_path)
		weapon_picked_up = false
		return
		
	var weapon_instance = weapon_scene.instantiate()
	
	# Find the WeaponBase component
	var weapon_base = null
	if weapon_instance is WeaponBase:
		weapon_base = weapon_instance
	elif weapon_instance.has_node("WeaponBase"):
		weapon_base = weapon_instance.get_node("WeaponBase")
	
	if not weapon_base:
		print("Instantiated weapon is not a WeaponBase")
		weapon_instance.queue_free()
		weapon_picked_up = false
		return
	
	# Set weapon name
	weapon_base.weapon_name = weapon_name
	
	# Check if player has inventory
	var inventory = null
	if player.has_method("get_inventory"):
		inventory = player.get_inventory()
	
	if inventory and inventory.has_method("add_weapon"):
		var success = inventory.add_weapon(weapon_base)
		if success:
			print("Weapon picked up: ", weapon_name)
			# Remove the pickup across all clients
			rpc("_remove_pickup")
		else:
			print("Failed to add weapon to inventory")
			weapon_instance.queue_free()
			weapon_picked_up = false
	else:
		print("Player doesn't have a valid inventory system")
		weapon_instance.queue_free()
		weapon_picked_up = false

@rpc("any_peer", "call_local")
func _remove_pickup():
	queue_free()
