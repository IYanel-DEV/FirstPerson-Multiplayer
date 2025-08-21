# PlayerController.gd - Main orchestrator class
class_name PlayerController
extends CharacterBody3D

# ===== NODE REFERENCES =====
@onready var movement_controller: PlayerMovement = $PlayerMovement
@onready var camera_controller: PlayerCamera = $PlayerCamera
@onready var network_controller: PlayerNetwork = $PlayerNetwork
@onready var weapon_controller: PlayerWeapons = $PlayerWeapons
@onready var inventory: Inventory = $Inventory

# Add jump_velocity property to fix synchronizer error
var jump_velocity: float = 12.0

# ===== PUBLIC API (same as before) =====
func _enter_tree():
	if network_controller:
		network_controller._enter_tree()

func _ready():
	if movement_controller:
		movement_controller._ready()
	if camera_controller:
		camera_controller._ready()
	if weapon_controller:
		weapon_controller._ready()
	if network_controller:
		network_controller._ready()
	
	# Make sure camera effects are updated
	if camera_controller:
		set_process(true)
	
	add_to_group("player")
	print("Player added to 'player' group")

func _process(delta):
	# Update camera effects if we have authority
	if camera_controller and is_multiplayer_authority():
		camera_controller.update_camera_effects(delta)

func _input(event):
	if movement_controller:
		movement_controller._input(event)
	if weapon_controller:
		weapon_controller._input(event)

func _physics_process(delta):
	if movement_controller:
		movement_controller._physics_process(delta)
	if network_controller:
		network_controller._physics_process(delta)

# Public property accessors
func get_inventory():
	return inventory

func get_random_spawn_position() -> Vector3:
	return Vector3(0, 1, 0) if not movement_controller else movement_controller.get_random_spawn_position()

func set_input_enabled(enabled: bool):
	if movement_controller:
		movement_controller.set_input_enabled(enabled)
	if camera_controller:
		camera_controller.set_input_enabled(enabled)
	if weapon_controller:
		weapon_controller.set_input_enabled(enabled)

# RPC methods (delegated to appropriate controllers)
@rpc("any_peer", "call_local")
func _sync_weapon_assignment(weapon_name: String):
	if weapon_controller:
		weapon_controller._sync_weapon_assignment(weapon_name)
# Add this RPC method to handle weapon visibility sync
@rpc("any_peer", "call_local")
func _sync_weapon_visibility(weapon_name: String, visible: bool):
	if has_node("PlayerWeapons"):
		var weapon_controller = get_node("PlayerWeapons")
		if weapon_controller.has_method("_sync_weapon_visibility"):
			weapon_controller._sync_weapon_visibility(weapon_name, visible)
@rpc("any_peer", "call_local", "reliable")
func _create_dropped_weapon(weapon_type: String, position: Vector3, direction: Vector3):
	if weapon_controller:
		weapon_controller._create_dropped_weapon(weapon_type, position, direction)

@rpc("unreliable_ordered", "any_peer")
func _receive_network_update(pos: Vector3, vel: Vector3, rot: Vector3, timestamp: float):
	if network_controller:
		network_controller._receive_network_update(pos, vel, rot, timestamp)
